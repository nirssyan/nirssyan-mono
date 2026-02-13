import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui';
import '../theme/colors.dart';
import '../models/news_item.dart';
import '../models/media_object.dart';
import '../services/theme_service.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/analytics_service.dart';
import '../models/analytics_event_schema.dart';
import 'fullscreen_image_gallery.dart';
import '../widgets/news_chewie_player.dart';
import '../widgets/custom_markdown_list_builder.dart';
import '../widgets/markdown_highlight_builder.dart';
import '../services/seen_posts_service.dart';
import '../utils/view_label_helper.dart';
import 'package:markdown/markdown.dart' as md;

class NewsDetailPage extends StatefulWidget {
  final NewsItem news;

  const NewsDetailPage({
    Key? key,
    required this.news,
  }) : super(key: key);

  @override
  State<NewsDetailPage> createState() => _NewsDetailPageState();
}

class _NewsDetailPageState extends State<NewsDetailPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;

  late AnimationController _tabSwitchController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  late Animation<double> _tabFadeAnimation;
  late Animation<Offset> _tabSlideAnimation;
  late Animation<double> _tabScaleAnimation;
  
  // Карусель изображений
  late PageController _imagePageController;
  int _currentImageIndex = 0;
  
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;
  double _scrollOffset = 0.0;
  
  // Состояние выбранного view для контента
  int _selectedViewIndex = 0;

  // Dropdown selector state
  bool _isDropdownOpen = false;
  late AnimationController _dropdownController;
  late Animation<double> _dropdownFadeAnimation;
  late Animation<Offset> _dropdownSlideAnimation;
  late Animation<double> _arrowRotationAnimation;

  // Получаем текущую тему
  bool get _isDarkMode => ThemeService().isDarkMode;

  // Проверка: нужно ли показывать toggle (только если больше 1 view)
  bool get _shouldShowViewToggle => widget.news.contentViews.length > 1;

  // Адаптивные цвета
  Color get _primaryTextColor => _isDarkMode ? AppColors.textPrimary : AppColors.lightTextPrimary;
  Color get _secondaryTextColor => _isDarkMode ? AppColors.textSecondary : AppColors.lightTextSecondary;

  Color get _backgroundColor => _isDarkMode ? AppColors.background : AppColors.lightBackground;


  @override
  void initState() {
    super.initState();

    // Инициализируем PageController
    _imagePageController = PageController(initialPage: 0);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );



    _tabSwitchController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Dropdown animation controller
    _dropdownController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _dropdownFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _dropdownController,
      curve: Curves.easeOutCubic,
    ));

    _dropdownSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _dropdownController,
      curve: Curves.easeOutCubic,
    ));

    _arrowRotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.5, // 180 degrees (0.5 * 2 * pi radians)
    ).animate(CurvedAnimation(
      parent: _dropdownController,
      curve: Curves.easeInOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));



    // Анимации для переключения табов
    _tabFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _tabSwitchController,
      curve: Curves.easeInOut,
    ));

    _tabSlideAnimation = Tween<Offset>(
      begin: const Offset(0.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _tabSwitchController,
      curve: Curves.easeOutCubic,
    ));

    _tabScaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _tabSwitchController,
      curve: Curves.easeOutBack,
    ));

    _scrollController.addListener(() {
      final offset = _scrollController.offset;

      // Обновляем scroll offset для анимации fade заголовка
      if (offset != _scrollOffset) {
        setState(() => _scrollOffset = offset);
      }

      if (offset > 100 && !_isScrolled) {
        setState(() => _isScrolled = true);
      } else if (offset <= 100 && _isScrolled) {
        setState(() => _isScrolled = false);
      }
    });

    // Запускаем анимации
    _fadeController.forward();
    _slideController.forward();

    _tabSwitchController.forward();

    // Mark post as seen when detail page opens
    _markPostAsSeen();

    // Предзагружаем ВСЕ изображения из карусели ПОСЛЕ построения виджета
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheImages();
    });
  }

  /// Mark the post as seen when opening the detail page
  void _markPostAsSeen() {
    final postId = widget.news.id;
    if (postId != null && !widget.news.seen) {
      // Mark as seen with haptic feedback
      HapticFeedback.lightImpact();

      // Use SeenPostsService to mark the post as seen
      SeenPostsService().markPostAsSeen(postId);

      // Analytics: post marked as seen
      AnalyticsService().capture(EventSchema.postViewed, properties: {
        'post_id': postId,
      });
    }
  }

  /// Handle share button tap
  void _handleShare() async {
    final postId = widget.news.id;

    // Check if post has ID
    if (postId == null || postId.isEmpty) {
      // Show error dialog if no ID
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(l10n.cannotShare),
          content: Text(l10n.noShareIdAvailable),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
      return;
    }

    // Haptic feedback
    HapticFeedback.mediumImpact();

    // Generate share URL
    const String shareBaseUrl = String.fromEnvironment(
      'SHARE_BASE_URL',
      defaultValue: 'https://infatium-nu.vercel.app',
    );
    final shareUrl = '$shareBaseUrl/news/$postId';

    // Share with title (iOS 26 requires sharePositionOrigin for Liquid Glass)
    try {
      final box = context.findRenderObject() as RenderBox?;
      await Share.share(
        shareUrl,
        subject: widget.news.title,
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : const Rect.fromLTWH(0, 0, 100, 100),
      );

      // Analytics: news shared
      AnalyticsService().capture(EventSchema.postShared, properties: {
        'post_id': postId,
        'share_method': 'system',
      });
    } catch (e) {
      // Error sharing
      print('Error sharing news: $e');
    }
  }

  /// AAA-level: предзагрузка всех изображений для мгновенной навигации
  void _precacheImages() {
    if (!mounted) return;

    final List<String> imagesToPrecache = [];

    // Приоритет: MediaObjects
    if (widget.news.mediaObjects.isNotEmpty) {
      for (final mediaObj in widget.news.mediaObjects) {
        if (mediaObj.url.startsWith('http')) {
          // Для фото - предзагружаем основное изображение
          if (mediaObj.isPhoto) {
            imagesToPrecache.add(mediaObj.url);
          }
          // Для видео - предзагружаем превью
          else if (mediaObj.isVideo && mediaObj.previewUrl != null) {
            imagesToPrecache.add(mediaObj.previewUrl!);
          }
        }
      }
    } else {
      // Fallback на старые поля
      final List<String> images = widget.news.mediaUrls.isNotEmpty
          ? widget.news.mediaUrls
          : (widget.news.imageUrl.isNotEmpty ? [widget.news.imageUrl] : <String>[]);

      imagesToPrecache.addAll(images.where((url) => url.startsWith('http')));
    }

    for (final imageUrl in imagesToPrecache) {
      precacheImage(
        NetworkImage(imageUrl),
        context,
        onError: (exception, stackTrace) {
          // Error precaching image silently
        },
      );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _tabSwitchController.dispose();
    _dropdownController.dispose();
    _scrollController.dispose();
    _imagePageController.dispose();
    super.dispose();
  }

  String _getTimeAgo(DateTime dateTime, BuildContext context) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    final l10n = AppLocalizations.of(context)!;

    if (difference.inHours < 1) {
      return l10n.minutesAgo(difference.inMinutes);
    } else if (difference.inHours < 24) {
      return l10n.hoursAgo(difference.inHours);
    } else {
      return l10n.daysAgo(difference.inDays);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Условная логика: hero layout для новостей с изображением, compact для остальных
    if (_hasImage()) {
      return _buildHeroLayout();
    } else {
      return _buildCompactLayout();
    }
  }

  /// Hero layout с изображением на 40% экрана и параллакс эффектом
  Widget _buildHeroLayout() {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final expandedHeight = (screenHeight * 0.4).roundToDouble(); // 40% экрана, rounded

    return CupertinoPageScaffold(
      backgroundColor: _backgroundColor,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // SliverAppBar с параллакс изображением
          SliverAppBar(
            expandedHeight: expandedHeight,
            pinned: true,
            stretch: true, // Растягивание при overscroll
            backgroundColor: _backgroundColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            leadingWidth: 58, // 16 (padding left) + 42 (new button width)
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax, // Параллакс эффект
              stretchModes: const [
                StretchMode.zoomBackground, // Зум при overscroll
                StretchMode.blurBackground, // Blur при растягивании
              ],
              background: _buildHeroImage(),
            ),
            // Glass button для back
            leading: Padding(
              padding: const EdgeInsets.only(left: 16, top: 12),
              child: _GlassButton(
                icon: CupertinoIcons.chevron_left,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            // Glass button для share
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16, top: 12),
                child: _GlassButton(
                  icon: CupertinoIcons.square_arrow_up,
                  onTap: _handleShare,
                ),
              ),
            ],
          ),

          // Content card с закругленными углами
          SliverToBoxAdapter(
            child: _buildContentCard(),
          ),
        ],
      ),
    );
  }

  /// Compact layout для новостей без изображения
  Widget _buildCompactLayout() {
    return CupertinoPageScaffold(
      backgroundColor: _backgroundColor,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Стандартный navigation bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _CustomHeaderDelegate(
              isScrolled: _isScrolled,
              title: widget.news.title,
              onShare: _handleShare,
              isDarkMode: _isDarkMode,
              showShareButton: true,
            ),
          ),

          // Контент без hero изображения
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Заголовок с fade-out при скролле
                      Opacity(
                        opacity: (1 - (_scrollOffset / 80)).clamp(0.0, 1.0),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Text(
                            widget.news.title,
                            style: TextStyle(
                              color: _primaryTextColor.withValues(alpha: 0.9),
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Метаданные
                      _buildMetadataRow(),

                      const SizedBox(height: 30),

                      // Контент
                      _buildContentSection(),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Hero изображение edge-to-edge без border radius
  Widget _buildHeroImage() {
    final List<MediaObject> mediaObjects = _getMediaObjects();

    if (mediaObjects.isEmpty) {
      return Container(color: _backgroundColor);
    }

    final bool isCarousel = mediaObjects.length > 1;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Изображение или карусель
        isCarousel
            ? NotificationListener<ScrollNotification>(
                onNotification: (notification) => true, // Блокируем вертикальный скролл
                child: PageView.builder(
                  controller: _imagePageController,
                  itemCount: mediaObjects.length,
                  physics: const BouncingScrollPhysics(),
                  pageSnapping: true,
                  allowImplicitScrolling: true,
                  onPageChanged: (index) {
                    setState(() => _currentImageIndex = index);
                    HapticFeedback.lightImpact();
                    AnalyticsService().capture(EventSchema.newsMediaSwiped, properties: {
                      'media_index': index,
                      'total_media': mediaObjects.length,
                    });
                  },
                  itemBuilder: (context, index) {
                    final mediaObj = mediaObjects[index];
                    if (mediaObj.isVideo) {
                      return NewsChewiePlayer(
                        mediaObject: mediaObj,
                        autoPlay: false,
                        aspectRatio: _getAspectRatio(index),
                      );
                    }
                    return _buildHeroMediaItem(mediaObj, index);
                  },
                ),
              )
            : _buildHeroMediaItem(mediaObjects.first, 0),

        // iOS-style многослойный blur сверху (плавный переход 4σ → 2σ → 1σ → 0)
        // Слой 1: сильный blur (0-40px)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 40,
          child: IgnorePointer(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
        ),
        // Слой 2: средний blur (40-70px)
        Positioned(
          top: 40,
          left: 0,
          right: 0,
          height: 30,
          child: IgnorePointer(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
        ),
        // Слой 3: легкий blur (70-100px)
        Positioned(
          top: 70,
          left: 0,
          right: 0,
          height: 30,
          child: IgnorePointer(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
        ),
        // Gradient overlay для легкого затемнения
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 100,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Категория (внизу слева, над закруглением карточки)
        Positioned(
          bottom: 40,
          left: 20,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                widget.news.category,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),

        // Page indicator для карусели
        if (isCarousel)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: _buildPageIndicator(mediaObjects.length),
          ),
      ],
    );
  }

  /// Один элемент hero изображения
  Widget _buildHeroMediaItem(MediaObject mediaObj, int index) {
    if (mediaObj.isVideo) {
      return NewsChewiePlayer(
        mediaObject: mediaObj,
        autoPlay: false,
        aspectRatio: _getAspectRatio(index),
      );
    }

    final heroTag = 'news_image_${widget.news.id ?? widget.news.title.hashCode}_$index';

    return GestureDetector(
      onTap: () => _openFullscreenGallery(mediaObj, index),
      child: Hero(
        tag: heroTag,
        child: Image.network(
          mediaObj.url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: (MediaQuery.of(context).size.width * MediaQuery.of(context).devicePixelRatio).round(),
          gaplessPlayback: true,
          filterQuality: FilterQuality.high,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: _isDarkMode ? Colors.grey[900] : Colors.grey[200],
              child: Center(
                child: CupertinoActivityIndicator(
                  color: _primaryTextColor,
                  radius: 14,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: _isDarkMode ? Colors.grey[900] : Colors.grey[200],
              child: Center(
                child: Icon(
                  CupertinoIcons.photo,
                  size: 48,
                  color: _secondaryTextColor.withValues(alpha: 0.5),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Content card с закругленными углами сверху
  Widget _buildContentCard() {
    return Transform.translate(
      offset: const Offset(0, -24), // "Наезжает" на изображение
      child: Container(
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Заголовок
                  Text(
                    widget.news.title,
                    style: TextStyle(
                      color: _primaryTextColor.withValues(alpha: 0.9),
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 16),

                  // Метаданные (источник)
                  _buildMetadataRow(),

                  const SizedBox(height: 24),

                  // Контент
                  _buildContentSection(),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Метаданные (источник, время, ссылки)
  Widget _buildMetadataRow() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _primaryTextColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              widget.news.source.isNotEmpty
                ? widget.news.source[0].toUpperCase()
                : '📰',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _primaryTextColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.news.source,
                style: TextStyle(
                  color: _primaryTextColor.withValues(alpha: 0.7),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getTimeAgo(widget.news.publishedAt, context),
                style: TextStyle(
                  color: _secondaryTextColor,
                  fontSize: 13,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
        if (widget.news.sources.isNotEmpty || (widget.news.link != null && widget.news.link!.isNotEmpty)) ...[
          const SizedBox(width: 8),
          _buildSourcePreviewChip(),
        ],
      ],
    );
  }

  /// Page indicator для карусели
  Widget _buildPageIndicator(int count) {
    return IgnorePointer(
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(count, (index) {
                  final bool isActive = index == _currentImageIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 24 : 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: isActive ? [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ] : null,
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Получить список MediaObjects
  List<MediaObject> _getMediaObjects() {
    if (widget.news.mediaObjects.isNotEmpty) {
      return widget.news.mediaObjects
          .where((obj) => obj.url.startsWith('http'))
          .toList();
    } else if (widget.news.mediaUrls.isNotEmpty) {
      return widget.news.mediaUrls
          .where((url) => url.startsWith('http'))
          .map((url) => MediaObject(type: MediaType.photo, url: url))
          .toList();
    } else if (widget.news.imageUrl.isNotEmpty && widget.news.imageUrl.startsWith('http')) {
      return [MediaObject(type: MediaType.photo, url: widget.news.imageUrl)];
    }
    return [];
  }

  /// Открыть fullscreen галерею
  void _openFullscreenGallery(MediaObject mediaObj, int index) async {
    final List<String> imageUrls = [];
    final List<int> carouselIndices = [];
    final mediaObjects = _getMediaObjects();

    for (int i = 0; i < mediaObjects.length; i++) {
      if (mediaObjects[i].isPhoto) {
        imageUrls.add(mediaObjects[i].url);
        carouselIndices.add(i);
      }
    }

    final imageIndex = imageUrls.indexOf(mediaObj.url);
    if (imageIndex == -1) return;

    HapticFeedback.mediumImpact();

    AnalyticsService().capture(EventSchema.newsImageFullscreen, properties: {
      'image_url': imageUrls[imageIndex],
    });

    final currentHeroTag = 'news_image_${widget.news.id ?? widget.news.title.hashCode}_$index';
    await Navigator.of(context).push<int>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FullscreenImageGallery(
            imageUrls: imageUrls,
            initialIndex: imageIndex,
            heroTag: currentHeroTag,
            newsId: widget.news.id ?? widget.news.title.hashCode,
            carouselIndices: carouselIndices,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }


  bool _hasImage() {
    // Проверяем наличие медиа объектов
    if (widget.news.mediaObjects.isNotEmpty) {
      return widget.news.mediaObjects
          .any((obj) => obj.url.startsWith('http'));
    }

    // Fallback на старые поля
    final List<String> images = widget.news.mediaUrls.isNotEmpty
        ? widget.news.mediaUrls
        : (widget.news.imageUrl.isNotEmpty ? [widget.news.imageUrl] : <String>[]);

    final List<String> httpImages = images
        .where((url) => url.startsWith('http'))
        .toList();

    return httpImages.isNotEmpty;
  }

  /// Получить aspect ratio для изображений из метаданных или использовать дефолтный
  double _getAspectRatio(int imageIndex) {
    // Пытаемся получить aspect ratio из mediaObjects (новый контракт)
    if (widget.news.mediaObjects.isNotEmpty && imageIndex < widget.news.mediaObjects.length) {
      final mediaObj = widget.news.mediaObjects[imageIndex];
      if (mediaObj.width != null && mediaObj.height != null && mediaObj.height! > 0) {
        final aspectRatio = mediaObj.width! / mediaObj.height!;
        return aspectRatio;
      }
    }

    // Fallback: стандартное соотношение 16:9 для фото
    return 16 / 9;
  }

  Widget _buildContentSection() {
    final views = widget.news.contentViews;
    final viewKeys = views.keys.toList();

    // Fallback if no views available
    if (viewKeys.isEmpty) {
      return _buildMarkdownContent(widget.news.content.isNotEmpty
          ? widget.news.content
          : widget.news.subtitle);
    }

    final currentKey = viewKeys[_selectedViewIndex.clamp(0, viewKeys.length - 1)];
    final currentContent = views[currentKey] ?? '';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main content column
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show selector only if multiple views available
            if (_shouldShowViewToggle) ...[
              _buildViewSelector(viewKeys),
              const SizedBox(height: 12),
            ],

            // Animated content container
            AnimatedBuilder(
              animation: _tabSwitchController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _tabFadeAnimation,
                  child: SlideTransition(
                    position: _tabSlideAnimation,
                    child: ScaleTransition(
                      scale: _tabScaleAnimation,
                      child: Container(
                        key: ValueKey(_selectedViewIndex),
                        child: _buildMarkdownContent(currentContent),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),

        // Dropdown ABOVE all content (rendered last = on top)
        if (_shouldShowViewToggle && (_isDropdownOpen || _dropdownController.isAnimating))
          Positioned(
            top: 26,
            left: 0,
            child: _buildViewDropdown(viewKeys),
          ),
      ],
    );
  }

  void _toggleDropdown() {
    setState(() {
      _isDropdownOpen = !_isDropdownOpen;
    });

    if (_isDropdownOpen) {
      _dropdownController.forward();
    } else {
      _dropdownController.reverse();
    }

    HapticFeedback.selectionClick();
  }

  void _selectView(int index, List<String> viewKeys) {
    if (_selectedViewIndex != index) {
      setState(() {
        _selectedViewIndex = index;
        _isDropdownOpen = false;
      });

      _dropdownController.reverse();
      _tabSwitchController.reset();
      _tabSwitchController.forward();

      HapticFeedback.mediumImpact();

      AnalyticsService().capture(EventSchema.newsDetailViewChanged, properties: {
        'view_type': viewKeys[index],
      });
    } else {
      // Just close dropdown if same view selected
      setState(() {
        _isDropdownOpen = false;
      });
      _dropdownController.reverse();
    }
  }

  Widget _buildViewSelector(List<String> viewKeys) {
    final currentKey = viewKeys[_selectedViewIndex.clamp(0, viewKeys.length - 1)];
    final accentColor = _isDarkMode ? AppColors.accent : AppColors.lightAccent;

    // Pill background color
    final pillBgColor = _isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);

    return GestureDetector(
      onTap: _toggleDropdown,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: pillBgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Icon(
              ViewLabelHelper.getIcon(currentKey),
              color: accentColor,
              size: 16,
            ),
            const SizedBox(width: 6),
            // Current view name
            Text(
              ViewLabelHelper.getLabel(context, currentKey),
              style: TextStyle(
                color: _primaryTextColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(width: 4),
            // Animated arrow
            RotationTransition(
              turns: _arrowRotationAnimation,
              child: Icon(
                CupertinoIcons.chevron_down,
                color: _secondaryTextColor.withValues(alpha: 0.6),
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewDropdown(List<String> viewKeys) {
    final accentColor = _isDarkMode ? AppColors.accent : AppColors.lightAccent;

    final bgColor = _isDarkMode ? const Color(0xFF1C1C1E) : Colors.white;

    return FadeTransition(
      opacity: _dropdownFadeAnimation,
      child: SlideTransition(
        position: _dropdownSlideAnimation,
        child: Material(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.25),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(viewKeys.length, (index) {
              final key = viewKeys[index];
              final isSelected = _selectedViewIndex == index;

              return GestureDetector(
                onTap: () => _selectView(index, viewKeys),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      // Icon
                      Icon(
                        ViewLabelHelper.getIcon(key),
                        color: _secondaryTextColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      // Label
                      Text(
                        ViewLabelHelper.getLabel(context, key),
                        style: TextStyle(
                          color: _primaryTextColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      // Checkmark for selected (right side) - always reserve space
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 16,
                        child: isSelected
                          ? Icon(
                              CupertinoIcons.checkmark,
                              color: accentColor,
                              size: 16,
                            )
                          : null,
                      ),
                    ],
                  ),
                ),
              );
            }),
            ),
          ),
        ),
      ),
    );
  }

  // Превью-чип источника справа от блока названия/времени
  Widget _buildSourcePreviewChip() {
    final accentColor = _isDarkMode ? AppColors.accent : AppColors.lightAccent;
    final borderColor = _secondaryTextColor.withValues(alpha:0.3);
    final urls = widget.news.sources.isNotEmpty
        ? widget.news.sources.map((s) => s.sourceUrl).whereType<String>().where((u) => u.isNotEmpty).toList()
        : (widget.news.link != null && widget.news.link!.isNotEmpty ? [widget.news.link!] : <String>[]);

    final bool isMultiple = urls.length > 1;
    final String label = isMultiple ? '+${urls.length}' : (urls.isNotEmpty ? _shortenLabel(_extractDomain(urls.first), 5) : '');
    final VoidCallback? onTap = isMultiple
        ? () {
            // Multiple sources - show modal
            HapticFeedback.mediumImpact();
            _showSourcesModal(context, urls);

            // Analytics: sources modal opened
            AnalyticsService().capture(EventSchema.sourcesModalOpened, properties: {
              'feed_id': widget.news.id ?? 'unknown',
              'source_count': urls.length,
            });
          }
        : (urls.isNotEmpty
            ? () {
                final target = urls.first;
                // Tapping source chip
                HapticFeedback.lightImpact();
                _openUrlSafe(target);
              }
            : null);

    return MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha:0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.link,
                size: 12,
                color: _isDarkMode ? Colors.white : accentColor,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _extractDomain(String url) {
    try {
      final trimmed = url.trim();
      final withoutScheme = trimmed.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
      var host = withoutScheme.split('/').first.split('?').first.split('#').first;
      if (host.startsWith('www.')) host = host.substring(4);
      return host.isNotEmpty ? host : url;
    } catch (_) {
      return url.trim().replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
    }
  }

  String _shortenLabel(String input, int maxLen) {
    if (input.length <= maxLen) return input;
    return input.substring(0, maxLen);
  }

  Future<void> _openUrlSafe(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  /// Shows a modal with all sources in custom iOS-style design
  void _showSourcesModal(BuildContext context, List<String> urls) {
    final l10n = AppLocalizations.of(context)!;
    final displayUrls = urls.take(15).toList();

    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext modalContext) {
        final isDark = _isDarkMode;
        final bgColor = isDark
            ? const Color(0xFF1C1C1E)
            : CupertinoColors.white;
        final secondaryColor = isDark
            ? Colors.white.withValues(alpha: 0.6)
            : Colors.black.withValues(alpha: 0.5);
        final dividerColor = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.1);

        return Container(
          margin: const EdgeInsets.all(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                decoration: BoxDecoration(
                  color: bgColor.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        l10n.sourcesModalTitle,
                        style: TextStyle(
                          color: secondaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Divider(height: 1, color: dividerColor),

                    // Links list
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: displayUrls.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: dividerColor),
                        itemBuilder: (context, index) {
                          final url = displayUrls[index];
                          final domain = _extractDomain(url);
                          return CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            onPressed: () {
                              Navigator.of(modalContext).pop();
                              HapticFeedback.lightImpact();
                              _openUrlSafe(url);
                              AnalyticsService().capture(EventSchema.sourceLinkOpened, properties: {
                                'source_url': url,
                              });
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: _primaryTextColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    CupertinoIcons.link,
                                    size: 14,
                                    color: _primaryTextColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    url.replaceFirst(RegExp(r'^https?://'), ''),
                                    style: TextStyle(
                                      color: _primaryTextColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  CupertinoIcons.arrow_up_right,
                                  size: 14,
                                  color: secondaryColor,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _preprocessMarkdownContent(String content) {
    if (content.isEmpty) return content;

    // Replace single \n with markdown hard break (two spaces + \n)
    // But preserve paragraph breaks (\n\n)
    return content
      .replaceAll('\r\n', '\n')  // Normalize Windows line endings
      .replaceAll('\n\n', '<<<PARAGRAPH_BREAK>>>')  // Temporarily mark paragraph breaks
      .replaceAll('\n', '  \n')  // Convert single newlines to hard breaks
      .replaceAll('<<<PARAGRAPH_BREAK>>>', '\n\n');  // Restore paragraph breaks
  }

  Widget _buildMarkdownContent(String content) {
    final processedContent = _preprocessMarkdownContent(content);
    return MarkdownBody(
      data: processedContent,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        // Основные стили текста
        p: TextStyle(
          color: _primaryTextColor.withValues(alpha:0.85),
          fontSize: 16,
          height: 1.6,
          letterSpacing: 0.1,
          fontWeight: FontWeight.w400,
        ),
        
        // Заголовки
        h1: TextStyle(
          color: _primaryTextColor.withValues(alpha:0.95),
          fontSize: 24,
          fontWeight: FontWeight.bold,
          height: 1.4,
          letterSpacing: -0.3,
        ),
        h2: TextStyle(
          color: _primaryTextColor.withValues(alpha:0.95),
          fontSize: 22,
          fontWeight: FontWeight.bold,
          height: 1.4,
          letterSpacing: -0.2,
        ),
        h3: TextStyle(
          color: _primaryTextColor.withValues(alpha:0.95),
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1.4,
          letterSpacing: -0.1,
        ),
        h4: TextStyle(
          color: _primaryTextColor.withValues(alpha:0.9),
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        h5: TextStyle(
          color: _primaryTextColor.withValues(alpha:0.9),
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        h6: TextStyle(
          color: _primaryTextColor.withValues(alpha:0.85),
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        
        // Жирный и курсивный текст
        strong: TextStyle(
          color: _primaryTextColor.withValues(alpha:0.95),
          fontWeight: FontWeight.w700,
        ),
        em: TextStyle(
          color: _primaryTextColor.withValues(alpha:0.9),
          fontStyle: FontStyle.italic,
        ),
        
        // Ссылки
        a: TextStyle(
          color: _isDarkMode ? const Color(0xFF4FC3F7) : const Color(0xFF1976D2),
          decoration: TextDecoration.underline,
          decorationColor: (_isDarkMode ? const Color(0xFF4FC3F7) : const Color(0xFF1976D2)).withValues(alpha:0.3),
          fontWeight: FontWeight.w500,
        ),
        
        // Код
        code: TextStyle(
          backgroundColor: _isDarkMode 
            ? Colors.white.withValues(alpha:0.1) 
            : Colors.black.withValues(alpha:0.05),
          color: _isDarkMode ? const Color(0xFFE91E63) : const Color(0xFFD32F2F),
          fontSize: 14,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w500,
        ),
        
        // Блоки кода
        codeblockDecoration: BoxDecoration(
          color: _isDarkMode 
            ? Colors.white.withValues(alpha:0.08) 
            : Colors.black.withValues(alpha:0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isDarkMode 
              ? Colors.white.withValues(alpha:0.1) 
              : Colors.black.withValues(alpha:0.08),
            width: 1,
          ),
        ),
        codeblockPadding: const EdgeInsets.all(16),
        
        // Цитаты
        blockquote: TextStyle(
          color: _primaryTextColor.withValues(alpha:0.7),
          fontSize: 16,
          height: 1.5,
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          color: _isDarkMode 
            ? Colors.white.withValues(alpha:0.05) 
            : Colors.black.withValues(alpha:0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: _isDarkMode ? const Color(0xFF4FC3F7) : const Color(0xFF1976D2),
              width: 4,
            ),
          ),
        ),
        
        // Списки
        listBullet: TextStyle(
          color: _isDarkMode ? const Color(0xFF4FC3F7) : const Color(0xFF1976D2),
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        
        // Отступы между элементами
        h1Padding: const EdgeInsets.only(top: 24, bottom: 16),
        h2Padding: const EdgeInsets.only(top: 20, bottom: 12),
        h3Padding: const EdgeInsets.only(top: 16, bottom: 8),
        h4Padding: const EdgeInsets.only(top: 12, bottom: 6),
        h5Padding: const EdgeInsets.only(top: 12, bottom: 6),
        h6Padding: const EdgeInsets.only(top: 8, bottom: 4),
        pPadding: const EdgeInsets.only(bottom: 16),
        listIndent: 24,
      ),

      // Custom builders for beautiful list rendering and text highlighting
      builders: {
        'ul': CustomMarkdownListBuilder(isDarkMode: _isDarkMode),
        'ol': CustomMarkdownListBuilder(isDarkMode: _isDarkMode),
        'mark': HighlightBuilder(isDarkMode: _isDarkMode),
      },

      // Custom markdown extensions for ==highlight== syntax
      extensionSet: md.ExtensionSet(
        [],
        [HighlightSyntax()],
      ),

      // Обработчики ссылок
      onTapLink: (text, href, title) async {
        if (href != null && href.isNotEmpty) {
          try {
            // Markdown link tap
            final uri = Uri.parse(href);
            if (await canLaunchUrl(uri)) {
              await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
            }
          } catch (e) {
            // Показываем уведомление об ошибке
            if (mounted) {
              final l10n = AppLocalizations.of(context)!;
              showCupertinoDialog(
                context: context,
                builder: (context) => CupertinoAlertDialog(
                  title: Text(l10n.error),
                  content: Text(l10n.couldNotOpenLink(href)),
                  actions: [
                    CupertinoDialogAction(
                      child: const Text('OK'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              );
            }
          }
        }
      },
    );
  }


}

// Улучшенная анимированная кнопка с glassmorphism и ripple эффектом
class _AnimatedButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDarkMode;
  final bool isScrolled;
  final String animationType; // 'rotation' или 'bounce'

  const _AnimatedButton({
    required this.icon,
    required this.onTap,
    required this.isDarkMode,
    required this.isScrolled,
    this.animationType = 'bounce',
  });

  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton>
    with TickerProviderStateMixin {
  late AnimationController _pressController;
  late AnimationController _rippleController;
  late AnimationController _iconController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _rippleAnimation;
  late Animation<double> _rippleFadeAnimation;
  late Animation<double> _iconAnimation;

  bool _isPressed = false;

  @override
  void initState() {
    super.initState();

    // Контроллер для press анимации (scale эффект)
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    // Контроллер для ripple эффекта
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Контроллер для анимации иконки
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Scale анимация при нажатии
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.93,
    ).animate(CurvedAnimation(
      parent: _pressController,
      curve: Curves.easeInOut,
    ));

    // Ripple расширение
    _rippleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    ));

    // Ripple fade out
    _rippleFadeAnimation = Tween<double>(
      begin: 0.6,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _rippleController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));

    // Анимация иконки (rotation или bounce)
    _iconAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _iconController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _pressController.dispose();
    _rippleController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _pressController.reverse();
    _rippleController.forward(from: 0.0);
    _iconController.forward(from: 0.0);

    // Haptic feedback
    HapticFeedback.mediumImpact();

    // Вызываем callback
    widget.onTap();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final primaryTextColor = widget.isDarkMode
        ? AppColors.textPrimary
        : AppColors.lightTextPrimary;
    final accentColor = widget.isDarkMode
        ? AppColors.accent
        : AppColors.lightAccent;

    return AnimatedScale(
      duration: const Duration(milliseconds: 300),
      scale: widget.isScrolled ? 1.0 : 1.05,
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Stack(
                  children: [
                    // Основная кнопка с glassmorphism
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            // Lighter Glass style
                            color: widget.isDarkMode
                                ? (_isPressed
                                    ? Colors.white.withValues(alpha: 0.22)
                                    : Colors.white.withValues(alpha: 0.15))
                                : (_isPressed
                                    ? Colors.black.withValues(alpha: 0.12)
                                    : Colors.black.withValues(alpha: 0.08)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: widget.isDarkMode
                                  ? Colors.white.withValues(alpha: 0.40)
                                  : Colors.black.withValues(alpha: 0.25),
                              width: 1.0,
                            ),
                            // Простые тени
                            boxShadow: [
                              BoxShadow(
                                color: widget.isDarkMode
                                    ? Colors.black.withValues(alpha: 0.2)
                                    : Colors.grey.shade400.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Center(
                            child: AnimatedBuilder(
                              animation: _iconAnimation,
                              builder: (context, child) {
                                // Разные анимации для разных типов кнопок
                                if (widget.animationType == 'rotation') {
                                  // Rotation для chevron (кнопка назад)
                                  return Transform.rotate(
                                    angle: _iconAnimation.value * -0.3, // -17 градусов
                                    child: Transform.scale(
                                      scale: 1.0 + (_iconAnimation.value * 0.2),
                                      child: Icon(
                                        widget.icon,
                                        color: primaryTextColor,
                                        size: 20,
                                      ),
                                    ),
                                  );
                                } else {
                                  // Bounce для share
                                  return Transform.translate(
                                    offset: Offset(0, -_iconAnimation.value * 4),
                                    child: Transform.scale(
                                      scale: 1.0 + (_iconAnimation.value * 0.3),
                                      child: Icon(
                                        widget.icon,
                                        color: primaryTextColor,
                                        size: 20,
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Ripple эффект
                    AnimatedBuilder(
                      animation: _rippleAnimation,
                      builder: (context, child) {
                        if (_rippleAnimation.value == 0.0) {
                          return const SizedBox.shrink();
                        }
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                center: Alignment.center,
                                radius: _rippleAnimation.value,
                                colors: [
                                  accentColor.withValues(alpha: _rippleFadeAnimation.value),
                                  accentColor.withValues(alpha: 0.0),
                                ],
                                stops: const [0.0, 1.0],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CustomHeaderDelegate extends SliverPersistentHeaderDelegate {
  final bool isScrolled;
  final String title;
  final VoidCallback onShare;
  final bool isDarkMode;
  final bool showShareButton;

  _CustomHeaderDelegate({
    required this.isScrolled,
    required this.title,
    required this.onShare,
    required this.isDarkMode,
    this.showShareButton = true, // Default to true for backward compatibility
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final backgroundColor = isDarkMode ? AppColors.background : AppColors.lightBackground;
    final primaryTextColor = isDarkMode ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final accentColor = isDarkMode ? AppColors.accent : AppColors.lightAccent;

    // Плавный прогресс анимации появления элементов при скролле
    final scrollProgress = (shrinkOffset / 50).clamp(0.0, 1.0);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: isScrolled ? 20 : 0,
          sigmaY: isScrolled ? 20 : 0,
        ),
        child: Container(
          decoration: BoxDecoration(
            // Glass morphism эффект с градиентом
            gradient: isScrolled
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDarkMode
                        ? [
                            backgroundColor.withValues(alpha: 0.85),
                            backgroundColor.withValues(alpha: 0.75),
                          ]
                        : [
                            backgroundColor.withValues(alpha: 0.9),
                            backgroundColor.withValues(alpha: 0.8),
                          ],
                  )
                : null,
            // Тонкая тень снизу для отделения от контента
            boxShadow: isScrolled
                ? [
                    BoxShadow(
                      color: (isDarkMode ? Colors.black : Colors.grey.shade300)
                          .withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                      spreadRadius: 0,
                    ),
                  ]
                : null,
            border: isScrolled
                ? Border(
                    bottom: BorderSide(
                      // Более контрастный border с акцентным оттенком
                      color: accentColor.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  )
                : null,
          ),
          child: SafeArea(
            bottom: false,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Stack(
                children: [
                  // Заголовок по центру с плавным появлением
                  Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: scrollProgress,
                      curve: Curves.easeInOut,
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 300),
                        offset: Offset(0, isScrolled ? 0 : 0.5),
                        curve: Curves.easeOutCubic,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 56),
                          child: Text(
                            title,
                            style: TextStyle(
                              color: primaryTextColor,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Кнопка назад с улучшенной анимацией
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _AnimatedButton(
                        icon: CupertinoIcons.chevron_left,
                        onTap: () {
                          Navigator.of(context).pop();
                        },
                        isDarkMode: isDarkMode,
                        isScrolled: isScrolled,
                        animationType: 'rotation',
                      ),
                    ),
                  ),

                  // Кнопка share с улучшенной анимацией (показывается только если флаг включен)
                  if (showShareButton)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _AnimatedButton(
                          icon: CupertinoIcons.square_arrow_up,
                          onTap: onShare,
                          isDarkMode: isDarkMode,
                          isScrolled: isScrolled,
                          animationType: 'bounce',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 44 + MediaQueryData.fromView(WidgetsBinding.instance.platformDispatcher.views.first).padding.top;

  @override
  double get minExtent => 44 + MediaQueryData.fromView(WidgetsBinding.instance.platformDispatcher.views.first).padding.top;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return oldDelegate is! _CustomHeaderDelegate ||
           oldDelegate.isScrolled != isScrolled ||
           oldDelegate.title != title ||
           oldDelegate.showShareButton != showShareButton;
  }
}

/// Glass button с blur эффектом для hero layout
class _GlassButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassButton({
    required this.icon,
    required this.onTap,
  });

  @override
  State<_GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<_GlassButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _isPressed
                        ? Colors.white.withValues(alpha: 0.22)
                        : Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.40),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      widget.icon,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}