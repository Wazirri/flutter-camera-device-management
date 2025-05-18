import 'package:flutter/material.dart';
import '../utils/time_formatting.dart';

/// Test utility for uptime formatting
class UptimeFormatTester extends StatefulWidget {
  const UptimeFormatTester({Key? key}) : super(key: key);

  @override
  State<UptimeFormatTester> createState() => _UptimeFormatTesterState();
}

class _UptimeFormatTesterState extends State<UptimeFormatTester> {
  final TextEditingController _controller = TextEditingController();
  String _formattedResult = '';
  
  @override
  void initState() {
    super.initState();
    _controller.text = '3600'; // Default 1 hour
    _updateResult();
  }
  
  void _updateResult() {
    setState(() {
      _formattedResult = _controller.text.formatUptime();
    });
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
        title: const Text('Uptime Format Tester'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter uptime value (in seconds):',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter uptime in seconds (e.g. 3600)',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _updateResult,
              child: const Text('Format Uptime'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Formatted result:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _formattedResult,
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Examples:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildExampleRow('60', '60'.formatUptime()),
            _buildExampleRow('3600', '3600'.formatUptime()),
            _buildExampleRow('86400', '86400'.formatUptime()),
            _buildExampleRow('90000', '90000'.formatUptime()),
            _buildExampleRow('172800', '172800'.formatUptime()),
          ],
        ),
      ),
    );
  }
  
  Widget _buildExampleRow(String seconds, String formatted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text('$seconds seconds:'),
          ),
          Text(formatted, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
