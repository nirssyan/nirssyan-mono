package service

import (
	"context"
	"errors"
	"net"
	"time"

	"github.com/google/uuid"
	"github.com/MargoRSq/infatium-mono/services/auth-service/internal/model"
	"github.com/MargoRSq/infatium-mono/services/auth-service/internal/repository"
	"github.com/rs/zerolog"
)

var (
	ErrTokenReuse            = errors.New("token reuse detected")
	ErrTokenAlreadyRefreshed = errors.New("token already refreshed")
	ErrTokenExpired          = errors.New("refresh token expired")
	ErrFamilyRevoked         = errors.New("token family revoked")
	ErrMagicLinkUsed         = errors.New("magic link already used")
	ErrMagicLinkExpired      = errors.New("magic link expired")
	ErrInvalidMagicLink      = errors.New("invalid magic link")
	ErrInvalidCredentials    = errors.New("invalid credentials")
)

const tokenReuseGracePeriod = 180 * time.Second

type AuthService struct {
	userRepo         *repository.UserRepository
	tokenFamilyRepo  *repository.TokenFamilyRepository
	refreshTokenRepo *repository.RefreshTokenRepository
	magicLinkRepo    *repository.MagicLinkRepository
	subscriptionRepo *repository.SubscriptionRepository

	jwtService    *JWTService
	googleService *GoogleService
	appleService  *AppleService
	emailService  *EmailService

	refreshTokenTTL time.Duration
	magicLinkTTL    time.Duration

	logger zerolog.Logger
}

func NewAuthService(
	userRepo *repository.UserRepository,
	tokenFamilyRepo *repository.TokenFamilyRepository,
	refreshTokenRepo *repository.RefreshTokenRepository,
	magicLinkRepo *repository.MagicLinkRepository,
	subscriptionRepo *repository.SubscriptionRepository,
	jwtService *JWTService,
	googleService *GoogleService,
	appleService *AppleService,
	emailService *EmailService,
	refreshTokenTTL, magicLinkTTL time.Duration,
	logger zerolog.Logger,
) *AuthService {
	return &AuthService{
		userRepo:         userRepo,
		tokenFamilyRepo:  tokenFamilyRepo,
		refreshTokenRepo: refreshTokenRepo,
		magicLinkRepo:    magicLinkRepo,
		subscriptionRepo: subscriptionRepo,
		jwtService:       jwtService,
		googleService:    googleService,
		appleService:     appleService,
		emailService:     emailService,
		refreshTokenTTL:  refreshTokenTTL,
		magicLinkTTL:     magicLinkTTL,
		logger:           logger,
	}
}

func (s *AuthService) AuthenticateGoogle(ctx context.Context, idToken string, deviceInfo *string, ipAddress net.IP) (*model.AuthResponse, error) {
	claims, err := s.googleService.ValidateIDToken(ctx, idToken)
	if err != nil {
		return nil, err
	}

	user, err := s.findOrCreateOAuthUser(ctx, "google", claims.Sub, claims.Email)
	if err != nil {
		return nil, err
	}

	return s.issueTokens(ctx, user, deviceInfo, ipAddress)
}

func (s *AuthService) AuthenticateApple(ctx context.Context, idToken string, deviceInfo *string, ipAddress net.IP) (*model.AuthResponse, error) {
	claims, err := s.appleService.ValidateIDToken(ctx, idToken)
	if err != nil {
		return nil, err
	}

	email := claims.Email
	if email == "" {
		email = claims.Sub + "@privaterelay.appleid.com"
	}

	user, err := s.findOrCreateOAuthUser(ctx, "apple", claims.Sub, email)
	if err != nil {
		return nil, err
	}

	return s.issueTokens(ctx, user, deviceInfo, ipAddress)
}

func (s *AuthService) AuthenticatePassword(ctx context.Context, email, password string, deviceInfo *string, ipAddress net.IP) (*model.AuthResponse, error) {
	user, err := s.userRepo.GetByEmail(ctx, email)
	if err != nil {
		if errors.Is(err, repository.ErrUserNotFound) {
			HashPassword("dummy-password-timing-pad")
			return nil, ErrInvalidCredentials
		}
		return nil, err
	}

	if user.PasswordHash == nil {
		HashPassword("dummy-password-timing-pad")
		return nil, ErrInvalidCredentials
	}

	match, err := VerifyPassword(password, *user.PasswordHash)
	if err != nil {
		return nil, err
	}
	if !match {
		return nil, ErrInvalidCredentials
	}

	return s.issueTokens(ctx, user, deviceInfo, ipAddress)
}

func (s *AuthService) SendMagicLink(ctx context.Context, email string) error {
	var userID *uuid.UUID
	user, err := s.userRepo.GetByEmail(ctx, email)
	if err == nil {
		userID = &user.ID
	} else if !errors.Is(err, repository.ErrUserNotFound) {
		return err
	}

	rawToken, err := GenerateSecureToken(32)
	if err != nil {
		return err
	}

	tokenHash := HashToken(rawToken)
	expiresAt := time.Now().Add(s.magicLinkTTL)

	_, err = s.magicLinkRepo.Create(ctx, email, tokenHash, userID, expiresAt)
	if err != nil {
		return err
	}

	return s.emailService.SendMagicLink(ctx, email, rawToken)
}

func (s *AuthService) VerifyMagicLink(ctx context.Context, token string, deviceInfo *string, ipAddress net.IP) (*model.AuthResponse, error) {
	tokenHash := HashToken(token)

	magicLink, err := s.magicLinkRepo.GetByHash(ctx, tokenHash)
	if err != nil {
		if errors.Is(err, repository.ErrMagicLinkNotFound) {
			return nil, ErrInvalidMagicLink
		}
		return nil, err
	}

	if magicLink.UsedAt != nil {
		return nil, ErrMagicLinkUsed
	}

	if time.Now().After(magicLink.ExpiresAt) {
		return nil, ErrMagicLinkExpired
	}

	if err := s.magicLinkRepo.MarkUsed(ctx, magicLink.ID); err != nil {
		return nil, err
	}

	var user *model.User
	if magicLink.UserID != nil {
		user, err = s.userRepo.GetByID(ctx, *magicLink.UserID)
		if err != nil {
			return nil, err
		}
	} else {
		user, err = s.userRepo.Create(ctx, magicLink.Email, "email", nil)
		if err != nil {
			return nil, err
		}

		if err := s.subscriptionRepo.EnsureFreeSubscription(ctx, user.ID); err != nil {
			s.logger.Warn().Err(err).Str("user_id", user.ID.String()).Msg("failed to create free subscription")
		}
	}

	if user.EmailVerifiedAt == nil {
		if err := s.userRepo.SetEmailVerified(ctx, user.ID); err != nil {
			return nil, err
		}
		now := time.Now()
		user.EmailVerifiedAt = &now
	}

	return s.issueTokens(ctx, user, deviceInfo, ipAddress)
}

func (s *AuthService) RefreshTokens(ctx context.Context, refreshToken string, deviceInfo *string, ipAddress net.IP) (*model.AuthResponse, error) {
	tokenHash := HashToken(refreshToken)

	rt, err := s.refreshTokenRepo.GetByHash(ctx, tokenHash)
	if err != nil {
		if errors.Is(err, repository.ErrRefreshTokenNotFound) {
			return nil, ErrInvalidToken
		}
		return nil, err
	}

	family, err := s.tokenFamilyRepo.GetByID(ctx, rt.FamilyID)
	if err != nil {
		return nil, err
	}

	if family.Revoked {
		s.logger.Warn().
			Str("user_id", rt.UserID.String()).
			Str("family_id", rt.FamilyID.String()).
			Msg("attempt to use token from revoked family")
		return nil, ErrFamilyRevoked
	}

	if rt.Used {
		if rt.UsedAt != nil && time.Since(*rt.UsedAt) < tokenReuseGracePeriod {
			s.logger.Info().
				Str("token_id", rt.ID.String()).
				Str("family_id", rt.FamilyID.String()).
				Dur("since_used", time.Since(*rt.UsedAt)).
				Msg("token reuse within grace period - not revoking")
			return nil, ErrTokenAlreadyRefreshed
		}

		s.logger.Warn().
			Str("user_id", rt.UserID.String()).
			Str("family_id", rt.FamilyID.String()).
			Str("token_id", rt.ID.String()).
			Msg("token reuse detected - revoking family")

		if err := s.tokenFamilyRepo.Revoke(ctx, rt.FamilyID, "token_reuse"); err != nil {
			s.logger.Error().Err(err).Msg("failed to revoke token family")
		}

		return nil, ErrTokenReuse
	}

	if time.Now().After(rt.ExpiresAt) {
		return nil, ErrTokenExpired
	}

	if err := s.refreshTokenRepo.MarkUsed(ctx, rt.ID); err != nil {
		return nil, err
	}

	user, err := s.userRepo.GetByID(ctx, rt.UserID)
	if err != nil {
		return nil, err
	}

	accessToken, err := s.jwtService.GenerateAccessToken(user.ID, user.Email)
	if err != nil {
		return nil, err
	}

	newRefreshToken, newTokenHash, err := GenerateRefreshToken()
	if err != nil {
		return nil, err
	}

	expiresAt := time.Now().Add(s.refreshTokenTTL)
	_, err = s.refreshTokenRepo.Create(ctx, newTokenHash, user.ID, rt.FamilyID, expiresAt, deviceInfo, ipAddress)
	if err != nil {
		return nil, err
	}

	return &model.AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: newRefreshToken,
		ExpiresIn:    int(s.jwtService.AccessTTL().Seconds()),
		TokenType:    "Bearer",
	}, nil
}

func (s *AuthService) Logout(ctx context.Context, refreshToken string) error {
	tokenHash := HashToken(refreshToken)

	rt, err := s.refreshTokenRepo.GetByHash(ctx, tokenHash)
	if err != nil {
		if errors.Is(err, repository.ErrRefreshTokenNotFound) {
			return nil
		}
		return err
	}

	return s.tokenFamilyRepo.Revoke(ctx, rt.FamilyID, "logout")
}

func (s *AuthService) findOrCreateOAuthUser(ctx context.Context, provider, providerID, email string) (*model.User, error) {
	user, err := s.userRepo.GetByProviderID(ctx, provider, providerID)
	if err == nil {
		return user, nil
	}

	if !errors.Is(err, repository.ErrUserNotFound) {
		return nil, err
	}

	user, err = s.userRepo.GetByEmail(ctx, email)
	if err == nil {
		if err := s.userRepo.UpdateProvider(ctx, user.ID, provider, &providerID); err != nil {
			return nil, err
		}
		user.Provider = provider
		user.ProviderID = &providerID
		return user, nil
	}

	if !errors.Is(err, repository.ErrUserNotFound) {
		return nil, err
	}

	user, err = s.userRepo.Create(ctx, email, provider, &providerID)
	if err != nil {
		return nil, err
	}

	if err := s.subscriptionRepo.EnsureFreeSubscription(ctx, user.ID); err != nil {
		s.logger.Warn().Err(err).Str("user_id", user.ID.String()).Msg("failed to create free subscription")
	}

	return user, nil
}

func (s *AuthService) issueTokens(ctx context.Context, user *model.User, deviceInfo *string, ipAddress net.IP) (*model.AuthResponse, error) {
	accessToken, err := s.jwtService.GenerateAccessToken(user.ID, user.Email)
	if err != nil {
		return nil, err
	}

	family, err := s.tokenFamilyRepo.Create(ctx, user.ID)
	if err != nil {
		return nil, err
	}

	refreshToken, tokenHash, err := GenerateRefreshToken()
	if err != nil {
		return nil, err
	}

	expiresAt := time.Now().Add(s.refreshTokenTTL)
	_, err = s.refreshTokenRepo.Create(ctx, tokenHash, user.ID, family.ID, expiresAt, deviceInfo, ipAddress)
	if err != nil {
		return nil, err
	}

	return &model.AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    int(s.jwtService.AccessTTL().Seconds()),
		TokenType:    "Bearer",
		User:         user,
	}, nil
}
