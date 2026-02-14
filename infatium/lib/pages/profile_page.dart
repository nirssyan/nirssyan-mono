import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, showModalBottomSheet;
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/colors.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/locale_service.dart';
import '../services/zen_mode_service.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/analytics_service.dart';
import '../models/analytics_event_schema.dart';
import '../services/telegram_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'view_settings_page.dart';
import 'profile_details_page.dart';
import '../widgets/feedback_modal.dart';
import '../widgets/telegram_icon.dart';

/// Cached profile avatar widget with placeholder fallback
/// Loads user avatar from OAuth providers (Google, Apple) if available
class ProfileAvatar extends StatelessWidget {
  final double size;

  const ProfileAvatar({
    super.key,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final photoUrl = AuthService().currentUserPhotoURL;

    // Placeholder widget (shown when no avatar or during loading)
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : AppColors.lightSurface,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark
            ? AppColors.accent.withOpacity(0.3)
            : AppColors.lightAccent.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Icon(
        CupertinoIcons.person_fill,
        color: isDark ? AppColors.accent : AppColors.lightAccent,
        size: size * 0.5, // Scale icon based on size
      ),
    );

    // If no photo URL, show placeholder immediately
    if (photoUrl == null || photoUrl.isEmpty) {
      return placeholder;
    }

    // Load cached image with placeholder and error fallback
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: photoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => placeholder,
        errorWidget: (context, url, error) => placeholder,
        fadeInDuration: const Duration(milliseconds: 300),
        fadeOutDuration: const Duration(milliseconds: 100),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  final LocaleService localeService;

  const ProfilePage({super.key, required this.localeService});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}


class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  final ThemeService _themeService = ThemeService();
  final ZenModeService _zenModeService = ZenModeService();
  final AnalyticsService _analyticsService = AnalyticsService();

  bool _emailCopied = false;
  Timer? _emailCopiedTimer;
  TelegramStatus? _telegramStatus;

  @override
  void initState() {
    super.initState();
    _zenModeService.addListener(_onZenModeChanged);
    _loadTelegramStatus();
  }

  Future<void> _loadTelegramStatus() async {
    final status = await TelegramService().getStatus();
    if (mounted) {
      setState(() => _telegramStatus = status);
    }
  }

  void _onZenModeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _linkTelegram() async {
    HapticFeedback.lightImpact();
    _analyticsService.capture(EventSchema.profileLinkTelegramTapped);

    final l10n = AppLocalizations.of(context)!;
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final cardBackground = isDark
        ? const Color(0xFFFFFFFF).withOpacity(0.08)
        : const Color(0xFFFFFFFF).withOpacity(0.92);

    // Show loading dialog
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(),
              const SizedBox(height: 16),
              Text(
                l10n.linkTelegramLoading,
                style: TextStyle(
                  color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final url = await TelegramService().getTelegramLinkUrl();
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading

      if (url != null) {
        await _openTelegramUrl(url);
        // Refresh status after returning
        _loadTelegramStatus();
      } else {
        _showTelegramError();
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showTelegramError();
    }
  }

  Future<void> _openTelegramUrl(String url) async {
    // Convert https://t.me/botname?start=token to tg://resolve?domain=botname&start=token
    final httpsUri = Uri.parse(url);

    String? botName;
    String? startParam;

    // Parse https://t.me/botname?start=token
    if (httpsUri.host == 't.me' && httpsUri.pathSegments.isNotEmpty) {
      botName = httpsUri.pathSegments.first;
      startParam = httpsUri.queryParameters['start'];
    }

    if (botName != null) {
      // Build tg:// deep link
      final tgUri = Uri(
        scheme: 'tg',
        host: 'resolve',
        queryParameters: {
          'domain': botName,
          if (startParam != null) 'start': startParam,
        },
      );

      // Try tg:// first (opens Telegram app directly)
      if (await canLaunchUrl(tgUri)) {
        await launchUrl(tgUri);
        _analyticsService.capture(EventSchema.profileLinkTelegramOpened,
            properties: {'method': 'deeplink'});
        return;
      }
    }

    // Fallback: try https://t.me/ with external app mode
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      _analyticsService.capture(EventSchema.profileLinkTelegramOpened,
          properties: {'method': 'https'});
      return;
    }

    // Final fallback: web.telegram.org
    final webUrl = Uri.parse(
        'https://web.telegram.org/k/#?tgaddr=${Uri.encodeComponent(url)}');
    await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    _analyticsService.capture(EventSchema.profileLinkTelegramOpened,
        properties: {'method': 'web'});
  }

  void _showTelegramError() {
    final l10n = AppLocalizations.of(context)!;
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(
          l10n.error,
          style: TextStyle(
            color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
          ),
        ),
        content: Text(
          l10n.linkTelegramError,
          style: TextStyle(
            color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
    _analyticsService.capture(EventSchema.profileLinkTelegramError);
  }

  void _showLogoutDialog() {
    // Analytics: logout attempted
    AnalyticsService().capture(EventSchema.profileLogoutAttempted);

    final l10n = AppLocalizations.of(context)!;
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final contentColor = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final cardBackground = isDark
        ? const Color(0xFFFFFFFF).withOpacity(0.08)
        : const Color(0xFFFFFFFF).withOpacity(0.92);
    final borderColor = isDark
        ? const Color(0xFFFFFFFF).withOpacity(0.2)
        : const Color(0xFF000000).withOpacity(0.08);

    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF000000).withOpacity(isDark ? 0.35 : 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: CupertinoColors.destructiveRed.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: CupertinoColors.destructiveRed.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.square_arrow_right,
                          color: CupertinoColors.destructiveRed,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.logout,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.logoutConfirm,
                        style: TextStyle(
                          color: contentColor,
                          fontSize: 15,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => Navigator.of(context).pop(),
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderColor, width: 1),
                                  color: CupertinoColors.transparent,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  l10n.cancel,
                                  style: TextStyle(
                                    color: titleColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                Navigator.of(context).pop();
                                // Analytics: logout confirmed
                                AnalyticsService().capture(EventSchema.profileLogoutConfirmed);
                                _authService.signOut();
                              },
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: CupertinoColors.destructiveRed,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  l10n.logout,
                                  style: const TextStyle(
                                    color: CupertinoColors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLanguageOptions() {
    final l10n = AppLocalizations.of(context)!;
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: Text(
            l10n.language,
            style: TextStyle(color: textColor),
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () async {
                await widget.localeService.setLocale(const Locale('ru'));
                Navigator.of(context).pop();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 8),
                  Text(
                    'Русский',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 20,
                    ),
                  ),
                  if (widget.localeService.currentLocale.languageCode == 'ru')
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        CupertinoIcons.check_mark,
                        size: 16,
                        color: textColor,
                      ),
                    ),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () async {
                await widget.localeService.setLocale(const Locale('en'));
                Navigator.of(context).pop();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 8),
                  Text(
                    'English',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 20,
                    ),
                  ),
                  if (widget.localeService.currentLocale.languageCode == 'en')
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        CupertinoIcons.check_mark,
                        size: 16,
                        color: textColor,
                      ),
                    ),
                ],
              ),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            child: Text(
              l10n.cancel,
              style: TextStyle(
                color: textColor,
                fontSize: 20,
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        );
      },
    );
  }

  void _showFeedbackModal() {
    HapticFeedback.lightImpact();

    _analyticsService.capture(EventSchema.feedbackModalOpened);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (BuildContext context) {
        return const FeedbackModal();
      },
    );
  }

  // Removed custom overlay toast in favor of inline copied badge

  Widget _buildSettingsSection(String title, List<Widget> children, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            title,
            style: TextStyle(
              color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingsItem({
    required String title,
    IconData? icon,
    Widget? iconWidget,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool isDark = false,
    bool isDestructive = false,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDestructive
                    ? CupertinoColors.destructiveRed.withOpacity(0.1)
                    : (isDark ? AppColors.accent : AppColors.lightAccent).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: iconWidget ?? Icon(
                  icon,
                  size: 18,
                  color: isDestructive
                      ? CupertinoColors.destructiveRed
                      : (isDark ? AppColors.accent : AppColors.lightAccent),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDestructive 
                          ? CupertinoColors.destructiveRed
                          : (isDark ? AppColors.textPrimary : AppColors.lightTextPrimary),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.background : AppColors.lightBackground;

    // DEBUG: Print feature flags

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: backgroundColor.withOpacity(0.8),
        border: null,
        middle: Text(
          l10n.profile,
          style: TextStyle(
            color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
          ),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 20, bottom: 100),
          children: [
            // User info section (clickable)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                HapticFeedback.lightImpact();
                AnalyticsService().capture(EventSchema.profileAccountTapped);

                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (context) => const ProfileDetailsPage(),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const ProfileAvatar(size: 60),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                l10n.account,
                                style: TextStyle(
                                  color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 20,
                      color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Settings sections
            _buildSettingsSection(
              l10n.settings,
              [
                _buildSettingsItem(
                  title: l10n.language,
                  subtitle: widget.localeService.getLocaleName(widget.localeService.currentLocale),
                  icon: CupertinoIcons.globe,
                  trailing: Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                  ),
                  onTap: _showLanguageOptions,
                  isDark: isDark,
                ),
                Container(
                  height: 0.5,
                  color: isDark
                      ? AppColors.textSecondary.withOpacity(0.2)
                      : AppColors.lightTextSecondary.withOpacity(0.2),
                  margin: const EdgeInsets.only(left: 60),
                ),
                _buildSettingsItem(
                  title: l10n.theme,
                  subtitle: _themeService.isDarkMode ? l10n.darkMode : l10n.lightMode,
                  icon: _themeService.isDarkMode ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill,
                  trailing: CupertinoSwitch(
                    value: _themeService.isDarkMode,
                    onChanged: (value) async {
                      await _themeService.setDarkMode(value);
                    },
                  ),
                  isDark: isDark,
                ),
                // View settings (Zen Mode + Image Previews)
                Container(
                  height: 0.5,
                  color: isDark
                      ? AppColors.textSecondary.withOpacity(0.2)
                      : AppColors.lightTextSecondary.withOpacity(0.2),
                  margin: const EdgeInsets.only(left: 60),
                ),
                _buildSettingsItem(
                  title: l10n.viewSettings,
                  subtitle: l10n.viewSettingsSubtitle,
                  icon: CupertinoIcons.eye_fill,
                  trailing: Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                  ),
                  onTap: () {
                    // Analytics: view settings opened
                    AnalyticsService().capture(EventSchema.profileViewSettingsOpened);

                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (context) => const ViewSettingsPage(),
                      ),
                    );
                  },
                  isDark: isDark,
                ),
                // Telegram link
                Container(
                  height: 0.5,
                  color: isDark
                      ? AppColors.textSecondary.withOpacity(0.2)
                      : AppColors.lightTextSecondary.withOpacity(0.2),
                  margin: const EdgeInsets.only(left: 60),
                ),
                _buildSettingsItem(
                  title: _telegramStatus?.linked == true
                      ? l10n.telegramLinked
                      : l10n.linkTelegram,
                  subtitle: _telegramStatus?.linked == true
                      ? _telegramStatus!.telegramUsername ?? ''
                      : l10n.linkTelegramSubtitle,
                  iconWidget: TelegramIcon(isDark: isDark),
                  trailing: Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                  ),
                  onTap: _linkTelegram,
                  isDark: isDark,
                ),
              ],
              isDark,
            ),

            const SizedBox(height: 20),

            // Contact section
            _buildSettingsSection(
              l10n.contactUs,
              [
                _buildSettingsItem(
                  title: 'contact@nirssyan.ru',
                  icon: CupertinoIcons.mail,
                  onTap: () async {
                    await Clipboard.setData(const ClipboardData(text: 'contact@nirssyan.ru'));
                    HapticFeedback.lightImpact();
                    AnalyticsService().capture(EventSchema.contactEmailCopied);
                    _emailCopiedTimer?.cancel();
                    if (!mounted) return;
                    setState(() => _emailCopied = true);
                    _emailCopiedTimer = Timer(const Duration(milliseconds: 1600), () {
                      if (!mounted) return;
                      setState(() => _emailCopied = false);
                    });
                  },
                  isDark: isDark,
                  trailing: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: _emailCopied
                        ? Container(
                            key: const ValueKey('email_copied_badge'),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? CupertinoColors.white : CupertinoColors.black,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? CupertinoColors.white : CupertinoColors.black,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.check_mark_circled_solid,
                                  size: 16,
                                  color: isDark ? CupertinoColors.black : CupertinoColors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  l10n.emailCopied,
                                  style: TextStyle(
                                    color: isDark ? CupertinoColors.black : CupertinoColors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                Container(
                  height: 0.5,
                  color: isDark
                      ? AppColors.textSecondary.withOpacity(0.2)
                      : AppColors.lightTextSecondary.withOpacity(0.2),
                  margin: const EdgeInsets.only(left: 60),
                ),
                _buildSettingsItem(
                  title: l10n.sendFeedback,
                  icon: CupertinoIcons.chat_bubble_text_fill,
                  trailing: Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                  ),
                  onTap: _showFeedbackModal,
                  isDark: isDark,
                ),
              ],
              isDark,
            ),
            
            const SizedBox(height: 20),
            
            // Logout section
            _buildSettingsSection(
              '',
              [
                _buildSettingsItem(
                  title: l10n.logout,
                  icon: CupertinoIcons.square_arrow_right,
                  onTap: _showLogoutDialog,
                  isDark: isDark,
                  isDestructive: true,
                ),
              ],
              isDark,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _zenModeService.removeListener(_onZenModeChanged);
    _emailCopiedTimer?.cancel();
    super.dispose();
  }
} 