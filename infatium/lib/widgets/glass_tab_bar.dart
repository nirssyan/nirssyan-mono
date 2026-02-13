import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';

class GlassTabBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;
  final List<GlassTabItem> items;
  final GlobalKey? homeTabKey;
  /// GlobalKeys for all tab items (for onboarding spotlight)
  final List<GlobalKey>? tabKeys;

  const GlassTabBar({
    Key? key,
    required this.currentIndex,
    this.onTap,
    required this.items,
    this.homeTabKey,
    this.tabKeys,
  }) : super(key: key);

  @override
  State<GlassTabBar> createState() => _GlassTabBarState();
}

class _GlassTabBarState extends State<GlassTabBar>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rippleAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: widget.currentIndex.toDouble(),
      end: widget.currentIndex.toDouble(),
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOutCubic,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _shimmerAnimation = Tween<double>(
      begin: -2.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _rippleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    ));

    // Запускаем циклические анимации
    _shimmerController.repeat(reverse: true);
    _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(GlassTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _animateToTab(widget.currentIndex);
    }
  }

  void _animateToTab(int index) {
    final currentPosition = _slideAnimation.value;
    final targetPosition = index.toDouble();
    final distance = (targetPosition - currentPosition).abs();
    
    // Используем более плавную анимацию с одинаковой продолжительностью
    final duration = distance > 2 
        ? const Duration(milliseconds: 350)
        : const Duration(milliseconds: 250);
    
    _slideController.duration = duration;
    
    _slideAnimation = Tween<double>(
      begin: currentPosition,
      end: targetPosition,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: distance > 2 ? Curves.easeInOutQuart : Curves.easeInOutCubic,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    // Убеждаемся, что анимация начинается с текущей позиции
    if (_slideController.isAnimating) {
      _slideController.stop();
    }
    if (_scaleController.isAnimating) {
      _scaleController.stop();
    }
    
    _slideController.reset();
    _scaleController.reset();
    
    _slideController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scaleController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  // Публичный метод для запуска ripple эффекта на Home табе
  void triggerHomeTabRipple() {
    _rippleController.reset();
    _rippleController.forward();
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    // Учитываем отступы более точно
    final totalContainerWidth = screenWidth - 32; // margins left/right
    final itemWidth = totalContainerWidth / widget.items.length;

    // Определяем цвета в зависимости от темы
    final tabBarBackground = isDark 
        ? [
            AppColors.surface.withOpacity(0.9),
            AppColors.background.withOpacity(0.8),
            AppColors.surface.withOpacity(0.9),
          ]
        : [
            AppColors.lightSurface.withOpacity(0.95),
            AppColors.lightBackground.withOpacity(0.9),
            AppColors.lightSurface.withOpacity(0.95),
          ];
    
    final borderColor = isDark 
        ? AppColors.textPrimary.withOpacity(0.15)
        : AppColors.lightAccent.withOpacity(0.1);
    
    final shadowColor = isDark 
        ? Colors.black.withOpacity(0.4)
        : Colors.black.withOpacity(0.08);
    
    final highlightColor = isDark 
        ? AppColors.textPrimary.withOpacity(0.1)
        : AppColors.lightAccent.withOpacity(0.05);
    
    final indicatorColors = isDark 
        ? [
            AppColors.accent.withOpacity(0.95),
            AppColors.accent.withOpacity(0.85),
            AppColors.accentSecondary.withOpacity(0.9),
          ]
        : [
            AppColors.lightAccent.withOpacity(0.95),
            AppColors.lightAccent.withOpacity(0.85),
            AppColors.lightAccentSecondary.withOpacity(0.9),
          ];
    
    final selectedIconColor = isDark ? AppColors.background : AppColors.lightBackground;
    final unselectedIconColor = isDark 
        ? AppColors.textPrimary.withOpacity(0.7)
        : AppColors.lightTextSecondary.withOpacity(0.8);

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: tabBarBackground,
                stops: const [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: borderColor,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: isDark ? 30 : 15,
                  offset: const Offset(0, 12),
                  spreadRadius: -5,
                ),
                BoxShadow(
                  color: highlightColor,
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Переливающийся фон
                AnimatedBuilder(
                  animation: _shimmerAnimation,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        gradient: LinearGradient(
                          begin: Alignment(_shimmerAnimation.value - 1, -1),
                          end: Alignment(_shimmerAnimation.value + 1, 1),
                          colors: [
                            Colors.transparent,
                            (isDark ? AppColors.textPrimary : AppColors.lightAccent).withOpacity(0.03),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    );
                  },
                ),
                
                // Плавающий индикатор
                AnimatedBuilder(
                  animation: _slideAnimation,
                  builder: (context, child) {
                    return AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        // Исправляем позиционирование индикатора - простой и точный подход
                        final indicatorWidth = itemWidth * 0.75;
                        final currentTabIndex = _slideAnimation.value;
                        
                        // Точный расчет левой позиции для каждого таба
                        var indicatorLeft = currentTabIndex * itemWidth + (itemWidth - indicatorWidth) / 2;
                        
                        // Специальная коррекция для четвертого таба (профиль)
                        final roundedIndex = currentTabIndex.round();
                        if (roundedIndex == 3) { // четвертый таб (индекс 3)
                          indicatorLeft -= 2; // сдвигаем влево на 2 пикселя
                        }
                        
                        return Positioned(
                          left: indicatorLeft,
                          top: 8,
                          bottom: 8,
                          width: indicatorWidth,
                          child: Transform.scale(
                            scale: _scaleAnimation.value,
                            child: AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(22),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: indicatorColors,
                                      stops: const [0.0, 0.7, 1.0],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isDark ? AppColors.accent : AppColors.lightAccent).withOpacity(0.4),
                                        blurRadius: 15 * _pulseAnimation.value,
                                        offset: const Offset(0, 0),
                                        spreadRadius: -2,
                                      ),
                                      BoxShadow(
                                        color: (isDark ? Colors.black : Colors.grey).withOpacity(0.15),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                        spreadRadius: -3,
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(22),
                                      gradient: LinearGradient(
                                        begin: Alignment(_shimmerAnimation.value - 1, -1),
                                        end: Alignment(_shimmerAnimation.value + 1, 1),
                                        colors: [
                                          Colors.transparent,
                                          (isDark ? AppColors.textPrimary : AppColors.lightBackground).withOpacity(0.3),
                                          Colors.transparent,
                                        ],
                                        stops: const [0.0, 0.5, 1.0],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                
                // Иконки табов
                Row(
                  children: widget.items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isSelected = index == widget.currentIndex;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (widget.onTap != null) {
                            HapticFeedback.lightImpact();
                            widget.onTap!(index);
                          }
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Stack(
                          children: [
                            // Ripple эффект для Home таба (индекс 0)
                            if (index == 0)
                              AnimatedBuilder(
                                animation: _rippleAnimation,
                                builder: (context, child) {
                                  if (_rippleAnimation.value == 0.0) return const SizedBox();

                                  return Positioned.fill(
                                    child: Center(
                                      child: Container(
                                        width: 64 * _rippleAnimation.value,
                                        height: 64 * _rippleAnimation.value,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: (isDark ? AppColors.accent : AppColors.lightAccent).withOpacity(
                                            (1 - _rippleAnimation.value) * 0.4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),

                            Container(
                              key: widget.tabKeys != null && index < widget.tabKeys!.length
                                  ? widget.tabKeys![index]
                                  : (index == 0 ? widget.homeTabKey : null),
                              height: 64,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                              child: Center(
                                child: AnimatedScale(
                              scale: isSelected ? 1.15 : 1.0,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOutBack,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                padding: const EdgeInsets.all(10),
                                child: isSelected
                                    ? Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // Эффект свечения для выбранной иконки
                                          AnimatedBuilder(
                                            animation: _pulseAnimation,
                                            builder: (context, child) {
                                              return Icon(
                                                item.icon,
                                                color: selectedIconColor.withOpacity(0.1 * _pulseAnimation.value),
                                                size: 28 + (4 * _pulseAnimation.value),
                                              );
                                            },
                                          ),
                                          // Основная иконка
                                          ShaderMask(
                                            shaderCallback: (bounds) => LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                selectedIconColor,
                                                selectedIconColor.withOpacity(0.8),
                                                selectedIconColor.withOpacity(0.9),
                                              ],
                                            ).createShader(bounds),
                                            child: Icon(
                                              item.icon,
                                              color: selectedIconColor,
                                              size: 26,
                                            ),
                                          ),
                                        ],
                                      )
                                      : AnimatedOpacity(
                                          opacity: 0.6,
                                          duration: const Duration(milliseconds: 200),
                                          child: Icon(
                                            item.icon,
                                            color: unselectedIconColor,
                                            size: 24,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GlassTabItem {
  final IconData icon;
  final String title;
  final bool isFab;

  const GlassTabItem({
    required this.icon,
    required this.title,
    this.isFab = false,
  });
} 