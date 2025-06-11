import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/camera_device.dart';
import '../models/camera_layout_config.dart';
import '../providers/multi_camera_view_provider.dart';
import '../providers/camera_devices_provider_optimized.dart';
import '../theme/app_theme.dart';

class MultiCameraViewScreen extends StatefulWidget {
  const MultiCameraViewScreen({Key? key}) : super(key: key);

  @override
  State<MultiCameraViewScreen> createState() => _MultiCameraViewScreenState();
}

class _MultiCameraViewScreenState extends State<MultiCameraViewScreen> {
  final PageController _pageController = PageController();
  int _lastKnownPage = 0;

  @override
  void initState() {
    super.initState();
    // Sayfa açıldığında mevcut kameraları provider'a aktar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cameraDevicesProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
      final multiCameraProvider = Provider.of<MultiCameraViewProvider>(context, listen: false);
      
      // Tüm cihazlardan tüm kameraları topla
      final allCameras = <Camera>[];
      for (final device in cameraDevicesProvider.devicesList) {
        allCameras.addAll(device.cameras);
      }
      
      multiCameraProvider.setAvailableCameras(allCameras);
    });
  }

  void _syncPageController(int newPageIndex) {
    if (_lastKnownPage != newPageIndex && _pageController.hasClients) {
      print('🎮 _syncPageController: $_lastKnownPage → $newPageIndex');
      _lastKnownPage = newPageIndex;
      
      // Auto rotation sırasında daha hızlı animasyon kullan
      final provider = Provider.of<MultiCameraViewProvider>(context, listen: false);
      final isAutoRotating = provider.isAutoPageRotationEnabled;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          print('🎮 PageController.animateToPage($newPageIndex) - isAutoRotating: $isAutoRotating');
          _pageController.animateToPage(
            newPageIndex,
            duration: isAutoRotating 
              ? const Duration(milliseconds: 100) // Auto rotation için daha hızlı
              : const Duration(milliseconds: 300), // Manuel geçiş için normal hız
            curve: isAutoRotating 
              ? Curves.easeInOut 
              : Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi Camera View'),
        backgroundColor: AppTheme.darkBackground,
        actions: [
          // Configuration management menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.save_alt),
            tooltip: 'Configuration',
            onSelected: (String action) {
              final provider = Provider.of<MultiCameraViewProvider>(context, listen: false);
              switch (action) {
                case 'save':
                  _saveConfiguration(context, provider);
                  break;
                case 'load':
                  _loadConfiguration(context, provider);
                  break;
                case 'manage':
                  _showConfigurationManager(context, provider);
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'save',
                child: Row(
                  children: [
                    Icon(Icons.save, size: 18),
                    SizedBox(width: 8),
                    Text('Save Configuration'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'load',
                child: Row(
                  children: [
                    Icon(Icons.folder_open, size: 18),
                    SizedBox(width: 8),
                    Text('Load Configuration'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'manage',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 18),
                    SizedBox(width: 8),
                    Text('Manage Configurations'),
                  ],
                ),
              ),
            ],
          ),
          // Layout seçme butonu
          IconButton(
            icon: const Icon(Icons.grid_view),
            tooltip: 'Change Layout',
            onPressed: () => _showLayoutSelector(context),
          ),
          // Kamera eşleştirme ayar sayfasına gitme butonu
          IconButton(
            icon: const Icon(Icons.settings_input_component),
            tooltip: 'Advanced Camera Assignment',
            onPressed: () {
              Navigator.pushNamed(context, '/camera-layout-assignment');
            },
          ),
          // Kamera atama modu değiştirme butonu
          Consumer<MultiCameraViewProvider>(
            builder: (context, provider, child) {
              return IconButton(
                icon: Icon(provider.isAutoAssignmentMode 
                  ? Icons.auto_fix_high 
                  : Icons.edit),
                tooltip: provider.isAutoAssignmentMode 
                  ? 'Auto Assignment Mode' 
                  : 'Manual Assignment Mode',
                onPressed: () {
                  provider.toggleAssignmentMode();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(provider.isAutoAssignmentMode 
                        ? 'Auto assignment mode activated' 
                        : 'Manual assignment mode activated'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              );
            },
          ),
          // Otomatik sayfa döngüsü butonu
          Consumer<MultiCameraViewProvider>(
            builder: (context, provider, child) {
              return PopupMenuButton<String>(
                icon: Icon(
                  provider.isAutoPageRotationEnabled 
                    ? Icons.play_circle_filled 
                    : Icons.play_circle_outline,
                  color: provider.isAutoPageRotationEnabled 
                    ? Colors.green 
                    : null,
                ),
                tooltip: 'Auto Page Rotation',
                onSelected: (String action) {
                  switch (action) {
                    case 'toggle':
                      provider.toggleAutoPageRotation();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(provider.isAutoPageRotationEnabled 
                            ? 'Auto page rotation started (${provider.autoPageRotationInterval}s)' 
                            : 'Auto page rotation stopped'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      break;
                    case 'settings':
                      _showAutoRotationSettings(context, provider);
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          provider.isAutoPageRotationEnabled 
                            ? Icons.pause 
                            : Icons.play_arrow,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(provider.isAutoPageRotationEnabled 
                          ? 'Stop Auto Rotation' 
                          : 'Start Auto Rotation'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.timer, size: 18),
                        SizedBox(width: 8),
                        Text('Rotation Settings'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<MultiCameraViewProvider>(
        builder: (context, provider, child) {
          // Provider'daki sayfa değişikliklerini PageController ile senkronize et
          _syncPageController(provider.activePageIndex);
          
          if (provider.layouts.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return Column(
            children: [
              // Kamera Görünümü (PageView)
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    // Auto rotation sırasında manuel sayfa değişikliklerini engelle
                    if (!provider.isAutoPageRotationEnabled) {
                      print('📖 Manual page change: $index');
                      provider.setActivePage(index);
                    } else {
                      print('📖 Page change ignored during auto rotation: $index');
                    }
                  },
                  itemCount: provider.pageLayouts.length,
                  itemBuilder: (context, index) {
                    // Bu sayfanın layout'unu al
                    int layoutCode = provider.pageLayouts[index];
                    CameraLayoutConfig? layout = provider.layouts.firstWhere(
                      (l) => l.layoutCode == layoutCode,
                      orElse: () => provider.layouts.first,
                    );
                    
                    // Bu sayfanın kamera atamalarını al
                    Map<int, int> assignments = provider.cameraAssignments(index);
                    
                    return CameraGridView(
                      layout: layout,
                      cameraAssignments: assignments,
                      availableCameras: provider.availableCameras,
                      onCameraAssign: !provider.isAutoAssignmentMode
                        ? (cameraPosition, cameraIndex) {
                            provider.assignCamera(cameraPosition, cameraIndex);
                          }
                        : null,
                    );
                  },
                ),
              ),
              
              // Sayfa Kontrolleri
              Container(
                color: AppTheme.darkSurface,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Sayfa Ekle Butonu
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'Add Page',
                      onPressed: () {
                        provider.addPage();
                        _pageController.animateToPage(
                          provider.activePageIndex,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                    
                    // Sayfa İndikatörleri
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              provider.pageLayouts.length,
                              (index) => GestureDetector(
                                onTap: () {
                                  _pageController.animateToPage(
                                    index,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: provider.activePageIndex == index
                                        ? AppTheme.primaryColor
                                        : Colors.grey,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Sayfa Silme Butonu (1'den fazla sayfa varsa)
                    IconButton(
                      icon: const Icon(Icons.remove),
                      tooltip: 'Remove Page',
                      onPressed: provider.pageLayouts.length > 1
                          ? () {
                              provider.removePage();
                            }
                          : null,
                    ),
                  ],
                ),
              ),
              
              // Gelişmiş Kamera Atama Butonu
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppTheme.darkBackground,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.settings_input_component),
                  label: const Text('Advanced Camera Assignment'),
                  onPressed: () {
                    Navigator.pushNamed(context, '/camera-layout-assignment');
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              
              // Aktif Sayfa Bilgisi
              Container(
                color: AppTheme.darkBackground,
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Page ${provider.activePageIndex + 1} / ${provider.pageLayouts.length}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Configuration management methods
  void _saveConfiguration(BuildContext context, MultiCameraViewProvider provider) {
    final TextEditingController nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.darkSurface,
          title: const Text('Save Configuration', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter a name for this configuration:',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Configuration name',
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primaryColor),
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white54),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primaryColor),
                  ),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  try {
                    await provider.saveConfiguration(name);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Configuration "$name" saved successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to save configuration: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _loadConfiguration(BuildContext context, MultiCameraViewProvider provider) async {
    try {
      final configurations = await provider.listConfigurations();
      
      if (configurations.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No saved configurations found'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        backgroundColor: AppTheme.darkSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: const Text(
                  'Load Configuration',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Divider(height: 1, color: Colors.white24),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: configurations.length,
                  itemBuilder: (context, index) {
                    final config = configurations[index];
                    return ListTile(
                      leading: const Icon(Icons.folder, color: Colors.white70),
                      title: Text(
                        config['name'] ?? 'Unknown',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        'Saved: ${config['timestamp']}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      onTap: () async {
                        final configName = config['name'];
                        if (configName == null) return;
                        
                        try {
                          await provider.loadConfiguration(configName);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Configuration "$configName" loaded successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to load configuration: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load configurations: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showConfigurationManager(BuildContext context, MultiCameraViewProvider provider) async {
    try {
      final configurations = await provider.listConfigurations();
      
      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                backgroundColor: AppTheme.darkSurface,
                title: const Text(
                  'Manage Configurations',
                  style: TextStyle(color: Colors.white),
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 400,
                  child: configurations.isEmpty
                      ? const Center(
                          child: Text(
                            'No saved configurations found',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.builder(
                          itemCount: configurations.length,
                          itemBuilder: (context, index) {
                            final config = configurations[index];
                            return Card(
                              color: AppTheme.darkBackground,
                              child: ListTile(
                                leading: const Icon(Icons.folder, color: Colors.white70),
                                title: Text(
                                  config['name'] ?? 'Unknown',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  'Saved: ${config['timestamp'] ?? 'Unknown'}',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.download, color: Colors.green),
                                      tooltip: 'Load',
                                      onPressed: () async {
                                        final configName = config['name'];
                                        if (configName == null) return;
                                        
                                        try {
                                          await provider.loadConfiguration(configName);
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Configuration "$configName" loaded'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Failed to load: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      tooltip: 'Delete',
                                      onPressed: () async {
                                        final configName = config['name'];
                                        if (configName == null) return;
                                        
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            backgroundColor: AppTheme.darkSurface,
                                            title: const Text(
                                              'Delete Configuration',
                                              style: TextStyle(color: Colors.white),
                                            ),
                                            content: Text(
                                              'Are you sure you want to delete "$configName"?',
                                              style: const TextStyle(color: Colors.white70),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, false),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(context, true),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                ),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        
                                        if (confirmed == true) {
                                          try {
                                            await provider.deleteConfiguration(configName);
                                            setState(() {
                                              configurations.removeAt(index);
                                            });
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Configuration "$configName" deleted'),
                                                backgroundColor: Colors.orange,
                                              ),
                                            );
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Failed to delete: $e'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load configurations: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showLayoutSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Consumer<MultiCameraViewProvider>(
          builder: (context, provider, child) {
            return ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              itemCount: provider.layouts.length,
              itemBuilder: (context, index) {
                final layout = provider.layouts[index];
                return ListTile(
                  title: Text('Layout ${layout.layoutCode}'),
                  subtitle: Text('Max ${layout.maxCameraNumber} cameras'),
                  leading: Icon(
                    Icons.grid_view,
                    color: provider.activeLayout?.layoutCode == layout.layoutCode
                        ? AppTheme.primaryColor
                        : Colors.grey,
                  ),
                  selected: provider.activeLayout?.layoutCode == layout.layoutCode,
                  selectedTileColor: AppTheme.primaryColor.withOpacity(0.1),
                  onTap: () {
                    provider.setActivePageLayout(layout.layoutCode);
                    Navigator.pop(context);
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class CameraGridView extends StatefulWidget {
  final CameraLayoutConfig layout;
  final Map<int, int> cameraAssignments;
  final List<Camera> availableCameras;
  final Function(int, int)? onCameraAssign;

  const CameraGridView({
    Key? key,
    required this.layout,
    required this.cameraAssignments,
    required this.availableCameras,
    this.onCameraAssign,
  }) : super(key: key);

  @override
  State<CameraGridView> createState() => _CameraGridViewState();
}

class _CameraGridViewState extends State<CameraGridView> {
  // Maps camera positions to Player instances
  final Map<int, Player> _players = {};
  final Map<int, VideoController> _controllers = {};
  final Map<int, bool> _loadingStates = {};
  final Map<int, bool> _errorStates = {};
  
  @override
  void initState() {
    super.initState();
    _initializePlayers();
  }
  
  @override
  void didUpdateWidget(CameraGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If camera assignments changed, update streams
    if (widget.cameraAssignments != oldWidget.cameraAssignments ||
        widget.availableCameras != oldWidget.availableCameras) {
      _updateStreams();
    }
  }
  
  void _initializePlayers() {
    // Create players for each camera location
    for (final location in widget.layout.cameraLoc) {
      // Initialize loading and error states
      _loadingStates[location.cameraCode] = false;
      _errorStates[location.cameraCode] = false;
      
      // Create a player for this location
      final player = Player();
      _players[location.cameraCode] = player;
      _controllers[location.cameraCode] = VideoController(player);
      
      // Set up event listeners
      player.stream.buffering.listen((buffering) {
        if (mounted) {
          setState(() {
            _loadingStates[location.cameraCode] = buffering;
          });
        }
      });
      
      player.stream.error.listen((error) {
        if (mounted) {
          setState(() {
            _errorStates[location.cameraCode] = true;
            _loadingStates[location.cameraCode] = false;
          });
          print('Player error at position ${location.cameraCode}: $error');
        }
      });
    }
    
    // Start streaming for all assigned cameras
    _updateStreams();
  }
  
  void _updateStreams() {
    // For each camera location
    for (final location in widget.layout.cameraLoc) {
      final cameraPosition = location.cameraCode;
      final cameraIndex = widget.cameraAssignments[cameraPosition] ?? 0;
      
      // Reset states
      setState(() {
        _errorStates[cameraPosition] = false;
      });
      
      // If there's a camera assigned
      if (cameraIndex > 0 && cameraIndex <= widget.availableCameras.length) {
        final camera = widget.availableCameras[cameraIndex - 1];
        _streamCamera(cameraPosition, camera);
      } else {
        // No camera assigned, stop any existing stream
        if (_players.containsKey(cameraPosition)) {
          _players[cameraPosition]!.stop();
        }
      }
    }
  }
  
  void _streamCamera(int positionCode, Camera camera) {
    if (!mounted || !_players.containsKey(positionCode)) return;
    
    setState(() {
      _errorStates[positionCode] = false;
      _loadingStates[positionCode] = true;
    });
    
    final player = _players[positionCode]!;
    
    // Check if camera has RTSP URL
    if (camera.rtspUri.isNotEmpty) {
      try {
        // Only open if player is not already playing this stream
        if (player.state.playlist.medias.isEmpty || 
            (player.state.playlist.medias.isNotEmpty && 
             player.state.playlist.medias.first.uri != camera.rtspUri)) {
          // Stop previous stream before loading new one
          player.stop();
          // Open new stream
          player.open(Media(camera.rtspUri));
        }
      } catch (e) {
        print('Error opening stream for camera ${camera.name} at position $positionCode: $e');
        if (mounted) {
          setState(() {
            _errorStates[positionCode] = true;
            _loadingStates[positionCode] = false;
          });
        }
      }
    } else {
      // No valid stream URL
      setState(() {
        _errorStates[positionCode] = true;
        _loadingStates[positionCode] = false;
      });
    }
  }
  
  @override
  void dispose() {
    // Dispose all players
    for (final player in _players.values) {
      player.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        
        return Stack(
          children: widget.layout.cameraLoc.map((location) {
            // Kamera konumu hesaplama (yüzde değerlerini piksel değerlerine dönüştür)
            final double left = location.x1 * width / 100;
            final double top = location.y1 * height / 100;
            final double right = location.x2 * width / 100;
            final double bottom = location.y2 * height / 100;
            
            // Bu konuma atanmış kamera indeksini al
            final int cameraIndex = widget.cameraAssignments[location.cameraCode] ?? 0;
            
            // Bu indekse karşılık gelen kamerayı bul
            Camera? camera;
            if (cameraIndex > 0 && cameraIndex <= widget.availableCameras.length) {
              camera = widget.availableCameras[cameraIndex - 1];
            }
            
            return Positioned(
              left: left,
              top: top,
              width: right - left,
              height: bottom - top,
              child: GestureDetector(
                onTap: widget.onCameraAssign != null
                    ? () => _showCameraSelector(context, location.cameraCode)
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: camera != null ? AppTheme.primaryColor : Colors.grey,
                      width: 1,
                    ),
                    color: Colors.black,
                  ),
                  child: camera != null
                      ? _buildCameraView(location.cameraCode, camera)
                      : const Center(
                          child: Text(
                            'No Camera',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
  
  Widget _buildCameraView(int positionCode, Camera camera) {
    // Check if we have a player for this position
    if (!_controllers.containsKey(positionCode)) {
      return CameraPreviewPlaceholder(camera: camera);
    }
    
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video player
        ClipRect(
          child: RepaintBoundary(
            child: Video(
              controller: _controllers[positionCode]!,
              fit: BoxFit.cover,
            ),
          ),
        ),
        
        // Loading indicator
        if (_loadingStates[positionCode] == true)
          const Center(
            child: CircularProgressIndicator(),
          ),
        
        // Error indicator
        if (_errorStates[positionCode] == true)
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 32),
                SizedBox(height: 8),
                Text(
                  'Stream Error',
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
          ),
        
        // Camera name overlay
        Positioned(
          top: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              camera.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ),
        
        // Camera status overlay
        Positioned(
          bottom: 4,
          right: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: camera.recording
                  ? Colors.red.withOpacity(0.7)
                  : Colors.green.withOpacity(0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              camera.recording ? 'REC' : 'LIVE',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showCameraSelector(BuildContext context, int cameraPosition) {
    if (widget.onCameraAssign == null) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: Text(
                'Select Camera for Position $cameraPosition',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: widget.availableCameras.length + 1, // +1 for "No Camera" option
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // "No Camera" option
                    return ListTile(
                      title: const Text('No Camera'),
                      leading: const Icon(Icons.videocam_off),
                      selected: widget.cameraAssignments[cameraPosition] == null ||
                          widget.cameraAssignments[cameraPosition] == 0,
                      onTap: () {
                        widget.onCameraAssign!(cameraPosition, 0);
                        Navigator.pop(context);
                      },
                    );
                  } else {
                    // Camera options
                    final camera = widget.availableCameras[index - 1];
                    return ListTile(
                      title: Text(camera.name),
                      subtitle: Text('${camera.brand} ${camera.hw}'),
                      leading: const Icon(Icons.videocam),
                      selected: widget.cameraAssignments[cameraPosition] == index,
                      onTap: () {
                        widget.onCameraAssign!(cameraPosition, index);
                        Navigator.pop(context);
                      },
                    );
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class CameraPreviewPlaceholder extends StatelessWidget {
  final Camera camera;

  const CameraPreviewPlaceholder({
    Key? key,
    required this.camera,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Placeholder for when no video stream is available
    return Stack(
      fit: StackFit.expand,
      children: [
        // Kamera görüntüsü (placeholder)
        Container(
          color: Colors.black54,
          child: Center(
            child: Icon(
              Icons.videocam,
              size: 48,
              color: camera.connected ? Colors.green : Colors.red,
            ),
          ),
        ),
        
        // Kamera bilgileri
        Positioned(
          left: 8,
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    camera.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (camera.recording)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.fiber_manual_record,
                          color: Colors.white,
                          size: 12,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'REC',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        // Kamera durum bilgisi
        Positioned(
          right: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: camera.connected ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              camera.connected ? 'Online' : 'Offline',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Auto rotation settings dialog
extension MultiCameraViewScreenExtensions on _MultiCameraViewScreenState {
  void _showAutoRotationSettings(BuildContext context, MultiCameraViewProvider provider) {
    int selectedInterval = provider.autoPageRotationInterval;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.timer, size: 24),
                  SizedBox(width: 8),
                  Text('Auto Page Rotation Settings'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select rotation interval:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  
                  // Süre seçici list tiles
                  ...[3, 5, 10, 15, 30, 60].map((seconds) => 
                    RadioListTile<int>(
                      title: Text('$seconds seconds'),
                      value: seconds,
                      groupValue: selectedInterval,
                      onChanged: (int? value) {
                        if (value != null) {
                          setState(() {
                            selectedInterval = value;
                          });
                        }
                      },
                      dense: true,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 20, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pages will automatically switch after the selected interval.',
                            style: TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    provider.setAutoPageRotationInterval(selectedInterval);
                    Navigator.of(context).pop();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Rotation interval set to $selectedInterval seconds'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
