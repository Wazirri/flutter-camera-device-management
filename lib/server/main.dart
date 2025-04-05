import 'dart:async';
import 'dart:io';
import 'package:camera_device_manager/server/server.dart';

void main() async {
  print('Starting WebSocket Server on port 5000...');
  
  // Create and start the server
  final server = ServerApp(port: 5000);
  final success = await server.start();
  
  if (success) {
    print('Server started successfully');
    print('- HTTP server: http://localhost:5000');
    print('- WebSocket: ws://localhost:5000/ws');
    
    // Add a signal handler for clean shutdown
    ProcessSignal.sigint.watch().listen((signal) async {
      print('Received SIGINT signal, shutting down server...');
      await server.stop();
      exit(0);
    });
    
    // Keep the server running
    await Future.delayed(const Duration(days: 365));
  } else {
    print('Failed to start server');
    exit(1);
  }
}
