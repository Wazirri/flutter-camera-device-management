import 'package:flutter/material.dart';
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({Key? key}) : super(key: key);

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  // FTP configuration
  final String _ftpHost = '212.253.90.143';
  final int _ftpPort = 20521;
  final String _ftpUsername = 'dahuaftp';
  final String _ftpPassword = 'dahuaftp';
  final String _ftpBasePath = '/cam_detections';
  
  // Current navigation state  
  final List<String> _currentPath = [];
  List<FtpItem> _currentItems = [];
  bool _isLoading = false;
  String _loadingError = '';
  
  @override
  void initState() {
    super.initState();
    _loadFtpContent();
  }
  
  // Load FTP content for current path
  Future<void> _loadFtpContent() async {
    setState(() {
      _isLoading = true;
      _loadingError = '';
    });
    
    try {
      final currentFtpPath = _ftpBasePath + (_currentPath.isEmpty ? '' : '/${_currentPath.join('/')}');
      print('[FTP] Loading content from: $currentFtpPath');
      
      final items = await _fetchFtpDirListing(currentFtpPath);
      
      setState(() {
        _currentItems = items;
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() {
        _loadingError = 'Error loading FTP content: $e';
        _isLoading = false;
      });
      print('[FTP] Error: $e');
    }
  }
  
  // Fetch FTP directory listing using curl
  Future<List<FtpItem>> _fetchFtpDirListing(String path) async {
    try {
      print('[FTP] Fetching directory listing for: $path');
      
      final result = await Process.run('curl', [
        '-s', // Silent mode
        '--show-error', // Show errors
        '--list-only', // List only
        '--user', '$_ftpUsername:$_ftpPassword',
        'ftp://$_ftpHost:$_ftpPort$path/',
      ]);
      
      print('[FTP] Curl exit code: ${result.exitCode}');
      print('[FTP] Curl output: ${result.stdout}');
      
      if (result.exitCode != 0) {
        throw Exception('FTP connection failed: ${result.stderr}');
      }
      
      final lines = result.stdout.toString().split('\n');
      final items = <FtpItem>[];
      
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed == '.' || trimmed == '..') continue;
        
        // Determine if it's a file or directory by checking for common file extensions
        final isFile = _isFileByExtension(trimmed);
        
        items.add(FtpItem(
          name: trimmed,
          isDirectory: !isFile,
          path: '$path/$trimmed',
        ));
      }
      
      // Sort: directories first, then files
      items.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.compareTo(b.name);
      });
      
      return items;
      
    } catch (e) {
      print('[FTP] Exception during fetch: $e');
      rethrow;
    }
  }
  
  // Check if item is a file based on extension
  bool _isFileByExtension(String name) {
    final extensions = ['.jpg', '.jpeg', '.png', '.gif', '.mp4', '.avi', '.mov', '.dav', '.idx'];
    return extensions.any((ext) => name.toLowerCase().endsWith(ext));
  }
  
  // Download file from FTP
  Future<File?> _downloadFtpFile(String ftpPath) async {
    try {
      debugPrint('[FTP] Downloading file from: $ftpPath');
      
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final fileName = ftpPath.split('/').last;
      final localFile = File('${tempDir.path}/$fileName');
      
      // URL encode the path to handle special characters
      final encodedPath = Uri.encodeFull(ftpPath);
      final ftpUrl = 'ftp://$_ftpHost:$_ftpPort$encodedPath';
      
      debugPrint('[FTP] Encoded URL: $ftpUrl');
      
      // Use curl to download the file with proper encoding
      final result = await Process.run('curl', [
        '-s', // Silent mode
        '--show-error', // Show errors
        '--user', '$_ftpUsername:$_ftpPassword',
        '-o', localFile.path, // Output file
        '--globoff', // Disable glob parsing for special characters
        ftpUrl,
      ]);
      
      if (result.exitCode != 0) {
        debugPrint('[FTP] Download failed: ${result.stderr}');
        return null;
      }
      
      if (await localFile.exists()) {
        debugPrint('[FTP] File downloaded successfully: ${localFile.path}');
        return localFile;
      }
      
      return null;
    } catch (e) {
      debugPrint('[FTP] Download error: $e');
      return null;
    }
  }
  
  // Navigate to directory
  void _navigateToDirectory(String dirName) {
    setState(() {
      _currentPath.add(dirName);
    });
    _loadFtpContent();
  }
  
  // Navigate back
  void _navigateBack() {
    if (_currentPath.isNotEmpty) {
      setState(() {
        _currentPath.removeLast();
      });
      _loadFtpContent();
    }
  }
  
  // Get current path display
  String _getCurrentPathDisplay() {
    if (_currentPath.isEmpty) {
      return 'cam_detections';
    }
    return 'cam_detections/${_currentPath.join('/')}';
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Activities',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFtpContent,
          ),
        ],
      ),
      body: Column(
        children: [
          // Current path display
          _buildPathDisplay(),
          
          // Content list
          Expanded(
            child: _buildContentList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPathDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.darkBorder,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          if (_currentPath.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              color: AppTheme.primaryOrange,
              onPressed: _navigateBack,
            ),
          Expanded(
            child: Text(
              _getCurrentPathDisplay(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildContentList() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading...'),
          ],
        ),
      );
    }
    
    if (_loadingError.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _loadingError,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: _loadFtpContent,
            ),
          ],
        ),
      );
    }
    
    if (_currentItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, color: Colors.grey, size: 48),
            SizedBox(height: 16),
            Text(
              'No items found in this directory',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: _currentItems.length,
      itemBuilder: (context, index) {
        final item = _currentItems[index];
        return _buildItemTile(item);
      },
    );
  }
  
  Widget _buildItemTile(FtpItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: item.isDirectory ? Colors.blue : _getFileColor(item.name),
          child: Icon(
            item.isDirectory ? Icons.folder : _getFileIcon(item.name),
            color: Colors.white,
          ),
        ),
        title: Text(item.name),
        subtitle: item.isDirectory 
            ? const Text('Directory')
            : Text(_getFileTypeLabel(item.name)),
        trailing: item.isDirectory 
            ? const Icon(Icons.chevron_right)
            : (_isMediaFile(item.name) 
                ? const Icon(Icons.visibility) 
                : null),
        onTap: () {
          if (item.isDirectory) {
            _navigateToDirectory(item.name);
          } else if (_isMediaFile(item.name)) {
            _openMediaFile(item);
          }
        },
      ),
    );
  }
  
  Color _getFileColor(String fileName) {
    if (fileName.toLowerCase().endsWith('.jpg') || 
        fileName.toLowerCase().endsWith('.jpeg') || 
        fileName.toLowerCase().endsWith('.png')) {
      return Colors.green;
    } else if (fileName.toLowerCase().endsWith('.mp4') || 
               fileName.toLowerCase().endsWith('.avi') || 
               fileName.toLowerCase().endsWith('.mov') || 
               fileName.toLowerCase().endsWith('.dav')) {
      return Colors.red;
    }
    return Colors.grey;
  }
  
  IconData _getFileIcon(String fileName) {
    if (fileName.toLowerCase().endsWith('.jpg') || 
        fileName.toLowerCase().endsWith('.jpeg') || 
        fileName.toLowerCase().endsWith('.png')) {
      return Icons.image;
    } else if (fileName.toLowerCase().endsWith('.mp4') || 
               fileName.toLowerCase().endsWith('.avi') || 
               fileName.toLowerCase().endsWith('.mov') || 
               fileName.toLowerCase().endsWith('.dav')) {
      return Icons.videocam;
    }
    return Icons.insert_drive_file;
  }
  
  String _getFileTypeLabel(String fileName) {
    if (fileName.toLowerCase().endsWith('.jpg') || 
        fileName.toLowerCase().endsWith('.jpeg') || 
        fileName.toLowerCase().endsWith('.png')) {
      return 'Image';
    } else if (fileName.toLowerCase().endsWith('.mp4') || 
               fileName.toLowerCase().endsWith('.avi') || 
               fileName.toLowerCase().endsWith('.mov') || 
               fileName.toLowerCase().endsWith('.dav')) {
      return 'Video';
    }
    return 'File';
  }
  
  bool _isMediaFile(String fileName) {
    final mediaExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.mp4', '.avi', '.mov', '.dav'];
    return mediaExtensions.any((ext) => fileName.toLowerCase().endsWith(ext));
  }
  
  void _openMediaFile(FtpItem item) {
    final ftpUrl = 'ftp://$_ftpUsername:$_ftpPassword@$_ftpHost:$_ftpPort${item.path}';
    
    print('[Activities] Opening media file: ${item.name}');
    print('[Activities] FTP URL: $ftpUrl');
    print('[Activities] File path: ${item.path}');
    
    if (item.name.toLowerCase().endsWith('.mp4') || 
        item.name.toLowerCase().endsWith('.avi') || 
        item.name.toLowerCase().endsWith('.mov') || 
        item.name.toLowerCase().endsWith('.dav')) {
      // Open video player
      print('[Activities] Opening video player for: ${item.name}');
      
      // For DAV files, offer both streaming and download options
      if (item.name.toLowerCase().endsWith('.dav')) {
        _showDavFileOptions(item, ftpUrl);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(videoUrl: ftpUrl, title: item.name),
          ),
        );
      }
    } else {
      // Download and open image viewer
      _downloadAndShowImage(item);
    }
  }
  
  void _showDavFileOptions(FtpItem item, String ftpUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Play ${item.name}'),
        content: const Text('DAV files may need to be downloaded first. Choose an option:'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Try direct streaming
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoPlayerScreen(videoUrl: ftpUrl, title: item.name),
                ),
              );
            },
            child: const Text('Try Streaming'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Download and play locally
              _downloadAndPlayVideo(item);
            },
            child: const Text('Download & Play'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  void _downloadAndPlayVideo(FtpItem item) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Downloading video...'),
            ],
          ),
        ),
      ),
    );
    
    try {
      final downloadedFile = await _downloadFtpFile(item.path);
      
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      
      if (downloadedFile != null && mounted) {
        // Play downloaded video
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(
              videoUrl: downloadedFile.path, 
              title: item.name,
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download video')),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading video: $e')),
        );
      }
    }
  }
  
  // Download and show image
  void _downloadAndShowImage(FtpItem item) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Downloading image...'),
            ],
          ),
        ),
      ),
    );
    
    try {
      final downloadedFile = await _downloadFtpFile(item.path);
      
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      
      if (downloadedFile != null && mounted) {
        _showLocalImageDialog(downloadedFile.path, item.name);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download image')),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading image: $e')),
        );
      }
    }
  }

  void _showLocalImageDialog(String imagePath, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(title),
              automaticallyImplyLeading: false,
              backgroundColor: AppTheme.darkSurface,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Flexible(
              child: Image.file(
                File(imagePath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 48),
                        SizedBox(height: 16),
                        Text('Failed to load image'),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  
  const VideoPlayerScreen({
    Key? key, 
    required this.videoUrl, 
    required this.title,
  }) : super(key: key);
  
  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  
  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }
  
  void _initializeVideoPlayer() async {
    try {
      print('[VideoPlayer] Initializing video player for URL: ${widget.videoUrl}');
      
      // Support both network URLs and local files
      if (widget.videoUrl.startsWith('http://') || widget.videoUrl.startsWith('https://')) {
        print('[VideoPlayer] Using network URL (HTTP/HTTPS)');
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      } else if (widget.videoUrl.startsWith('ftp://')) {
        print('[VideoPlayer] Using FTP URL');
        // FTP URLs need special handling - try converting to HTTP equivalent
        // Some IP cameras serve files via both FTP and HTTP
        final ftpUri = Uri.parse(widget.videoUrl);
        
        // Extract components from FTP URL
        final host = ftpUri.host;
        final port = ftpUri.port;
        final path = ftpUri.path;
        
        print('[VideoPlayer] FTP Host: $host, Port: $port, Path: $path');
        
        // Try HTTP equivalent first (many IP cameras support this)
        final httpUrl = 'http://$host:8080$path';
        print('[VideoPlayer] Trying HTTP equivalent: $httpUrl');
        
        try {
          // Use VideoPlayerOptions for better codec support
          _controller = VideoPlayerController.networkUrl(
            Uri.parse(httpUrl),
            videoPlayerOptions: VideoPlayerOptions(
              mixWithOthers: true,
              allowBackgroundPlayback: false,
            ),
          );
        } catch (e) {
          print('[VideoPlayer] HTTP attempt failed, trying direct FTP: $e');
          // Fallback to original FTP URL with options
          _controller = VideoPlayerController.networkUrl(
            Uri.parse(widget.videoUrl),
            videoPlayerOptions: VideoPlayerOptions(
              mixWithOthers: true,
              allowBackgroundPlayback: false,
            ),
          );
        }
      } else {
        // For local files
        print('[VideoPlayer] Using local file');
        _controller = VideoPlayerController.file(File(widget.videoUrl));
      }
      
      // Add listener for controller state changes
      _controller.addListener(() {
        if (mounted) {
          setState(() {});
          if (_controller.value.hasError) {
            print('[VideoPlayer] Controller error: ${_controller.value.errorDescription}');
          }
        }
      });
      
      print('[VideoPlayer] Starting controller initialization...');
      
      // Initialize the controller
      await _controller.initialize();
      
      print('[VideoPlayer] Controller initialized successfully');
      print('[VideoPlayer] Video duration: ${_controller.value.duration}');
      print('[VideoPlayer] Video size: ${_controller.value.size}');
      print('[VideoPlayer] Aspect ratio: ${_controller.value.aspectRatio}');
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        
        // Auto play video
        print('[VideoPlayer] Starting playback...');
        _controller.play();
      }
    } catch (e) {
      print('[VideoPlayer] Initialization error: $e');
      print('[VideoPlayer] Error type: ${e.runtimeType}');
      
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error loading video: $e';
        });
      }
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppTheme.darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isInitialized) ...[
            // Play/Pause button
            IconButton(
              icon: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying ? _controller.pause() : _controller.play();
                });
              },
            ),
            // Volume button
            IconButton(
              icon: Icon(
                _controller.value.volume > 0 ? Icons.volume_up : Icons.volume_off,
              ),
              onPressed: () {
                setState(() {
                  _controller.setVolume(_controller.value.volume > 0 ? 0.0 : 1.0);
                });
              },
            ),
          ],
        ],
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: _buildVideoPlayer(),
      ),
    );
  }
  
  Widget _buildVideoPlayer() {
    if (_hasError) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          const Text(
            'Error Loading Video',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _hasError = false;
                _errorMessage = '';
                _isInitialized = false;
              });
              _initializeVideoPlayer();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      );
    }
    
    if (!_isInitialized) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryOrange),
          ),
          SizedBox(height: 16),
          Text(
            'Loading video...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      );
    }
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Video player with aspect ratio
        AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _controller.value.isPlaying ? _controller.pause() : _controller.play();
                  });
                },
                child: VideoPlayer(_controller),
              ),
              // Controls overlay
              _buildControlsOverlay(),
              // Progress indicator
              VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: AppTheme.primaryOrange,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white12,
                ),
              ),
            ],
          ),
        ),
        
        // Video information
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (_controller.value.duration != Duration.zero) ...[
                Text(
                  'Duration: ${_formatDuration(_controller.value.duration)}',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                'Position: ${_formatDuration(_controller.value.position)}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildControlsOverlay() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _controller.value.isPlaying ? _controller.pause() : _controller.play();
        });
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 50),
        reverseDuration: const Duration(milliseconds: 200),
        child: _controller.value.isPlaying
            ? const SizedBox.shrink()
            : Container(
                color: Colors.black26,
                child: const Center(
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 100.0,
                    semanticLabel: 'Play',
                  ),
                ),
              ),
      ),
    );
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }
}

class FtpItem {
  final String name;
  final bool isDirectory;
  final String path;
  
  FtpItem({
    required this.name,
    required this.isDirectory,
    required this.path,
  });
}