import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ArticleCard extends StatelessWidget {
  final String title;
  final String summary;
  final String coverUrl;
  final int viewCount;
  final int likeCount;
  final String highlightKeyword;
  final VoidCallback onTap;

  const ArticleCard({
    super.key,
    required this.title,
    required this.summary,
    required this.coverUrl,
    required this.viewCount,
    required this.likeCount,
    this.highlightKeyword = '',
    required this.onTap,
  });

  String _formatCount(int value) {
    if (value >= 10000) {
      final double v = value / 10000.0;
      return '${v.toStringAsFixed(1)}万';
    }
    return value.toString();
  }

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

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          clipBehavior: Clip.hardEdge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
                        coverUrl.isEmpty
                            ? Container(color: Colors.grey.shade300)
                            : CachedNetworkImage(
                                imageUrl: coverUrl,
                                width: double.infinity,
                                height: imageHeight,
                                fit: BoxFit.cover,
                                memCacheWidth: 540,
                                memCacheHeight: 320,
                                fadeInDuration: Duration.zero,
                                fadeOutDuration: Duration.zero,
                                filterQuality: FilterQuality.low,
                                placeholder: (_, __) => Container(
                                  width: double.infinity,
                                  height: imageHeight,
                                  color: Colors.grey.shade200,
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  width: double.infinity,
                                  height: imageHeight,
                                  color: Colors.grey.shade300,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                  ),
                                ),
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
                              color: Colors.black.withValues(alpha: 0.55),
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
                                  _formatCount(viewCount),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Icon(
                                  Icons.thumb_up,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatCount(likeCount),
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
      ),
    );
  }
}
