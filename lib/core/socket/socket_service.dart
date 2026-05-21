import 'package:socket_io_client/socket_io_client.dart' as io;
import '../api/api_client.dart';

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

  io.Socket? _socket;
  bool _isConnected = false;
  bool _connecting = false;

  AttendanceScanCallback? onAttendanceScan;
  AttendanceStatusChangedCallback? onAttendanceStatusChanged;
  SessionEndedCallback? onSessionEnded;
  FraudAlertCallback? onFraudAlert;

  void connect() {
    if (_connecting || _isConnected) return;

    _connecting = true;

    final token = ApiClient().token ?? '';
    final uri = 'http://localhost:3000?token=$token';

    _socket = io.io(uri, io.OptionBuilder()
      .setTransports(['websocket'])
      .enableAutoConnect()
      .build());

    _socket!.onConnect((_) {
      _isConnected = true;
      _connecting = false;
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      _connecting = false;
    });

    _socket!.onConnectError((data) {
      _connecting = false;
    });

    _socket!.on('attendance:scan', (data) {
      if (onAttendanceScan != null && data is Map) {
        onAttendanceScan!(
          sessionId: data['sessionId'] ?? '',
          studentId: data['studentId'] ?? '',
          studentName: data['studentName'] ?? '',
          status: data['status'] ?? '',
          scanTime: data['scanTime'] ?? '',
        );
      }
    });

    _socket!.on('attendance:status-changed', (data) {
      if (onAttendanceStatusChanged != null && data is Map) {
        onAttendanceStatusChanged!(
          sessionId: data['sessionId'] ?? '',
          studentId: data['studentId'] ?? '',
          newStatus: data['newStatus'] ?? '',
        );
      }
    });

    _socket!.on('session:ended', (data) {
      if (onSessionEnded != null && data is Map) {
        onSessionEnded!(data['sessionId'] ?? '');
      }
    });

    _socket!.on('attendance:fraud-alert', (data) {
      if (onFraudAlert != null && data is Map) {
        onFraudAlert!(
          sessionId: data['sessionId'] ?? '',
          studentId: data['studentId'] ?? '',
          reason: data['reason'] ?? '',
          riskScore: data['riskScore'] ?? 0,
        );
      }
    });
  }

  void joinSession(String sessionId) {
    _socket?.emit('join:session', sessionId);
  }

  void leaveSession(String sessionId) {
    _socket?.emit('leave:session', sessionId);
  }

  void joinTeacher(String teacherId) {
    _socket?.emit('join:teacher', teacherId);
  }

  void leaveTeacher(String teacherId) {
    _socket?.emit('leave:teacher', teacherId);
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _isConnected = false;
    _connecting = false;
  }
}
