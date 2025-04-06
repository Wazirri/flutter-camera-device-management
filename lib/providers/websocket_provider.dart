import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:http/http.dart' as http;

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
}

enum EnvType {
  development,
  production,
}

class WebSocketProvider extends ChangeNotifier {
  String _ip = ''; // Server IP address
  int _port = 0; // Server port
  WebSocketChannel? _channel;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  bool _isAuthenticated = false;
  String _username = '';
  String _password = '';
  EnvType _environment = EnvType.production;
  
  // Latest message from the server
  Map<String, dynamic>? _lastMessage;
  
  // Getters
  ConnectionStatus get status => _status;
  bool get isConnected => _status == ConnectionStatus.connected;
  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get lastMessage => _lastMessage;
  String get serverAddress => '$_ip:$_port';
  EnvType get environment => _environment;
  
  // Constructor - Initialize connection parameters
  WebSocketProvider({EnvType environment = EnvType.production}) {
    _environment = environment;
    
    // Set default connection parameters based on environment
    if (_environment == EnvType.development) {
      // In development, connect to localhost
      _ip = 'localhost';
      _port = 5000;
    } else {
      // In production, connect to the actual server
      _ip = '85.104.114.145';
      _port = 1200;
    }
  }
  
  // Initialize connection and set up listeners
  Future<void> initialize() async {
    await connect();
  }
  
  // Connect to WebSocket server
  Future<void> connect() async {
    if (_status == ConnectionStatus.connecting) return;
    
    _status = ConnectionStatus.connecting;
    notifyListeners();
    
    try {
      final uri = Uri.parse('ws://$_ip:$_port');
      debugPrint('Connecting to WebSocket at $uri');
      
      _channel = IOWebSocketChannel.connect(
        uri.toString(),
        pingInterval: const Duration(seconds: 30),
      );
      
      _status = ConnectionStatus.connected;
      notifyListeners();
      
      _setupListeners();
      _startHeartbeat();
      
      debugPrint('WebSocket connected successfully');
    } catch (e) {
      debugPrint('Error connecting to WebSocket: $e');
      _status = ConnectionStatus.disconnected;
      notifyListeners();
      _scheduleReconnect();
    }
  }
  
  // Set up message and error listeners
  void _setupListeners() {
    _channel?.stream.listen(
      (dynamic message) {
        _handleMessage(message);
      },
      onError: (error) {
        debugPrint('WebSocket error: $error');
        _handleDisconnection();
      },
      onDone: () {
        debugPrint('WebSocket connection closed');
        _handleDisconnection();
      },
    );
  }
  
  // Handle incoming messages from the server
  void _handleMessage(dynamic message) {
    try {
      if (message is String) {
        final Map<String, dynamic> jsonData = json.decode(message);
        
        // Store the latest message
        _lastMessage = jsonData;
        
        // Check for login-related messages
        if (jsonData['c'] == 'login') {
          _handleLoginMessage(jsonData);
        }
        
        // Notify listeners of the new message
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error parsing message: $e');
    }
  }
  
  // Handle login-related messages
  void _handleLoginMessage(Map<String, dynamic> message) {
    if (message['msg'] == 'Oturum açıldı!') {
      debugPrint('Login successful');
      _isAuthenticated = true;
      
      // After successful login, request system monitoring
      if (_isAuthenticated) {
        sendMessage('DO MONITORECS');
      }
      
      notifyListeners();
    } else if (message['msg'] == 'Oturum açılmamış!') {
      debugPrint('Not logged in, attempting login');
      _isAuthenticated = false;
      
      // If we have credentials, try to log in
      if (_username.isNotEmpty && _password.isNotEmpty) {
        login(_username, _password);
      }
      
      notifyListeners();
    }
  }
  
  // Handle disconnection events
  void _handleDisconnection() {
    _status = ConnectionStatus.disconnected;
    _channel?.sink.close();
    _channel = null;
    _isAuthenticated = false;
    
    // Cancel heartbeat timer
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    
    notifyListeners();
    _scheduleReconnect();
  }
  
  // Schedule a reconnection attempt
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () async {
      debugPrint('Attempting to reconnect to WebSocket');
      await connect();
    });
  }
  
  // Start heartbeat timer to keep connection alive
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_status == ConnectionStatus.connected) {
        // Send a ping message to keep the connection alive
        sendMessage('PING');
      }
    });
  }
  
  // Login with username and password
  Future<void> login(String username, String password) async {
    _username = username;
    _password = password;
    
    if (_status == ConnectionStatus.connected) {
      // Send login command
      final loginCommand = 'LOGIN $username $password';
      sendMessage(loginCommand);
      debugPrint('Login command sent');
    } else {
      debugPrint('Cannot login: not connected to server');
      await connect();
    }
  }
  
  // Send a message to the server
  void sendMessage(String message) {
    if (_status == ConnectionStatus.connected && _channel != null) {
      try {
        _channel!.sink.add(message);
        debugPrint('Sent: $message');
      } catch (e) {
        debugPrint('Error sending message: $e');
        _handleDisconnection();
      }
    } else {
      debugPrint('Cannot send message: not connected to server');
    }
  }
  
  // Set environment type and reconnect if necessary
  void setEnvironment(EnvType env) {
    if (_environment != env) {
      _environment = env;
      
      // Update connection parameters based on new environment
      if (_environment == EnvType.development) {
        _ip = 'localhost';
        _port = 5000;
      } else {
        _ip = '85.104.114.145';
        _port = 1200;
      }
      
      // Disconnect from current server
      _channel?.sink.close();
      _channel = null;
      _status = ConnectionStatus.disconnected;
      
      // Connect to new server
      connect();
      
      notifyListeners();
    }
  }
  
  // Get server health status
  Future<bool> checkServerHealth() async {
    try {
      final response = await http.get(Uri.parse('http://$_ip:$_port/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  // Clean up resources when provider is disposed
  @override
  void dispose() {
    _channel?.sink.close();
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}