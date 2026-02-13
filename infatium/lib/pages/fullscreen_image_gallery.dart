import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:dismissible_page/dismissible_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui';
import 'package:dio/dio.dart';
import '../l10n/generated/app_localizations.dart';

class FullscreenImageGallery extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String heroTag;
  final dynamic newsId;
  final List<int>? carouselIndices; // Индексы изображений в оригинальной карусели

  const FullscreenImageGallery({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    required this.heroTag,
    required this.newsId,
    this.carouselIndices,
  });

  @override
  State<FullscreenImageGallery> createState() => _FullscreenImageGalleryState();
}

class _FullscreenImageGalleryState extends State<FullscreenImageGallery>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  bool _isControlsVisible = true;
  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsOpacityAnimation;

  // Zoom indicator
  double _currentScale = 1.0;
  bool _showZoomIndicator = false;
  late AnimationController _zoomIndicatorController;
  late Animation<double> _zoomIndicatorOpacity;

  // UI opacity для fade при dismiss
  double _uiOpacity = 1.0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _controlsOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controlsAnimationController,
      curve: Curves.easeInOut,
    ));

    _zoomIndicatorController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _zoomIndicatorOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _zoomIndicatorController,
      curve: Curves.easeOut,
    ));

    _controlsAnimationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _controlsAnimationController.dispose();
    _zoomIndicatorController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _isControlsVisible = !_isControlsVisible;
      if (_isControlsVisible) {
        _controlsAnimationController.forward();
      } else {
        _controlsAnimationController.reverse();
      }
    });
  }

  void _updateZoomLevel(double scale) {
    setState(() {
      _currentScale = scale;
      _showZoomIndicator = scale > 1.05;
    });

    if (_showZoomIndicator) {
      _zoomIndicatorController.forward();

      // Auto-hide после 1 секунды
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && _currentScale <= 1.05) {
          _zoomIndicatorController.reverse().then((_) {
            if (mounted) {
              setState(() => _showZoomIndicator = false);
            }
          });
        }
      });
    } else {
      _zoomIndicatorController.reverse();
    }
  }

  Future<void> _shareImage() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final imageUrl = widget.imageUrls[_currentIndex];
      // iOS 26 requires sharePositionOrigin for Liquid Glass
      final box = context.findRenderObject() as RenderBox?;
      await Share.share(
        imageUrl,
        subject: l10n.shareImage,
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : const Rect.fromLTWH(0, 0, 100, 100),
      );
      HapticFeedback.mediumImpact();
    } catch (e) {
      _showError(l10n.shareImageFailed);
    }
  }

  Future<void> _downloadImage() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      // Проверка разрешений
      if (await Permission.storage.request().isGranted ||
          await Permission.photos.request().isGranted) {

        final imageUrl = widget.imageUrls[_currentIndex];

        // Показываем loading
        if (mounted) {
          _showLoading(l10n.saving);
        }

        // Скачиваем изображение
        final dio = Dio();
        final response = await dio.get(
          imageUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        final Uint8List bytes = Uint8List.fromList(response.data as List<int>);

        // Сохраняем в галерею
        await Gal.putImageBytes(bytes);

        if (mounted) {
          Navigator.of(context).pop(); // Close loading
          _showSuccess(l10n.imageSavedToGallery);
          HapticFeedback.mediumImpact();
        }
      } else {
        _showError(l10n.noPermissionToSave);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading if open
      }
      _showError(l10n.imageSaveError);
    }
  }

  void _showLoading(String message) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(
                radius: 16,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    _showToast(message, CupertinoIcons.checkmark_circle_fill, Colors.green);
  }

  void _showError(String message) {
    _showToast(message, CupertinoIcons.xmark_circle_fill, Colors.red);
  }

  void _showToast(String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.black.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Слой 1: DismissiblePage с галереей (свайпается)
        DismissiblePage(
          onDismissed: () => Navigator.of(context).pop(_currentIndex),
          direction: DismissiblePageDismissDirection.vertical,
          backgroundColor: Colors.black,
          isFullScreen: true,
          disabled: _currentScale > 1.0, // Отключаем dismiss когда изображение зумировано
          child: Theme(
            data: ThemeData(
              brightness: Brightness.dark,
              platform: TargetPlatform.iOS,
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: PhotoViewGallery.builder(
                scrollPhysics: const BouncingScrollPhysics(),
                builder: (BuildContext context, int index) {
                  final imageUrl = widget.imageUrls[index];
                  // Используем индекс из оригинальной карусели, если он передан
                  final carouselIndex = widget.carouselIndices != null && index < widget.carouselIndices!.length
                      ? widget.carouselIndices![index]
                      : index;
                  final heroTag = 'news_image_${widget.newsId}_$carouselIndex';
                  return PhotoViewGalleryPageOptions(
                    imageProvider: NetworkImage(imageUrl),
                    initialScale: PhotoViewComputedScale.contained,
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 4.0,
                    heroAttributes: PhotoViewHeroAttributes(tag: heroTag),
                    onTapUp: (context, details, controllerValue) {
                      _toggleControls();
                    },
                    onScaleEnd: (context, details, controllerValue) {
                      _updateZoomLevel(controllerValue.scale ?? 1.0);
                    },
                  );
                },
                itemCount: widget.imageUrls.length,
                loadingBuilder: (context, event) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CupertinoActivityIndicator(
                        radius: 20,
                        color: Colors.white,
                      ),
                      if (event != null && event.expectedTotalBytes != null) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: 200,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: event.cumulativeBytesLoaded / event.expectedTotalBytes!,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              minHeight: 3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                backgroundDecoration: const BoxDecoration(
                  color: Colors.black,
                ),
                pageController: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                    _currentScale = 1.0;
                    _showZoomIndicator = false;
                  });
                  HapticFeedback.selectionClick();
                },
                enableRotation: false,
              ),
            ),
          ),
        ),

        // Слой 2: UI элементы поверх (не свайпаются, fade при dismiss)
        Positioned.fill(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // Отслеживаем скролл для fade UI
              if (notification is ScrollUpdateNotification && _currentScale <= 1.0) {
                final delta = notification.scrollDelta?.abs() ?? 0;
                if (delta > 0) {
                  setState(() {
                    _uiOpacity = (_uiOpacity - (delta / 500)).clamp(0.0, 1.0);
                  });
                }
              } else if (notification is ScrollEndNotification) {
                // Возвращаем opacity после окончания скролла
                Future.delayed(const Duration(milliseconds: 150), () {
                  if (mounted && _uiOpacity < 1.0) {
                    setState(() {
                      _uiOpacity = 1.0;
                    });
                  }
                });
              }
              return false; // Не блокируем уведомления
            },
            child: AnimatedOpacity(
              opacity: _uiOpacity,
              duration: const Duration(milliseconds: 150),
              child: IgnorePointer(
                ignoring: false,
                child: Stack(
                  children: [
              // Zoom indicator
              if (_showZoomIndicator)
                Positioned(
                  top: 100,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FadeTransition(
                      opacity: _zoomIndicatorOpacity,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '${_currentScale.toStringAsFixed(1)}x',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Градиентный оверлей сверху
              if (_isControlsVisible)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: FadeTransition(
                    opacity: _controlsOpacityAnimation,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Top controls (close button, counter, actions)
              if (_isControlsVisible)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: FadeTransition(
                      opacity: _controlsOpacityAnimation,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Кнопка закрытия
                            _buildActionButton(
                              icon: CupertinoIcons.xmark,
                              onTap: () => Navigator.of(context).pop(_currentIndex),
                            ),

                            // Счетчик изображений
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '${_currentIndex + 1} / ${widget.imageUrls.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Action buttons (share, download)
                            Row(
                              children: [
                                _buildActionButton(
                                  icon: CupertinoIcons.share,
                                  onTap: _shareImage,
                                ),
                                const SizedBox(width: 8),
                                _buildActionButton(
                                  icon: CupertinoIcons.arrow_down_to_line,
                                  onTap: _downloadImage,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Градиентный оверлей снизу
              if (_isControlsVisible && widget.imageUrls.length > 1)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: FadeTransition(
                    opacity: _controlsOpacityAnimation,
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Индикаторы страниц снизу
              if (_isControlsVisible && widget.imageUrls.length > 1)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: FadeTransition(
                      opacity: _controlsOpacityAnimation,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 0.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(
                                    widget.imageUrls.length,
                                    (index) {
                                      final bool isActive = index == _currentIndex;
                                      return AnimatedContainer(
                                        duration: const Duration(milliseconds: 400),
                                        curve: Curves.easeInOutCubic,
                                        margin: const EdgeInsets.symmetric(horizontal: 3),
                                        width: isActive ? 24 : 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? Colors.white
                                              : Colors.white.withOpacity(0.35),
                                          borderRadius: BorderRadius.circular(2),
                                          boxShadow: isActive
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.white.withOpacity(0.3),
                                                    blurRadius: 4,
                                                    spreadRadius: 0,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
