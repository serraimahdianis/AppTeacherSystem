import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../api/api_client.dart';
import '../api/constants.dart';

typedef AttendanceScanCallback = void Function({
  required String sessionId,
  required String studentId,
  required String studentName,
  required String status,
  required String scanTime,
});

typedef AttendanceStatusChangedCallback = void Function({
  required String sessionId,
  required String studentId,
  required String newStatus,
});

typedef SessionEndedCallback = void Function(String sessionId);

typedef FraudAlertCallback = void Function({
  required String sessionId,
  required String studentId,
  required String reason,
  required int riskScore,
});

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  bool _connecting = false;
  Timer? _reconnectTimer;

  AttendanceScanCallback? onAttendanceScan;
  AttendanceStatusChangedCallback? onAttendanceStatusChanged;
  SessionEndedCallback? onSessionEnded;
  FraudAlertCallback? onFraudAlert;

  void connect() {
    if (_connecting || _isConnected) return;

    _connecting = true;

    final token = ApiClient().token ?? '';
    final wsUrl = ApiConstants.baseUrl.replaceFirst('http', 'ws');
    final uri = Uri.parse('$wsUrl?token=$token');

    try {
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;
      _connecting = false;

      _subscription = _channel!.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            _handleEvent(msg['event'] as String?, msg['data']);
          } catch (_) {}
        },
        onDone: () {
          _isConnected = false;
          _connecting = false;
          _scheduleReconnect();
        },
        onError: (_) {
          _isConnected = false;
          _connecting = false;
          _scheduleReconnect();
        },
      );
    } catch (_) {
      _isConnected = false;
      _connecting = false;
      _scheduleReconnect();
    }
  }

  void _handleEvent(String? event, dynamic data) {
    if (event == null || data is! Map) return;

    switch (event) {
      case 'attendance:scan':
        onAttendanceScan?.call(
          sessionId: data['sessionId'] ?? '',
          studentId: data['studentId'] ?? '',
          studentName: data['studentName'] ?? '',
          status: data['status'] ?? '',
          scanTime: data['scanTime'] ?? '',
        );
        break;
      case 'attendance:status-changed':
        onAttendanceStatusChanged?.call(
          sessionId: data['sessionId'] ?? '',
          studentId: data['studentId'] ?? '',
          newStatus: data['newStatus'] ?? '',
        );
        break;
      case 'session:ended':
        onSessionEnded?.call(data['sessionId'] ?? '');
        break;
      case 'attendance:fraud-alert':
        onFraudAlert?.call(
          sessionId: data['sessionId'] ?? '',
          studentId: data['studentId'] ?? '',
          reason: data['reason'] ?? '',
          riskScore: data['riskScore'] ?? 0,
        );
        break;
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _connecting = false;
      connect();
    });
  }

  void joinSession(String sessionId) {
    _send('join:session', sessionId);
  }

  void leaveSession(String sessionId) {
    _send('leave:session', sessionId);
  }

  void joinTeacher(String teacherId) {
    _send('join:teacher', teacherId);
  }

  void leaveTeacher(String teacherId) {
    _send('leave:teacher', teacherId);
  }

  void _send(String event, dynamic data) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({'event': event, 'data': data}));
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _connecting = false;
  }
}
