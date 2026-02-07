import 'package:flutter/material.dart';

class CoursesCard extends StatelessWidget {
  final String title;
  final String summary;
  final String coverUrl;
  final int viewCount;
  final int favoriteCount;
  final VoidCallback onTap;

  const CoursesCard({
    super.key,
    required this.title,
    required this.summary,
    required this.coverUrl,
    required this.viewCount,
    required this.favoriteCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Image.network(
                  coverUrl,
                  width: double.infinity,
                  height: 92,
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
                        const Icon(Icons.remove_red_eye, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          formatCount(viewCount),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.favorite, size: 14, color: Colors.white),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    summary,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.1),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 92,
            color: Colors.grey.shade300,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 20,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 14,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 30,
                      height: 12,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 16,
                      height: 16,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 30,
                      height: 12,
                      color: Colors.grey.shade300,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
