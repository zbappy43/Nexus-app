import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_config.dart';
import '../../core/di/app_services.dart';
import '../../models/app_notification.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/notification_provider.dart';
import '../../utils/ui_utils.dart';
import '../../utils/url_utils.dart';

/// Inbox of received push notifications.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static String _relativeTime(DateTime time) {
    final Duration diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year}';
  }

  Future<void> _open(BuildContext context, AppNotification n) async {
    final NotificationProvider provider = context.read<NotificationProvider>();
    await provider.markRead(n.id);
    final String? raw = n.url;
    if (raw == null || raw.isEmpty || !context.mounted) return;
    final String url = raw.startsWith('/') ? AppConfig.url(raw) : raw;
    final String? internal = UrlUtils.resolveDeepLink(url);
    if (internal != null) {
      Navigator.of(context).pop();
      unawaited(context.read<NavigationProvider>().openUrl(internal));
    } else {
      await context.read<AppServices>().launcher.openExternal(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final NotificationProvider provider = context.watch<NotificationProvider>();
    final List<AppNotification> items = provider.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: <Widget>[
          if (provider.unreadCount > 0)
            IconButton(
              tooltip: 'Mark all as read',
              icon: const Icon(Icons.done_all_rounded),
              onPressed: provider.markAllRead,
            ),
          if (items.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                final bool ok = await UiUtils.confirm(
                  context,
                  title: 'Clear notifications?',
                  message: 'All notifications will be removed from this device.',
                  confirmLabel: 'Clear',
                  destructive: true,
                  icon: Icons.delete_sweep_outlined,
                );
                if (ok) await provider.clear();
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.refresh,
        child: items.isEmpty
            ? ListView(
                children: <Widget>[
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
                  const Icon(Icons.notifications_off_outlined, size: 88, color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Notices and account updates will appear here.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
                itemBuilder: (BuildContext context, int index) {
                  final AppNotification n = items[index];
                  return Dismissible(
                    key: ValueKey<String>(n.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      color: AppColors.error,
                      child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                    ),
                    onDismissed: (_) => provider.remove(n.id),
                    child: ListTile(
                      onTap: () => _open(context, n),
                      leading: CircleAvatar(
                        backgroundColor: n.isRead
                            ? Theme.of(context).colorScheme.surfaceContainerHighest
                            : AppColors.accent,
                        child: Icon(
                          n.isRead ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
                          color: n.isRead ? null : AppColors.primaryDark,
                        ),
                      ),
                      title: Text(
                        n.title.isEmpty ? AppConfig.shortName : n.title,
                        style: TextStyle(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (n.body.isNotEmpty)
                            Text(n.body, maxLines: 3, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(
                            _relativeTime(n.receivedAt),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                      isThreeLine: n.body.isNotEmpty,
                      trailing: n.url == null ? null : const Icon(Icons.chevron_right_rounded),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
