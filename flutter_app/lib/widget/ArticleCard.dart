import 'package:flutter/material.dart';

class ArticleCard extends StatelessWidget {
  final String title;
  final String summary;
  final String coverUrl;
  final int viewCount;
  final int likeCount;
  final VoidCallback onTap;

  const ArticleCard({
    super.key,
    required this.title,
    required this.summary,
    required this.coverUrl,
    required this.viewCount,
    required this.likeCount,
    required this.onTap,
  });

  String _formatCount(int value) {
    if (value >= 10000) {
      final double v = value / 10000.0;
      return '${v.toStringAsFixed(1)}万';
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                      coverUrl.isEmpty
                          ? Container(color: Colors.grey.shade300)
                          : Image.network(
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
                              const Icon(Icons.remove_red_eye,
                                  size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                _formatCount(viewCount),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(Icons.thumb_up,
                                  size: 14, color: Colors.white),
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
                  padding:
                      EdgeInsets.fromLTRB(12, verticalPadding, 12, verticalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                          fontSize: compact ? 13 : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        summary,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.1,
                          fontSize: compact ? 11 : null,
                        ),
                        maxLines: summaryLines,
                        overflow: TextOverflow.ellipsis,
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
