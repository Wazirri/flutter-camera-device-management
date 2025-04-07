import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/websocket_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/desktop_side_menu.dart';
import '../utils/responsive_helper.dart';

class WebSocketLogScreen extends StatefulWidget {
  static const routeName = '/websocket-logs';

  const WebSocketLogScreen({Key? key}) : super(key: key);

  @override
  WebSocketLogScreenState createState() => WebSocketLogScreenState();
}

class WebSocketLogScreenState extends State<WebSocketLogScreen> {
  late WebSocketProvider _webSocketProvider;
  List<String> logs = [];
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _webSocketProvider = Provider.of<WebSocketProvider>(context, listen: false);
    logs = List.from(_webSocketProvider.messageLog);
    
    // Subscribe to log updates
    _webSocketProvider.addLogListener(_updateLogs);
  }

  @override
  void dispose() {
    _webSocketProvider.removeLogListener(_updateLogs);
    super.dispose();
  }

  void _updateLogs() {
    setState(() {
      logs = List.from(_webSocketProvider.messageLog);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebSocket Logs'),
        actions: [
          // Clear logs button
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              setState(() {
                _webSocketProvider.clearLogs();
                logs = [];
              });
            },
          ),
          // Auto-scroll toggle
          IconButton(
            icon: Icon(
              _autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_center,
              color: _autoScroll ? AppTheme.accentColor : null,
            ),
            onPressed: () {
              setState(() {
                _autoScroll = !_autoScroll;
              });
            },
            tooltip: _autoScroll ? 'Auto-scroll enabled' : 'Auto-scroll disabled',
          ),
        ],
      ),
      drawer: isDesktop ? null : const DesktopSideMenu(),
      body: Row(
        children: [
          if (isDesktop) const DesktopSideMenu(),
          Expanded(
            child: Column(
              children: [
                // Header with counters
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildCounter('Total Messages', logs.length),
                      _buildCounter('Sent', _webSocketProvider.sentCount),
                      _buildCounter('Received', _webSocketProvider.receivedCount),
                    ],
                  ),
                ),
                
                // Log messages
                Expanded(
                  child: logs.isEmpty
                      ? Center(
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
                                  style: TextStyle(
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounter(String label, int count) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppTheme.darkTextSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: TextStyle(
              color: AppTheme.darkTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
