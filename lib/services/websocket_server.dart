import 'dart:async';
import 'dart:convert';
import 'dart:io';

class WebSocketServer {
  final HttpServer _httpServer;
  final String _path;
  final List<WebSocket> _clients = [];
  bool _isRunning = false;
  StreamSubscription? _httpSubscription;
  
  // Event controllers
  final _messageController = StreamController<WebSocketMessage>.broadcast();
  final _connectionController = StreamController<WebSocketClient>.broadcast();
  final _disconnectionController = StreamController<WebSocketClient>.broadcast();
  
  // Properties
  bool get isRunning => _isRunning;
  int get clientCount => _clients.length;
  
  // Streams for events
  Stream<WebSocketMessage> get onMessage => _messageController.stream;
  Stream<WebSocketClient> get onConnection => _connectionController.stream;
  Stream<WebSocketClient> get onDisconnection => _disconnectionController.stream;
  
  WebSocketServer(this._httpServer, {String path = '/ws'}) : _path = path;
  
  void start() {
    if (_isRunning) {
      print('WebSocket server already running');
      return; // Already running
    }
    
    try {
      // Create a custom HttpServer.bind() instance just for WebSockets
      HttpServer.bind(InternetAddress.anyIPv4, 5001).then((server) {
        print('WebSocket server started on ws://localhost:5001$_path');
        
        server.listen((HttpRequest request) {
          if (request.uri.path == _path) {
            // This is a WebSocket request
            WebSocketTransformer.upgrade(request).then((WebSocket socket) {
              _handleConnection(socket);
            }).catchError((error) {
              print('Error upgrading to WebSocket: $error');
              request.response.statusCode = HttpStatus.internalServerError;
              request.response.close();
            });
          } else {
            // Not a WebSocket request
            request.response.statusCode = HttpStatus.notFound;
            request.response.close();
          }
        });
        
        _isRunning = true;
      });
    } catch (e) {
      print('Error starting WebSocket server: $e');
    }
  }
  
  void stop() {
    if (_isRunning) {
      _httpSubscription?.cancel();
      
      for (final client in _clients) {
        try {
          client.close();
        } catch (e) {
          print('Error closing client: $e');
        }
      }
      _clients.clear();
      _isRunning = false;
      print('WebSocket server stopped');
    }
  }
  
  void _handleConnection(WebSocket socket) {
    print('New WebSocket connection established');
    _clients.add(socket);
    
    final client = WebSocketClient(socket, _clients.length - 1);
    _connectionController.add(client);
    
    socket.listen(
      (dynamic data) {
        if (data is String) {
          _handleTextMessage(socket, data);
        } else if (data is List<int>) {
          _handleBinaryMessage(socket, data);
        }
      },
      onDone: () => _handleDisconnection(socket),
      onError: (error) => _handleClientError(socket, error),
      cancelOnError: false,
    );
  }
  
  void _handleTextMessage(WebSocket socket, String message) {
    final client = WebSocketClient(socket, _clients.indexOf(socket));
    final wsMessage = WebSocketMessage(
      client: client,
      message: message,
      isBinary: false,
    );
    _messageController.add(wsMessage);
  }
  
  void _handleBinaryMessage(WebSocket socket, List<int> message) {
    final client = WebSocketClient(socket, _clients.indexOf(socket));
    final wsMessage = WebSocketMessage(
      client: client,
      message: message,
      isBinary: true,
    );
    _messageController.add(wsMessage);
  }
  
  void _handleDisconnection(WebSocket socket) {
    final index = _clients.indexOf(socket);
    if (index != -1) {
      final client = WebSocketClient(socket, index);
      _disconnectionController.add(client);
      _clients.remove(socket);
      print('WebSocket client disconnected');
    }
  }
  
  void _handleClientError(WebSocket socket, dynamic error) {
    print('WebSocket client error: $error');
    if (_clients.contains(socket)) {
      _handleDisconnection(socket);
    }
  }
  
  void _handleError(dynamic error) {
    print('WebSocket server error: $error');
  }
  
  // Send a message to all connected clients
  void broadcast(dynamic message) {
    for (final client in _clients) {
      sendTo(WebSocketClient(client, _clients.indexOf(client)), message);
    }
  }
  
  // Send a message to a specific client
  void sendTo(WebSocketClient client, dynamic message) {
    try {
      if (client.index < 0 || client.index >= _clients.length) {
        print('Invalid client index: ${client.index}');
        return;
      }
      
      final socket = _clients[client.index];
      if (socket.readyState == WebSocket.open) {
        if (message is String) {
          socket.add(message);
        } else if (message is List<int>) {
          socket.add(message);
        } else if (message is Map) {
          socket.add(jsonEncode(message));
        } else {
          socket.add(message.toString());
        }
      } else {
        print('Cannot send to client in state ${socket.readyState}');
      }
    } catch (e) {
      print('Error sending message: $e');
    }
  }
  
  // Dispose resources when the server is no longer needed
  void dispose() {
    stop();
    _messageController.close();
    _connectionController.close();
    _disconnectionController.close();
  }
}

class WebSocketClient {
  final WebSocket socket;
  final int index;
  
  WebSocketClient(this.socket, this.index);
  
  // Get the IP address of the client
  String get ip {
    try {
      return 'unknown'; // Not easily accessible without the original HttpRequest
    } catch (e) {
      return 'unknown';
    }
  }
  
  // Check if the connection is still open
  bool get isConnected => socket.readyState == WebSocket.open;
  
  // Close the connection
  void close([int? code, String? reason]) {
    socket.close(code, reason);
  }
}

class WebSocketMessage {
  final WebSocketClient client;
  final dynamic message;
  final bool isBinary;
  
  WebSocketMessage({
    required this.client,
    required this.message,
    required this.isBinary,
  });
  
  // Parse the message as JSON if possible
  Map<String, dynamic>? get asJson {
    if (!isBinary && message is String) {
      try {
        return jsonDecode(message as String) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
    return null;
  }
  
  // Get the message as a string
  String get asString {
    if (isBinary && message is List<int>) {
      try {
        return utf8.decode(message as List<int>);
      } catch (_) {
        return '<binary data>';
      }
    } else if (!isBinary && message is String) {
      return message as String;
    } else {
      return message.toString();
    }
  }
  
  // Get the message as binary data
  List<int>? get asBinary {
    if (isBinary && message is List<int>) {
      return message as List<int>;
    } else if (!isBinary && message is String) {
      return utf8.encode(message as String);
    }
    return null;
  }
}
