import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import '../services/auth_service.dart';
import '../services/locale_service.dart';
import '../models/auth_error_codes.dart';
import '../theme/colors.dart';
import '../l10n/generated/app_localizations.dart';
import '../widgets/email_sent_modal.dart';
import 'package:url_launcher/url_launcher.dart';

enum AuthMode {
  signIn,               // Страница 0
  signUp,               // Страница 1
  forgotPasswordEmail,  // Страница 2 - ввод email для сброса
  resetPassword,        // Страница 3 - ввод нового пароля
  magicLinkEmail,       // Страница 4 - ввод email для magic link
  magicLinkSent         // Страница 5 - подтверждение отправки magic link
}

class AuthPage extends StatefulWidget {
  final LocaleService localeService;

  // GlobalKey для доступа к состоянию извне
  static final GlobalKey<_AuthPageState> globalKey = GlobalKey<_AuthPageState>();

  const AuthPage({super.key, required this.localeService});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

// Кастомный painter для Apple логотипа
class AppleLogoPainter extends CustomPainter {
  final Color color;
  
  AppleLogoPainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final path = Path();
    final w = size.width;
    final h = size.height;
    
    // Рисуем упрощенный Apple логотип, масштабированный ближе к краям контейнера
    // Яблоко (увеличено по высоте и ширине для визуального соответствия Google-иконке)
    path.moveTo(w * 0.5, h * 0.10);
    path.cubicTo(w * 0.78, h * 0.10, w * 0.88, h * 0.34, w * 0.88, h * 0.56);
    path.cubicTo(w * 0.88, h * 0.78, w * 0.78, h * 0.90, w * 0.5, h * 0.90);
    path.cubicTo(w * 0.22, h * 0.90, w * 0.12, h * 0.78, w * 0.12, h * 0.56);
    path.cubicTo(w * 0.12, h * 0.34, w * 0.22, h * 0.10, w * 0.5, h * 0.10);
    path.close();
    
    // Листик
    path.moveTo(w * 0.56, h * 0.02);
    path.cubicTo(w * 0.66, h * 0.02, w * 0.72, h * 0.08, w * 0.72, h * 0.14);
    path.cubicTo(w * 0.72, h * 0.20, w * 0.66, h * 0.22, w * 0.56, h * 0.22);
    path.cubicTo(w * 0.50, h * 0.18, w * 0.50, h * 0.12, w * 0.56, h * 0.02);
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AnimatedButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color? backgroundColor;

  const _AnimatedButton({
    required this.onPressed,
    required this.child,
    this.backgroundColor,
  });

  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).scaffoldBackgroundColor == CupertinoColors.black;
    
    return GestureDetector(
      onTapDown: widget.onPressed != null ? (_) {
        setState(() {
          _isPressed = true;
        });
      } : null,
      onTapUp: widget.onPressed != null ? (_) {
        setState(() {
          _isPressed = false;
        });
      } : null,
      onTapCancel: () {
        setState(() {
          _isPressed = false;
        });
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? (isDark ? CupertinoColors.white : CupertinoColors.black),
            borderRadius: BorderRadius.circular(12),
            boxShadow: _isPressed ? [] : [
              BoxShadow(
                color: CupertinoColors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: CupertinoButton(
            onPressed: widget.onPressed,
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _AuthPageState extends State<AuthPage> {
  AuthMode _currentMode = AuthMode.signIn;
  late PageController _pageController;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  bool _isMagicLinkLoading = false;
  String? _errorMessage;
  bool _agreedToTerms = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Для reset password
  final _newPasswordController = TextEditingController();
  final _confirmNewPasswordController = TextEditingController();
  final bool _obscureNewPassword = true;
  final bool _obscureConfirmNewPassword = true;

  // Для magic link resend cooldown
  int? _resendCooldownSeconds;
  Timer? _resendTimer;
  String _sentEmailAddress = '';

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  /// Translates an AuthResult error code to a localized string for display.
  String? _translateError(AuthResult result) {
    final l10n = AppLocalizations.of(context)!;
    if (result.errorCode != null) {
      return translateAuthError(result.errorCode!, l10n);
    }
    return result.error;
  }

  // Публичный метод для переключения в режим reset password извне
  void switchToResetPassword() {
    setState(() {
      _currentMode = AuthMode.resetPassword;
      _errorMessage = null;
    });
    _pageController.animateToPage(
      2,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _toggleMode() {
    AuthMode newMode;

    // Определяем новый режим
    if (_currentMode == AuthMode.signIn) {
      newMode = AuthMode.signUp; // Sign In → Sign Up
    } else if (_currentMode == AuthMode.signUp) {
      newMode = AuthMode.signIn; // Sign Up → Sign In
    } else {
      // From forgotPasswordEmail or resetPassword → back to Sign In
      newMode = AuthMode.signIn;
    }

    // Для signIn ↔ signUp: только setState (без slide анимации)
    // Для других переходов: используем _switchToPage (slide анимация)
    if ((_currentMode == AuthMode.signIn && newMode == AuthMode.signUp) ||
        (_currentMode == AuthMode.signUp && newMode == AuthMode.signIn)) {
      // Переключение внутри одной страницы - только setState
      setState(() {
        _currentMode = newMode;
        _errorMessage = null;
        _clearFields();
      });
    } else {
      // Переход на другую страницу - используем _switchToPage
      setState(() {
        _errorMessage = null;
        _clearFields();
      });
      _switchToPage(newMode);
    }
  }

  void _clearFields() {
    _emailController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    _newPasswordController.clear();
    _confirmNewPasswordController.clear();
  }

  Future<void> _authenticate() async {
    final l10n = AppLocalizations.of(context)!;

    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = l10n.fillAllFields;
      });
      return;
    }

    // Простая валидация email
    if (!_emailController.text.contains('@')) {
      setState(() {
        _errorMessage = l10n.enterValidEmail;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = AuthService();
    AuthResult result;

    if (_currentMode == AuthMode.signIn) {
      result = await authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } else {
      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() {
          _isLoading = false;
          _errorMessage = l10n.passwordsDoNotMatch;
        });
        return;
      }

      result = await authService.createUserWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
    }

    setState(() {
      _isLoading = false;
      if (!result.success) {
        _errorMessage = _translateError(result);
      }
    });
  }

  Future<void> _resetPassword() async {
    final l10n = AppLocalizations.of(context)!;

    if (_newPasswordController.text.isEmpty || _confirmNewPasswordController.text.isEmpty) {
      setState(() {
        _errorMessage = l10n.fillAllFields;
      });
      return;
    }

    if (_newPasswordController.text != _confirmNewPasswordController.text) {
      setState(() {
        _errorMessage = l10n.passwordsDoNotMatch;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = AuthService();
    final result = await authService.updatePassword(_newPasswordController.text);

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      if (result.success) {
        // Show success dialog
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text(l10n.success),
            content: Text(l10n.passwordChangedSuccessfully),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () {
                  Navigator.of(context).pop();
                  _toggleMode(); // Return to sign in
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        setState(() {
          _errorMessage = _translateError(result);
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    final l10n = AppLocalizations.of(context)!;

    // Check if user agreed to terms
    if (!_agreedToTerms) {
      setState(() {
        _errorMessage = l10n.mustAgreeToTerms;
      });
      return;
    }

    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    final authService = AuthService();
    final result = await authService.signInWithGoogle();

    // Guard against setState on disposed widget
    if (!mounted) return;

    setState(() {
      _isGoogleLoading = false;
      if (!result.success) {
        _errorMessage = _translateError(result);
      }
    });
  }

  Future<void> _signInWithApple() async {
    final l10n = AppLocalizations.of(context)!;

    // Check if user agreed to terms
    if (!_agreedToTerms) {
      setState(() {
        _errorMessage = l10n.mustAgreeToTerms;
      });
      return;
    }

    setState(() {
      _isAppleLoading = true;
      _errorMessage = null;
    });

    final authService = AuthService();
    final result = await authService.signInWithApple();

    // Guard against setState on disposed widget
    if (!mounted) return;

    setState(() {
      _isAppleLoading = false;
      if (!result.success) {
        _errorMessage = _translateError(result);
      }
    });
  }

  Future<void> _sendMagicLink() async {
    final l10n = AppLocalizations.of(context)!;

    // Check if user agreed to terms
    if (!_agreedToTerms) {
      setState(() {
        _errorMessage = l10n.mustAgreeToTerms;
      });
      return;
    }

    if (_emailController.text.isEmpty) {
      setState(() {
        _errorMessage = l10n.enterValidEmail;
      });
      return;
    }

    if (!_emailController.text.contains('@')) {
      setState(() {
        _errorMessage = l10n.enterValidEmail;
      });
      return;
    }

    setState(() {
      _isMagicLinkLoading = true;
      _errorMessage = null;
    });

    final authService = AuthService();
    final result = await authService.signInWithMagicLink(_emailController.text);

    setState(() {
      _isMagicLinkLoading = false;
    });

    if (result.success && mounted) {
      // Сохраняем email для повторной отправки
      _sentEmailAddress = _emailController.text.trim();

      // Запускаем таймер cooldown
      _startResendCooldown();

      // Скрываем клавиатуру
      FocusScope.of(context).unfocus();

      // Переходим на страницу подтверждения
      _switchToPage(AuthMode.magicLinkSent);
    } else if (!result.success) {
      setState(() {
        _errorMessage = _translateError(result);
      });
    }
  }

  /// Запускает таймер обратного отсчета для повторной отправки magic link
  void _startResendCooldown() {
    setState(() {
      _resendCooldownSeconds = 60;
    });

    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_resendCooldownSeconds! > 0) {
          _resendCooldownSeconds = _resendCooldownSeconds! - 1;
        } else {
          _resendTimer?.cancel();
          _resendCooldownSeconds = null;
        }
      });
    });
  }

  /// Повторно отправляет magic link на сохраненный email
  Future<void> _resendMagicLink() async {
    if (_resendCooldownSeconds != null) {
      // Таймер еще не истек
      return;
    }

    setState(() {
      _isMagicLinkLoading = true;
      _errorMessage = null;
    });

    final authService = AuthService();
    final result = await authService.signInWithMagicLink(_sentEmailAddress);

    setState(() {
      _isMagicLinkLoading = false;
    });

    if (result.success && mounted) {
      // Перезапускаем таймер
      _startResendCooldown();

      // Показываем небольшое уведомление об успехе (опционально)
      // Можно оставить тихо, чтобы не отвлекать пользователя
    } else if (!result.success) {
      setState(() {
        _errorMessage = _translateError(result);
      });
    }
  }

  /// Отправляет email для сброса пароля (используется из forgotPasswordEmail page)
  Future<void> _sendResetEmail() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();

    // Валидация email
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = l10n.enterValidEmail;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = AuthService();
    final resetResult = await authService.resetPassword(email);

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      if (resetResult.success) {
        // Показываем success modal
        await showCupertinoModalPopup(
          context: context,
          builder: (context) => EmailSentModal(
            title: l10n.resetPasswordSuccess,
            message: l10n.resetPasswordSuccessMessage,
          ),
        );

        // Возвращаемся на страницу входа после закрытия модала
        if (mounted) {
          _switchToPage(AuthMode.signIn);
        }
      } else {
        setState(() {
          _errorMessage = resetResult.errorCode != null
              ? translateAuthError(resetResult.errorCode!, l10n)
              : resetResult.error;
        });
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String placeholder,
    bool obscureText = false,
    TextInputType? keyboardType,
    List<String>? autofillHints,
  }) {
    final isDark = CupertinoTheme.of(context).scaffoldBackgroundColor == CupertinoColors.black;

    return FocusableActionDetector(
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: isDark ? AppColors.surface : CupertinoColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isFocused
                    ? (isDark ? CupertinoColors.white : CupertinoColors.black)
                    : (isDark ? AppColors.accentSecondary : AppColors.lightAccentSecondary),
                width: isFocused ? 2 : 1,
              ),
              boxShadow: isFocused ? [
                BoxShadow(
                  color: (isDark ? CupertinoColors.white : CupertinoColors.black).withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: CupertinoTextField(
              controller: controller,
              placeholder: placeholder,
              obscureText: obscureText,
              keyboardType: keyboardType,
              autofillHints: autofillHints,
              textInputAction: keyboardType == TextInputType.emailAddress
                  ? TextInputAction.next
                  : (placeholder.toLowerCase().contains('confirm')
                      ? TextInputAction.done
                      : TextInputAction.done),
              onSubmitted: (_) {
                if (keyboardType == TextInputType.emailAddress) {
                  // Переходим к следующему полю (password)
                  FocusScope.of(context).nextFocus();
                } else {
                  // Отправляем форму
                  if (!_isLoading && !_isGoogleLoading) {
                    _authenticate();
                  }
                }
              },
              padding: const EdgeInsets.all(16),
              decoration: null,
              cursorColor: isDark ? CupertinoColors.white : CupertinoColors.black,
              style: TextStyle(
                color: isDark ? CupertinoColors.white : CupertinoColors.black,
                fontSize: 16,
              ),
              placeholderStyle: TextStyle(
                color: isDark ? CupertinoColors.systemGrey : CupertinoColors.systemGrey2,
                fontSize: 16,
              ),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGoogleSignInButton(bool isDark) {
    return _AnimatedButton(
      onPressed: _isGoogleLoading || _isLoading || _isAppleLoading ? null : _signInWithGoogle,
      backgroundColor: isDark ? CupertinoColors.white : AppColors.lightSurface,
      child: _isGoogleLoading
          ? const CupertinoActivityIndicator(
              color: CupertinoColors.black,
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Image.asset(
                    'assets/icons/google.png',
                    width: 18,
                    height: 18,
                  ),
                ),
                const Text(
                  'Google',
                  style: TextStyle(
                    color: CupertinoColors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAppleSignInButton(bool isDark) {
    // Визуально совпадает с кнопкой Google, но с корректным логотипом Apple
    return _AnimatedButton(
      onPressed: _isAppleLoading || _isLoading || _isGoogleLoading ? null : _signInWithApple,
      backgroundColor: isDark ? CupertinoColors.white : AppColors.lightSurface,
      child: _isAppleLoading
          ? const CupertinoActivityIndicator(color: CupertinoColors.black)
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Image.asset(
                    'assets/icons/apple.png',
                    width: 18,
                    height: 18,
                  ),
                ),
                const Text(
                  'Apple',
                  style: TextStyle(
                    color: CupertinoColors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }

  // Removed: inline logo builder is no longer used since we use a dedicated widget

  Widget _buildTermsCheckbox(AppLocalizations l10n, bool isDark) {
    final textColor = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final linkColor = isDark ? AppColors.accent : AppColors.lightAccent;

    return GestureDetector(
      onTap: () {
        setState(() {
          _agreedToTerms = !_agreedToTerms;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: _agreedToTerms
                  ? (isDark ? CupertinoColors.white : CupertinoColors.black)
                  : Colors.transparent,
              border: Border.all(
                color: _agreedToTerms
                    ? (isDark ? CupertinoColors.white : CupertinoColors.black)
                    : textColor,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: _agreedToTerms
                ? Icon(
                    CupertinoIcons.check_mark,
                    size: 14,
                    color: isDark ? CupertinoColors.black : CupertinoColors.white,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          // Text with clickable links
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  l10n.agreeToTermsPrefix,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    final url = Uri.parse('https://infatium.ru/consent');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Text(
                    l10n.termsOfService,
                    style: TextStyle(
                      color: linkColor,
                      fontSize: 13,
                      height: 1.4,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                Text(
                  l10n.andText,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    final url = Uri.parse('https://infatium.ru/privacy');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Text(
                    l10n.privacyPolicy,
                    style: TextStyle(
                      color: linkColor,
                      fontSize: 13,
                      height: 1.4,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== PAGE BUILDERS FOR PAGEVIEW ==========

  /// Главная страница: OAuth кнопки + email поле (все на одном экране)
  Widget _buildSignInSignUpPage(AppLocalizations l10n, bool isDark, bool keyboardVisible, double screenHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // OAuth Sign In Buttons
        if (Platform.isIOS || Platform.isMacOS)
          // iOS/macOS: Google + Apple side by side
          Row(
            children: [
              Expanded(child: _buildGoogleSignInButton(isDark)),
              const SizedBox(width: 12),
              Expanded(child: _buildAppleSignInButton(isDark)),
            ],
          )
        else
          // Android / Web: only Google full width
          _buildGoogleSignInButton(isDark),

        const SizedBox(height: 16),

        // Divider "OR"
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                color: isDark ? AppColors.accentSecondary : AppColors.lightAccentSecondary,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.or,
                style: TextStyle(
                  color: isDark ? CupertinoColors.systemGrey : CupertinoColors.systemGrey2,
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                color: isDark ? AppColors.accentSecondary : AppColors.lightAccentSecondary,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Email field
        AutofillGroup(
          child: _buildTextField(
            controller: _emailController,
            placeholder: l10n.enterYourEmail,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
          ),
        ),

        const SizedBox(height: 16),

        // Continue with email button
        _AnimatedButton(
          onPressed: _isMagicLinkLoading || _isLoading || _isGoogleLoading || _isAppleLoading
              ? null
              : _sendMagicLink,
          backgroundColor: isDark ? CupertinoColors.white : CupertinoColors.black,
          child: _isMagicLinkLoading
              ? CupertinoActivityIndicator(
                  color: isDark ? CupertinoColors.black : CupertinoColors.white,
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.envelope_fill,
                      color: isDark ? CupertinoColors.black : CupertinoColors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.continueWithEmail,
                      style: TextStyle(
                        color: isDark ? CupertinoColors.black : CupertinoColors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),

        const SizedBox(height: 16),

        // Terms and Privacy checkbox
        _buildTermsCheckbox(l10n, isDark),
      ],
    );
  }

  /// Страница 1: Ввод email для сброса пароля
  Widget _buildForgotPasswordEmailPage(AppLocalizations l10n, bool isDark, bool keyboardVisible, double screenHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // AutofillGroup для email поля
        AutofillGroup(
          child: _buildTextField(
            controller: _emailController,
            placeholder: l10n.email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
          ),
        ),
        const SizedBox(height: 16),

        // Информационный текст
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            l10n.enterEmailToReset,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? CupertinoColors.systemGrey : CupertinoColors.systemGrey2,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  /// Страница: Ввод email для Magic Link
  Widget _buildMagicLinkEmailPage(AppLocalizations l10n, bool isDark, bool keyboardVisible, double screenHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // AutofillGroup для email поля
        AutofillGroup(
          child: _buildTextField(
            controller: _emailController,
            placeholder: l10n.email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
          ),
        ),
        const SizedBox(height: 16),

        // Информационный текст
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            l10n.magicLinkDescription ?? 'Мы отправим вам ссылку для входа на email',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? CupertinoColors.systemGrey : CupertinoColors.systemGrey2,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  /// Страница: Подтверждение отправки Magic Link
  Widget _buildMagicLinkSentPage(AppLocalizations l10n, bool isDark, bool keyboardVisible, double screenHeight) {
    final accentColor = isDark ? AppColors.accent : AppColors.lightAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Анимированная иконка конверта
        Center(
          child: _EmailSentAnimation(accentColor: accentColor),
        ),

        const SizedBox(height: 24),

        // Основное сообщение
        Text(
          l10n.magicLinkSentToEmail,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDark ? CupertinoColors.white : CupertinoColors.black,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 12),

        // Инструкция
        Text(
          l10n.clickLinkToSignIn,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? CupertinoColors.systemGrey : CupertinoColors.systemGrey2,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 24),

        // Предупреждение о спаме
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accentColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                CupertinoIcons.info_circle,
                color: accentColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.cantFindEmail,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? CupertinoColors.white : CupertinoColors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.checkSpamFolder,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? CupertinoColors.systemGrey : CupertinoColors.systemGrey2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Кнопка "Отправить повторно"
        _AnimatedButton(
          onPressed: _resendCooldownSeconds == null && !_isMagicLinkLoading
              ? _resendMagicLink
              : null,
          backgroundColor: isDark ? CupertinoColors.white : CupertinoColors.black,
          child: _isMagicLinkLoading
              ? CupertinoActivityIndicator(
                  color: isDark ? CupertinoColors.black : CupertinoColors.white,
                )
              : Text(
                  _resendCooldownSeconds != null
                      ? l10n.resendEmailIn(_resendCooldownSeconds!)
                      : l10n.resendEmail,
                  style: TextStyle(
                    color: isDark ? CupertinoColors.black : CupertinoColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),

        const SizedBox(height: 16),

        // Кнопка "Назад"
        CupertinoButton(
          onPressed: () => _switchToPage(AuthMode.signIn),
          child: Text(
            l10n.backToSignIn,
            style: TextStyle(
              color: isDark ? CupertinoColors.white : CupertinoColors.black,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Страница 2: Ввод нового пароля (reset password)
  Widget _buildResetPasswordPage(AppLocalizations l10n, bool isDark, bool keyboardVisible, double screenHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // AutofillGroup для password полей
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // New password field
              _buildTextField(
                controller: _newPasswordController,
                placeholder: l10n.newPassword,
                obscureText: _obscureNewPassword,
                autofillHints: const [AutofillHints.newPassword],
              ),
              const SizedBox(height: 16),

              // Confirm new password field
              _buildTextField(
                controller: _confirmNewPasswordController,
                placeholder: l10n.confirmPassword,
                obscureText: _obscureConfirmNewPassword,
                autofillHints: const [AutofillHints.newPassword],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Password requirements hint
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            l10n.passwordRequirements,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? CupertinoColors.systemGrey : CupertinoColors.systemGrey2,
            ),
          ),
        ),
      ],
    );
  }

  /// Возвращает заголовок в зависимости от текущего режима
  String _getTitle(AppLocalizations l10n) {
    switch (_currentMode) {
      case AuthMode.signIn:
        return l10n.signIn;
      case AuthMode.signUp:
        return l10n.registration;
      case AuthMode.forgotPasswordEmail:
        return l10n.resetPassword;
      case AuthMode.resetPassword:
        return l10n.createNewPassword;
      case AuthMode.magicLinkEmail:
        return l10n.signInWithMagicLink ?? 'Войти по ссылке';
      case AuthMode.magicLinkSent:
        return l10n.checkYourEmail;
    }
  }

  /// Возвращает подзаголовок в зависимости от текущего режима
  String _getSubtitle(AppLocalizations l10n) {
    switch (_currentMode) {
      case AuthMode.signIn:
        return l10n.signInToAccount;
      case AuthMode.signUp:
        return l10n.createNewAccount;
      case AuthMode.forgotPasswordEmail:
        return l10n.enterEmailToReset;
      case AuthMode.resetPassword:
        return l10n.enterNewPasswordBelow;
      case AuthMode.magicLinkEmail:
        return l10n.magicLinkDescription ?? 'Введите email для получения ссылки';
      case AuthMode.magicLinkSent:
        return ''; // Детали на самой странице
    }
  }

  /// Возвращает текст главной кнопки действия
  String _getMainButtonText(AppLocalizations l10n) {
    switch (_currentMode) {
      case AuthMode.signIn:
        return l10n.signIn;
      case AuthMode.signUp:
        return l10n.signUp;
      case AuthMode.forgotPasswordEmail:
        return l10n.send;
      case AuthMode.resetPassword:
        return l10n.resetPassword;
      case AuthMode.magicLinkEmail:
        return l10n.send;
      case AuthMode.magicLinkSent:
        return ''; // Не используется, кнопки на странице строятся отдельно
    }
  }

  /// Возвращает главное действие для текущего режима
  VoidCallback _getMainAction() {
    switch (_currentMode) {
      case AuthMode.signIn:
      case AuthMode.signUp:
        return _authenticate;
      case AuthMode.forgotPasswordEmail:
        return _sendResetEmail;
      case AuthMode.resetPassword:
        return _resetPassword;
      case AuthMode.magicLinkEmail:
        return _sendMagicLink;
      case AuthMode.magicLinkSent:
        return () {}; // Не используется, действия на странице обрабатываются отдельно
    }
  }

  /// Вычисляет высоту PageView в зависимости от текущей страницы
  double _calculatePageHeight() {
    switch (_currentMode) {
      case AuthMode.signIn:
      case AuthMode.signUp:
        return 300.0; // OAuth кнопки + divider + email поле + кнопка (все на одном экране)
      case AuthMode.forgotPasswordEmail:
        return 150.0; // Email field + info text
      case AuthMode.resetPassword:
        return 250.0; // New password + confirm + requirements hint
      case AuthMode.magicLinkEmail:
        return 150.0; // Email field + info text (как Forgot Password)
      case AuthMode.magicLinkSent:
        return 500.0; // Icon + texts + warning box + buttons
    }
  }

  /// Хелпер для переключения между страницами
  void _switchToPage(AuthMode mode) {
    int pageIndex;
    switch (mode) {
      case AuthMode.signIn:
      case AuthMode.signUp:
        pageIndex = 0;  // Sign In и Sign Up на одной странице
        break;
      case AuthMode.forgotPasswordEmail:
        pageIndex = 1;
        break;
      case AuthMode.resetPassword:
        pageIndex = 2;
        break;
      case AuthMode.magicLinkEmail:
        pageIndex = 3;
        break;
      case AuthMode.magicLinkSent:
        pageIndex = 4;
        break;
    }

    setState(() {
      _currentMode = mode;
      _errorMessage = null;
    });

    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = CupertinoTheme.of(context).scaffoldBackgroundColor == CupertinoColors.black;

    // Получаем высоту экрана и клавиатуры для адаптивной верстки
    final mediaQuery = MediaQuery.of(context);
    final keyboardVisible = mediaQuery.viewInsets.bottom > 0;
    final screenHeight = mediaQuery.size.height;

    return CupertinoPageScaffold(
      backgroundColor: isDark ? AppColors.background : CupertinoColors.white,
      resizeToAvoidBottomInset: true,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            Widget scrollView = SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.only(
                bottom: mediaQuery.viewInsets.bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Адаптивный верхний отступ
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          height: keyboardVisible 
                              ? 20 
                              : screenHeight * 0.08,
                        ),
                        
                        // App Icon/Logo с AAA 3D анимацией при смене режима
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          height: (keyboardVisible || _currentMode == AuthMode.magicLinkSent) ? 0 : 150,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            opacity: (keyboardVisible || _currentMode == AuthMode.magicLinkSent) ? 0.0 : 1.0,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 350),
                              switchInCurve: Curves.easeInOut,
                              switchOutCurve: Curves.easeInOut,
                              transitionBuilder: (Widget child, Animation<double> animation) {
                                // Минималистичная анимация: простой fade + scale
                                final scaleAnimation = Tween<double>(
                                  begin: 0.95,
                                  end: 1.0,
                                ).animate(CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeInOut,
                                ));

                                return FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(
                                    scale: scaleAnimation,
                                    child: child,
                                  ),
                                );
                              },
                              child: _currentMode == AuthMode.signIn
                                  // Logo для Sign In экрана
                                  ? Image.asset(
                                      key: const ValueKey('logo'),
                                      isDark
                                          ? 'newlogo/infatiumv5.png'
                                          : 'newlogo/infatiumv5light.png',
                                      width: 150,
                                      height: 150,
                                      fit: BoxFit.contain,
                                    )
                                  // Иконки для других режимов
                                  : Icon(
                                      key: ValueKey(_currentMode),
                                      _currentMode == AuthMode.signUp
                                        ? CupertinoIcons.person_badge_plus_fill
                                        : (_currentMode == AuthMode.forgotPasswordEmail
                                            ? CupertinoIcons.lock_rotation
                                            : (_currentMode == AuthMode.resetPassword
                                                ? CupertinoIcons.lock_shield_fill
                                                : CupertinoIcons.envelope_fill)),
                                      size: 150,
                                      color: isDark ? CupertinoColors.white : CupertinoColors.black,
                                    ),
                            ),
                          ),
                        ),
                        
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          height: keyboardVisible ? 0 : 20,
                        ),
                        
                        // Title с плавным изменением размера
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          style: TextStyle(
                            fontSize: keyboardVisible ? 28 : 32,
                            fontWeight: FontWeight.bold,
                            color: isDark ? CupertinoColors.white : CupertinoColors.black,
                          ),
                          child: Text(
                            _getTitle(l10n),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          _getSubtitle(l10n),
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? CupertinoColors.systemGrey : CupertinoColors.systemGrey2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          height: keyboardVisible ? 24 : 40,
                        ),

                        // PageView с 5 страницами авторизации и плавной анимацией высоты
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          height: _calculatePageHeight(),
                          child: PageView(
                            controller: _pageController,
                            physics: const NeverScrollableScrollPhysics(), // Отключаем свайп
                            children: [
                              _buildSignInSignUpPage(l10n, isDark, keyboardVisible, screenHeight),  // Страница 0: Sign In / Sign Up
                              _buildForgotPasswordEmailPage(l10n, isDark, keyboardVisible, screenHeight),  // Страница 1: Forgot Password
                              _buildResetPasswordPage(l10n, isDark, keyboardVisible, screenHeight),  // Страница 2: Reset Password
                              _buildMagicLinkEmailPage(l10n, isDark, keyboardVisible, screenHeight),  // Страница 3: Magic Link Email
                              _buildMagicLinkSentPage(l10n, isDark, keyboardVisible, screenHeight),  // Страница 4: Magic Link Sent
                            ],
                          ),
                        ),

                        // Error message с анимацией появления
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: _errorMessage != null ? Column(
                            children: [
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 300),
                                opacity: _errorMessage != null ? 1.0 : 0.0,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.destructiveRed.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: CupertinoColors.destructiveRed.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    _errorMessage ?? '',
                                    style: const TextStyle(
                                      color: CupertinoColors.destructiveRed,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ) : const SizedBox.shrink(),
                        ),

                        // Main action button - только для страниц с полями ввода
                        if (_currentMode != AuthMode.signIn &&
                            _currentMode != AuthMode.signUp &&
                            _currentMode != AuthMode.magicLinkSent) ...[
                          _AnimatedButton(
                            onPressed: (_isLoading || _isGoogleLoading || _isAppleLoading)
                                ? null
                                : _getMainAction(),
                            child: _isLoading
                                ? CupertinoActivityIndicator(
                                    color: isDark ? CupertinoColors.black : CupertinoColors.white,
                                  )
                                : Text(
                                    _getMainButtonText(l10n),
                                    style: TextStyle(
                                      color: isDark ? CupertinoColors.black : CupertinoColors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),

                          const SizedBox(height: 20),

                          // Back to sign in button
                          CupertinoButton(
                            onPressed: _toggleMode,
                            child: Text(
                              l10n.backToSignIn,
                              style: TextStyle(
                                color: isDark ? CupertinoColors.white : CupertinoColors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        
                        // Нижний отступ для обеспечения доступности кнопок
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          height: keyboardVisible ? 20 : 40,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );

            return scrollView;
          },
        ),
      ),
    );
  }
}

/// Animated icon widget for magic link sent page
/// Modern email sent animation with wave/ripple effects
class _EmailSentAnimation extends StatefulWidget {
  final Color accentColor;

  const _EmailSentAnimation({
    required this.accentColor,
  });

  @override
  State<_EmailSentAnimation> createState() => _EmailSentAnimationState();
}

class _EmailSentAnimationState extends State<_EmailSentAnimation>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _pulseController;
  late AnimationController _bounceController;
  late AnimationController _rotationController;

  late Animation<double> _waveAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _bounceAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    // Wave/ripple animation - 3 second loop
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();

    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeOut),
    );

    // Pulse animation - gentle breathing effect
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Bounce animation - initial entrance
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _bounceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _bounceController,
        curve: Curves.elasticOut,
      ),
    );

    // Rotation for envelope flap effect
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat();

    _rotationAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );

    // Start entrance animation
    _bounceController.forward();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _pulseController.dispose();
    _bounceController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).scaffoldBackgroundColor == CupertinoColors.black;

    return SizedBox(
      width: 200,
      height: 200,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _waveAnimation,
          _pulseAnimation,
          _bounceAnimation,
        ]),
        builder: (context, child) {
          return Transform.scale(
            scale: _bounceAnimation.value,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Wave/Ripple background effect
                CustomPaint(
                  size: const Size(200, 200),
                  painter: _WaveRipplePainter(
                    animation: _waveAnimation,
                    color: widget.accentColor,
                  ),
                ),

                // Main animated envelope
                Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: isDark
                          ? [
                              widget.accentColor.withOpacity(0.25),
                              widget.accentColor.withOpacity(0.08),
                            ]
                          : [
                              AppColors.lightSurface,
                              AppColors.lightSurface.withOpacity(0.5),
                            ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                            ? widget.accentColor.withOpacity(0.4)
                            : CupertinoColors.black.withOpacity(0.08),
                          blurRadius: 30,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Envelope icon
                        Icon(
                          CupertinoIcons.envelope_fill,
                          color: widget.accentColor,
                          size: 60,
                        ),

                        // Animated particles/sparkles
                        AnimatedBuilder(
                          animation: _rotationAnimation,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _rotationAnimation.value,
                              child: CustomPaint(
                                size: const Size(120, 120),
                                painter: _ParticlesPainter(
                                  animation: _rotationAnimation,
                                  color: widget.accentColor,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Success checkmark overlay
                AnimatedBuilder(
                  animation: _bounceAnimation,
                  builder: (context, child) {
                    if (_bounceAnimation.value > 0.7) {
                      return Positioned(
                        bottom: 20,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: CupertinoColors.white,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4CAF50).withOpacity(0.5),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            CupertinoIcons.checkmark,
                            color: CupertinoColors.white,
                            size: 20,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Wave/Ripple painter for animated concentric circles
class _WaveRipplePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  _WaveRipplePainter({
    required this.animation,
    required this.color,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw 3 waves with different phases
    for (int i = 0; i < 3; i++) {
      final phase = (animation.value + (i * 0.33)) % 1.0;
      final radius = maxRadius * phase;
      final opacity = (1.0 - phase) * 0.4;

      if (opacity > 0) {
        final paint = Paint()
          ..color = color.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        canvas.drawCircle(center, radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_WaveRipplePainter oldDelegate) => false;
}

/// Particles painter for floating sparkles around envelope
class _ParticlesPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  _ParticlesPainter({
    required this.animation,
    required this.color,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw 8 particles at different angles
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4) + (animation.value * 2 * math.pi * 0.2);
      final distance = radius * 0.75;
      final x = center.dx + distance * math.cos(angle);
      final y = center.dy + distance * math.sin(angle);

      // Pulsating opacity
      final pulseOpacity = (math.sin(animation.value * 2 * math.pi * 2 + i) + 1) / 2;

      final paint = Paint()
        ..color = color.withOpacity(0.3 * pulseOpacity)
        ..style = PaintingStyle.fill;

      // Draw small circles as particles
      canvas.drawCircle(Offset(x, y), 3, paint);

      // Draw tiny stars occasionally
      if (i % 2 == 0) {
        _drawTinyStar(canvas, Offset(x, y), paint, 2.5);
      }
    }
  }

  void _drawTinyStar(Canvas canvas, Offset position, Paint paint, double size) {
    final path = Path();
    for (int i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      final x = position.dx + size * math.cos(angle);
      final y = position.dy + size * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ParticlesPainter oldDelegate) => false;
}

// Removed custom painter widget in favor of network image for consistent rendering