#!/usr/bin/env python3

# This script adds logging functionality to the WebSocketProvider class

with open('lib/providers/websocket_provider.dart', 'r') as file:
    content = file.read()

# Add log tracking properties if not already there
logs_properties = """
  // Log tracking
  final List<String> _logs = [];
  int _sentCount = 0;
  int _receivedCount = 0;
  final List<Function(List<String>)> _logListeners = [];
"""

if "final List<String> _logs = [];" not in content:
    insert_pos = content.find("String? _lastMessage;")
    if insert_pos > 0:
        # Find the end of the line
        end_line_pos = content.find("\n", insert_pos)
        if end_line_pos > 0:
            # Insert log properties after lastMessage
            before_prop = content[:end_line_pos + 1]
            after_prop = content[end_line_pos + 1:]
            
            # Combine the parts
            content = before_prop + logs_properties + after_prop

# Add log methods if not already there
log_methods = """
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

  // Getters for log counts
  int get sentCount => _sentCount;
  int get receivedCount => _receivedCount;
"""

if "void clearLogs()" not in content:
    insert_pos = content.find("void sendMessage(String message)")
    if insert_pos > 0:
        # Find the end of the method
        method_end = content.find("}", insert_pos)
        if method_end > 0:
            # Find the end of the closing brace line
            end_line_pos = content.find("\n", method_end)
            if end_line_pos > 0:
                # Insert log methods after sendMessage method
                before_methods = content[:end_line_pos + 1]
                after_methods = content[end_line_pos + 1:]
                
                # Combine the parts
                content = before_methods + log_methods + after_methods

# Update the sendMessage method to log outgoing messages
if "_logs.add(\"➡️ $message\");" not in content:
    # Find the sendMessage method
    send_method_pos = content.find("void sendMessage(String message)")
    if send_method_pos > 0:
        # Find where to add the logging
        socket_add_pos = content.find("_socket!.add(message);", send_method_pos)
        if socket_add_pos > 0:
            # Find the end of the line
            end_line_pos = content.find("\n", socket_add_pos)
            if end_line_pos > 0:
                # Insert log tracking after socket add
                before_log = content[:end_line_pos + 1]
                after_log = content[end_line_pos + 1:]
                
                # Add the logging code
                log_code = "        _sentCount++;\n        _logs.add(\"➡️ $message\");\n        _notifyLogListeners();\n"
                
                # Combine the parts
                content = before_log + log_code + after_log

# Update the handleMessage method to log incoming messages
if "_logs.add(\"⬅️ $message\");" not in content:
    # Find the handleMessage method
    handle_method_pos = content.find("_handleMessage(String message)")
    if handle_method_pos > 0:
        # Find where to add the logging - after setting lastMessage
        last_message_pos = content.find("_lastMessage = message;", handle_method_pos)
        if last_message_pos > 0:
            # Find the end of the line
            end_line_pos = content.find("\n", last_message_pos)
            if end_line_pos > 0:
                # Insert log tracking after setting lastMessage
                before_log = content[:end_line_pos + 1]
                after_log = content[end_line_pos + 1:]
                
                # Add the logging code
                log_code = "    _receivedCount++;\n    _logs.add(\"⬅️ $message\");\n    _notifyLogListeners();\n"
                
                # Combine the parts
                content = before_log + log_code + after_log

# Write the updated content back to the file
with open('lib/providers/websocket_provider.dart', 'w') as file:
    file.write(content)

print("Added logging functionality to WebSocketProvider")
