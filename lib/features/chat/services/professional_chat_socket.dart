import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as sio;

import '../domain/chat_message.dart';

typedef ChatIncomingCallback = void Function(ChatMessage message);

class ProfessionalChatSocket {
  ProfessionalChatSocket({
    required this.serverUrl,
    required this.token,
    required this.conversationId,
    required this.onIncomingMessage,
    required this.isCurrentUserProfessional,
    this.onJoined,
    this.onJoinFailed,
    this.onConnectError,
  });

  final String serverUrl;
  final String token;
  final int conversationId;
  final bool isCurrentUserProfessional;
  final ChatIncomingCallback onIncomingMessage;
  final void Function()? onJoined;
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
        'chat:join',
        {'conversationId': conversationId},
        ack: (data) {
          final map = _asMap(data);
          if (map != null && map['ok'] == true) {
            onJoined?.call();
          } else {
            final msg = map?['message']?.toString() ?? 'Failed to join conversation.';
            onJoinFailed?.call(msg);
          }
        },
      );
    });

    socket.onConnectError((err) => onConnectError?.call(err));

    socket.on('chat:message', (data) {
      onIncomingMessage(
        ChatMessage.fromServerPayload(
          data,
          isCurrentUserProfessional: isCurrentUserProfessional,
        ),
      );
    });

    socket.connect();
  }

  void sendMessage(String body, {void Function(ChatMessage? saved)? onAck}) {
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
      'chat:message',
      {'conversationId': conversationId, 'body': text},
      ack: (data) {
        onAck?.call(
          ChatMessage.fromSendAck(
            data,
            isCurrentUserProfessional: isCurrentUserProfessional,
          ),
        );
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
        'chat:leave',
        {'conversationId': conversationId},
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
