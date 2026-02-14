import 'package:flutter/material.dart';

class CoursesCard extends StatelessWidget {
  final String title;
  final String summary;
  final String coverUrl;
  final int viewCount;
  final int favoriteCount;
  final String highlightKeyword;
  final VoidCallback onTap;

  const CoursesCard({
    super.key,
    required this.title,
    required this.summary,
    required this.coverUrl,
    required this.viewCount,
    required this.favoriteCount,
    this.highlightKeyword = '',
    required this.onTap,
  });

  List<TextSpan> _highlightSpans(
    BuildContext context,
    String text,
    TextStyle? baseStyle,
  ) {
    final keyword = highlightKeyword.trim();
    if (keyword.isEmpty || text.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final lowerText = text.toLowerCase();
    final lowerKeyword = keyword.toLowerCase();
    final start = lowerText.indexOf(lowerKeyword);
    if (start < 0) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final highlightStyle = baseStyle?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w700,
    );

    final spans = <TextSpan>[];
    int cursor = 0;
    while (cursor < text.length) {
      final index = lowerText.indexOf(lowerKeyword, cursor);
      if (index < 0) {
        spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
        break;
      }
      if (index > cursor) {
        spans.add(
          TextSpan(text: text.substring(cursor, index), style: baseStyle),
        );
      }
      final end = index + keyword.length;
      spans.add(
        TextSpan(text: text.substring(index, end), style: highlightStyle),
      );
      cursor = end;
    }
    return spans;
  }

  Widget _buildHighlightText(
    BuildContext context,
    String text,
    TextStyle? style, {
    required int maxLines,
  }) {
    return Text.rich(
      TextSpan(children: _highlightSpans(context, text, style)),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String formatCount(int value) {
      if (value >= 10000) {
        final double v = value / 10000.0;
        return '${v.toStringAsFixed(1)}万';
      }
      return value.toString();
    }

    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.hardEdge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool hasBound = constraints.maxHeight.isFinite;
            final bool compact = hasBound && constraints.maxHeight < 140;
            final double imageHeight = hasBound
                ? (constraints.maxHeight * 0.56).clamp(64.0, 92.0)
                : 92.0;
            final double verticalPadding = compact ? 4 : 6;
            final int summaryLines = compact ? 1 : 2;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: imageHeight,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      Image.network(
                        coverUrl,
                        width: double.infinity,
                        height: imageHeight,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.remove_red_eye,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                formatCount(viewCount),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(
                                Icons.favorite,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                formatCount(favoriteCount),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    verticalPadding,
                    12,
                    verticalPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHighlightText(
                        context,
                        title,
                        theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                          fontSize: compact ? 13 : null,
                        ),
                        maxLines: 1,
                      ),
                      const SizedBox(height: 3),
                      _buildHighlightText(
                        context,
                        summary,
                        theme.textTheme.bodySmall?.copyWith(
                          height: 1.1,
                          fontSize: compact ? 11 : null,
                        ),
                        maxLines: summaryLines,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class CoursesCardSkeleton extends StatelessWidget {
  const CoursesCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool hasBound = constraints.maxHeight.isFinite;
          final bool compact = hasBound && constraints.maxHeight < 140;
          final double imageHeight = hasBound
              ? (constraints.maxHeight * 0.56).clamp(64.0, 92.0)
              : 92.0;
          final double verticalPadding = compact ? 4 : 6;
          final double titleHeight = compact ? 14 : 20;
          final double summaryHeight = compact ? 10 : 14;
          final double iconSize = compact ? 12 : 16;
          final double statWidth = compact ? 24 : 30;
          final double rowGap = compact ? 8 : 16;
          final double lineGap = compact ? 4 : 6;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: imageHeight,
                color: Colors.grey.shade300,
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  verticalPadding,
                  12,
                  verticalPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: titleHeight,
                      color: Colors.grey.shade300,
                    ),
                    SizedBox(height: lineGap),
                    Container(
                      width: double.infinity,
                      height: summaryHeight,
                      color: Colors.grey.shade300,
                    ),
                    SizedBox(height: lineGap),
                    Row(
                      children: [
                        Container(
                          width: iconSize,
                          height: iconSize,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: statWidth,
                          height: summaryHeight,
                          color: Colors.grey.shade300,
                        ),
                        SizedBox(width: rowGap),
                        Container(
                          width: iconSize,
                          height: iconSize,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: statWidth,
                          height: summaryHeight,
                          color: Colors.grey.shade300,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
