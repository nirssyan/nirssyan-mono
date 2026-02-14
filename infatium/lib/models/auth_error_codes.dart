import '../l10n/generated/app_localizations.dart';

/// Error codes returned by AuthService instead of hardcoded strings.
/// The UI layer translates these codes into localized messages.
enum AuthErrorCode {
  // Sign-in errors
  invalidCredentials,
  emailNotConfirmed,
  invalidLoginData,
  invalidEmailFormat,
  tooManyAttempts,
  signInFailed,
  signInError,

  // Sign-up errors
  emailAlreadyRegistered,
  tooManySignUpAttempts,
  signUpFailed,
  signUpError,

  // Password validation
  passwordTooShort,
  passwordNeedsUppercase,
  passwordNeedsLowercase,
  passwordNeedsNumbers,
  passwordNeedsSpecialChars,

  // OAuth errors
  googleSignInCancelled,
  googleSignInFailed,
  googleNoIdToken,
  googleSignInError,
  appleSignInCancelled,
  appleSignInError,
  oauthCancelled,
  oauthError,
  oauthTimeout,

  // Session errors
  sessionRefreshFailed,
  sessionRefreshError,

  // Password reset
  passwordResetFailed,
  passwordResetError,

  // Password update
  passwordUpdateFailed,
  passwordUpdateError,

  // Profile update
  noDataToUpdate,
  profileUpdateFailed,
  profileUpdateError,

  // Account deletion
  notAuthenticated,
  accountDeleteFailed,
  accountDeleteError,

  // Magic link
  magicLinkInvalidEmail,
  magicLinkTooManyAttempts,
  magicLinkSendError,
  magicLinkError,

  // Demo login
  demoLoginMissingToken,
  demoLoginFailed,
  demoLoginConnectionError,

  // Email confirmation
  userNotFound,
  emailConfirmationError,

  // Generic
  networkError,
  unknownError,
}

/// Translates an [AuthErrorCode] into a localized string for display.
String translateAuthError(AuthErrorCode code, AppLocalizations l10n, {String? detail}) {
  switch (code) {
    // Sign-in
    case AuthErrorCode.invalidCredentials:
      return l10n.authErrorInvalidCredentials;
    case AuthErrorCode.emailNotConfirmed:
      return l10n.authErrorEmailNotConfirmed;
    case AuthErrorCode.invalidLoginData:
      return l10n.authErrorInvalidLoginData;
    case AuthErrorCode.invalidEmailFormat:
      return l10n.authErrorInvalidEmailFormat;
    case AuthErrorCode.tooManyAttempts:
      return l10n.authErrorTooManyAttempts;
    case AuthErrorCode.signInFailed:
      return l10n.authErrorSignInFailed;
    case AuthErrorCode.signInError:
      return l10n.authErrorSignInError;

    // Sign-up
    case AuthErrorCode.emailAlreadyRegistered:
      return l10n.authErrorEmailAlreadyRegistered;
    case AuthErrorCode.tooManySignUpAttempts:
      return l10n.authErrorTooManySignUpAttempts;
    case AuthErrorCode.signUpFailed:
      return l10n.authErrorSignUpFailed;
    case AuthErrorCode.signUpError:
      return l10n.authErrorSignUpError;

    // Password validation
    case AuthErrorCode.passwordTooShort:
      return l10n.authErrorPasswordTooShort;
    case AuthErrorCode.passwordNeedsUppercase:
      return l10n.authErrorPasswordNeedsUppercase;
    case AuthErrorCode.passwordNeedsLowercase:
      return l10n.authErrorPasswordNeedsLowercase;
    case AuthErrorCode.passwordNeedsNumbers:
      return l10n.authErrorPasswordNeedsNumbers;
    case AuthErrorCode.passwordNeedsSpecialChars:
      return l10n.authErrorPasswordNeedsSpecialChars;

    // OAuth
    case AuthErrorCode.googleSignInCancelled:
      return l10n.authErrorGoogleCancelled;
    case AuthErrorCode.googleSignInFailed:
      return l10n.authErrorGoogleFailed;
    case AuthErrorCode.googleNoIdToken:
      return l10n.authErrorGoogleNoIdToken;
    case AuthErrorCode.googleSignInError:
      return l10n.authErrorGoogleError;
    case AuthErrorCode.appleSignInCancelled:
      return l10n.authErrorAppleCancelled;
    case AuthErrorCode.appleSignInError:
      return l10n.authErrorAppleError;
    case AuthErrorCode.oauthCancelled:
      return l10n.authErrorOAuthCancelled;
    case AuthErrorCode.oauthError:
      return l10n.authErrorOAuthError;
    case AuthErrorCode.oauthTimeout:
      return l10n.authErrorOAuthTimeout;

    // Session
    case AuthErrorCode.sessionRefreshFailed:
      return l10n.authErrorSessionRefreshFailed;
    case AuthErrorCode.sessionRefreshError:
      return l10n.authErrorSessionRefreshError;

    // Password reset
    case AuthErrorCode.passwordResetFailed:
      return l10n.authErrorPasswordResetFailed;
    case AuthErrorCode.passwordResetError:
      return l10n.authErrorPasswordResetError;

    // Password update
    case AuthErrorCode.passwordUpdateFailed:
      return l10n.authErrorPasswordUpdateFailed;
    case AuthErrorCode.passwordUpdateError:
      return l10n.authErrorPasswordUpdateError;

    // Profile
    case AuthErrorCode.noDataToUpdate:
      return l10n.authErrorNoDataToUpdate;
    case AuthErrorCode.profileUpdateFailed:
      return l10n.authErrorProfileUpdateFailed;
    case AuthErrorCode.profileUpdateError:
      return l10n.authErrorProfileUpdateError;

    // Account deletion
    case AuthErrorCode.notAuthenticated:
      return l10n.authErrorNotAuthenticated;
    case AuthErrorCode.accountDeleteFailed:
      return l10n.authErrorAccountDeleteFailed;
    case AuthErrorCode.accountDeleteError:
      return l10n.authErrorAccountDeleteError;

    // Magic link
    case AuthErrorCode.magicLinkInvalidEmail:
      return l10n.authErrorInvalidEmailFormat;
    case AuthErrorCode.magicLinkTooManyAttempts:
      return l10n.authErrorTooManyAttempts;
    case AuthErrorCode.magicLinkSendError:
      return l10n.authErrorMagicLinkSendError;
    case AuthErrorCode.magicLinkError:
      return l10n.authErrorMagicLinkError;

    // Demo login
    case AuthErrorCode.demoLoginMissingToken:
      return l10n.authErrorDemoLoginMissingToken;
    case AuthErrorCode.demoLoginFailed:
      return l10n.authErrorDemoLoginFailed;
    case AuthErrorCode.demoLoginConnectionError:
      return l10n.authErrorDemoLoginConnectionError;

    // Email confirmation
    case AuthErrorCode.userNotFound:
      return l10n.authErrorUserNotFound;
    case AuthErrorCode.emailConfirmationError:
      return l10n.authErrorEmailConfirmationError;

    // Generic
    case AuthErrorCode.networkError:
      return l10n.authErrorNetworkError;
    case AuthErrorCode.unknownError:
      return l10n.authErrorUnknownError;
  }
}
