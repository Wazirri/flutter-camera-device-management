#!/usr/bin/env python3

# This script adds lastMessage to the WebSocketProvider class
# and adds the sendMessage method

with open('lib/providers/websocket_provider.dart', 'r') as file:
    content = file.read()

# Add lastMessage property to WebSocketProvider
if "String? _lastMessage;" not in content:
    insert_pos = content.find("SystemInfo? _systemInfo;")
    if insert_pos > 0:
        # Find the end of the line
        end_line_pos = content.find("\n", insert_pos)
        if end_line_pos > 0:
            # Insert lastMessage property after systemInfo
            before_prop = content[:end_line_pos + 1]
            after_prop = content[end_line_pos + 1:]
            
            # Add the property
            last_message_prop = "  String? _lastMessage;\n  \n  // Log tracking\n  final List<String> _logs = [];\n  int _sentCount = 0;\n  int _receivedCount = 0;\n  final List<Function(List<String>)> _logListeners = [];\n"
            
            # Combine the parts
            content = before_prop + last_message_prop + after_prop

# Add the sendMessage method
if "void sendMessage(String message)" not in content:
    # Find a good place to add it - after a method
    insert_pos = content.find("void dispose() {")
    if insert_pos > 0:
        # Go to the beginning of the line
        line_start = content.rfind("\n", 0, insert_pos) + 1
        if line_start > 0:
            # Insert the method before dispose
            before_method = content[:line_start]
            after_method = content[line_start:]
            
            # Add the send message method
            send_message_method = """
  // Send a message via WebSocket
  void sendMessage(String message) {
    if (_socket != null && _isConnected) {
      try {
        _socket!.add(message);
        _sentCount++;
        _logs.add("➡️ $message");
        _notifyLogListeners();
        notifyListeners();
      } catch (e) {
        print("Error sending message: $e");
        _errorMessage = 'Failed to send message: $e';
        notifyListeners();
      }
    } else {
      _errorMessage = 'WebSocket not connected';
      notifyListeners();
    }
  }

  // Clear logs
  void clearLogs() {
    _logs.clear();
    _notifyLogListeners();
    notifyListeners();
  }

  // Add a log listener
  void addLogListener(Function(List<String>) listener) {
    _logListeners.add(listener);
  }

  // Remove a log listener
  void removeLogListener(Function(List<String>) listener) {
    _logListeners.remove(listener);
  }

  // Notify log listeners
  void _notifyLogListeners() {
    for (var listener in _logListeners) {
      listener(_logs);
    }
  }

  // Getter for the last message received
  String? get lastMessage => _lastMessage;

  // Getters for log counts
  int get sentCount => _sentCount;
  int get receivedCount => _receivedCount;

"""
            
            # Combine the parts
            content = before_method + send_message_method + after_method

# Update the _handleMessage method to set lastMessage
content = content.replace("_handleMessage(String message) {", """_handleMessage(String message) {
    // Store the last message
    _lastMessage = message;
    _receivedCount++;
    _logs.add("⬅️ $message");
    _notifyLogListeners();
""")

# Fix the problem of uptime being a String in dashboard_screen.dart
if "if (responseJson['c'] == 'sysinfo') {" in content:
    # Make sure upTime is parsed as an int in SystemInfo.fromJson
    content = content.replace("if (responseJson['c'] == 'sysinfo') {", """if (responseJson['c'] == 'sysinfo') {
        // Convert upTime to int if it's a string
        if (responseJson['upTime'] is String) {
          responseJson['upTime'] = int.tryParse(responseJson['upTime']) ?? 0;
        }""")

# Write the updated content back to the file
with open('lib/providers/websocket_provider.dart', 'w') as file:
    file.write(content)

print("Fixed WebSocketProvider with lastMessage property and sendMessage method")
