#!/usr/bin/env python3

with open('lib/screens/record_view_screen.dart', 'r') as file:
    content = file.read()

# Check for a damaged _fetchRecordings method
if "// Fetch available recording dates for the selected camera\n      // Construct the recordings" in content:
    print("Found damaged _fetchRecordings method, fixing...")
    
    # Fix the damaged method
    new_method = """  // Fetch available recording dates for the selected camera
  void _fetchRecordings() async {
    if (_camera == null) {
      setState(() {
        _availableRecordings = [];
        _recordingsByDate.clear();
      });
      return;
    }
    
    setState(() {
      _isLoadingDates = true;
      _loadingError = '';
    });
    
    try {
      // Get the parent device of this camera
      final cameraProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
      final parentDevice = cameraProvider.getDeviceForCamera(_camera!);
      
      if (parentDevice == null) {
        throw Exception('Could not find parent device for this camera');
      }
      
      // Construct the recordings base URL using the device IP (not camera IP)
      final deviceIp = parentDevice.ipv4;
      if (deviceIp.isEmpty) {
        throw Exception('Device IP is not available');
      }
      
      _recordingsUrl = 'http://$deviceIp:8080/Rec/${_camera!.name}/';"""
    
    # Remove the damaged method (search for the header and the partial method)
    damaged_start = content.find("  // Fetch available recording dates for the selected camera\n      // Construct the recordings")
    
    # Find the next occurrence of a method definition to determine where to stop replacing
    next_method_start = content.find("  void _update", damaged_start)
    
    if damaged_start != -1 and next_method_start != -1:
        # Extract the part after the damaged method that we want to keep
        part_to_keep_after_new_method = content[next_method_start:]
        
        # Extract the part before the damaged method
        part_before_damaged_method = content[:damaged_start]
        
        # Combine all parts
        updated_content = part_before_damaged_method + new_method
        
        # Find the rest of the _fetchRecordings implementation from another part of the file
        fetch_recordings_end = """
      // Fetch the recordings directory listing
      final response = await http.get(Uri.parse(_recordingsUrl!));
      
      if (response.statusCode == 200) {
        // Parse the directory listing (this is simplified and would need to be adjusted 
        // based on actual server response format)
        
        // For demo purposes, let's assume response contains a basic HTML directory listing
        // In reality, you might need to use a regex or HTML parser to extract folders
        final dateRegex = RegExp(r'(\d{4}_\d{2}_\d{2})');
        final matches = dateRegex.allMatches(response.body);
        
        final Map<DateTime, List<String>> newRecordings = {};
        
        // Extract dates
        for (final match in matches) {
          final dateStr = match.group(1)!;
          final dateParts = dateStr.split('_');
          if (dateParts.length == 3) {
            final year = int.parse(dateParts[0]);
            final month = int.parse(dateParts[1]);
            final day = int.parse(dateParts[2]);
            
            final date = DateTime(year, month, day);
            // Add the date to map with empty recordings list, will be populated when selected
            newRecordings[date] = [];
          }
        }
        
        if (mounted) {
          setState(() {
            _recordingsByDate.clear();
            _recordingsByDate.addAll(newRecordings);
            _isLoadingDates = false;
          });
        }
        
        // Update recordings for selected day
        _updateRecordingsForSelectedDay();
      } else {
        throw Exception('Failed to load recordings: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching recordings: $e');
      if (mounted) {
        setState(() {
          _isLoadingDates = false;
          _loadingError = 'Failed to load recordings: $e';
        });
      }
    }
  }"""
        
        updated_content = updated_content + fetch_recordings_end + part_to_keep_after_new_method
        
        # Write the fixed content back to the file
        with open('lib/screens/record_view_screen.dart', 'w') as file:
            file.write(updated_content)
        
        print("Successfully fixed the _fetchRecordings method")
    else:
        print("Could not locate the method boundaries correctly")
else:
    print("_fetchRecordings method not damaged, no fix needed")
