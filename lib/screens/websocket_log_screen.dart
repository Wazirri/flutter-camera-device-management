import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  
  // Multi-select state
  bool _isSelectionMode = false;
  final Set<int> _selectedIndices = {};
  
  // Scroll control - keep position when user scrolls up
  final ScrollController _scrollController = ScrollController();
  bool _autoScrollEnabled = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }
  
  void _onScroll() {
    // With reverse: true, position 0 is the bottom (newest messages)
    // If user scrolls up (position > 100), disable auto-scroll
    if (_scrollController.hasClients) {
      final isNearBottom = _scrollController.position.pixels < 100;
      if (_autoScrollEnabled != isNearBottom) {
        setState(() {
          _autoScrollEnabled = isNearBottom;
        });
      }
    }
  }
  
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0, // With reverse: true, 0 is the bottom
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      setState(() {
        _autoScrollEnabled = true;
      });
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedIndices.clear();
      }
    });
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _selectAll(List<String> logs) {
    setState(() {
      _selectedIndices.clear();
      for (int i = 0; i < logs.length; i++) {
        _selectedIndices.add(i);
      }
    });
  }

  void _copySelectedLogs(List<String> logs) {
    if (_selectedIndices.isEmpty) return;
    
    final sortedIndices = _selectedIndices.toList()..sort();
    final selectedLogs = sortedIndices.map((i) => logs[i]).join('\n');
    
    Clipboard.setData(ClipboardData(text: selectedLogs));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_selectedIndices.length} satır kopyalandı'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WebSocketProviderOptimized>(
      builder: (context, provider, child) {
        final isConnected = provider.isConnected;
        
        // Use paused logs if paused, otherwise live logs
        final allLogs = _isPaused ? _pausedLogs : provider.messageLog;
        
        // Filter logs by search query
        // Space-separated words are treated as AND (all words must match)
        final logs = _searchQuery.isEmpty
            ? allLogs
            : allLogs.where((log) {
                final logLower = log.toLowerCase();
                final searchTerms = _searchQuery.toLowerCase().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
                // All search terms must be present in the log line
                return searchTerms.every((term) => logLower.contains(term));
              }).toList();
        
        return Scaffold(
          appBar: AppBar(
            title: _isSelectionMode 
                ? Text('${_selectedIndices.length} seçili')
                : const Text('WebSocket Logs'),
            backgroundColor: _isSelectionMode ? AppTheme.primaryOrange.withOpacity(0.8) : AppTheme.darkSurface,
            automaticallyImplyLeading: false,
            leading: _isSelectionMode 
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _toggleSelectionMode,
                    tooltip: 'Seçimi İptal',
                  )
                : null,
            actions: _isSelectionMode 
                ? [
                    // Select all button
                    IconButton(
                      icon: const Icon(Icons.select_all),
                      onPressed: () => _selectAll(logs),
                      tooltip: 'Tümünü Seç',
                    ),
                    // Copy button
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: _selectedIndices.isNotEmpty 
                          ? () => _copySelectedLogs(logs)
                          : null,
                      tooltip: 'Kopyala',
                    ),
                  ]
                : [
                    // Selection mode button
                    IconButton(
                      icon: const Icon(Icons.checklist),
                      onPressed: _toggleSelectionMode,
                      tooltip: 'Çoklu Seçim',
                    ),
                    // Pause button
                    IconButton(
                      icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                      onPressed: () {
                        setState(() {
                          if (!_isPaused) {
                            // Pause - save current logs
                            _pausedLogs = List.from(provider.messageLog);
                          }
                          _isPaused = !_isPaused;
                        });
                      },
                      tooltip: _isPaused ? 'Devam' : 'Duraklat',
                    ),
                    // Clear button
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        provider.clearLog();
                        setState(() {
                          _pausedLogs.clear();
                          _selectedIndices.clear();
                        });
                      },
                      tooltip: 'Temizle',
                    ),
                  ],
          ),
          body: Column(
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
                      isConnected ? 'Bağlı' : 'Bağlantı Yok',
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
                          'DURAKLATILDI',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      '${logs.length} / ${allLogs.length} mesaj',
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
                    hintText: 'Log ara...',
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
                      // Clear selections when search changes
                      _selectedIndices.clear();
                    });
                  },
                ),
              ),
              
              // Log messages
              Expanded(
                child: Stack(
                  children: [
                    logs.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isNotEmpty ? 'Eşleşen mesaj yok' : 'Henüz mesaj yok',
                            style: const TextStyle(color: AppTheme.darkTextSecondary),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: logs.length,
                          reverse: true,
                          itemBuilder: (context, index) {
                          final reversedIndex = logs.length - 1 - index;
                          final logMessage = logs[reversedIndex];
                          final isSelected = _selectedIndices.contains(reversedIndex);
                          
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
                            color: isSelected 
                                ? AppTheme.primaryOrange.withOpacity(0.3) 
                                : AppTheme.darkSurface,
                            child: InkWell(
                              onTap: _isSelectionMode 
                                  ? () => _toggleSelection(reversedIndex)
                                  : null,
                              onLongPress: !_isSelectionMode
                                  ? () {
                                      _toggleSelectionMode();
                                      _toggleSelection(reversedIndex);
                                    }
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_isSelectionMode) ...[
                                      Checkbox(
                                        value: isSelected,
                                        onChanged: (_) => _toggleSelection(reversedIndex),
                                        activeColor: AppTheme.primaryOrange,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Expanded(child: messageWidget),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    // Scroll to bottom button when not at bottom
                    if (!_autoScrollEnabled && logs.isNotEmpty)
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: FloatingActionButton.small(
                          onPressed: _scrollToBottom,
                          backgroundColor: AppTheme.primaryOrange,
                          child: const Icon(Icons.arrow_downward, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
