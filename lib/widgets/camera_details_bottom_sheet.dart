import 'package:flutter/material.dart';
import '../models/camera_device.dart';
import '../theme/app_theme.dart';

class CameraDetailsBottomSheet extends StatelessWidget {
  final Camera camera;
  final ScrollController scrollController;

  const CameraDetailsBottomSheet({
    Key? key,
    required this.camera,
    required this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle ve Başlık
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.videocam,
                  color: AppTheme.primaryBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      camera.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: camera.connected ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          camera.connected ? 'Connected' : 'Disconnected',
                          style: TextStyle(
                            fontSize: 14,
                            color: camera.connected ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          
          // Detaylar
          Expanded(
            child: ListView(
              controller: scrollController,
              children: [
                _buildDetailGroup(
                  context: context,
                  title: 'Basic Information',
                  details: [
                    DetailItem(name: 'Name', value: camera.name),
                    DetailItem(name: 'Camera IP', value: camera.ip),
                    DetailItem(name: 'Raw IP', value: camera.rawIp.toString()),
                    DetailItem(name: 'Username', value: camera.username),
                    DetailItem(name: 'Password', value: camera.password),
                    DetailItem(name: 'Connected', value: camera.connected ? 'Yes' : 'No'),
                    DetailItem(name: 'Recording', value: camera.recording ? 'Yes' : 'No'),
                    DetailItem(name: 'Last Seen', value: camera.lastSeenAt),
                  ],
                ),
                _buildDetailGroup(
                  context: context,
                  title: 'Device Information',
                  details: [
                    DetailItem(name: 'Hardware', value: camera.hw),
                    DetailItem(name: 'Brand', value: camera.brand),
                    DetailItem(name: 'Manufacturer', value: camera.manufacturer),
                    DetailItem(name: 'Country', value: camera.country),
                    DetailItem(name: 'Sound Recording', value: camera.soundRec ? 'Enabled' : 'Disabled'),
                  ],
                ),
                _buildDetailGroup(
                  context: context,
                  title: 'Connection URLs',
                  details: [
                    DetailItem(name: 'xAddrs', value: camera.xAddrs),
                    DetailItem(name: 'xAddr', value: camera.xAddr),
                    DetailItem(name: 'Media URI', value: camera.mediaUri),
                    DetailItem(name: 'Record URI', value: camera.recordUri),
                    DetailItem(name: 'Sub URI', value: camera.subUri),
                    DetailItem(name: 'Remote URI', value: camera.remoteUri),
                    DetailItem(name: 'Main Snapshot', value: camera.mainSnapShot),
                    DetailItem(name: 'Sub Snapshot', value: camera.subSnapShot),
                  ],
                ),
                _buildDetailGroup(
                  context: context,
                  title: 'Recording Information',
                  details: [
                    DetailItem(name: 'Record Path', value: camera.recordPath),
                    DetailItem(name: 'Record Codec', value: camera.recordCodec),
                    DetailItem(name: 'Record Resolution', value: '${camera.recordWidth}x${camera.recordHeight}'),
                    DetailItem(name: 'Sub Codec', value: camera.subCodec),
                    DetailItem(name: 'Sub Resolution', value: '${camera.subWidth}x${camera.subHeight}'),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Butonlar
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Live View'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          // Live view sayfasına git (mevcut implemenatasyonunuza göre düzenleyin)
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.history),
                        label: const Text('Recordings'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryOrange,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          // Recordings sayfasına git (mevcut implemenatasyonunuza göre düzenleyin)
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Her bir detay grubu için widget oluşturma
  Widget _buildDetailGroup({
    required BuildContext context,
    required String title,
    required List<DetailItem> details,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryOrange,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          color: AppTheme.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: details.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final detail = details[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          detail.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.darkTextSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          detail.value.isEmpty ? '-' : detail.value,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.darkTextPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// Detayları temsil eden helper sınıf
class DetailItem {
  final String name;
  final String value;

  DetailItem({required this.name, required this.value});
}
