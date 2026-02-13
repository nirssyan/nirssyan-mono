import 'package:flutter/cupertino.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

/// Custom markdown inline syntax for ==highlighted text==
/// Converts ==text== to <mark>text</mark> HTML tag
class HighlightSyntax extends md.InlineSyntax {
  HighlightSyntax() : super(r'==([^=]+)==');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final text = match[1]!;
    parser.addNode(md.Element.text('mark', text));
    return true;
  }
}

/// Custom markdown element builder for <mark> tag (highlighted text)
/// Renders text with yellow-green background like in reference screenshot
class HighlightBuilder extends MarkdownElementBuilder {
  final bool isDarkMode;

  HighlightBuilder({required this.isDarkMode});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    if (element.tag == 'mark') {
      final text = element.textContent;

      // Yellow-green background colors (like in screenshot)
      final backgroundColor = isDarkMode
          ? const Color(0xFF3A4D2C) // Dark green-ish for dark mode
          : const Color(0xFFF0F8E8); // Light yellow-green for light mode

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          text,
          style: preferredStyle,
        ),
      );
    }
    return null;
  }
}
