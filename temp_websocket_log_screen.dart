import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/websocket_provider.dart';
import '../theme/app_theme.dart';

class WebSocketLogScreen extends StatelessWidget {
  const WebSocketLogScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebSocket Logs'),
        backgroundColor: AppTheme.darkSurface,
        // Geri dön butonu ekleniyor
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Ana sayfaya dön
            Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
          },
          tooltip: 'Geri Dön',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              // Clear WebSocket logs
              Provider.of<WebSocketProvider>(context, listen: false).clearLog();
            },
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: Consumer<WebSocketProvider>(
        builder: (context, provider, child) {
          final isConnected = provider.isConnected;
          final logs = provider.messageLog;
          
          return Column(
            children: [
              // Connection status
              Container(
                padding: const EdgeInsets.all(16),
                color: isConnected ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                child: Row(
                  children: [
                    Icon(
                      isConnected ? Icons.check_circle_outline : Icons.error_outline,
                      color: isConnected ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isConnected ? 'Connected to WebSocket' : 'Disconnected',
                      style: TextStyle(
                        color: isConnected ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Log messages
              Expanded(
                child: logs.isEmpty
                    ? const Center(
                        child: Text(
                          'No messages received yet',
                          style: TextStyle(color: AppTheme.darkTextSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: logs.length,
                        reverse: true, // Show newest messages at the bottom
                        itemBuilder: (context, index) {
                          final reversedIndex = logs.length - 1 - index;
                          final logMessage = logs[reversedIndex];
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 8,
                            ),
                            color: AppTheme.darkSurface,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                logMessage,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: AppTheme.darkTextPrimary,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
