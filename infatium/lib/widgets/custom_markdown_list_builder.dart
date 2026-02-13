import 'package:flutter/cupertino.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

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
        final itemContent = _extractTextContent(child);
        if (itemContent.isNotEmpty) {
          items.add(
            _CustomListItemWidget(
              content: itemContent,
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

  String _extractTextContent(md.Element element) {
    final buffer = StringBuffer();

    void visit(md.Node node) {
      if (node is md.Text) {
        buffer.write(node.text);
      } else if (node is md.Element) {
        for (final child in node.children ?? []) {
          visit(child);
        }
      }
    }

    visit(element);
    return buffer.toString().trim();
  }
}

class _CustomListItemWidget extends StatelessWidget {
  final String content;
  final bool isDarkMode;
  final bool isOrdered;
  final int index;
  final bool isLast;
  final TextStyle? textStyle;

  const _CustomListItemWidget({
    required this.content,
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
            child: Text(
              content,
              style: effectiveTextStyle,
            ),
          ),
        ],
      ),
    );
  }
}
