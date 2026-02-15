import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

class AppShimmerBlock extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const AppShimmerBlock({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE7EBF0),
      highlightColor: const Color(0xFFF5F7FA),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE7EBF0),
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionText;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry margin;

  const AppEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.subtitle,
    this.actionText,
    this.onAction,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: Colors.grey.shade500),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 14),
            TDButton(
              text: actionText!,
              size: TDButtonSize.small,
              type: TDButtonType.outline,
              onTap: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

class AppListSkeleton extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsetsGeometry padding;
  final bool scrollable;

  const AppListSkeleton({
    super.key,
    this.itemCount = 6,
    this.itemHeight = 84,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 16),
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      primary: false,
      shrinkWrap: true,
      physics: scrollable
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) {
        return Container(
          height: itemHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(12),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppShimmerBlock(height: 16, width: 150),
              SizedBox(height: 10),
              AppShimmerBlock(height: 12),
              SizedBox(height: 8),
              AppShimmerBlock(height: 12, width: 180),
            ],
          ),
        );
      },
    );
  }
}

class AppGridSkeleton extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;
  final EdgeInsetsGeometry padding;

  const AppGridSkeleton({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 2,
    this.crossAxisSpacing = 12,
    this.mainAxisSpacing = 12,
    this.childAspectRatio = 1.25,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      primary: false,
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: (_, __) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(10),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppShimmerBlock(height: 80),
              SizedBox(height: 10),
              AppShimmerBlock(height: 14, width: 120),
              SizedBox(height: 8),
              AppShimmerBlock(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class AppWeakNetworkBanner extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry margin;

  const AppWeakNetworkBanner({
    super.key,
    required this.text,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFD591)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_tethering_error_rounded, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8A5D00)),
            ),
          ),
        ],
      ),
    );
  }
}
