import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/websocket_provider.dart';
import '../theme/app_theme.dart';

class WebSocketLogScreen extends StatefulWidget {
  const WebSocketLogScreen({Key? key}) : super(key: key);

  @override
  State<WebSocketLogScreen> createState() => _WebSocketLogScreenState();
}

class _WebSocketLogScreenState extends State<WebSocketLogScreen> {
  bool _isPaused = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<String> _pausedLogs = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebSocket Logs'),
        backgroundColor: AppTheme.darkSurface,
        automaticallyImplyLeading: false,
        actions: [
          // Pause button
          IconButton(
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            onPressed: () {
              setState(() {
                if (!_isPaused) {
                  // Pause - save current logs
                  final provider = Provider.of<WebSocketProviderOptimized>(context, listen: false);
                  _pausedLogs = List.from(provider.messageLog);
                }
                _isPaused = !_isPaused;
              });
            },
            tooltip: _isPaused ? 'Resume' : 'Pause',
          ),
          // Clear button
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              Provider.of<WebSocketProviderOptimized>(context, listen: false).clearLog();
              setState(() {
                _pausedLogs.clear();
              });
            },
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: Consumer<WebSocketProviderOptimized>(
        builder: (context, provider, child) {
          final isConnected = provider.isConnected;
          
          // Use paused logs if paused, otherwise live logs
          final allLogs = _isPaused ? _pausedLogs : provider.messageLog;
          
          // Filter logs by search query
          final logs = _searchQuery.isEmpty
              ? allLogs
              : allLogs.where((log) => log.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
          
          return Column(
            children: [
              // Connection status and pause indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: isConnected ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                child: Row(
                  children: [
                    Icon(
                      isConnected ? Icons.check_circle_outline : Icons.error_outline,
                      color: isConnected ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isConnected ? 'Connected' : 'Disconnected',
                      style: TextStyle(
                        color: isConnected ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (_isPaused) ...[
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'PAUSED',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      '${logs.length} / ${allLogs.length} messages',
                      style: const TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              
              // Search bar
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search logs...',
                    hintStyle: const TextStyle(color: AppTheme.darkTextSecondary),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.darkTextSecondary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppTheme.darkTextSecondary),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.darkSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  style: const TextStyle(color: AppTheme.darkTextPrimary),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              
              // Log messages
              Expanded(
                child: logs.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isNotEmpty ? 'No matching messages' : 'No messages received yet',
                          style: const TextStyle(color: AppTheme.darkTextSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: logs.length,
                        reverse: true,
                        itemBuilder: (context, index) {
                          final reversedIndex = logs.length - 1 - index;
                          final logMessage = logs[reversedIndex];
                          
                          // Highlight search matches
                          Widget messageWidget;
                          if (_searchQuery.isNotEmpty) {
                            messageWidget = _buildHighlightedText(logMessage, _searchQuery);
                          } else {
                            messageWidget = Text(
                              logMessage,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: AppTheme.darkTextPrimary,
                              ),
                            );
                          }
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                            color: AppTheme.darkSurface,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: messageWidget,
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
  
  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) {
      return Text(
        text,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: AppTheme.darkTextPrimary,
        ),
      );
    }
    
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(
          text: text.substring(start),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: AppTheme.darkTextPrimary,
          ),
        ));
        break;
      }
      
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: AppTheme.darkTextPrimary,
          ),
        ));
      }
      
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: Colors.black,
          backgroundColor: Colors.yellow,
          fontWeight: FontWeight.bold,
        ),
      ));
      
      start = index + query.length;
    }
    
    return RichText(text: TextSpan(children: spans));
  }
}
