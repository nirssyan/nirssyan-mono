import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'dart:ui';
import '../theme/colors.dart';
import '../services/app_icon_service.dart';
import '../services/zen_mode_service.dart';
import '../services/image_preview_service.dart';
import '../services/analytics_service.dart';
import '../models/analytics_event_schema.dart';
import '../l10n/generated/app_localizations.dart';

class ViewSettingsPage extends StatefulWidget {
  const ViewSettingsPage({super.key});

  @override
  State<ViewSettingsPage> createState() => _ViewSettingsPageState();
}

class _ViewSettingsPageState extends State<ViewSettingsPage> {
  final AppIconService _appIconService = AppIconService();
  final ZenModeService _zenModeService = ZenModeService();
  final ImagePreviewService _imagePreviewService = ImagePreviewService();

  @override
  void initState() {
    super.initState();
    _appIconService.addListener(_onSettingsChanged);
    _zenModeService.addListener(_onSettingsChanged);
    _imagePreviewService.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _appIconService.removeListener(_onSettingsChanged);
    _zenModeService.removeListener(_onSettingsChanged);
    _imagePreviewService.removeListener(_onSettingsChanged);
    super.dispose();
  }

  Widget _buildIconPreview({
    required String assetPath,
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final accentColor = isDark ? AppColors.accent : AppColors.lightAccent;
    final textColor = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon preview with subtle selection ring
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18), // iOS app icon radius
              border: isSelected
                  ? Border.all(color: accentColor.withOpacity(0.4), width: 2.5)
                  : null,
              boxShadow: isSelected ? [
                BoxShadow(
                  color: accentColor.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ] : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                assetPath,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Label with conditional styling
          Text(
            label,
            style: TextStyle(
              color: isSelected ? textColor : secondaryTextColor,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.background : AppColors.lightBackground;
    final textColor = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final subtitleColor = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: backgroundColor.withOpacity(0.8),
        border: null,
        middle: Text(
          l10n.viewSettings,
          style: TextStyle(color: textColor),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: Icon(
            CupertinoIcons.back,
            color: isDark ? AppColors.accent : AppColors.lightAccent,
          ),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 20),
          children: [
            // Header section - minimalistic like model selector
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (isDark ? AppColors.accent : AppColors.lightAccent).withOpacity(0.08),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.accent : AppColors.lightAccent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      CupertinoIcons.eye_fill,
                      color: isDark ? AppColors.background : CupertinoColors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.viewSettings,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          l10n.viewSettingsPageSubtitle,
                          style: TextStyle(
                            color: subtitleColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Zen Mode toggle section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: null, // Disabled tap on the container, only switch is tappable
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      // Icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _zenModeService.isZenMode
                              ? (isDark ? AppColors.accent.withOpacity(0.15) : AppColors.lightAccent.withOpacity(0.1))
                              : (isDark ? AppColors.accent.withOpacity(0.1) : AppColors.lightAccent.withOpacity(0.08)),
                          borderRadius: BorderRadius.circular(10),
                          border: _zenModeService.isZenMode
                              ? Border.all(
                                  color: (isDark ? AppColors.accent : AppColors.lightAccent).withOpacity(0.3),
                                  width: 1,
                                )
                              : null,
                        ),
                        child: Icon(
                          _zenModeService.isZenMode ? CupertinoIcons.eye_slash_fill : CupertinoIcons.eye_fill,
                          size: 20,
                          color: isDark ? AppColors.accent : AppColors.lightAccent,
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Title and description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.zenMode,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _zenModeService.isZenMode
                                  ? l10n.zenModeEnabledDescription
                                  : l10n.zenModeDisabledDescription,
                              style: TextStyle(
                                color: subtitleColor.withOpacity(0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Toggle switch
                      CupertinoSwitch(
                        value: _zenModeService.isZenMode,
                        onChanged: (value) async {
                          await _zenModeService.setZenMode(value);
                          // Analytics: zen mode toggled
                          AnalyticsService().capture(EventSchema.zenModeToggled, properties: {
                            'enabled': value,
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Image Previews toggle section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: null, // Disabled tap on the container, only switch is tappable
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      // Icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _imagePreviewService.showImagePreviews
                              ? (isDark ? AppColors.accent.withOpacity(0.15) : AppColors.lightAccent.withOpacity(0.1))
                              : (isDark ? AppColors.accent.withOpacity(0.1) : AppColors.lightAccent.withOpacity(0.08)),
                          borderRadius: BorderRadius.circular(10),
                          border: _imagePreviewService.showImagePreviews
                              ? Border.all(
                                  color: (isDark ? AppColors.accent : AppColors.lightAccent).withOpacity(0.3),
                                  width: 1,
                                )
                              : null,
                        ),
                        child: Icon(
                          CupertinoIcons.photo,
                          size: 20,
                          color: isDark ? AppColors.accent : AppColors.lightAccent,
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Title and description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.imagePreviews,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _imagePreviewService.showImagePreviews
                                  ? l10n.imagePreviewsEnabledDescription
                                  : l10n.imagePreviewsDisabledDescription,
                              style: TextStyle(
                                color: subtitleColor.withOpacity(0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Toggle switch
                      CupertinoSwitch(
                        value: _imagePreviewService.showImagePreviews,
                        onChanged: (value) async {
                          await _imagePreviewService.setImagePreviews(value);
                          // Analytics: image preview toggled
                          AnalyticsService().capture(EventSchema.imagePreviewsToggled, properties: {
                            'enabled': value,
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // App Icon selector (iOS only)
            if (Platform.isIOS) ...[
              const SizedBox(height: 12),

              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: (isDark ? AppColors.accent : AppColors.lightAccent).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            CupertinoIcons.app_badge,
                            size: 20,
                            color: isDark ? AppColors.accent : AppColors.lightAccent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.appIcon,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Choose your app icon style',
                                style: TextStyle(
                                  color: subtitleColor.withOpacity(0.7),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Icon previews
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildIconPreview(
                          assetPath: 'assets/icons/app_icon_dark.png',
                          label: l10n.darkIcon,
                          isSelected: _appIconService.isDefaultIcon,
                          isDark: isDark,
                          onTap: () async {
                            HapticFeedback.mediumImpact();
                            await _appIconService.setDefaultIcon();
                            AnalyticsService().capture(EventSchema.appIconChanged,
                              properties: {'icon_name': 'dark'});
                          },
                        ),
                        _buildIconPreview(
                          assetPath: 'assets/icons/app_icon_light.png',
                          label: l10n.lightIcon,
                          isSelected: _appIconService.isLightIcon,
                          isDark: isDark,
                          onTap: () async {
                            HapticFeedback.mediumImpact();
                            await _appIconService.setLightIcon();
                            AnalyticsService().capture(EventSchema.appIconChanged,
                              properties: {'icon_name': 'light'});
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

          ],
        ),
      ),
    );
  }
}
