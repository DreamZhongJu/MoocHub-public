import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ShareSheet {
  static void show(
    BuildContext context, {
    required String title,
    String? subtitle,
    String? url,
    String? imageUrl,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ShareSheetContent(
        title: title,
        subtitle: subtitle,
        url: url,
        imageUrl: imageUrl,
      ),
    );
  }
}

class _ShareSheetContent extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? url;
  final String? imageUrl;

  const _ShareSheetContent({
    required this.title,
    this.subtitle,
    this.url,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E2230) : Colors.white;
    final cardColor = isDark
        ? const Color(0xFF252A38)
        : const Color(0xFFF5F7FA);

    final options = [
      _ShareOption(
        icon: Icons.link_rounded,
        label: '复制链接',
        color: const Color(0xFF5C6BC0),
      ),
      _ShareOption(
        icon: Icons.qr_code_2_rounded,
        label: '二维码',
        color: const Color(0xFF26A69A),
      ),
      _ShareOption(
        icon: Icons.wechat_rounded,
        label: '微信',
        color: const Color(0xFF43A047),
      ),
      _ShareOption(
        icon: Icons.groups_2_rounded,
        label: '朋友圈',
        color: const Color(0xFF66BB6A),
      ),
      _ShareOption(
        icon: Icons.chat_bubble_rounded,
        label: 'QQ',
        color: const Color(0xFF42A5F5),
      ),
      _ShareOption(
        icon: Icons.ios_share_rounded,
        label: '更多',
        color: const Color(0xFF78909C),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '分享至',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            // Preview card
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildPreviewImage(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                          if (subtitle != null && subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Options grid
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: options
                    .map((opt) => _buildOption(context, opt))
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            // Cancel
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewImage() {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(
        imageUrl!,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholderIcon(),
      );
    }
    return _placeholderIcon();
  }

  Widget _placeholderIcon() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF7C4DFF).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.play_lesson_rounded,
        color: Color(0xFF7C4DFF),
        size: 26,
      ),
    );
  }

  Widget _buildOption(BuildContext context, _ShareOption opt) {
    return GestureDetector(
      onTap: () => _handleShare(context, opt),
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: opt.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(opt.icon, color: opt.color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              opt.label,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _handleShare(BuildContext context, _ShareOption opt) {
    if (opt.label == '复制链接') {
      final text = url?.isNotEmpty == true ? url! : title;
      Clipboard.setData(ClipboardData(text: text));
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 16,
              ),
              SizedBox(width: 8),
              Text('链接已复制到剪贴板'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2D2D3A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${opt.label} 分享功能即将上线'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _ShareOption {
  final IconData icon;
  final String label;
  final Color color;

  const _ShareOption({
    required this.icon,
    required this.label,
    required this.color,
  });
}
