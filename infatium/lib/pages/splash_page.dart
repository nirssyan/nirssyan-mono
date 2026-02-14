import 'package:flutter/cupertino.dart';
import '../theme/colors.dart';
import '../config/app_config.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  static const String _text = AppConfig.splashText;
  static const Duration _charDelay = Duration(milliseconds: 40);
  late final AnimationController _controller;
  late final int _charCount;
  late final AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _charCount = _text.length;
    final total = Duration(milliseconds: _charDelay.inMilliseconds * _charCount);
    _controller = AnimationController(vsync: this, duration: total)
      ..addListener(() => setState(() {}))
      ..forward();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final progress = (_controller.value * _charCount).clamp(0, _charCount).floor();
    final shown = _text.substring(0, progress);

    final style = TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.5,
      color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
    );

    return CupertinoPageScaffold(
      backgroundColor: isDark ? AppColors.background : AppColors.lightBackground,
      child: SafeArea(
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                shown.isEmpty ? ' ' : shown,
                style: style,
              ),
              const SizedBox(width: 2),
              AnimatedBuilder(
                animation: _blinkController,
                builder: (context, _) {
                  final visible = _blinkController.value < 0.5;
                  return Opacity(
                    opacity: visible ? 1.0 : 0.0,
                    child: Container(
                      width: 2,
                      height: (style.fontSize ?? 32) * 1.2,
                      color: style.color,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}


