import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../models/camera_device.dart';
import '../providers/camera_devices_provider_optimized.dart';
import '../providers/websocket_provider_optimized.dart';
import '../providers/user_group_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/camera_details_bottom_sheet.dart';
import 'live_view_screen.dart';

// Snapshot cache manager for efficient memory usage
class SnapshotCacheManager {
  static final SnapshotCacheManager _instance = SnapshotCacheManager._internal();
  factory SnapshotCacheManager() => _instance;
  SnapshotCacheManager._internal();

  // Cache with max size limit
  final Map<String, Uint8List> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const int maxCacheSize = 100; // Keep max 100 snapshots in memory
  static const Duration cacheExpiry = Duration(minutes: 5);

  Uint8List? get(String url) {
    final timestamp = _cacheTimestamps[url];
    if (timestamp != null && DateTime.now().difference(timestamp) > cacheExpiry) {
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
}

// Async snapshot loader widget
class CameraSnapshotWidget extends StatefulWidget {
  final String snapshotUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final String cameraId;
  final bool showRefreshButton;

  const CameraSnapshotWidget({
    Key? key,
    required this.snapshotUrl,
    required this.cameraId,
    this.width = double.infinity,
    this.height = 120,
    this.fit = BoxFit.cover,
    this.showRefreshButton = true,
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
      final response = await http.get(
        Uri.parse(widget.snapshotUrl),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && mounted) {
        final data = response.bodyBytes;
        _cacheManager.set(widget.snapshotUrl, data);
        setState(() {
          _imageData = data;
          _isLoading = false;
          _hasError = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      if (mounted) {
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
                _cacheManager._cache.remove(widget.snapshotUrl);
                _cacheManager._cacheTimestamps.remove(widget.snapshotUrl);
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

class AllCamerasScreen extends StatefulWidget {
  const AllCamerasScreen({Key? key}) : super(key: key);

  @override
  State<AllCamerasScreen> createState() => _AllCamerasScreenState();
}

class _AllCamerasScreenState extends State<AllCamerasScreen> {
  String _searchQuery = '';
  String _sortBy = 'name'; // name, ip, status, resolution
  bool _sortAscending = true;
  String? _filterBrand;
  String? _filterStatus; // 'online', 'offline', 'recording'
  String? _filterResolution; // '4k', '2k', 'fhd', 'hd', 'sd'
  String? _filterCodec; // 'h264', 'h265', etc.
  String? _filterSubnet; // e.g., '192.168.1', '10.0.0'

  // Pagination
  int _currentPage = 0;
  int _itemsPerPage = 10;
  final List<int> _itemsPerPageOptions = [5, 10, 20, 50, 100];

  // Search controller
  final TextEditingController _searchController = TextEditingController();
  
  String _getSubnetFromIp(String ip) {
    if (ip.isEmpty) return '';
    final parts = ip.split('.');
    if (parts.length >= 3) {
      return '${parts[0]}.${parts[1]}.${parts[2]}';
    }
    return '';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('All Cameras'),
        backgroundColor: AppTheme.darkSurface,
        actions: [
          // Sort
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                if (_sortBy == value) {
                  _sortAscending = !_sortAscending;
                } else {
                  _sortBy = value;
                  _sortAscending = true;
                }
              });
            },
            itemBuilder: (context) => [
              _buildSortMenuItem('name', 'Name'),
              _buildSortMenuItem('ip', 'IP Address'),
              _buildSortMenuItem('status', 'Status'),
              _buildSortMenuItem('resolution', 'Resolution'),
              _buildSortMenuItem('brand', 'Brand'),
            ],
          ),
          // Filter - now opens a modal bottom sheet with all filter options
          IconButton(
            icon: Icon(
              Icons.filter_list,
              color: _hasActiveFilters() ? AppTheme.primaryOrange : null,
            ),
            onPressed: () => _showFilterBottomSheet(context),
          ),
        ],
      ),
      body: Consumer3<CameraDevicesProviderOptimized,
          WebSocketProviderOptimized, UserGroupProvider>(
        builder: (context, provider, wsProvider, userGroupProvider, child) {
          // Get authorized cameras
          final currentUsername = wsProvider.currentLoggedInUsername;
          Set<String>? authorizedMacs;

          if (currentUsername != null) {
            final userType = userGroupProvider.getUserType(currentUsername);
            if (userType != 'admin') {
              authorizedMacs = userGroupProvider
                  .getUserAuthorizedCameraMacs(currentUsername);
            }
          }

          List<Camera> cameras = provider.getAuthorizedCameras(authorizedMacs);
          final allCameras = List<Camera>.from(cameras);

          // Apply search filter
          if (_searchQuery.isNotEmpty) {
            final query = _searchQuery.toLowerCase();
            cameras = cameras.where((cam) {
              return cam.name.toLowerCase().contains(query) ||
                  cam.ip.toLowerCase().contains(query) ||
                  cam.mac.toLowerCase().contains(query) ||
                  cam.brand.toLowerCase().contains(query) ||
                  cam.manufacturer.toLowerCase().contains(query);
            }).toList();
          }

          // Apply status filter
          if (_filterStatus != null) {
            cameras = cameras.where((cam) {
              switch (_filterStatus) {
                case 'online':
                  return cam.connected;
                case 'offline':
                  return !cam.connected;
                case 'recording':
                  return cam.recording;
                case 'assigned':
                  return cam.currentDevices.isNotEmpty ||
                      (cam.parentDeviceMacKey != null &&
                          cam.parentDeviceMacKey!.isNotEmpty);
                case 'unassigned':
                  return cam.currentDevices.isEmpty &&
                      (cam.parentDeviceMacKey == null ||
                          cam.parentDeviceMacKey!.isEmpty);
                case 'sharing':
                  return cam.sharingActive;
                default:
                  return true;
              }
            }).toList();
          }

          // Apply brand filter
          if (_filterBrand != null) {
            cameras =
                cameras.where((cam) => cam.brand == _filterBrand).toList();
          }

          // Apply resolution filter
          if (_filterResolution != null) {
            cameras = cameras.where((cam) {
              final resLabel =
                  _getResolutionLabel(cam.recordWidth, cam.recordHeight)
                      .toLowerCase();
              return resLabel == _filterResolution;
            }).toList();
          }

          // Apply codec filter
          if (_filterCodec != null) {
            cameras = cameras
                .where((cam) =>
                    cam.recordCodec.toLowerCase() ==
                    _filterCodec!.toLowerCase())
                .toList();
          }

          // Apply subnet filter
          if (_filterSubnet != null) {
            cameras = cameras.where((cam) {
              final subnet = _getSubnetFromIp(cam.ip);
              return subnet == _filterSubnet;
            }).toList();
          }
          // Sort cameras
          cameras = _sortCameras(cameras);

          // Calculate pagination
          final totalPages = (cameras.length / _itemsPerPage).ceil();
          if (_currentPage >= totalPages && totalPages > 0) {
            _currentPage = totalPages - 1;
          }
          final startIndex = _currentPage * _itemsPerPage;
          final endIndex =
              (startIndex + _itemsPerPage).clamp(0, cameras.length);
          final paginatedCameras = cameras.sublist(startIndex, endIndex);

          if (cameras.isEmpty && !_hasActiveFilters()) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              // Search bar
              _buildSearchBar(),

              // Stats bar
              _buildStatsBar(allCameras, cameras),

              // Camera list
              if (cameras.isEmpty && _hasActiveFilters())
                Expanded(child: _buildNoResultsState())
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: paginatedCameras.length,
                    itemBuilder: (context, index) {
                      return _buildCameraCard(paginatedCameras[index]);
                    },
                  ),
                ),

              // Pagination bar
              if (cameras.isNotEmpty)
                _buildPaginationBar(cameras.length, totalPages),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: AppTheme.darkSurface,
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search by name, IP, MAC, brand...',
          hintStyle: TextStyle(color: Colors.grey.shade500),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                      _currentPage = 0;
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: AppTheme.darkBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _currentPage = 0; // Reset to first page on search
          });
        },
      ),
    );
  }

  Widget _buildPaginationBar(int totalItems, int totalPages) {
    final startItem = _currentPage * _itemsPerPage + 1;
    final endItem = ((_currentPage + 1) * _itemsPerPage).clamp(1, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(
          top: BorderSide(color: Colors.grey.shade800, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Items per page selector
          Row(
            children: [
              Text(
                'Show: ',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade700),
                ),
                child: DropdownButton<int>(
                  value: _itemsPerPage,
                  dropdownColor: AppTheme.darkSurface,
                  underline: const SizedBox(),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: _itemsPerPageOptions.map((count) {
                    return DropdownMenuItem(
                      value: count,
                      child: Text('$count'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _itemsPerPage = value;
                        _currentPage = 0; // Reset to first page
                      });
                    }
                  },
                ),
              ),
            ],
          ),

          const Spacer(),

          // Page info
          Text(
            '$startItem-$endItem of $totalItems',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),

          const SizedBox(width: 16),

          // Page navigation
          Row(
            children: [
              // First page
              IconButton(
                icon: Icon(
                  Icons.first_page,
                  color: _currentPage > 0 ? Colors.white : Colors.grey.shade600,
                ),
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage = 0)
                    : null,
                tooltip: 'First page',
                visualDensity: VisualDensity.compact,
              ),
              // Previous page
              IconButton(
                icon: Icon(
                  Icons.chevron_left,
                  color: _currentPage > 0 ? Colors.white : Colors.grey.shade600,
                ),
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage--)
                    : null,
                tooltip: 'Previous page',
                visualDensity: VisualDensity.compact,
              ),
              // Page indicator
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_currentPage + 1} / $totalPages',
                  style: const TextStyle(
                    color: AppTheme.primaryOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              // Next page
              IconButton(
                icon: Icon(
                  Icons.chevron_right,
                  color: _currentPage < totalPages - 1
                      ? Colors.white
                      : Colors.grey.shade600,
                ),
                onPressed: _currentPage < totalPages - 1
                    ? () => setState(() => _currentPage++)
                    : null,
                tooltip: 'Next page',
                visualDensity: VisualDensity.compact,
              ),
              // Last page
              IconButton(
                icon: Icon(
                  Icons.last_page,
                  color: _currentPage < totalPages - 1
                      ? Colors.white
                      : Colors.grey.shade600,
                ),
                onPressed: _currentPage < totalPages - 1
                    ? () => setState(() => _currentPage = totalPages - 1)
                    : null,
                tooltip: 'Last page',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildSortMenuItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (_sortBy == value)
            Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: AppTheme.primaryOrange,
            )
          else
            const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  List<Camera> _sortCameras(List<Camera> cameras) {
    // Create a copy to avoid modifying the original list
    final sortedCameras = List<Camera>.from(cameras);

    sortedCameras.sort((a, b) {
      int result;
      switch (_sortBy) {
        case 'name':
          result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case 'ip':
          // Sort IP addresses numerically
          result = _compareIpAddresses(a.ip, b.ip);
          break;
        case 'status':
          // Online cameras first when ascending
          result = (b.connected ? 1 : 0).compareTo(a.connected ? 1 : 0);
          break;
        case 'resolution':
          result = (a.recordWidth * a.recordHeight)
              .compareTo(b.recordWidth * b.recordHeight);
          break;
        case 'brand':
          result = a.brand.toLowerCase().compareTo(b.brand.toLowerCase());
          break;
        default:
          result = 0;
      }
      return _sortAscending ? result : -result;
    });
    return sortedCameras;
  }

  int _compareIpAddresses(String ip1, String ip2) {
    try {
      final parts1 = ip1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final parts2 = ip2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < 4; i++) {
        final p1 = i < parts1.length ? parts1[i] : 0;
        final p2 = i < parts2.length ? parts2[i] : 0;
        if (p1 != p2) return p1.compareTo(p2);
      }
      return 0;
    } catch (e) {
      return ip1.compareTo(ip2);
    }
  }

  Widget _buildStatsBar(List<Camera> allCameras, List<Camera> filteredCameras) {
    final online = allCameras.where((c) => c.connected).length;
    final offline = allCameras.where((c) => !c.connected).length;
    final recording = allCameras.where((c) => c.recording).length;
    // A camera is assigned only if it has currentDevices with non-empty deviceMac
    final assigned = allCameras
        .where((c) =>
            c.currentDevices.isNotEmpty && c.currentDevices.keys.any((k) => k.isNotEmpty))
        .length;
    final unassigned = allCameras.length - assigned;
    final sharing = allCameras.where((c) => c.sharingActive).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade800, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter chips row - use Row with Expanded to prevent shifting
          Row(
            children: [
              // Total count (click to clear status filter)
              Expanded(
                child: _buildClickableStatChip(
                  icon: Icons.videocam,
                  label: '${allCameras.length}',
                  subtitle: 'Total',
                  color: Colors.blue,
                  isSelected: _filterStatus == null,
                  onTap: () {
                    setState(() {
                      _filterStatus = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildClickableStatChip(
                  icon: Icons.check_circle,
                  label: '$online',
                  subtitle: 'Online',
                  color: Colors.green,
                  isSelected: _filterStatus == 'online',
                  onTap: () {
                    setState(() {
                      _filterStatus =
                          _filterStatus == 'online' ? null : 'online';
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildClickableStatChip(
                  icon: Icons.cancel,
                  label: '$offline',
                  subtitle: 'Offline',
                  color: Colors.red,
                  isSelected: _filterStatus == 'offline',
                  onTap: () {
                    setState(() {
                      _filterStatus =
                          _filterStatus == 'offline' ? null : 'offline';
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildClickableStatChip(
                  icon: Icons.fiber_manual_record,
                  label: '$recording',
                  subtitle: 'Recording',
                  color: Colors.orange,
                  isSelected: _filterStatus == 'recording',
                  onTap: () {
                    setState(() {
                      _filterStatus =
                          _filterStatus == 'recording' ? null : 'recording';
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Second row - Assigned/Unassigned
          Row(
            children: [
              Expanded(
                child: _buildClickableStatChip(
                  icon: Icons.link,
                  label: '$assigned',
                  subtitle: 'Assigned',
                  color: Colors.cyan,
                  isSelected: _filterStatus == 'assigned',
                  onTap: () {
                    setState(() {
                      _filterStatus =
                          _filterStatus == 'assigned' ? null : 'assigned';
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildClickableStatChip(
                  icon: Icons.link_off,
                  label: '$unassigned',
                  subtitle: 'Unassigned',
                  color: Colors.grey,
                  isSelected: _filterStatus == 'unassigned',
                  onTap: () {
                    setState(() {
                      _filterStatus =
                          _filterStatus == 'unassigned' ? null : 'unassigned';
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildClickableStatChip(
                  icon: Icons.share,
                  label: '$sharing',
                  subtitle: 'Sharing',
                  color: Colors.purple,
                  isSelected: _filterStatus == 'sharing',
                  onTap: () {
                    setState(() {
                      _filterStatus =
                          _filterStatus == 'sharing' ? null : 'sharing';
                    });
                  },
                ),
              ),
              // Empty space to keep alignment
              const SizedBox(width: 8),
              const Expanded(child: SizedBox()),
            ],
          ),
          // Subnet filter row
          _buildSubnetBar(allCameras),
          // Active filters indicator
          if (_hasActiveFilters()) ...[
            const SizedBox(height: 12),
            _buildActiveFiltersRow(filteredCameras.length, allCameras.length),
          ],
        ],
      ),
    );
  }

  Widget _buildSubnetBar(List<Camera> allCameras) {
    // Extract unique subnets with counts
    final subnetCounts = <String, int>{};
    for (final camera in allCameras) {
      final subnet = _getSubnetFromIp(camera.ip);
      if (subnet.isNotEmpty) {
        subnetCounts[subnet] = (subnetCounts[subnet] ?? 0) + 1;
      }
    }

    if (subnetCounts.isEmpty) return const SizedBox.shrink();

    // Sort by count descending
    final sortedSubnets = subnetCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.lan, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 6),
            Text(
              'Subnets',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sortedSubnets.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final entry = sortedSubnets[index];
              final isSelected = _filterSubnet == entry.key;
              return InkWell(
                onTap: () {
                  setState(() {
                    _filterSubnet = isSelected ? null : entry.key;
                    _currentPage = 0;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryOrange.withOpacity(0.2)
                        : Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryOrange
                          : Colors.grey.shade700,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${entry.key}.x',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? AppTheme.primaryOrange
                              : Colors.grey.shade300,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryOrange.withOpacity(0.3)
                              : Colors.grey.shade700,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${entry.value}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? AppTheme.primaryOrange
                                : Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  bool _hasActiveFilters() {
    return _searchQuery.isNotEmpty ||
        _filterBrand != null ||
        _filterStatus != null ||
        _filterResolution != null ||
        _filterCodec != null ||
        _filterSubnet != null;
  }

  Widget _buildActiveFiltersRow(int filtered, int total) {
    return Row(
      children: [
        Icon(Icons.filter_list, size: 14, color: AppTheme.primaryOrange),
        const SizedBox(width: 6),
        Text(
          'Showing $filtered of $total cameras',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade400,
          ),
        ),
        const Spacer(),
        // Active filter chips
        Wrap(
          spacing: 6,
          children: [
            if (_filterStatus != null)
              _buildFilterChip(_filterStatus!, () {
                setState(() => _filterStatus = null);
              }),
            if (_filterBrand != null)
              _buildFilterChip(_filterBrand!, () {
                setState(() => _filterBrand = null);
              }),
            if (_filterResolution != null)
              _buildFilterChip(_filterResolution!, () {
                setState(() => _filterResolution = null);
              }),
            if (_filterCodec != null)
              _buildFilterChip(_filterCodec!, () {
                setState(() => _filterCodec = null);
              }),
            if (_filterSubnet != null)
              _buildFilterChip('${_filterSubnet!}.x', () {
                setState(() => _filterSubnet = null);
              }),
            if (_searchQuery.isNotEmpty)
              _buildFilterChip('"$_searchQuery"', () {
                setState(() => _searchQuery = '');
              }),
          ],
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          icon: const Icon(Icons.clear_all, size: 16),
          label: const Text('Clear All'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red.shade300,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          onPressed: () {
            setState(() {
              _searchQuery = '';
              _searchController.clear();
              _filterBrand = null;
              _filterStatus = null;
              _filterResolution = null;
              _filterCodec = null;
              _filterSubnet = null;
              _currentPage = 0;
            });
          },
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryOrange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.primaryOrange,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close,
                size: 12, color: AppTheme.primaryOrange),
          ),
        ],
      ),
    );
  }

  Widget _buildClickableStatChip({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.3) : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraCard(Camera camera) {
    final isOnline = camera.connected;
    final isRecording = camera.recording;
    final resolution = camera.recordWidth > 0 && camera.recordHeight > 0
        ? '${camera.recordWidth}x${camera.recordHeight}'
        : 'Unknown';
    final resolutionLabel =
        _getResolutionLabel(camera.recordWidth, camera.recordHeight);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOnline
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showCameraDetails(camera),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Snapshot thumbnail, Name and status
              Row(
                children: [
                  // Snapshot thumbnail (like cameras_screen) - tappable to show full size
                  GestureDetector(
                    onTap: (camera.mainSnapShot.isNotEmpty || camera.subSnapShot.isNotEmpty)
                        ? () => _showFullSnapshot(
                            context,
                            camera.subSnapShot.isNotEmpty 
                                ? camera.subSnapShot 
                                : camera.mainSnapShot,
                            camera.name,
                          )
                        : null,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isOnline
                              ? Colors.green.withOpacity(0.5)
                              : Colors.red.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: (camera.mainSnapShot.isNotEmpty || camera.subSnapShot.isNotEmpty)
                            ? CameraSnapshotWidget(
                                snapshotUrl: camera.subSnapShot.isNotEmpty 
                                    ? camera.subSnapShot 
                                    : camera.mainSnapShot,
                                cameraId: camera.mac,
                                height: 48,
                                showRefreshButton: false,
                              )
                            : Icon(
                                isOnline ? Icons.videocam : Icons.videocam_off,
                                color: isOnline ? Colors.green : Colors.grey,
                                size: 24,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Name and IP
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          camera.name.isNotEmpty
                              ? camera.name
                              : 'Unknown Camera',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          camera.ip.isNotEmpty ? camera.ip : camera.mac,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Status badges column
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Online/Offline badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isOnline ? 'Online' : 'Offline',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // Recording badge (if recording)
                      if (isRecording) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fiber_manual_record,
                                  color: Colors.white, size: 10),
                              SizedBox(width: 4),
                              Text(
                                'Recording',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Sharing badge (if sharing active)
                      if (camera.sharingActive) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.purple,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.share, color: Colors.white, size: 10),
                              SizedBox(width: 4),
                              Text(
                                'Sharing',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              // Device info (if camera is assigned to device(s))
              if (camera.currentDevices.isNotEmpty ||
                  camera.parentDeviceMacKey != null) ...[
                const SizedBox(height: 12),
                _buildDeviceInfoSection(camera),
              ],

              const SizedBox(height: 16),

              // Details grid
              Row(
                children: [
                  // Resolution
                  Expanded(
                    child: _buildDetailItem(
                      icon: Icons.aspect_ratio,
                      label: 'Resolution',
                      value: resolution,
                      badge: resolutionLabel,
                      badgeColor: _getResolutionColor(resolutionLabel),
                    ),
                  ),

                  // Codec
                  Expanded(
                    child: _buildDetailItem(
                      icon: Icons.video_settings,
                      label: 'Codec',
                      value: camera.recordCodec.isNotEmpty
                          ? camera.recordCodec
                          : '-',
                    ),
                  ),

                  // Brand
                  Expanded(
                    child: _buildDetailItem(
                      icon: Icons.business,
                      label: 'Brand',
                      value: camera.brand.isNotEmpty
                          ? camera.brand
                          : camera.manufacturer,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Additional info row
              Row(
                children: [
                  // MAC
                  Expanded(
                    flex: 2,
                    child: _buildDetailItem(
                      icon: Icons.router,
                      label: 'MAC',
                      value: camera.mac.isNotEmpty
                          ? camera.mac.toUpperCase()
                          : '-',
                    ),
                  ),

                  // Last Seen
                  Expanded(
                    child: _buildDetailItem(
                      icon: Icons.access_time,
                      label: 'Last Seen',
                      value: camera.lastSeenAt.isNotEmpty
                          ? _formatLastSeen(camera.lastSeenAt)
                          : '-',
                    ),
                  ),

                  // Port
                  Expanded(
                    child: _buildDetailItem(
                      icon: Icons.settings_ethernet,
                      label: 'Port',
                      value: camera.macPort?.toString() ?? '80',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.play_circle_outline, size: 18),
                      label: const Text('Live View'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                      ),
                      onPressed: isOnline ? () => _openLiveView(camera) : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text('Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryOrange,
                        side: const BorderSide(color: AppTheme.primaryOrange),
                      ),
                      onPressed: () => _showCameraDetails(camera),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceInfoSection(Camera camera) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Devices (can be multiple)
          if (camera.currentDevices.isNotEmpty) ...[
            // Device header
            Row(
              children: [
                const Icon(Icons.devices, size: 14, color: Colors.blue),
                const SizedBox(width: 6),
                Text(
                  camera.currentDevices.length > 1
                      ? 'Assigned Devices (${camera.currentDevices.length})'
                      : 'Assigned Device',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Device details for each assigned device
            ...camera.currentDevices.entries.map((entry) {
              final deviceMac = entry.key;
              final deviceInfo = entry.value;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: camera.currentDevices.entries.last.key != deviceMac ? 8.0 : 0,
                ),
                child: Row(
                  children: [
                    // Device MAC
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Device MAC',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            deviceMac.isNotEmpty
                                ? deviceMac.toUpperCase()
                                : '-',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Device IP
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Device IP',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            deviceInfo.deviceIp.isNotEmpty
                                ? deviceInfo.deviceIp
                                : '-',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Assigned date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assigned',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            deviceInfo.startDate > 0
                                ? _formatTimestamp(deviceInfo.startDate)
                                : '-',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ] else if (camera.parentDeviceMacKey != null &&
              camera.parentDeviceMacKey!.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.devices, size: 14, color: Colors.blue),
                const SizedBox(width: 6),
                const Text(
                  'Device MAC:',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  camera.parentDeviceMacKey!.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],

          // Device History
          if (camera.deviceHistory.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.history, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  'History: ${camera.deviceHistory.length} device(s)',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showDeviceHistory(camera),
                  child: Text(
                    'View History',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade300,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showDeviceHistory(Camera camera) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: AppTheme.primaryOrange),
                const SizedBox(width: 8),
                Text(
                  'Device History - ${camera.name}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (camera.deviceHistory.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No device history',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: camera.deviceHistory.length,
                  itemBuilder: (context, index) {
                    final history = camera.deviceHistory[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.darkBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.devices,
                                  size: 16, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  history.name.isNotEmpty
                                      ? history.name
                                      : history.deviceMac,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildHistoryDetail(
                                    'Device MAC', history.deviceMac),
                              ),
                              Expanded(
                                child: _buildHistoryDetail(
                                    'Device IP', history.deviceIp),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: _buildHistoryDetail(
                                    'Camera IP', history.cameraIp),
                              ),
                              Expanded(
                                child: _buildHistoryDetail('Start Date',
                                    _formatTimestamp(history.startDate)),
                              ),
                            ],
                          ),
                          if (history.endDate > 0) ...[
                            const SizedBox(height: 4),
                            _buildHistoryDetail(
                                'End Date', _formatTimestamp(history.endDate)),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade500,
          ),
        ),
        Text(
          value.isNotEmpty ? value : '-',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  String _formatTimestamp(int timestamp) {
    if (timestamp <= 0) return '-';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    String? badge,
    Color? badgeColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Flexible(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (badgeColor ?? Colors.blue).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeColor ?? Colors.blue,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _getResolutionLabel(int width, int height) {
    if (width >= 3840) return '4K';
    if (width >= 2560) return '2K';
    if (width >= 1920) return 'FHD';
    if (width >= 1280) return 'HD';
    if (width >= 640) return 'SD';
    return '';
  }

  Color _getResolutionColor(String label) {
    switch (label) {
      case '4K':
        return Colors.purple;
      case '2K':
        return Colors.blue;
      case 'FHD':
        return Colors.green;
      case 'HD':
        return Colors.orange;
      case 'SD':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _formatLastSeen(String lastSeen) {
    if (lastSeen.isEmpty) return '-';
    try {
      // Format: "2026-01-04 - 23:07:06"
      final parts = lastSeen.split(' - ');
      if (parts.length >= 2) {
        return parts[1]; // Return just the time
      }
      return lastSeen;
    } catch (e) {
      return lastSeen;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.videocam_off_outlined,
            size: 80,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 16),
          const Text(
            'No cameras found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cameras will appear here when detected',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 16),
          const Text(
            'No cameras match filters',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or search query',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.clear_all),
            label: const Text('Clear All Filters'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
            ),
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _filterBrand = null;
                _filterStatus = null;
                _filterResolution = null;
                _filterCodec = null;
              });
            },
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    // Get camera data for filter options
    final provider = context.read<CameraDevicesProviderOptimized>();
    final cameras = provider.cameras;

    // Get unique brands
    final brands = cameras
        .map((c) => c.brand)
        .where((b) => b.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    // Get unique codecs
    final codecs = cameras
        .map((c) => c.recordCodec)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    // Resolution counts
    final resolutions = <String, int>{};
    for (final cam in cameras) {
      final label = _getResolutionLabel(cam.recordWidth, cam.recordHeight);
      if (label.isNotEmpty) {
        resolutions[label] = (resolutions[label] ?? 0) + 1;
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.filter_list,
                        color: AppTheme.primaryOrange),
                    const SizedBox(width: 8),
                    const Text(
                      'Filter Cameras',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _filterBrand = null;
                          _filterStatus = null;
                          _filterResolution = null;
                          _filterCodec = null;
                        });
                        setModalState(() {});
                      },
                      child: const Text('Reset All'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.grey),

                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      // Status Filter
                      _buildFilterSection(
                        title: 'Status',
                        icon: Icons.power_settings_new,
                        children: [
                          _buildFilterOption(
                              'Online', 'online', _filterStatus, Colors.green,
                              (val) {
                            setState(() => _filterStatus = val);
                            setModalState(() {});
                          }),
                          _buildFilterOption(
                              'Offline', 'offline', _filterStatus, Colors.red,
                              (val) {
                            setState(() => _filterStatus = val);
                            setModalState(() {});
                          }),
                          _buildFilterOption('Recording', 'recording',
                              _filterStatus, Colors.orange, (val) {
                            setState(() => _filterStatus = val);
                            setModalState(() {});
                          }),
                          _buildFilterOption('Assigned', 'assigned',
                              _filterStatus, Colors.cyan, (val) {
                            setState(() => _filterStatus = val);
                            setModalState(() {});
                          }),
                          _buildFilterOption('Unassigned', 'unassigned',
                              _filterStatus, Colors.grey, (val) {
                            setState(() => _filterStatus = val);
                            setModalState(() {});
                          }),
                          _buildFilterOption('Sharing', 'sharing',
                              _filterStatus, Colors.purple, (val) {
                            setState(() => _filterStatus = val);
                            setModalState(() {});
                          }),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Resolution Filter
                      _buildFilterSection(
                        title: 'Resolution',
                        icon: Icons.high_quality,
                        children: [
                          _buildFilterOption('4K (${resolutions['4K'] ?? 0})',
                              '4k', _filterResolution, Colors.purple, (val) {
                            setState(() => _filterResolution = val);
                            setModalState(() {});
                          }),
                          _buildFilterOption('2K (${resolutions['2K'] ?? 0})',
                              '2k', _filterResolution, Colors.blue, (val) {
                            setState(() => _filterResolution = val);
                            setModalState(() {});
                          }),
                          _buildFilterOption('FHD (${resolutions['FHD'] ?? 0})',
                              'fhd', _filterResolution, Colors.green, (val) {
                            setState(() => _filterResolution = val);
                            setModalState(() {});
                          }),
                          _buildFilterOption('HD (${resolutions['HD'] ?? 0})',
                              'hd', _filterResolution, Colors.orange, (val) {
                            setState(() => _filterResolution = val);
                            setModalState(() {});
                          }),
                          _buildFilterOption('SD (${resolutions['SD'] ?? 0})',
                              'sd', _filterResolution, Colors.grey, (val) {
                            setState(() => _filterResolution = val);
                            setModalState(() {});
                          }),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Brand Filter
                      if (brands.isNotEmpty)
                        _buildFilterSection(
                          title: 'Brand',
                          icon: Icons.business,
                          children: brands
                              .map(
                                (brand) => _buildFilterOption(
                                    brand,
                                    brand,
                                    _filterBrand,
                                    AppTheme.primaryOrange, (val) {
                                  setState(() => _filterBrand = val);
                                  setModalState(() {});
                                }),
                              )
                              .toList(),
                        ),

                      const SizedBox(height: 16),

                      // Codec Filter
                      if (codecs.isNotEmpty)
                        _buildFilterSection(
                          title: 'Codec',
                          icon: Icons.video_settings,
                          children: codecs
                              .map(
                                (codec) => _buildFilterOption(
                                    codec.toUpperCase(),
                                    codec.toLowerCase(),
                                    _filterCodec,
                                    Colors.teal, (val) {
                                  setState(() => _filterCodec = val);
                                  setModalState(() {});
                                }),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Apply button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Apply Filters',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: children,
        ),
      ],
    );
  }

  Widget _buildFilterOption(
    String label,
    String value,
    String? currentValue,
    Color color,
    Function(String?) onTap,
  ) {
    final isSelected = currentValue == value;
    return GestureDetector(
      onTap: () => onTap(isSelected ? null : value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade600,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : Colors.grey.shade400,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _showFullSnapshot(BuildContext context, String snapshotUrl, String cameraName) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with camera name and close button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.darkSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.videocam, color: AppTheme.primaryOrange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cameraName.isNotEmpty ? cameraName : 'Camera Snapshot',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Snapshot image
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                child: CameraSnapshotWidget(
                  snapshotUrl: snapshotUrl,
                  cameraId: snapshotUrl,
                  height: MediaQuery.of(context).size.height * 0.5,
                  width: MediaQuery.of(context).size.width - 32,
                  showRefreshButton: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCameraDetails(Camera camera) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return CameraDetailsBottomSheet(
              camera: camera,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }

  void _openLiveView(Camera camera) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveViewScreen(camera: camera),
      ),
    );
  }
}
