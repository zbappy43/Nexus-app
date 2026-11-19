import 'package:flutter/foundation.dart';

/// A push notification stored in the in-app inbox.
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.url,
    this.imageUrl,
    this.isRead = false,
    this.data = const <String, String>{},
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final Object? rawData = json['data'];
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      url: json['url'] as String?,
      imageUrl: json['image_url'] as String?,
      receivedAt: DateTime.fromMillisecondsSinceEpoch(json['received_at'] as int),
      isRead: json['is_read'] as bool? ?? false,
      data: rawData is Map
          ? rawData.map((Object? k, Object? v) => MapEntry<String, String>('$k', '$v'))
          : const <String, String>{},
    );
  }

  /// Builds a notification from an FCM / OneSignal data payload.
  factory AppNotification.fromPayload({
    required String id,
    String? title,
    String? body,
    String? imageUrl,
    Map<String, dynamic> data = const <String, dynamic>{},
  }) {
    final Map<String, String> stringData = data.map(
      (String k, dynamic v) => MapEntry<String, String>(k, '$v'),
    );
    return AppNotification(
      id: id,
      title: title ?? stringData['title'] ?? '',
      body: body ?? stringData['body'] ?? stringData['message'] ?? '',
      url: stringData['url'] ?? stringData['link'] ?? stringData['click_action_url'],
      imageUrl: imageUrl ?? stringData['image'],
      receivedAt: DateTime.now(),
      data: stringData,
    );
  }

  final String id;
  final String title;
  final String body;
  final String? url;
  final String? imageUrl;
  final DateTime receivedAt;
  final bool isRead;
  final Map<String, String> data;

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        body: body,
        url: url,
        imageUrl: imageUrl,
        receivedAt: receivedAt,
        isRead: isRead ?? this.isRead,
        data: data,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'body': body,
        'url': url,
        'image_url': imageUrl,
        'received_at': receivedAt.millisecondsSinceEpoch,
        'is_read': isRead,
        'data': data,
      };

  @override
  bool operator ==(Object other) => other is AppNotification && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
