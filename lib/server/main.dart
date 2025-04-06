import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

// User credentials for authentication
const validUsername = 'admin';
const validPassword = 'password';

// Camera configuration data
final Map<String, dynamic> cameraConfig = {
  'cameras': [
    {
      'id': 1,
      'name': 'Front Door Camera',
      'ip': '192.168.1.10',
      'rtspUri': 'rtsp://demo:demo@ipvmdemo.dyndns.org:5541/onvif-media/media.amp?profile=profile_1_h264&sessiontimeout=60&streamtype=unicast',
      'connected': true,
      'mac': 'AA:BB:CC:DD:EE:FF',
    },
    {
      'id': 2,
      'name': 'Backyard Camera',
      'ip': '192.168.1.11',
      'rtspUri': 'rtsp://demo:demo@ipvmdemo.dyndns.org:5541/onvif-media/media.amp?profile=profile_1_h264&sessiontimeout=60&streamtype=unicast',
      'connected': true,
      'mac': 'AA:BB:CC:DD:EE:FF',
    },
    {
      'id': 3,
      'name': 'Garage Camera',
      'ip': '192.168.1.12',
      'rtspUri': 'rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mp4',
      'connected': false,
      'mac': '11:22:33:44:55:66',
    },
    {
      'id': 4,
      'name': 'Living Room',
      'ip': '192.168.1.13',
      'rtspUri': 'rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mp4',
      'connected': true,
      'mac': '11:22:33:44:55:66',
    },
    {
      'id': 5,
      'name': 'Kitchen Camera',
      'ip': '192.168.1.14',
      'rtspUri': 'rtsp://demo:demo@ipvmdemo.dyndns.org:5541/onvif-media/media.amp?profile=profile_1_h264&sessiontimeout=60&streamtype=unicast',
      'connected': true,
      'mac': 'CC:DD:EE:FF:00:11',
    },
    {
      'id': 6,
      'name': 'Driveway Camera',
      'ip': '192.168.1.15',
      'rtspUri': 'rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mp4',
      'connected': true,
      'mac': 'CC:DD:EE:FF:00:11',
    },
  ],
};

void main() async {
  // Create an HTTP server
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 5000);
  print('Server listening on port 5000');

  // Upgrade connections to WebSocket when requested
  server.listen((HttpRequest request) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      handleWebSocketRequest(request);
    } else {
      handleHttpRequest(request);
    }
  });
}

void handleWebSocketRequest(HttpRequest request) async {
  try {
    // Upgrade the HTTP request to a WebSocket connection
    final WebSocket webSocket = await WebSocketTransformer.upgrade(request);
    print('WebSocket connection established');
    
    // Create client connection handler
    final client = ClientConnection(webSocket);
    
    // Start handling this client's messages
    client.start();
  } catch (e) {
    print('Error during WebSocket upgrade: $e');
    request.response.statusCode = HttpStatus.internalServerError;
    request.response.close();
  }
}

void handleHttpRequest(HttpRequest request) {
  if (request.uri.path == '/health') {
    // Health check endpoint
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(json.encode({'status': 'ok', 'timestamp': DateTime.now().toIso8601String()}));
  } else {
    // Not found
    request.response.statusCode = HttpStatus.notFound;
  }
  request.response.close();
}

class ClientConnection {
  final WebSocket _webSocket;
  bool _isAuthenticated = false;
  Timer? _systemInfoTimer;
  Timer? _cameraUpdateTimer;
  final Random _random = Random();
  
  ClientConnection(this._webSocket);
  
  void start() {
    // Listen for incoming messages
    _webSocket.listen(
      _handleMessage,
      onError: _handleError,
      onDone: _handleDone,
    );
    
    // Send initial login required message
    _sendMessage({
      'c': 'login',
      'msg': 'Oturum açılmamış!',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  void _handleMessage(dynamic message) {
    try {
      print('Received message: $message');
      
      if (message is String) {
        // Handle commands
        if (message.startsWith('LOGIN')) {
          _handleLoginCommand(message);
        } else if (message == 'DO MONITORECS') {
          _handleMonitorCommand();
        } else if (message == 'PING') {
          _handlePingCommand();
        }
      }
    } catch (e) {
      print('Error handling message: $e');
    }
  }
  
  void _handleLoginCommand(String message) {
    final parts = message.split(' ');
    if (parts.length >= 3) {
      final username = parts[1];
      final password = parts[2];
      
      if (username == validUsername && password == validPassword) {
        _isAuthenticated = true;
        _sendMessage({
          'c': 'login',
          'msg': 'Oturum açıldı!',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        print('Client authenticated');
      } else {
        _sendMessage({
          'c': 'login',
          'msg': 'Hatalı kullanıcı adı veya şifre!',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        print('Authentication failed');
      }
    }
  }
  
  void _handleMonitorCommand() {
    if (!_isAuthenticated) {
      _sendMessage({
        'c': 'login',
        'msg': 'Oturum açılmamış!',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      return;
    }
    
    print('Starting system monitoring');
    
    // Send initial camera information
    _sendCameraInfo();
    
    // Start sending system info updates
    _systemInfoTimer?.cancel();
    _systemInfoTimer = Timer.periodic(Duration(seconds: 3), (_) {
      _sendSystemInfo();
    });
    
    // Start sending camera updates
    _cameraUpdateTimer?.cancel();
    _cameraUpdateTimer = Timer.periodic(Duration(seconds: 10), (_) {
      _sendCameraUpdates();
    });
  }
  
  void _handlePingCommand() {
    if (_isAuthenticated) {
      _sendMessage({
        'c': 'pong',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }
  
  void _sendSystemInfo() {
    if (!_isAuthenticated) return;
    
    // Generate random system metrics
    final cpuTemp = (60 + _random.nextInt(20)).toDouble();
    final upTime = 1000 + _random.nextInt(5000);
    final cpuUsage = _random.nextInt(100).toDouble();
    final memoryUsage = _random.nextInt(100).toDouble();
    final diskUsage = _random.nextInt(100).toDouble();
    
    _sendMessage({
      'c': 'sysinfo',
      'cpuTemp': cpuTemp.toStringAsFixed(2),
      'upTime': upTime.toString(),
      'cpuUsage': cpuUsage.toStringAsFixed(2),
      'memoryUsage': memoryUsage.toStringAsFixed(2),
      'diskUsage': diskUsage.toStringAsFixed(2),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  void _sendCameraInfo() {
    if (!_isAuthenticated) return;
    
    for (final camera in cameraConfig['cameras']) {
      final String mac = camera['mac'];
      final String formattedMac = mac.replaceAll(':', '_');
      
      _sendMessage({
        'c': 'changed',
        'data': 'ecs.slaves.m_${formattedMac}.cam.${camera['id'] - 1}.name',
        'val': camera['name'],
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      _sendMessage({
        'c': 'changed',
        'data': 'ecs.slaves.m_${formattedMac}.cam.${camera['id'] - 1}.ip',
        'val': camera['ip'],
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      _sendMessage({
        'c': 'changed',
        'data': 'ecs.slaves.m_${formattedMac}.cam.${camera['id'] - 1}.subUri',
        'val': camera['rtspUri'],
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      _sendMessage({
        'c': 'changed',
        'data': 'ecs.slaves.m_${formattedMac}.cam.${camera['id'] - 1}.connected',
        'val': camera['connected'] ? '1' : '0',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      _sendMessage({
        'c': 'changed',
        'data': 'ecs.slaves.m_${formattedMac}.cam.${camera['id'] - 1}.snapshot',
        'val': 'https://via.placeholder.com/320x240.png',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }
  
  void _sendCameraUpdates() {
    if (!_isAuthenticated) return;
    
    // Randomly update camera connection status
    final cameraIndex = _random.nextInt(cameraConfig['cameras'].length);
    final camera = cameraConfig['cameras'][cameraIndex];
    final connected = _random.nextBool();
    
    camera['connected'] = connected;
    
    final String mac = camera['mac'];
    final String formattedMac = mac.replaceAll(':', '_');
    
    _sendMessage({
      'c': 'changed',
      'data': 'ecs.slaves.m_${formattedMac}.cam.${camera['id'] - 1}.connected',
      'val': connected ? '1' : '0',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  void _sendMessage(Map<String, dynamic> data) {
    try {
      final jsonString = json.encode(data);
      _webSocket.add(jsonString);
    } catch (e) {
      print('Error sending message: $e');
    }
  }
  
  void _handleError(Object error, StackTrace stackTrace) {
    print('WebSocket error: $error');
    _cleanup();
  }
  
  void _handleDone() {
    print('WebSocket connection closed');
    _cleanup();
  }
  
  void _cleanup() {
    _systemInfoTimer?.cancel();
    _cameraUpdateTimer?.cancel();
    _webSocket.close();
  }
}