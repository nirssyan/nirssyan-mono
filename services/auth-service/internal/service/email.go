package service

import (
	"context"
	"fmt"

	"github.com/resend/resend-go/v2"
)

type EmailService struct {
	client     *resend.Client
	from       string
	appBaseURL string
}

func NewEmailService(apiKey, from, appBaseURL string) *EmailService {
	return &EmailService{
		client:     resend.NewClient(apiKey),
		from:       from,
		appBaseURL: appBaseURL,
	}
}

func (s *EmailService) SendMagicLink(ctx context.Context, email, token string) error {
	link := fmt.Sprintf("%s/auth/verify?token=%s", s.appBaseURL, token)
	logoURL := s.appBaseURL + "/auth/static/logo.png"

	htmlContent := fmt.Sprintf(`<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta name="color-scheme" content="dark only">
  <meta name="supported-color-schemes" content="dark only">
  <title>Вход по ссылке</title>
  <style>
    :root { color-scheme: dark only; supported-color-schemes: dark only; }
    /* Reset */
    body, table, td, a { -webkit-text-size-adjust: 100%%; -ms-text-size-adjust: 100%%; }
    table, td { mso-table-lspace: 0pt; mso-table-rspace: 0pt; }
    img { -ms-interpolation-mode: bicubic; border: 0; height: auto; line-height: 100%%; outline: none; text-decoration: none; }

    [data-ogsc] body, [data-ogsb] body { background-color: #0a0a0a !important; }
    [data-ogsc] .container, [data-ogsb] .container { background-color: #1a1a1a !important; }
    [data-ogsc] h1, [data-ogsb] h1 { color: #ffffff !important; }
    [data-ogsc] p, [data-ogsb] p { color: inherit !important; }

    @media (prefers-color-scheme: light) {
      body, .body-bg { background-color: #0a0a0a !important; }
      .container { background-color: #1a1a1a !important; }
      .footer-bg { background-color: #1e1e1e !important; }
      h1 { color: #ffffff !important; }
    }

    /* Responsive */
    @media only screen and (max-width: 600px) {
      .container { width: 100%% !important; }
      .header-logo { width: 80px !important; height: 80px !important; }
      .header-title { font-size: 24px !important; }
      .content { padding: 32px 24px !important; }
      .button { padding: 14px 32px !important; font-size: 15px !important; }
    }
  </style>
</head>
<body class="body-bg" style="margin: 0; padding: 0; background-color: #0a0a0a; color: #ffffff; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;">

  <!-- Wrapper -->
  <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%%" style="background-color: #0a0a0a;">
    <tr>
      <td style="padding: 40px 20px;">

        <!-- Container -->
        <table role="presentation" cellspacing="0" cellpadding="0" border="0" class="container" style="max-width: 600px; width: 100%%; margin: 0 auto; background-color: #1a1a1a; border: 1px solid #333333; border-radius: 16px;">

          <!-- Logo Header -->
          <tr>
            <td style="padding: 48px 40px 32px; text-align: center; border-bottom: 1px solid #333333;">
              <img src="%s"
                   alt="infatium"
                   class="header-logo"
                   style="width: 120px; height: 120px; display: inline-block; margin: 0 0 24px 0;" />
              <h1 class="header-title" style="margin: 0; font-size: 32px; font-weight: 700; color: #ffffff; letter-spacing: -0.5px;">
                infatium
              </h1>
              <p style="margin: 12px 0 0; font-size: 16px; color: #b0b0b0; line-height: 1.5;">
                Вход в аккаунт
              </p>
            </td>
          </tr>

          <!-- Content -->
          <tr>
            <td class="content" style="padding: 40px 40px 32px;">
              <p style="margin: 0 0 24px; font-size: 16px; color: #ffffff; line-height: 1.6;">
                Нажмите на кнопку ниже, чтобы войти в ваш аккаунт. Ссылка действительна в течение 15 минут.
              </p>

              <!-- CTA Button -->
              <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%%">
                <tr>
                  <td style="padding: 16px 0; text-align: center;">
                    <a href="%s"
                       class="button"
                       style="display: inline-block; padding: 16px 48px; background-color: #ffffff; color: #000000; text-decoration: none; border-radius: 12px; font-size: 16px; font-weight: 600; letter-spacing: 0.3px; border: 1px solid #ffffff;">
                      Войти в аккаунт
                    </a>
                  </td>
                </tr>
              </table>

              <!-- Alternative Link -->
              <p style="margin: 24px 0 0; font-size: 14px; color: #808080; line-height: 1.5; text-align: center;">
                Или <a href="%s" style="color: #b0b0b0; text-decoration: underline;">перейдите по этой ссылке</a>
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td class="footer-bg" style="padding: 32px 40px; background-color: #1e1e1e; border-top: 1px solid #333333; border-radius: 0 0 16px 16px;">
              <p style="margin: 0; font-size: 13px; color: #808080; line-height: 1.5; text-align: center;">
                Если вы не запрашивали вход, просто проигнорируйте это письмо.
              </p>
              <p style="margin: 12px 0 0; font-size: 12px; color: #666666; text-align: center;">
                © 2026 infatium. Все права защищены.
              </p>
            </td>
          </tr>

        </table>

      </td>
    </tr>
  </table>

</body>
</html>`, logoURL, link, link)

	textContent := fmt.Sprintf(`Вход в аккаунт infatium

Нажмите на ссылку ниже, чтобы войти в ваш аккаунт:

%s

Ссылка действительна в течение 15 минут.

Если вы не запрашивали вход, просто проигнорируйте это письмо.

© 2026 infatium. Все права защищены.`, link)

	params := &resend.SendEmailRequest{
		From:    s.from,
		To:      []string{email},
		Subject: "Вход в аккаунт",
		Html:    htmlContent,
		Text:    textContent,
	}

	_, err := s.client.Emails.SendWithContext(ctx, params)
	return err
}
