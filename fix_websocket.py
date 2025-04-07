#!/usr/bin/env python3

def fix_websocket_provider():
    with open('lib/providers/websocket_provider.dart', 'r') as f:
        content = f.read()
    
    # Replace auto-connect in loadSettings with a comment
    content = content.replace('''      // Auto-connect if we have credentials and rememberMe is true
      if (_rememberMe && _lastUsername != null && _lastPassword != null) {
        connect(_serverIp, _serverPort, 
          username: _lastUsername, 
          password: _lastPassword,
          rememberMe: _rememberMe);
      }''', '''      // No longer auto-connect - wait for user to press login button
      // Auto-connect functionality removed as per requirement''')
    
    # Write the updated content back
    with open('lib/providers/websocket_provider.dart', 'w') as f:
        f.write(content)
    
    print("WebSocket provider updated to not auto-connect")

if __name__ == "__main__":
    fix_websocket_provider()
