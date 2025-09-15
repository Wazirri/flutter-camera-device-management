import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Added import for DateFormat

import '../models/camera_device.dart';
import '../providers/camera_devices_provider_optimized.dart';
import '../theme/app_theme.dart'; // Fixed import for AppTheme
// Removed app_localizations import to fix build error

class CameraDevicesScreen extends StatefulWidget {
  const CameraDevicesScreen({Key? key}) : super(key: key);

  @override
  State<CameraDevicesScreen> createState() => _CameraDevicesScreenState();
}

class _CameraDevicesScreenState extends State<CameraDevicesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera Devices'),
        backgroundColor: AppTheme.darkBackground,
      ),
      body: Consumer<CameraDevicesProviderOptimized>(
        builder: (context, provider, child) {
          final devices = provider.devicesList;
          
          if (devices.isEmpty) {
            return const Center(
              child: Text(
                'No camera devices found.\nMake sure you are connected to the server.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              final isSelected = provider.selectedDevice?.macKey == device.macKey;
              return DeviceCard(
                device: device,
                isSelected: isSelected,
                onTap: () {
                  provider.setSelectedDevice(device.macKey);
                  _showDeviceDetails(context, device);
                },
              );
            },
          );
        },
      ),
    );
  }
  
  void _showDeviceDetails(BuildContext context, CameraDevice device) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return DeviceDetailsSheet(
              device: device,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }
}

class DeviceCard extends StatelessWidget {
  final CameraDevice device;
  final VoidCallback onTap;
  final bool isSelected;

  const DeviceCard({
    Key? key,
    required this.device,
    required this.onTap,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('DeviceCard build START for ${device.macAddress}');

    // Access status via the getter, which now includes logging
    final currentStatus = device.status; 
    print('DeviceCard build: ${device.macAddress}, connected: ${device.connected}, online: ${device.online}, firstTime: ${device.firstTime}, status from getter: $currentStatus'); // MODIFIED
    
    final isMaster = device.isMaster == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isSelected ? 8 : (isMaster ? 6 : 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isMaster 
              ? Colors.amber
              : (isSelected 
                  ? AppTheme.primaryColor.withOpacity(0.8)
                  : (device.connected 
                      ? AppTheme.primaryColor
                      : Theme.of(context).dividerColor)),
          width: isMaster ? 3 : (isSelected ? 3 : (device.connected ? 2 : 1)),
        ),
      ),
      color: isMaster 
          ? Colors.amber.withOpacity(0.1)
          : (isSelected 
              ? AppTheme.primaryColor.withOpacity(0.1)
              : null),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (isSelected) ...[
                          Icon(
                            Icons.check_circle,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (isMaster) ...[
                          Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                device.deviceType.isEmpty 
                                    ? 'Device ${device.macAddress}' 
                                    : device.deviceType,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isMaster 
                                      ? Colors.amber 
                                      : (isSelected ? AppTheme.primaryColor : null),
                                ),
                              ),
                              if (isMaster)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'MASTER DEVICE',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: device.connected
                          ? AppTheme.primaryColor
                          : Colors.grey,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      // Use device.status to determine online/offline text
                      device.status == DeviceStatus.online ? 'Online' : 
                      (device.status == DeviceStatus.warning ? 'Warning' : 'Offline'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'MAC: ${device.macAddress}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'IP: ${device.ipv4}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Cameras: ${device.cameras.length}',
                style: const TextStyle(fontSize: 14),
              ),
              if (device.uptime.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Uptime: ${device.formattedUptime}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
              if (device.firmwareVersion.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Firmware: ${device.firmwareVersion}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
              // ADDED: Explicit display for device.online and device.connected
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Icon(
                    device.online ? Icons.power_settings_new : Icons.power_off,
                    color: device.online ? AppTheme.online : AppTheme.offline,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Powered: ${device.online ? "On" : "Off"}',
                    style: const TextStyle(fontSize: 14, color: AppTheme.darkTextSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 4), // Space between the two new rows
              Row(
                children: <Widget>[
                  Icon(
                    device.connected ? Icons.link : Icons.link_off,
                    color: device.connected ? AppTheme.online : AppTheme.offline,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Connection: ${device.connected ? "Active" : "Inactive"}',
                    style: const TextStyle(fontSize: 14, color: AppTheme.darkTextSecondary),
                  ),
                ],
              ),
              // END ADDED
              const SizedBox(height: 8),
              Text(
                'Last seen: ${device.lastSeenAt}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeviceDetailsSheet extends StatelessWidget {
  final CameraDevice device;
  final ScrollController scrollController;

  const DeviceDetailsSheet({
    Key? key,
    required this.device,
    required this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('DeviceDetailsSheet build START for ${device.macAddress}');
    
    final currentStatus = device.status; // Access status via the getter
    print('DeviceDetailsSheet build: ${device.macAddress}, connected: ${device.connected}, online: ${device.online}, firstTime: ${device.firstTime}, status from getter: $currentStatus'); // MODIFIED

    return DefaultTabController(
      length: 5, // Beş tab için: ECS Slaves, Sistem, App, Test, Kameralar
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.deviceType.isEmpty 
                            ? 'Device ${device.macAddress}' 
                            : device.deviceType,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'MAC: ${device.macAddress}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: device.connected
                        ? AppTheme.primaryColor
                        : Colors.grey,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    // Use device.status to determine online/offline text
                    device.status == DeviceStatus.online ? 'Online' : 
                    (device.status == DeviceStatus.warning ? 'Warning' : 'Offline'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Tab Bar
          TabBar(
            isScrollable: true,
            tabs: const [
              Tab(
                icon: Icon(Icons.devices),
                text: 'ECS Slaves',
              ),
              Tab(
                icon: Icon(Icons.computer),
                text: 'Sistem',
              ),
              Tab(
                icon: Icon(Icons.settings),
                text: 'App',
              ),
              Tab(
                icon: Icon(Icons.bug_report),
                text: 'Test',
              ),
              Tab(
                icon: Icon(Icons.videocam_outlined),
                text: 'Kameralar',
              ),
            ],
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.primaryColor,
          ),
          
          // Tab Bar View
          Expanded(
            child: TabBarView(
              children: [
                // ECS Slaves Tab
                _buildEcsSlavesTab(context),
                // Sistem Tab
                _buildSystemTab(context),
                // App Tab
                _buildAppTab(context),
                // Test Tab
                _buildTestTab(context),
                // Kameralar Tab
                _buildCamerasTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ECS Slaves Tab - Temel cihaz bilgileri
  Widget _buildEcsSlavesTab(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ECS Slaves Bilgileri',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // Temel cihaz bilgileri
          InfoRow(label: 'Cihaz Adı', value: device.deviceName ?? 'Bilinmiyor'),
          InfoRow(label: 'IPv4 Adresi', value: device.ipv4),
          if (device.ipv6 != null && device.ipv6!.isNotEmpty)
            InfoRow(label: 'IPv6 Adresi', value: device.ipv6!),
          InfoRow(label: 'MAC Adresi', value: device.macAddress),
          InfoRow(label: 'İlk Görülme', value: device.firstTime),
          InfoRow(label: 'Son Görülme', value: device.lastSeenAt),
          InfoRow(label: 'Şu Anki Zaman', value: device.currentTime ?? 'Bilinmiyor'),
          InfoRow(label: 'Firmware Versiyonu', value: device.firmwareVersion),
          if (device.smartwebVersion != null && device.smartwebVersion!.isNotEmpty)
            InfoRow(label: 'SmartWeb Versiyonu', value: device.smartwebVersion!),
          InfoRow(
            label: 'CPU Sıcaklığı', 
            value: device.cpuTemp > 0 ? '${device.cpuTemp.toStringAsFixed(1)}°C' : 'Mevcut değil'
          ),
          InfoRow(label: 'Master Durumu', value: device.isMaster == true ? 'Master' : 'Slave'),
          InfoRow(label: 'Son Timestamp', value: device.lastTs ?? 'Bilinmiyor'),
          InfoRow(label: 'Kayıt Yolu', value: device.recordPath),
          InfoRow(label: 'Kamera Sayısı', value: '${device.camCount}'),
          
          // Ready States
          const SizedBox(height: 16),
          const Text(
            'Hazırlık Durumları',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatusRow('App Hazır', device.appReady),
          _buildStatusRow('Sistem Hazır', device.systemReady),
          _buildStatusRow('Programlar Hazır', device.programsReady),
          _buildStatusRow('Kamera Hazır', device.camReady),
          _buildStatusRow('Konfigürasyon Hazır', device.configurationReady),
          _buildStatusRow('Kamera Raporları Hazır', device.camreportsReady),
          _buildStatusRow('Movita Hazır', device.movitaReady),
          
          // Cihaz durum bilgileri
          const SizedBox(height: 16),
          const Text(
            'Cihaz Durum Bilgileri',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatusRow('Kayıtlı', device.registered),
          InfoRow(label: 'App Versiyonu', value: '${device.appVersion}'),
          InfoRow(label: 'Sistem Sayısı', value: '${device.systemCount}'),
          InfoRow(label: 'Kamera Raporları Sayısı', value: '${device.camreportsCount}'),
          InfoRow(label: 'Program Sayısı', value: '${device.programsCount}'),
          _buildStatusRow('Master Tarafından Kapatıldı', device.isClosedByMaster),
          InfoRow(label: 'Son Heartbeat', value: device.lastHeartbeatTs > 0 ? DateTime.fromMillisecondsSinceEpoch(device.lastHeartbeatTs * 1000).toString() : 'Bilinmiyor'),
          InfoRow(label: 'Offline Başlangıcı', value: device.offlineSince > 0 ? DateTime.fromMillisecondsSinceEpoch(device.offlineSince * 1000).toString() : 'Hiçbir zaman'),
        ],
      ),
    );
  }

  // Sistem Bilgileri Tab
  Widget _buildSystemTab(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sistem Bilgileri',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // System bilgileri
          if (device.systemMac != null)
            InfoRow(label: 'Sistem MAC', value: device.systemMac!),
          if (device.gateway != null)
            InfoRow(label: 'Gateway', value: device.gateway!),
          if (device.systemIp != null)
            InfoRow(label: 'Sistem IP', value: device.systemIp!),
          _buildStatusRow('GPS Durumu', device.gpsOk),
          _buildStatusRow('Kontak Durumu', device.ignition),
          _buildStatusRow('İnternet Bağlantısı', device.internetExists),
          InfoRow(label: 'Boot Sayısı', value: '${device.bootCount}'),
          if (device.diskFree != null)
            InfoRow(label: 'Disk Boş Alan', value: device.diskFree!),
          if (device.diskRunning != null)
            InfoRow(label: 'Disk Durumu', value: device.diskRunning!),
          InfoRow(label: 'Boş Alan (GB)', value: '${device.emptySize}'),
          InfoRow(label: 'Kayıt Boyutu (GB)', value: '${device.recordSize}'),
          InfoRow(label: 'Kayıt Durumu', value: '${device.recording}'),
          _buildStatusRow('SHMC Hazır', device.shmcReady),
          _buildStatusRow('Zaman Ayarlandı', device.timeset),
          _buildStatusRow('Uyku Modu', device.uykumodu),
          
          // RAM Bilgileri
          const SizedBox(height: 16),
          const Text(
            'RAM Bilgileri',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          InfoRow(
            label: 'Toplam RAM', 
            value: device.totalRam > 0 ? '${(device.totalRam / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB' : 'Mevcut değil'
          ),
          InfoRow(
            label: 'Boş RAM', 
            value: device.freeRam > 0 ? '${(device.freeRam / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB' : 'Mevcut değil'
          ),
          
          // Ağ Bilgileri
          const SizedBox(height: 16),
          const Text(
            'Ağ Bilgileri',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          InfoRow(label: 'Ağ Bilgileri', value: device.networkInfo ?? 'Bilinmiyor'),
          InfoRow(label: 'Toplam Bağlantı', value: '${device.totalConnections}'),
          InfoRow(label: 'Toplam Oturum', value: '${device.totalSessions}'),
        ],
      ),
    );
  }

  // App Bilgileri Tab
  Widget _buildAppTab(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Uygulama Bilgileri',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // App konfigürasyonu
          if (device.appDeviceType != null)
            InfoRow(label: 'Cihaz Tipi', value: device.appDeviceType!),
          if (device.firmwareDate != null)
            InfoRow(label: 'Firmware Tarihi', value: device.firmwareDate!),
          if (device.appFirmwareVersion != null)
            InfoRow(label: 'App Firmware Versiyonu', value: device.appFirmwareVersion!),
          _buildStatusRow('GPS Veri Akışı', device.gpsDataFlowStatus),
          InfoRow(label: 'Grup', value: '${device.group}'),
          _buildStatusRow('İç Bağlantı', device.intConnection),
          if (device.isai != null)
            InfoRow(label: 'ISAI', value: device.isai!),
          if (device.libPath != null)
            InfoRow(label: 'Lib Yolu', value: device.libPath!),
          if (device.logPath != null)
            InfoRow(label: 'Log Yolu', value: device.logPath!),
          if (device.macAddressPath != null)
            InfoRow(label: 'MAC Adres Yolu', value: device.macAddressPath!),
          InfoRow(label: 'Maksimum Kayıt Süresi', value: '${device.maxRecordDuration} dk'),
          InfoRow(label: 'Minimum Alan (MB)', value: '${device.minSpaceInMBytes}'),
          if (device.movitabinPath != null)
            InfoRow(label: 'Movita Bin Yolu', value: device.movitabinPath!),
          if (device.movitarecPath != null)
            InfoRow(label: 'Movita Rec Yolu', value: device.movitarecPath!),
          if (device.netdev != null)
            InfoRow(label: 'Ağ Cihazı', value: device.netdev!),
          if (device.pinCode != null)
            InfoRow(label: 'PIN Kodu', value: device.pinCode!),
          _buildStatusRow('PPP', device.ppp),
          _buildStatusRow('TCP Üzerinden Kayıt', device.recordOverTcp),
          if (device.appRecordPath != null)
            InfoRow(label: 'App Kayıt Yolu', value: device.appRecordPath!),
          _buildStatusRow('App Kayıt Yapıyor', device.appRecording),
          InfoRow(label: 'Kayıt Yapan Kameralar', value: '${device.recordingCameras}'),
          InfoRow(label: 'Player Restart Timeout', value: '${device.restartPlayerTimeout}'),
          if (device.rp2040version != null)
            InfoRow(label: 'RP2040 Versiyonu', value: device.rp2040version!),
        ],
      ),
    );
  }

  // Test Bilgileri Tab
  Widget _buildTestTab(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Test Bilgileri',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // Test uptime
          if (device.testUptime != null)
            InfoRow(label: 'Test Uptime', value: device.testUptime!),
          _buildStatusRow('Test Hatası Var', device.testIsError),
          
          // Bağlantı testleri
          const SizedBox(height: 16),
          const Text(
            'Bağlantı Testleri',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          InfoRow(label: 'Bağlantı Test Sayısı', value: '${device.testConnectionCount}'),
          if (device.testConnectionLastUpdate != null)
            InfoRow(label: 'Son Bağlantı Test Güncellemesi', value: device.testConnectionLastUpdate!),
          InfoRow(label: 'Bağlantı Test Hataları', value: '${device.testConnectionError}'),
          
          // Kamera bağlantı testleri
          const SizedBox(height: 16),
          const Text(
            'Kamera Bağlantı Testleri',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          InfoRow(label: 'Kamera Bağlantı Test Sayısı', value: '${device.testKameraBaglantiCount}'),
          if (device.testKameraBaglantiLastUpdate != null)
            InfoRow(label: 'Son Kamera Test Güncellemesi', value: device.testKameraBaglantiLastUpdate!),
          InfoRow(label: 'Kamera Bağlantı Test Hataları', value: '${device.testKameraBaglantiError}'),
          
          // Program testleri
          const SizedBox(height: 16),
          const Text(
            'Program Testleri',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          InfoRow(label: 'Program Test Sayısı', value: '${device.testProgramCount}'),
          if (device.testProgramLastUpdate != null)
            InfoRow(label: 'Son Program Test Güncellemesi', value: device.testProgramLastUpdate!),
          InfoRow(label: 'Program Test Hataları', value: '${device.testProgramError}'),
        ],
      ),
    );
  }

  // Kameralar Tab
  Widget _buildCamerasTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kameralar (${device.cameras.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (device.cameras.isNotEmpty && device.connected)
                TextButton.icon(
                  icon: const Icon(Icons.visibility),
                  label: const Text('Tümünü Görüntüle'),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/live-view');
                  },
                ),
            ],
          ),
        ),
        Expanded(
          child: device.cameras.isEmpty
              ? const Center(
                  child: Text('Bu cihaz için kamera bulunamadı'),
                )
              : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: device.cameras.length,
                  itemBuilder: (context, index) {
                    final camera = device.cameras[index];
                    return CameraCard(
                      camera: camera,
                      onTap: () {
                        // Set the selected camera
                        Provider.of<CameraDevicesProviderOptimized>(context, listen: false)
                            .setSelectedCameraIndex(index);
                            
                        // Navigate to live view screen
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/live-view');
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Durum göstergesi satırı
  Widget _buildStatusRow(String label, bool status) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
              ),
            ),
          ),
          Icon(
            status ? Icons.check_circle : Icons.cancel,
            color: status ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              status ? "Evet" : "Hayır",
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  
  const InfoRow({
    Key? key,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return value.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          );
  }
}

class CameraCard extends StatelessWidget {
  final Camera camera;
  final VoidCallback onTap;
  
  const CameraCard({
    Key? key,
    required this.camera,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: camera.connected 
              ? camera.recording
                  ? Colors.red
                  : AppTheme.accentColor
              : Theme.of(context).dividerColor,
          width: camera.connected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      camera.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      // Recording indicator
                      if (camera.recording)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.fiber_manual_record,
                                size: 12,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'REC',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Status indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: camera.connected 
                              ? AppTheme.accentColor 
                              : Colors.grey,
                          borderRadius: BorderRadius.circular(12),
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
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'IP: ${camera.ip}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Model: ${camera.brand} ${camera.hw}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.videocam,
                    size: 16,
                    color: AppTheme.accentColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Resolution: ${camera.recordWidth}x${camera.recordHeight}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Last seen: ${camera.lastSeenAt}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}