import 'package:flutter/cupertino.dart';

class Loadingwidget extends StatelessWidget {
  final String? text;
  final double size;
  final double spacing;
  final bool showText;

  const Loadingwidget({
    super.key,
    this.text,
    this.size = 22,
    this.spacing = 10,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    final label = text ?? '加载中...';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoActivityIndicator(radius: size / 2),
          if (showText) ...[
            SizedBox(height: spacing),
            DefaultTextStyle(
              style: const TextStyle(
                fontSize: 13,
                color: CupertinoColors.systemGrey,
              ),
              child: Text(label),
            ),
          ],
        ],
      ),
    );
  }
}
