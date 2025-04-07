#!/usr/bin/env python3

# This script adds a macAddress getter to the CameraDevice class
# to maintain backward compatibility with existing code

with open('lib/models/camera_device.dart', 'r') as file:
    content = file.read()

# Add macAddress getter that returns macKey
if "String get macAddress => macKey;" not in content:
    insert_pos = content.find("CameraDevice({")
    
    # Find the position before the constructor
    if insert_pos > 0:
        # Add the getter before the constructor
        before_constructor = content[:insert_pos]
        after_constructor = content[insert_pos:]
        
        # Add the getter
        macaddress_getter = "\n  // For backward compatibility with existing code\n  String get macAddress => macKey;\n  \n"
        
        # Combine the parts
        content = before_constructor + macaddress_getter + after_constructor

# Add country property and getter to Camera class
if "String country = '';" not in content:
    # Find the position after the last property in the Camera class properties
    insert_pos = content.find("String lastSeenAt = '';")
    if insert_pos > 0:
        # Find the end of the line
        end_line_pos = content.find("\n", insert_pos)
        if end_line_pos > 0:
            # Insert country property after lastSeenAt
            before_prop = content[:end_line_pos + 1]
            after_prop = content[end_line_pos + 1:]
            
            # Add the country property
            country_prop = "  String country = '';     // Camera country location\n"
            
            # Combine the parts
            content = before_prop + country_prop + after_prop

# Write the updated content back to the file
with open('lib/models/camera_device.dart', 'w') as file:
    file.write(content)

print("Fixed CameraDevice model with macAddress getter and added country property to Camera class")
