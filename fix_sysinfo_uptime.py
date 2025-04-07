#!/usr/bin/env python3

# This script fixes the SystemInfo model to ensure upTime is an integer

with open('lib/models/system_info.dart', 'r') as file:
    content = file.read()

# Check if the upTime is already an int
if "final int upTime;" not in content and "final String upTime;" in content:
    # Replace String upTime with int upTime
    content = content.replace("final String upTime;", "final int upTime;")
    
    # Update constructor
    content = content.replace("required this.upTime,", "required this.upTime,")
    
    # Update fromJson method to parse upTime as int
    if "upTime: json['upTime'] ?? ''," in content:
        content = content.replace(
            "upTime: json['upTime'] ?? '',", 
            "upTime: json['upTime'] is String ? int.tryParse(json['upTime']) ?? 0 : json['upTime'] ?? 0,"
        )

# Write the updated content back to the file
with open('lib/models/system_info.dart', 'w') as file:
    file.write(content)

print("Fixed SystemInfo model to use int for upTime")
