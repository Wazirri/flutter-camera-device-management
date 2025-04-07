import 'dart:convert';
import 'dart:io';

// A simple test client for our WebSocket server
void main() async {
  final uri = Uri.parse('ws://0.0.0.0:5000/ws');
  
  print('Connecting to WebSocket server at ${uri.toString()}...');
  
  try {
    final socket = await WebSocket.connect(uri.toString());
    print('Connected successfully!');
    
    // Handle incoming messages
    socket.listen(
      (dynamic data) {
        print('Received: $data');
        
        try {
          final jsonData = jsonDecode(data.toString());
          print('Message type: ${jsonData['c']}');
        } catch (e) {
          // Not a JSON message
          print('Non-JSON message received');
        }
      },
      onDone: () {
        print('Connection closed');
        exit(0);
      },
      onError: (error) {
        print('Error: $error');
        exit(1);
      },
    );
    
    // Send login message
    print('Sending login message...');
    socket.add('LOGIN admin admin');
    
    // Wait a few seconds
    await Future.delayed(const Duration(seconds: 2));
    
    // Send monitor request
    print('Sending monitor request...');
    socket.add('DO MONITORECS');
    
    // Keep the connection open
    print('Waiting for updates (press Ctrl+C to exit)...');
    
    // Process will stay running until closed or an error occurs
  } catch (e) {
    print('Failed to connect: $e');
    exit(1);
  }
}
