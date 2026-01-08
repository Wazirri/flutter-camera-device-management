import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http_auth/http_auth.dart';
import '../theme/app_theme.dart';

// Custom HTTP client that accepts self-signed certificates
http.Client _createInsecureClient() {
  final httpClient = HttpClient()
    ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  return IOClient(httpClient);
}

// Snapshot cache manager for efficient memory usage
class SnapshotCacheManager {
  static final SnapshotCacheManager _instance =
      SnapshotCacheManager._internal();
  factory SnapshotCacheManager() => _instance;
  SnapshotCacheManager._internal();

  // Cache with max size limit
  final Map<String, Uint8List> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const int maxCacheSize = 100; // Keep max 100 snapshots in memory
  static const Duration cacheExpiry = Duration(minutes: 5);

  Uint8List? get(String url) {
    final timestamp = _cacheTimestamps[url];
    if (timestamp != null &&
        DateTime.now().difference(timestamp) > cacheExpiry) {
      _cache.remove(url);
      _cacheTimestamps.remove(url);
      return null;
    }
    return _cache[url];
  }

  void set(String url, Uint8List data) {
    // Remove oldest entries if cache is full
    if (_cache.length >= maxCacheSize) {
      final oldestUrl = _cacheTimestamps.entries
          .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
          .key;
      _cache.remove(oldestUrl);
      _cacheTimestamps.remove(oldestUrl);
    }
    _cache[url] = data;
    _cacheTimestamps[url] = DateTime.now();
  }

  void clear() {
    _cache.clear();
    _cacheTimestamps.clear();
  }
  
  void remove(String url) {
    _cache.remove(url);
    _cacheTimestamps.remove(url);
  }
}

// Async snapshot loader widget with authentication support
class CameraSnapshotWidget extends StatefulWidget {
  final String snapshotUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final String cameraId;
  final bool showRefreshButton;
  final String? username;
  final String? password;

  const CameraSnapshotWidget({
    Key? key,
    required this.snapshotUrl,
    required this.cameraId,
    this.width = double.infinity,
    this.height = 120,
    this.fit = BoxFit.cover,
    this.showRefreshButton = true,
    this.username,
    this.password,
  }) : super(key: key);

  @override
  State<CameraSnapshotWidget> createState() => _CameraSnapshotWidgetState();
}

class _CameraSnapshotWidgetState extends State<CameraSnapshotWidget> {
  Uint8List? _imageData;
  bool _isLoading = true;
  bool _hasError = false;
  static final _cacheManager = SnapshotCacheManager();

  // Throttle concurrent requests
  static int _activeRequests = 0;
  static const int _maxConcurrentRequests = 10;
  static final List<VoidCallback> _pendingRequests = [];

  @override
  void initState() {
    super.initState();
    _loadSnapshot();
  }

  @override
  void didUpdateWidget(CameraSnapshotWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshotUrl != widget.snapshotUrl) {
      _loadSnapshot();
    }
  }

  Future<void> _loadSnapshot() async {
    if (widget.snapshotUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      return;
    }

    // Check cache first
    final cached = _cacheManager.get(widget.snapshotUrl);
    if (cached != null) {
      if (mounted) {
        setState(() {
          _imageData = cached;
          _isLoading = false;
          _hasError = false;
        });
      }
      return;
    }

    // Throttle requests
    if (_activeRequests >= _maxConcurrentRequests) {
      _pendingRequests.add(_loadSnapshot);
      return;
    }

    _activeRequests++;

    try {
      http.Response response;
      final uri = Uri.parse(widget.snapshotUrl);
      final isHttps = uri.scheme == 'https';
      
      if (widget.username != null && widget.username!.isNotEmpty) {
        // Use Digest Auth (most cameras use this)
        if (isHttps) {
          // For HTTPS with self-signed certificates, use custom client
          final insecureClient = _createInsecureClient();
          final digestAuth = DigestAuthClient(
            widget.username!, 
            widget.password ?? '',
            inner: insecureClient,
          );
          debugPrint('Snapshot for ${widget.cameraId}: Using Digest Auth (HTTPS insecure)');
          response = await digestAuth
              .get(uri)
              .timeout(const Duration(seconds: 15));
        } else {
          // HTTP - use default client
          final digestAuth = DigestAuthClient(widget.username!, widget.password ?? '');
          debugPrint('Snapshot for ${widget.cameraId}: Using Digest Auth (HTTP)');
          response = await digestAuth
              .get(uri)
              .timeout(const Duration(seconds: 15));
        }
      } else {
        // No auth needed
        if (isHttps) {
          final insecureClient = _createInsecureClient();
          response = await insecureClient
              .get(uri)
              .timeout(const Duration(seconds: 10));
        } else {
          response = await http
              .get(uri)
              .timeout(const Duration(seconds: 10));
        }
      }

      if (response.statusCode == 200 && mounted) {
        final data = response.bodyBytes;
        _cacheManager.set(widget.snapshotUrl, data);
        setState(() {
          _imageData = data;
          _isLoading = false;
          _hasError = false;
        });
      } else if (mounted) {
        debugPrint(
            'Snapshot load failed for ${widget.cameraId}: HTTP ${response.statusCode}');
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Snapshot load error for ${widget.cameraId}: $e');
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } finally {
      _activeRequests--;
      // Process pending requests
      if (_pendingRequests.isNotEmpty) {
        final next = _pendingRequests.removeAt(0);
        Future.microtask(next);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(8),
        ),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: SizedBox(
          width: widget.height < 60 ? 16 : 24,
          height: widget.height < 60 ? 16 : 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppTheme.primaryOrange.withOpacity(0.7),
            ),
          ),
        ),
      );
    }

    if (_hasError || _imageData == null) {
      return Center(
        child: Icon(
          Icons.videocam_off,
          size: widget.height < 60 ? 20 : 32,
          color: Colors.grey.shade600,
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(
          _imageData!,
          fit: widget.fit,
          gaplessPlayback: true,
        ),
        // Refresh button overlay (only if enabled)
        if (widget.showRefreshButton)
          Positioned(
            right: 4,
            top: 4,
            child: InkWell(
              onTap: () {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
                _cacheManager.remove(widget.snapshotUrl);
                _loadSnapshot();
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.refresh,
                  size: 16,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
