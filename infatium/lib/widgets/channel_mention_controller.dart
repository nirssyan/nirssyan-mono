import 'package:flutter/widgets.dart';
import '../theme/telegram_colors.dart';

class ChannelMentionTextController extends TextEditingController {
  ChannelMentionTextController({String? text}) : super(text: text);

  bool highlightEnabled = false;
  Color mentionColor = TelegramColors.brandBlue;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final fullText = value.text;

    if (!highlightEnabled || fullText.isEmpty) {
      return TextSpan(style: style, text: fullText);
    }

    final List<InlineSpan> spans = <InlineSpan>[];
    int index = 0;

    while (index < fullText.length) {
      final int atIndex = fullText.indexOf('@', index);

      if (atIndex == -1) {
        spans.add(TextSpan(text: fullText.substring(index), style: style));
        break;
      }

      // Add text before '@'
      if (atIndex > index) {
        spans.add(TextSpan(text: fullText.substring(index, atIndex), style: style));
      }

      // Compute end of mention (until whitespace)
      int end = atIndex + 1;
      while (end < fullText.length) {
        final String char = fullText[end];
        if (char == ' ' || char == '\n' || char == '\t') {
          break;
        }
        end++;
      }

      final String mentionText = fullText.substring(atIndex, end);

      final TextStyle mentionStyle = (style ?? const TextStyle()).copyWith(
        color: mentionColor,
        backgroundColor: mentionColor.withOpacity(0.12),
        fontWeight: FontWeight.w600,
      );

      spans.add(TextSpan(text: mentionText, style: mentionStyle));

      index = end;
    }

    return TextSpan(style: style, children: spans);
  }
}

