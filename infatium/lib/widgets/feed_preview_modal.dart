import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/feed_builder_models.dart';
import '../services/locale_service.dart';
import '../services/theme_service.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

class FeedPreviewModal extends StatefulWidget {
  final FeedPreview preview;
  final LocaleService localeService;
  final Future<bool> Function() onCreateFeed;
  final bool isSubscriptionMode; // true для подписки на существующую ленту, false для создания новой

  const FeedPreviewModal({
    super.key,
    required this.preview,
    required this.localeService,
    required this.onCreateFeed,
    this.isSubscriptionMode = false,
  });

  @override
  State<FeedPreviewModal> createState() => _FeedPreviewModalState();
}

class _FeedPreviewModalState extends State<FeedPreviewModal>
    with SingleTickerProviderStateMixin {
  bool _isCreating = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Анимация появления модалки
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateFeed() async {
    if (_isCreating) return;


    setState(() {
      _isCreating = true;
    });

    HapticFeedback.mediumImpact();

    try {

      final success = await widget.onCreateFeed(); // Ждем пока POST запрос завершится


      if (mounted) {
        Navigator.of(context).pop(success);
      }
    } catch (e) {

      if (mounted) {
        Navigator.of(context).pop(false);
      }
    }
  }

  String _getFeedTypeLabel(String type) {
    final l10n = AppLocalizations.of(context)!;

    switch (type.toUpperCase()) {
      case 'FILTER':
        return '🔍 ${l10n.previewFilterMode}';
      case 'SUMMARY':
        return '📝 ${l10n.previewDigestMode}';
      case 'COMMENT':
        return '💬 ${l10n.previewCommentsMode}';
      case 'READ':
        return '📖 ${l10n.previewReadMode}';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeService(),
      builder: (context, child) {
        final isDark = ThemeService().isDarkMode;
        final backgroundColor = isDark
            ? AppColors.background
            : AppColors.lightBackground;
        final surfaceColor = isDark
            ? AppColors.surface
            : AppColors.lightSurface;
        final textColor = isDark
            ? AppColors.textPrimary
            : AppColors.lightTextPrimary;
        final secondaryTextColor = isDark
            ? AppColors.textSecondary
            : AppColors.lightTextSecondary;
        final accentColor = isDark
            ? AppColors.accent
            : AppColors.lightAccent;

        final l10n = AppLocalizations.of(context)!;
        final isRu = widget.localeService.currentLocale.languageCode == 'ru';

        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: GestureDetector(
                onTap: () {}, // Предотвращаем закрытие при нажатии на модалку
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                      constraints: BoxConstraints(
                        maxWidth: 500,
                        minHeight: MediaQuery.of(context).size.height * 0.75,
                        maxHeight: MediaQuery.of(context).size.height * 0.95,
                      ),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          // Шапка модалки
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                            child: Row(
                              children: [
                                // Невидимый элемент слева для баланса (той же ширины что и кнопка)
                                const SizedBox(width: 44),
                                // Название по центру
                                Expanded(
                                  child: Text(
                                    widget.preview.name,
                                    style: AppTextStyles.navTitle.copyWith(
                                      color: textColor,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      height: 1.2,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Кнопка закрытия справа
                                SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: Icon(
                                      CupertinoIcons.xmark_circle_fill,
                                      color: secondaryTextColor.withOpacity(0.6),
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Контент модалки
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Тип и владелец в одну линию
                                  _buildTypeAndOwner(
                                    l10n: l10n,
                                    isRu: isRu,
                                    isDark: isDark,
                                    textColor: textColor,
                                    secondaryTextColor: secondaryTextColor,
                                    accentColor: accentColor,
                                    surfaceColor: surfaceColor,
                                  ),

                                  const SizedBox(height: 20),
                                  Divider(
                                    color: isDark
                                        ? AppColors.glassBorder.withOpacity(0.1)
                                        : AppColors.lightGlassBorder.withOpacity(0.15),
                                    height: 1,
                                  ),
                                  const SizedBox(height: 20),

                                  // Описание
                                  _buildSection(
                                    title: l10n.previewDescription,
                                    content: widget.preview.description,
                                    textColor: textColor,
                                    secondaryTextColor: secondaryTextColor,
                                  ),

                                  const SizedBox(height: 20),
                                  Divider(
                                    color: isDark
                                        ? AppColors.glassBorder.withOpacity(0.1)
                                        : AppColors.lightGlassBorder.withOpacity(0.15),
                                    height: 1,
                                  ),
                                  const SizedBox(height: 20),

                                  // Промпт
                                  _buildSection(
                                    title: l10n.previewPrompt,
                                    content: widget.preview.prompt,
                                    textColor: textColor,
                                    secondaryTextColor: secondaryTextColor,
                                  ),

                                  // Источники
                                  if (widget.preview.sources.isNotEmpty) ...[
                                    const SizedBox(height: 20),
                                    Divider(
                                      color: isDark
                                          ? AppColors.glassBorder.withOpacity(0.1)
                                          : AppColors.lightGlassBorder.withOpacity(0.15),
                                      height: 1,
                                    ),
                                    const SizedBox(height: 20),
                                    _buildSources(
                                      l10n: l10n,
                                      isRu: isRu,
                                      isDark: isDark,
                                      textColor: textColor,
                                      secondaryTextColor: secondaryTextColor,
                                      surfaceColor: surfaceColor,
                                    ),
                                  ],

                                  // Фильтры (под источниками)
                                  if (widget.preview.filters != null && widget.preview.filters!.isNotEmpty) ...[
                                    const SizedBox(height: 20),
                                    Divider(
                                      color: isDark
                                          ? AppColors.glassBorder.withOpacity(0.1)
                                          : AppColors.lightGlassBorder.withOpacity(0.15),
                                      height: 1,
                                    ),
                                    const SizedBox(height: 20),
                                    _buildFilters(
                                      l10n: l10n,
                                      isRu: isRu,
                                      isDark: isDark,
                                      textColor: textColor,
                                      secondaryTextColor: secondaryTextColor,
                                      surfaceColor: surfaceColor,
                                    ),
                                  ],

                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ),

                          // Кнопка создания ленты
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Divider(
                                color: isDark
                                    ? AppColors.glassBorder.withOpacity(0.1)
                                    : AppColors.lightGlassBorder.withOpacity(0.15),
                                height: 1,
                              ),
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: _buildCreateButton(
                                  l10n: l10n,
                                  isDark: isDark,
                                  accentColor: accentColor,
                                  backgroundColor: backgroundColor,
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypeAndOwner({
    required AppLocalizations l10n,
    required bool isRu,
    required bool isDark,
    required Color textColor,
    required Color secondaryTextColor,
    required Color accentColor,
    required Color surfaceColor,
  }) {
    final typeLabel = _getFeedTypeLabel(widget.preview.type);
    final ownerName = widget.preview.owner.name.isNotEmpty
        ? widget.preview.owner.name
        : l10n.previewUnknown;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  surfaceColor.withOpacity(0.5),
                  surfaceColor.withOpacity(0.3),
                ]
              : [
                  AppColors.lightSurface.withOpacity(0.4),
                  AppColors.lightSurface.withOpacity(0.2),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Тип ленты
          Icon(
            _getTypeIcon(widget.preview.type),
            color: isDark ? accentColor : AppColors.lightAccent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            typeLabel.replaceAll('🔍 ', '').replaceAll('📝 ', '').replaceAll('💬 ', '').replaceAll('📖 ', ''),
            style: AppTextStyles.body.copyWith(
              color: isDark ? textColor : AppColors.lightTextPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),

          // Разделитель
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: 1,
              height: 20,
              color: isDark
                  ? AppColors.glassBorder.withOpacity(0.15)
                  : AppColors.lightGlassBorder.withOpacity(0.2),
            ),
          ),

          // Владелец
          Icon(
            CupertinoIcons.person_circle,
            color: isDark
                ? secondaryTextColor.withOpacity(0.7)
                : AppColors.lightTextSecondary.withOpacity(0.8),
            size: 18,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              ownerName,
              style: AppTextStyles.body.copyWith(
                color: isDark
                    ? secondaryTextColor.withOpacity(0.9)
                    : AppColors.lightTextSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type.toUpperCase()) {
      case 'FILTER':
        return CupertinoIcons.line_horizontal_3_decrease;
      case 'SUMMARY':
        return CupertinoIcons.doc_text_fill;
      case 'COMMENT':
        return CupertinoIcons.chat_bubble_2_fill;
      case 'READ':
        return CupertinoIcons.book_fill;
      default:
        return CupertinoIcons.layers_fill;
    }
  }

  Widget _buildSection({
    required String title,
    required String content,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.body.copyWith(
            color: secondaryTextColor.withOpacity(0.7),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: AppTextStyles.body.copyWith(
            color: textColor,
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildSources({
    required AppLocalizations l10n,
    required bool isRu,
    required bool isDark,
    required Color textColor,
    required Color secondaryTextColor,
    required Color surfaceColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.previewSourcesCount(widget.preview.sources.length),
          style: AppTextStyles.body.copyWith(
            color: secondaryTextColor.withOpacity(0.7),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.preview.sources.map((source) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? surfaceColor.withOpacity(0.3)
                    : AppColors.lightSurface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '@${source.getLabel(isRu)}',
                style: AppTextStyles.body.copyWith(
                  color: textColor.withOpacity(0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFilters({
    required AppLocalizations l10n,
    required bool isRu,
    required bool isDark,
    required Color textColor,
    required Color secondaryTextColor,
    required Color surfaceColor,
  }) {
    final filters = widget.preview.filters;
    if (filters == null || filters.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.previewFiltersCount(filters.length),
          style: AppTextStyles.body.copyWith(
            color: secondaryTextColor.withOpacity(0.7),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filters.map((filter) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? surfaceColor.withOpacity(0.3)
                    : AppColors.lightSurface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                filter.getLabel(isRu),
                style: AppTextStyles.body.copyWith(
                  color: textColor.withOpacity(0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }


  Widget _buildCreateButton({
    required AppLocalizations l10n,
    required bool isDark,
    required Color accentColor,
    required Color backgroundColor,
  }) {
    // Тексты для разных режимов
    final String loadingText = widget.isSubscriptionMode
        ? l10n.previewSubscribing
        : l10n.previewCreating;

    final String buttonText = widget.isSubscriptionMode
        ? l10n.previewSubscribe
        : l10n.previewCreateFeed;

    return GestureDetector(
      onTap: _isCreating ? null : _handleCreateFeed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: _isCreating ? accentColor.withOpacity(0.9) : accentColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Center(
          child: _isCreating
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          backgroundColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      loadingText,
                      style: AppTextStyles.body.copyWith(
                        color: backgroundColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.add_circled_solid,
                      color: backgroundColor,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      buttonText,
                      style: AppTextStyles.body.copyWith(
                        color: backgroundColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
