import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F6F8);

    return Scaffold(
      appBar: AppBar(title: const Text('\u901a\u77e5\u8bbe\u7f6e')),
      body: Container(
        color: pageBg,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: isDark ? const Color(0xFF171A21) : Colors.white,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.notifications_active_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('\u6253\u5f00\u901a\u77e5\u8bbe\u7f6e'),
                    subtitle: const Text(
                      '\u8fdb\u5165\u7cfb\u7edf\u901a\u77e5\u8bbe\u7f6e\u9875',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      AppSettings.openAppSettings(
                        type: AppSettingsType.notification,
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.settings_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('\u5e94\u7528\u8bbe\u7f6e'),
                    subtitle: const Text(
                      '\u7cfb\u7edf\u5e94\u7528\u8bbe\u7f6e\u9875',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      AppSettings.openAppSettings();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '\u8bf4\u660e\uff1aAndroid 8+ \u901a\u77e5\u7531\u7cfb\u7edf\u6e20\u9053\u63a7\u5236\uff0c\u82e5\u6536\u4e0d\u5230\u901a\u77e5\uff0c\u8bf7\u5728\u7cfb\u7edf\u8bbe\u7f6e\u4e2d\u6253\u5f00\u201c\u91cd\u8981\u901a\u77e5\u201d\u6e20\u9053\u3002',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
