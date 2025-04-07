import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

// Demo WebSocket server for testing the camera management app
void main() async {
  // Constants
  const int port = 5000;
  const String host = '0.0.0.0';

  // Create an HTTP server
  final server = await HttpServer.bind(
    host,
    port,
  );

  print('Starting WebSocket Server on port $port...');
  print('HTTP server started on http://$host:$port');

  // Store active WebSocket connections
  final List<WebSocket> connections = [];
  
  // Mock camera data
  final mockCameraDevices = generateMockCameraDevices();
  
  // HTTP route handling
  server.listen((HttpRequest request) async {
    if (request.uri.path == '/ws') {
      // Handle WebSocket upgrades
      try {
        final socket = await WebSocketTransformer.upgrade(request);
        connections.add(socket);
        print('Client connected: ${request.connectionInfo!.remoteAddress.address}');
        
        // Handle incoming WebSocket messages
        socket.listen(
          (dynamic data) {
            handleClientMessage(socket, data as String, connections, mockCameraDevices);
          },
          onDone: () {
            connections.remove(socket);
            print('Client disconnected');
          },
          onError: (error) {
            connections.remove(socket);
            print('WebSocket error: $error');
          },
          cancelOnError: true,
        );
      } catch (e) {
        print('Error during WebSocket upgrade: $e');
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.close();
      }
    } else if (request.uri.path == '/health') {
      // Health check endpoint
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType('application', 'json', charset: 'utf-8')
        ..write(jsonEncode({'status': 'ok', 'connections': connections.length}))
        ..close();
    } else {
      // Serve a simple response for other paths
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write('<html><body><h1>Camera Device Manager WebSocket Server</h1>'
                '<p>This is a mock WebSocket server for testing the Camera Device Manager application.</p>'
                '<p>Connect to the WebSocket endpoint at <code>ws://$host:$port/ws</code></p>'
                '</body></html>')
        ..close();
    }
  });
  
  print('Server started successfully');
  print('- HTTP server: http://$host:$port');
  print('- WebSocket: ws://$host:$port/ws');
  
  // Start sending mock system info and camera updates periodically
  startSystemInfoUpdates(connections);
  startCameraDeviceUpdates(connections, mockCameraDevices);
}

// Process client messages
void handleClientMessage(WebSocket socket, String message, List<WebSocket> connections, List<Map<String, dynamic>> mockCameraDevices) {
  print('Received message: $message');
  
  if (message.startsWith('LOGIN')) {
    // Handle login attempt
    final parts = message.split(' ');
    if (parts.length >= 3) {
      final username = parts[1];
      final password = parts[2];
      
      // Very basic authentication (for testing only)
      if (username == 'admin' && password == 'admin') {
        socket.add(jsonEncode({
          'c': 'login',
          'msg': 'Login successful',
          'status': 'success',
          'user': {'username': username, 'role': 'admin'}
        }));
      } else {
        socket.add(jsonEncode({
          'c': 'login',
          'msg': 'Invalid credentials',
          'status': 'error'
        }));
      }
    } else {
      socket.add(jsonEncode({
        'c': 'login',
        'msg': 'Invalid login format',
        'status': 'error'
      }));
    }
  } else if (message == 'DO MONITORECS') {
    // Send initial camera device data after monitoring request
    for (final device in mockCameraDevices) {
      final data = {
        'c': 'changed',
        'data': 'ecs.slaves.${device['macAddress']}',
        'value': device
      };
      socket.add(jsonEncode(data));
    }
    
    // Confirm monitoring started
    socket.add(jsonEncode({
      'c': 'monitorecs',
      'msg': 'Monitoring started',
      'status': 'success'
    }));
  } else if (message == 'PING') {
    // Respond to ping
    socket.add('PONG');
  } else {
    // Echo other messages back (for testing)
    socket.add(jsonEncode({
      'c': 'echo',
      'msg': message
    }));
  }
}

// Generate random mock camera devices
List<Map<String, dynamic>> generateMockCameraDevices() {
  final devices = <Map<String, dynamic>>[];
  final macAddresses = [
    'm_AA_BB_CC_DD_EE_01',
    'm_AA_BB_CC_DD_EE_02',
    'm_AA_BB_CC_DD_EE_03',
    'm_AA_BB_CC_DD_EE_04',
    'm_AA_BB_CC_DD_EE_05'
  ];
  
  for (var i = 0; i < macAddresses.length; i++) {
    final mac = macAddresses[i];
    final baseIp = '192.168.1.${10 + i}';
    
    // Add 2-5 cameras per device (with different IPs)
    final cameraCount = 2 + Random().nextInt(4);
    for (var j = 0; j < cameraCount; j++) {
      final cameraIp = '192.168.1.${20 + (i * 10) + j}';
      devices.add({
        'macAddress': mac,
        'cam': j,
        'name': 'Camera $j on Device $i',
        'model': 'IP Camera Model X${100 + j}',
        'username': 'admin',
        'password': 'admin',
        'cameraIp': cameraIp,
        'xAddrs': 'http://$cameraIp/onvif/device_service',
        'mediaUri': 'rtsp://$cameraIp:554/live',
        'subUri': 'rtsp://$cameraIp:554/sub',
        'recordUri': 'rtsp://$cameraIp:554/playback',
        'remoteUri': 'http://$cameraIp:8080/video',
        'status': 'online',
        'type': 'ONVIF',
        'lastUpdated': DateTime.now().toIso8601String(),
      });
    }
  }
  
  return devices;
}

// Send periodic system information updates
void startSystemInfoUpdates(List<WebSocket> connections) {
  Timer.periodic(const Duration(seconds: 5), (timer) {
    if (connections.isEmpty) return;
    
    final sysinfo = {
      'c': 'sysinfo',
      'cpuTemp': (40 + Random().nextInt(30)).toString(),
      'upTime': (timer.tick * 5 + 100).toString(),
      'cpuUsage': (Random().nextDouble() * 70).toStringAsFixed(1),
      'memTotal': '8192',
      'memFree': (1024 + Random().nextInt(3072)).toString(),
      'diskTotal': '500000',
      'diskFree': (200000 + Random().nextInt(200000)).toString(),
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    final message = jsonEncode(sysinfo);
    for (final connection in List<WebSocket>.from(connections)) {
      try {
        connection.add(message);
      } catch (e) {
        print('Error sending sysinfo update: $e');
      }
    }
  });
}

// Send periodic camera device updates
void startCameraDeviceUpdates(List<WebSocket> connections, List<Map<String, dynamic>> devices) {
  Timer.periodic(const Duration(seconds: 15), (timer) {
    if (connections.isEmpty) return;
    
    // Randomly update status for some cameras
    final deviceToUpdate = devices[Random().nextInt(devices.length)];
    deviceToUpdate['status'] = Random().nextInt(10) > 2 ? 'online' : 'offline';
    deviceToUpdate['lastUpdated'] = DateTime.now().toIso8601String();
    
    final update = {
      'c': 'changed',
      'data': 'ecs.slaves.${deviceToUpdate['macAddress']}',
      'value': deviceToUpdate
    };
    
    final message = jsonEncode(update);
    for (final connection in List<WebSocket>.from(connections)) {
      try {
        connection.add(message);
      } catch (e) {
        print('Error sending camera update: $e');
      }
    }
  });
}
