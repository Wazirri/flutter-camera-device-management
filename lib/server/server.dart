import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

class ServerApp {
  HttpServer? _httpServer;
  bool _isRunning = false;
  final int _port;
  
  // Properties for simulation
  Timer? _systemInfoTimer;
  Timer? _cameraUpdateTimer;
  final List<WebSocket> _webSocketClients = [];
  final Map<String, bool> _clientLoginStatus = {};
  
  ServerApp({int port = 5000}) : _port = port;
  
  // Start the server
  Future<bool> start() async {
    if (_isRunning) {
      print('Server is already running');
      return true;
    }
    
    try {
      // Create HTTP server
      _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      print('HTTP server started on http://localhost:$_port');
      
      // Handle HTTP requests
      _httpServer!.listen(_handleRequest);
      
      _isRunning = true;
      return true;
    } catch (e) {
      print('Error starting server: $e');
      return false;
    }
  }
  
  // Stop the server
  Future<void> stop() async {
    _systemInfoTimer?.cancel();
    _cameraUpdateTimer?.cancel();
    
    for (final client in _webSocketClients) {
      try {
        client.close();
      } catch (e) {
        print('Error closing WebSocket client: $e');
      }
    }
    _webSocketClients.clear();
    _clientLoginStatus.clear();
    
    if (_httpServer != null) {
      await _httpServer!.close(force: true);
      _httpServer = null;
    }
    
    _isRunning = false;
    print('Server stopped');
  }
  
  // Handle HTTP request and WebSocket upgrades
  void _handleRequest(HttpRequest request) async {
    print('${request.method} ${request.uri.path}');
    
    // Set CORS headers
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Origin, Content-Type');
    
    // Handle OPTIONS (preflight) requests
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }
    
    // Handle WebSocket requests at /ws
    if (request.uri.path == '/ws') {
      // Upgrade the request to a WebSocket connection
      try {
        final socket = await WebSocketTransformer.upgrade(request);
        _handleWebSocket(socket);
        return;
      } catch (e) {
        print('Error upgrading to WebSocket: $e');
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
        return;
      }
    }
    
    // Handle other HTTP routes
    switch (request.uri.path) {
      case '/':
      case '/index.html':
        await _serveStaticFile(request, 'text/html', _getIndexHtml());
        break;
      
      case '/health':
        await _serveJsonResponse(request, 200, {'status': 'ok', 'timestamp': DateTime.now().toIso8601String()});
        break;
      
      default:
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('404 Not Found');
        await request.response.close();
        break;
    }
  }
  
  // Handle WebSocket connection
  void _handleWebSocket(WebSocket socket) {
    print('New WebSocket client connected');
    _webSocketClients.add(socket);
    _clientLoginStatus[socket.hashCode.toString()] = false;
    
    // Send login required message after short delay
    Timer(Duration(milliseconds: 500), () {
      try {
        socket.add(jsonEncode({
          'c': 'login',
          'msg': 'Oturum açılmamış!',
        }));
      } catch (e) {
        print('Error sending initial message: $e');
      }
    });
    
    // Listen for messages
    socket.listen(
      (dynamic data) {
        _handleWebSocketMessage(socket, data);
      },
      onDone: () {
        print('WebSocket connection closed');
        _webSocketClients.remove(socket);
        _clientLoginStatus.remove(socket.hashCode.toString());
      },
      onError: (error) {
        print('WebSocket error: $error');
        _webSocketClients.remove(socket);
        _clientLoginStatus.remove(socket.hashCode.toString());
      },
      cancelOnError: true,
    );
  }
  
  // Handle WebSocket message
  void _handleWebSocketMessage(WebSocket socket, dynamic message) {
    try {
      final data = message.toString();
      print('Received WebSocket message: $data');
      
      if (data.startsWith('LOGIN')) {
        // Handle login
        final regex = RegExp(r'LOGIN\s+"([^"]*)"\s+"([^"]*)"');
        final match = regex.firstMatch(data);
        
        if (match != null && match.groupCount >= 2) {
          final username = match.group(1) ?? '';
          final password = match.group(2) ?? '';
          
          if (username == 'admin' && password == 'admin') {
            socket.add(jsonEncode({
              'c': 'loginok',
              'username': username,
              'msg': 'Logged in successfully',
            }));
            
            // Mark client as logged in
            _clientLoginStatus[socket.hashCode.toString()] = true;
          } else {
            socket.add(jsonEncode({
              'c': 'login',
              'msg': 'Invalid credentials',
            }));
          }
        }
      } else if (data == 'Monitor ecs_slaves') {
        // Check if client is logged in
        if (_clientLoginStatus[socket.hashCode.toString()] == true) {
          // Start sending system info and camera updates periodically
          _startSystemInfoUpdates(socket);
          _startCameraUpdates(socket);
        } else {
          // Send login required message
          socket.add(jsonEncode({
            'c': 'login',
            'msg': 'Oturum açılmamış!',
          }));
        }
      } else if (data == 'PING') {
        // Respond to ping
        socket.add('PONG');
      } else {
        // Echo unknown messages
        socket.add('Server received: $data');
      }
    } catch (e) {
      print('Error handling WebSocket message: $e');
    }
  }
  
  // Start sending periodic system info updates
  void _startSystemInfoUpdates(WebSocket socket) {
    _systemInfoTimer?.cancel();
    
    _systemInfoTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      try {
        if (_webSocketClients.contains(socket)) {
          final systemInfo = {
            'c': 'sysinfo',
            'cpuTemp': (35 + (DateTime.now().second % 15)).toString(),
            'cpuUsage': (10 + (DateTime.now().second % 30)).toString(),
            'ramUsage': (512 + (DateTime.now().second % 256)).toString(),
            'ramTotal': '8192',
            'diskUsage': (25 + (DateTime.now().second % 15)).toString(),
            'diskTotal': '256',
            'upTime': (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
            'netSentSpeed': (150 + (DateTime.now().second % 100)).toString(),
            'netRecvSpeed': (200 + (DateTime.now().second % 150)).toString(),
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          };
          
          socket.add(jsonEncode(systemInfo));
        } else {
          timer.cancel();
        }
      } catch (e) {
        print('Error sending system info: $e');
        timer.cancel();
      }
    });
  }
  
  // Start sending mock camera updates
  void _startCameraUpdates(WebSocket socket) {
    // Generate two mock camera devices
    _cameraUpdateTimer?.cancel();
    
    // Send initial device data
    _sendInitialCameraDevices(socket);
    
    // Send periodic updates for camera status, etc.
    _cameraUpdateTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      try {
        if (_webSocketClients.contains(socket)) {
          _sendRandomCameraUpdates(socket);
        } else {
          timer.cancel();
        }
      } catch (e) {
        print('Error sending camera updates: $e');
        timer.cancel();
      }
    });
  }
  
  // Send initial camera device data
  void _sendInitialCameraDevices(WebSocket socket) {
    // First device with two cameras
    final macKey1 = 'm_AA_BB_CC_DD_EE_01';
    
    // Base device data
    _sendCameraDeviceProperty(socket, macKey1, 'ipv4', '192.168.1.100');
    _sendCameraDeviceProperty(socket, macKey1, 'connected', 1);
    _sendCameraDeviceProperty(socket, macKey1, 'last_seen_at', DateTime.now().toIso8601String());
    _sendCameraDeviceProperty(socket, macKey1, 'test.uptime', '3600');
    _sendCameraDeviceProperty(socket, macKey1, 'app.deviceType', 'NVR');
    _sendCameraDeviceProperty(socket, macKey1, 'app.firmware_version', 'v2.5.1');
    _sendCameraDeviceProperty(socket, macKey1, 'app.recordPath', '/recordings');
    
    // Camera 1
    _sendCameraProperty(socket, macKey1, 0, 'name', 'Front Door');
    _sendCameraProperty(socket, macKey1, 0, 'cameraIp', '192.168.1.101');
    _sendCameraProperty(socket, macKey1, 0, 'username', 'admin');
    _sendCameraProperty(socket, macKey1, 0, 'password', 'admin');
    _sendCameraProperty(socket, macKey1, 0, 'brand', 'Hikvision');
    _sendCameraProperty(socket, macKey1, 0, 'hw', 'DS-2CD2142FWD-I');
    _sendCameraProperty(socket, macKey1, 0, 'manufacturer', 'Hikvision');
    _sendCameraProperty(socket, macKey1, 0, 'xAddrs', 'http://192.168.1.101/onvif/device_service');
    _sendCameraProperty(socket, macKey1, 0, 'mediaUri', 'rtsp://192.168.1.101:554/Streaming/Channels/101');
    _sendCameraProperty(socket, macKey1, 0, 'recordUri', 'rtsp://192.168.1.101:554/Streaming/Channels/101');
    _sendCameraProperty(socket, macKey1, 0, 'subUri', 'rtsp://192.168.1.101:554/Streaming/Channels/102');
    _sendCameraProperty(socket, macKey1, 0, 'remoteUri', 'rtsp://192.168.1.101:554/Streaming/Channels/103');
    _sendCameraProperty(socket, macKey1, 0, 'mainSnapShot', 'http://192.168.1.101/Streaming/Channels/1/picture');
    _sendCameraProperty(socket, macKey1, 0, 'subSnapShot', 'http://192.168.1.101/Streaming/Channels/2/picture');
    _sendCameraProperty(socket, macKey1, 0, 'recordwidth', 1920);
    _sendCameraProperty(socket, macKey1, 0, 'recordheight', 1080);
    _sendCameraProperty(socket, macKey1, 0, 'subwidth', 640);
    _sendCameraProperty(socket, macKey1, 0, 'subheight', 480);
    
    // Send camera report data as well
    _sendCameraReportProperty(socket, macKey1, 'Front Door', 'connected', 1);
    _sendCameraReportProperty(socket, macKey1, 'Front Door', 'last_seen_at', DateTime.now().toIso8601String());
    _sendCameraReportProperty(socket, macKey1, 'Front Door', 'recording', 1);
    
    // Camera 2
    _sendCameraProperty(socket, macKey1, 1, 'name', 'Back Yard');
    _sendCameraProperty(socket, macKey1, 1, 'cameraIp', '192.168.1.102');
    _sendCameraProperty(socket, macKey1, 1, 'username', 'admin');
    _sendCameraProperty(socket, macKey1, 1, 'password', 'admin');
    _sendCameraProperty(socket, macKey1, 1, 'brand', 'Hikvision');
    _sendCameraProperty(socket, macKey1, 1, 'hw', 'DS-2CD2142FWD-I');
    _sendCameraProperty(socket, macKey1, 1, 'manufacturer', 'Hikvision');
    _sendCameraProperty(socket, macKey1, 1, 'xAddrs', 'http://192.168.1.102/onvif/device_service');
    _sendCameraProperty(socket, macKey1, 1, 'mediaUri', 'rtsp://192.168.1.102:554/Streaming/Channels/101');
    _sendCameraProperty(socket, macKey1, 1, 'recordUri', 'rtsp://192.168.1.102:554/Streaming/Channels/101');
    _sendCameraProperty(socket, macKey1, 1, 'subUri', 'rtsp://192.168.1.102:554/Streaming/Channels/102');
    _sendCameraProperty(socket, macKey1, 1, 'remoteUri', 'rtsp://192.168.1.102:554/Streaming/Channels/103');
    _sendCameraProperty(socket, macKey1, 1, 'mainSnapShot', 'http://192.168.1.102/Streaming/Channels/1/picture');
    _sendCameraProperty(socket, macKey1, 1, 'subSnapShot', 'http://192.168.1.102/Streaming/Channels/2/picture');
    _sendCameraProperty(socket, macKey1, 1, 'recordwidth', 1920);
    _sendCameraProperty(socket, macKey1, 1, 'recordheight', 1080);
    _sendCameraProperty(socket, macKey1, 1, 'subwidth', 640);
    _sendCameraProperty(socket, macKey1, 1, 'subheight', 480);
    
    // Send camera report data as well
    _sendCameraReportProperty(socket, macKey1, 'Back Yard', 'connected', 1);
    _sendCameraReportProperty(socket, macKey1, 'Back Yard', 'last_seen_at', DateTime.now().toIso8601String());
    _sendCameraReportProperty(socket, macKey1, 'Back Yard', 'recording', 0);
    
    // Second device with one camera
    final macKey2 = 'm_AA_BB_CC_DD_EE_02';
    
    // Base device data
    _sendCameraDeviceProperty(socket, macKey2, 'ipv4', '192.168.1.200');
    _sendCameraDeviceProperty(socket, macKey2, 'connected', 1);
    _sendCameraDeviceProperty(socket, macKey2, 'last_seen_at', DateTime.now().toIso8601String());
    _sendCameraDeviceProperty(socket, macKey2, 'test.uptime', '7200');
    _sendCameraDeviceProperty(socket, macKey2, 'app.deviceType', 'DVR');
    _sendCameraDeviceProperty(socket, macKey2, 'app.firmware_version', 'v3.1.0');
    _sendCameraDeviceProperty(socket, macKey2, 'app.recordPath', '/recordings');
    
    // Camera 1
    _sendCameraProperty(socket, macKey2, 0, 'name', 'Garage');
    _sendCameraProperty(socket, macKey2, 0, 'cameraIp', '192.168.1.201');
    _sendCameraProperty(socket, macKey2, 0, 'username', 'admin');
    _sendCameraProperty(socket, macKey2, 0, 'password', 'admin');
    _sendCameraProperty(socket, macKey2, 0, 'brand', 'Dahua');
    _sendCameraProperty(socket, macKey2, 0, 'hw', 'IPC-HDBW4631R-ZS');
    _sendCameraProperty(socket, macKey2, 0, 'manufacturer', 'Dahua');
    _sendCameraProperty(socket, macKey2, 0, 'xAddrs', 'http://192.168.1.201/onvif/device_service');
    _sendCameraProperty(socket, macKey2, 0, 'mediaUri', 'rtsp://192.168.1.201:554/cam/realmonitor?channel=1&subtype=0');
    _sendCameraProperty(socket, macKey2, 0, 'recordUri', 'rtsp://192.168.1.201:554/cam/realmonitor?channel=1&subtype=0');
    _sendCameraProperty(socket, macKey2, 0, 'subUri', 'rtsp://192.168.1.201:554/cam/realmonitor?channel=1&subtype=1');
    _sendCameraProperty(socket, macKey2, 0, 'remoteUri', 'rtsp://192.168.1.201:554/cam/realmonitor?channel=1&subtype=2');
    _sendCameraProperty(socket, macKey2, 0, 'mainSnapShot', 'http://192.168.1.201/cgi-bin/snapshot.cgi?channel=1');
    _sendCameraProperty(socket, macKey2, 0, 'subSnapShot', 'http://192.168.1.201/cgi-bin/snapshot.cgi?channel=2');
    _sendCameraProperty(socket, macKey2, 0, 'recordwidth', 2560);
    _sendCameraProperty(socket, macKey2, 0, 'recordheight', 1440);
    _sendCameraProperty(socket, macKey2, 0, 'subwidth', 720);
    _sendCameraProperty(socket, macKey2, 0, 'subheight', 480);
    
    // Send camera report data as well
    _sendCameraReportProperty(socket, macKey2, 'Garage', 'connected', 1);
    _sendCameraReportProperty(socket, macKey2, 'Garage', 'last_seen_at', DateTime.now().toIso8601String());
    _sendCameraReportProperty(socket, macKey2, 'Garage', 'recording', 1);
  }
  
  // Send random camera updates for simulation
  void _sendRandomCameraUpdates(WebSocket socket) {
    final random = Random();
    
    // Update Front Door camera last_seen_at
    _sendCameraReportProperty(
      socket, 
      'm_AA_BB_CC_DD_EE_01', 
      'Front Door', 
      'last_seen_at', 
      DateTime.now().toIso8601String()
    );
    
    // Randomly toggle recording state for Back Yard camera
    if (random.nextDouble() < 0.2) {
      _sendCameraReportProperty(
        socket, 
        'm_AA_BB_CC_DD_EE_01', 
        'Back Yard', 
        'recording', 
        random.nextBool() ? 1 : 0
      );
    }
    
    // Update Back Yard camera last_seen_at
    _sendCameraReportProperty(
      socket, 
      'm_AA_BB_CC_DD_EE_01', 
      'Back Yard', 
      'last_seen_at', 
      DateTime.now().toIso8601String()
    );
    
    // Update Garage camera last_seen_at
    _sendCameraReportProperty(
      socket, 
      'm_AA_BB_CC_DD_EE_02', 
      'Garage', 
      'last_seen_at', 
      DateTime.now().toIso8601String()
    );
    
    // Randomly toggle connection state for one of the cameras
    if (random.nextDouble() < 0.05) {
      final macKey = random.nextBool() ? 'm_AA_BB_CC_DD_EE_01' : 'm_AA_BB_CC_DD_EE_02';
      final cameraName = macKey == 'm_AA_BB_CC_DD_EE_01' 
                         ? (random.nextBool() ? 'Front Door' : 'Back Yard') 
                         : 'Garage';
                         
      _sendCameraReportProperty(
        socket, 
        macKey, 
        cameraName, 
        'connected', 
        random.nextBool() ? 1 : 0
      );
    }
  }
  
  // Helper to send camera device property update
  void _sendCameraDeviceProperty(WebSocket socket, String macKey, String propertyPath, dynamic value) {
    final message = {
      'c': 'changed',
      'data': 'ecs_slaves.$macKey.$propertyPath',
      'val': value,
    };
    socket.add(jsonEncode(message));
  }
  
  // Helper to send camera property update
  void _sendCameraProperty(WebSocket socket, String macKey, int cameraIndex, String propertyName, dynamic value) {
    final message = {
      'c': 'changed',
      'data': 'ecs_slaves.$macKey.cam[$cameraIndex].$propertyName',
      'val': value,
    };
    socket.add(jsonEncode(message));
  }
  
  // Helper to send camera report property
  void _sendCameraReportProperty(WebSocket socket, String macKey, String cameraName, String propertyName, dynamic value) {
    final message = {
      'c': 'changed',
      'data': 'ecs_slaves.$macKey.camreports.$cameraName.$propertyName',
      'val': value,
    };
    socket.add(jsonEncode(message));
  }
  
  // Serve static file content
  Future<void> _serveStaticFile(HttpRequest request, String contentType, String content) async {
    request.response.headers.contentType = ContentType.parse(contentType);
    request.response.write(content);
    await request.response.close();
  }
  
  // Serve JSON response
  Future<void> _serveJsonResponse(HttpRequest request, int statusCode, Map<String, dynamic> data) async {
    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(data));
    await request.response.close();
  }
  
  // Get HTML content for the index page
  String _getIndexHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
    <title>WebSocket Test Server</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
        h1 { color: #333; }
        #log { border: 1px solid #ccc; padding: 10px; height: 300px; overflow-y: scroll; margin-top: 20px; }
        #controls { margin-top: 20px; }
        input, button { padding: 8px; margin-right: 5px; }
        button { cursor: pointer; background: #4CAF50; color: white; border: none; }
        button:hover { background: #45a049; }
    </style>
</head>
<body>
    <h1>WebSocket Test Server</h1>
    <div id="status">Status: Disconnected</div>
    
    <div id="controls">
        <input type="text" id="message" placeholder="Enter message" />
        <button id="send">Send</button>
        <button id="connect">Connect</button>
        <button id="disconnect">Disconnect</button>
    </div>
    
    <h2>Message Log:</h2>
    <div id="log"></div>
    
    <script>
        // WebSocket connection
        let socket = null;
        const log = document.getElementById('log');
        const status = document.getElementById('status');
        const messageInput = document.getElementById('message');
        
        // Connect to WebSocket server
        document.getElementById('connect').addEventListener('click', () => {
            if (socket && socket.readyState === WebSocket.OPEN) {
                logMessage('Already connected');
                return;
            }
            
            try {
                const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
                const wsUrl = protocol + '//' + window.location.host + '/ws';
                
                logMessage('Connecting to ' + wsUrl + '...');
                socket = new WebSocket(wsUrl);
                
                socket.onopen = () => {
                    status.textContent = 'Status: Connected';
                    logMessage('Connection established');
                };
                
                socket.onmessage = (event) => {
                    logMessage('Received: ' + event.data);
                };
                
                socket.onclose = () => {
                    status.textContent = 'Status: Disconnected';
                    logMessage('Connection closed');
                };
                
                socket.onerror = (error) => {
                    logMessage('Error: ' + error);
                };
            } catch (err) {
                logMessage('Connection error: ' + err.message);
            }
        });
        
        // Disconnect from WebSocket server
        document.getElementById('disconnect').addEventListener('click', () => {
            if (socket) {
                socket.close();
                socket = null;
                status.textContent = 'Status: Disconnected';
                logMessage('Disconnected');
            }
        });
        
        // Send message
        document.getElementById('send').addEventListener('click', () => {
            const message = messageInput.value.trim();
            if (!message) return;
            
            if (socket && socket.readyState === WebSocket.OPEN) {
                socket.send(message);
                logMessage('Sent: ' + message);
                messageInput.value = '';
            } else {
                logMessage('Cannot send message: Not connected');
            }
        });
        
        // Allow sending message with Enter key
        messageInput.addEventListener('keypress', (event) => {
            if (event.key === 'Enter') {
                document.getElementById('send').click();
            }
        });
        
        // Log message
        function logMessage(msg) {
            const timestamp = new Date().toLocaleTimeString();
            const entry = document.createElement('div');
            entry.textContent = '[' + timestamp + '] ' + msg;
            log.appendChild(entry);
            log.scrollTop = log.scrollHeight;
        }
        
        // Try to connect automatically
        window.addEventListener('load', () => {
            setTimeout(() => {
                document.getElementById('connect').click();
            }, 1000);
        });
    </script>
</body>
</html>
    ''';
  }
}
