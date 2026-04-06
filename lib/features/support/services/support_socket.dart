import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as sio;

import '../domain/support_message.dart';

typedef SupportMessageCallback = void Function(SupportMessage message);
typedef SupportStatusCallback = void Function(String status);

class SupportSocket {
  SupportSocket({
    required this.serverUrl,
    required this.token,
    required this.threadId,
    required this.onIncomingMessage,
    this.onStatusChanged,
    this.onJoinFailed,
    this.onConnectError,
  });

  final String serverUrl;
  final String token;
  final int threadId;
  final SupportMessageCallback onIncomingMessage;
  final SupportStatusCallback? onStatusChanged;
  final void Function(String message)? onJoinFailed;
  final void Function(Object error)? onConnectError;

  sio.Socket? _socket;

  bool get isConnected => _socket?.connected == true;

  void connect() {
    _socket?.dispose();
    final socket = sio.io(
      serverUrl,
      sio.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      socket.emitWithAck(
        'support:join',
        {'threadId': threadId},
        ack: (data) {
          final map = _asMap(data);
          if (map == null || map['ok'] != true) {
            final msg = map?['message']?.toString() ?? 'Failed to join support thread.';
            onJoinFailed?.call(msg);
          }
        },
      );
    });

    socket.onConnectError((err) => onConnectError?.call(err));

    socket.on('support:message', (data) {
      final map = _asMap(data);
      if (map == null) return;
      final msg = SupportMessage.fromMap(map);
      if (msg.body.isNotEmpty) onIncomingMessage(msg);
    });

    socket.on('support:status', (data) {
      final map = _asMap(data);
      if (map == null) return;
      final status = (map['status'] ?? '').toString();
      if (status.isNotEmpty) onStatusChanged?.call(status);
    });

    socket.connect();
  }

  void sendMessage(
    String body, {
    void Function(SupportMessage? saved)? onAck,
  }) {
    final socket = _socket;
    if (socket == null || !socket.connected) {
      onAck?.call(null);
      return;
    }
    final text = body.trim();
    if (text.isEmpty) {
      onAck?.call(null);
      return;
    }
    socket.emitWithAck(
      'support:message',
      {'threadId': threadId, 'body': text},
      ack: (data) {
        final map = _asMap(data);
        if (map != null && map['ok'] == true) {
          final raw = map['message'];
          if (raw is Map) {
            onAck?.call(SupportMessage.fromMap(Map<String, dynamic>.from(raw)));
            return;
          }
        }
        onAck?.call(null);
      },
    );
  }

  void close() {
    final socket = _socket;
    _socket = null;
    if (socket == null) return;

    var finished = false;
    void done() {
      if (finished) return;
      finished = true;
      try {
        socket.disconnect();
        socket.dispose();
      } catch (_) {}
    }

    if (socket.connected) {
      socket.emitWithAck(
        'support:leave',
        {'threadId': threadId},
        ack: (_) => done(),
      );
      unawaited(
        Future<void>.delayed(const Duration(seconds: 2)).then((_) {
          if (!finished) done();
        }),
      );
    } else {
      done();
    }
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }
}
