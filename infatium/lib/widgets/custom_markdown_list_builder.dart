import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

/// Custom markdown element builder for beautiful bullet and numbered lists
/// with minimal dividers and custom styling (Perplexity/Particle.news-like)
class CustomMarkdownListBuilder extends MarkdownElementBuilder {
  final bool isDarkMode;

  CustomMarkdownListBuilder({required this.isDarkMode});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    if (element.tag == 'ul' || element.tag == 'ol') {
      return _buildCustomList(element, preferredStyle, isOrdered: element.tag == 'ol');
    }
    return null;
  }

  Widget _buildCustomList(md.Element element, TextStyle? preferredStyle, {required bool isOrdered}) {
    final items = <Widget>[];
    int index = 1;

    for (final child in element.children ?? []) {
      if (child is md.Element && child.tag == 'li') {
        final spans = _buildInlineSpans(child, preferredStyle);
        if (spans.isNotEmpty) {
          items.add(
            _CustomListItemWidget(
              spans: spans,
              isDarkMode: isDarkMode,
              isOrdered: isOrdered,
              index: index,
              isLast: child == element.children?.last,
              textStyle: preferredStyle,
            ),
          );
          index++;
        }
      }
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items,
      ),
    );
  }

  List<InlineSpan> _buildInlineSpans(md.Node node, TextStyle? baseStyle) {
    final spans = <InlineSpan>[];

    void visit(md.Node node, TextStyle? currentStyle) {
      if (node is md.Text) {
        final text = node.text;
        if (text.isNotEmpty) {
          spans.add(TextSpan(text: text, style: currentStyle));
        }
      } else if (node is md.Element) {
        switch (node.tag) {
          case 'a':
            final href = node.attributes['href'] ?? '';
            final recognizer = TapGestureRecognizer()
              ..onTap = () async {
                if (href.isNotEmpty) {
                  final uri = Uri.parse(href);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              };
            final linkStyle = (currentStyle ?? const TextStyle()).copyWith(
              color: isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
              decoration: TextDecoration.underline,
              decorationColor: isDarkMode
                  ? const Color(0x66FFFFFF)
                  : const Color(0x59000000),
              decorationThickness: 1.0,
              fontWeight: FontWeight.w600,
            );
            for (final child in node.children ?? []) {
              if (child is md.Text) {
                spans.add(TextSpan(
                  text: child.text,
                  style: linkStyle,
                  recognizer: recognizer,
                ));
              } else {
                visit(child, linkStyle);
              }
            }
          case 'strong':
            final boldStyle = (currentStyle ?? const TextStyle()).copyWith(
              fontWeight: FontWeight.bold,
            );
            for (final child in node.children ?? []) {
              visit(child, boldStyle);
            }
          case 'em':
            final italicStyle = (currentStyle ?? const TextStyle()).copyWith(
              fontStyle: FontStyle.italic,
            );
            for (final child in node.children ?? []) {
              visit(child, italicStyle);
            }
          default:
            for (final child in node.children ?? []) {
              visit(child, currentStyle);
            }
        }
      }
    }

    visit(node, baseStyle);
    return spans;
  }
}

class _CustomListItemWidget extends StatelessWidget {
  final List<InlineSpan> spans;
  final bool isDarkMode;
  final bool isOrdered;
  final int index;
  final bool isLast;
  final TextStyle? textStyle;

  const _CustomListItemWidget({
    required this.spans,
    required this.isDarkMode,
    required this.isOrdered,
    required this.index,
    required this.isLast,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    // Neutral gray color for bullets/numbers (subtle, not distracting)
    final markerColor = isDarkMode
        ? const Color(0xFF999999) // Medium gray for dark mode
        : const Color(0xFF666666); // Darker gray for light mode

    // Default text color if not provided
    final defaultTextColor = isDarkMode
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF000000);

    final effectiveTextStyle = textStyle ?? TextStyle(
      fontSize: 16,
      color: defaultTextColor,
      height: 1.5,
    );

    return Padding(
      padding: const EdgeInsets.only(left: 24.0, right: 16.0, bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bullet or number marker
          SizedBox(
            width: 20,
            child: Text(
              isOrdered ? '$index.' : '•',
              style: TextStyle(
                fontSize: 14, // Smaller, more subtle bullet
                color: markerColor,
                fontWeight: FontWeight.w500, // Slightly less bold
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Content
          Expanded(
            child: Text.rich(
              TextSpan(children: spans, style: effectiveTextStyle),
            ),
          ),
        ],
      ),
    );
  }
}
