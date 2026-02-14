import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/colors.dart';

class TelegramIcon extends StatelessWidget {
  final double size;
  final bool isDark;
  final Color? color;

  const TelegramIcon({
    super.key,
    this.size = 18,
    required this.isDark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? (isDark ? AppColors.accent : AppColors.lightAccent);

    return SvgPicture.asset(
      'assets/icons/telegram.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(
        iconColor,
        BlendMode.srcIn,
      ),
    );
  }
}
