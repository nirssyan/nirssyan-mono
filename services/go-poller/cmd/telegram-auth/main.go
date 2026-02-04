package main

import (
	"bufio"
	"context"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/gotd/td/telegram"
	"github.com/gotd/td/telegram/auth"
	"github.com/gotd/td/tg"
	"golang.org/x/term"

	tgsession "github.com/MargoRSq/infatium-mono/services/go-poller/internal/telegram"
)

func main() {
	var (
		apiID       int
		apiHash     string
		phone       string
		sessionPath string
	)

	flag.IntVar(&apiID, "api-id", 0, "Telegram API ID")
	flag.StringVar(&apiHash, "api-hash", "", "Telegram API Hash")
	flag.StringVar(&phone, "phone", "", "Phone number (with country code, e.g., +79001234567)")
	flag.StringVar(&sessionPath, "session-path", "", "Path to session file (e.g., /app/.telegram/go_session)")
	flag.Parse()

	if apiID == 0 {
		apiID = getEnvInt("TELEGRAM_API_ID", 0)
	}
	if apiHash == "" {
		apiHash = os.Getenv("TELEGRAM_API_HASH")
	}
	if phone == "" {
		phone = os.Getenv("TELEGRAM_PHONE")
	}
	if sessionPath == "" {
		sessionPath = os.Getenv("TELEGRAM_SESSION_PATH")
		if sessionPath == "" {
			sessionPath = filepath.Join(os.Getenv("TELEGRAM_WORKDIR"), os.Getenv("TELEGRAM_SESSION_NAME"))
		}
	}

	if apiID == 0 || apiHash == "" || phone == "" || sessionPath == "" {
		fmt.Println("Usage: telegram-auth [flags]")
		fmt.Println()
		fmt.Println("Flags:")
		flag.PrintDefaults()
		fmt.Println()
		fmt.Println("Environment variables:")
		fmt.Println("  TELEGRAM_API_ID        - Telegram API ID")
		fmt.Println("  TELEGRAM_API_HASH      - Telegram API Hash")
		fmt.Println("  TELEGRAM_PHONE         - Phone number")
		fmt.Println("  TELEGRAM_SESSION_PATH  - Path to session file")
		fmt.Println("  TELEGRAM_WORKDIR       - Session directory (if SESSION_PATH not set)")
		fmt.Println("  TELEGRAM_SESSION_NAME  - Session name (if SESSION_PATH not set)")
		os.Exit(1)
	}

	dir := filepath.Dir(sessionPath)
	name := strings.TrimSuffix(filepath.Base(sessionPath), ".session")

	fmt.Printf("Telegram Auth Tool\n")
	fmt.Printf("==================\n")
	fmt.Printf("API ID:       %d\n", apiID)
	fmt.Printf("Phone:        %s\n", phone)
	fmt.Printf("Session path: %s\n", filepath.Join(dir, name+".session"))
	fmt.Println()

	if err := os.MkdirAll(dir, 0o700); err != nil {
		fmt.Printf("Error creating session directory: %v\n", err)
		os.Exit(1)
	}

	storage := tgsession.NewFileStorage(dir, name)

	if storage.Exists() {
		fmt.Printf("Session file already exists at %s\n", storage.Path())
		fmt.Print("Overwrite? [y/N]: ")
		reader := bufio.NewReader(os.Stdin)
		answer, _ := reader.ReadString('\n')
		answer = strings.TrimSpace(strings.ToLower(answer))
		if answer != "y" && answer != "yes" {
			fmt.Println("Aborted.")
			os.Exit(0)
		}
	}

	ctx := context.Background()

	client := telegram.NewClient(apiID, apiHash, telegram.Options{
		SessionStorage: storage,
	})

	codePrompt := &terminalCodePrompt{phone: phone}

	if err := client.Run(ctx, func(ctx context.Context) error {
		flow := auth.NewFlow(
			&terminalAuth{phone: phone, codePrompt: codePrompt},
			auth.SendCodeOptions{},
		)

		if err := client.Auth().IfNecessary(ctx, flow); err != nil {
			return fmt.Errorf("auth flow: %w", err)
		}

		status, err := client.Auth().Status(ctx)
		if err != nil {
			return fmt.Errorf("auth status: %w", err)
		}

		if !status.Authorized {
			return fmt.Errorf("not authorized after auth flow")
		}

		fmt.Println()
		fmt.Printf("✓ Successfully authenticated as %s (ID: %d)\n",
			formatUsername(status.User), status.User.ID)
		fmt.Printf("✓ Session saved to: %s\n", storage.Path())

		return nil
	}); err != nil {
		fmt.Printf("\nError: %v\n", err)
		os.Exit(1)
	}

	fmt.Println()
	fmt.Println("Done! You can now use this session file with go-poller.")
}

type terminalAuth struct {
	phone      string
	codePrompt *terminalCodePrompt
}

func (a *terminalAuth) Phone(_ context.Context) (string, error) {
	return a.phone, nil
}

func (a *terminalAuth) Password(_ context.Context) (string, error) {
	fmt.Print("Enter 2FA password: ")
	password, err := term.ReadPassword(int(os.Stdin.Fd()))
	fmt.Println()
	if err != nil {
		return "", fmt.Errorf("read password: %w", err)
	}
	return string(password), nil
}

func (a *terminalAuth) AcceptTermsOfService(_ context.Context, tos tg.HelpTermsOfService) error {
	fmt.Println("Accepting Terms of Service...")
	return nil
}

func (a *terminalAuth) SignUp(_ context.Context) (auth.UserInfo, error) {
	return auth.UserInfo{}, fmt.Errorf("sign up not supported, phone must be registered")
}

func (a *terminalAuth) Code(_ context.Context, _ *tg.AuthSentCode) (string, error) {
	return a.codePrompt.Code()
}

type terminalCodePrompt struct {
	phone string
}

func (p *terminalCodePrompt) Code() (string, error) {
	fmt.Printf("Code sent to %s\n", p.phone)
	fmt.Print("Enter code: ")

	reader := bufio.NewReader(os.Stdin)
	code, err := reader.ReadString('\n')
	if err != nil {
		return "", fmt.Errorf("read code: %w", err)
	}

	return strings.TrimSpace(code), nil
}

func getEnvInt(key string, defaultVal int) int {
	if v := os.Getenv(key); v != "" {
		var i int
		if _, err := fmt.Sscanf(v, "%d", &i); err == nil {
			return i
		}
	}
	return defaultVal
}

func formatUsername(user *tg.User) string {
	if user.Username != "" {
		return "@" + user.Username
	}
	name := user.FirstName
	if user.LastName != "" {
		name += " " + user.LastName
	}
	return name
}
