#!/usr/bin/env python3

def update_imports():
    with open('lib/screens/record_view_screen.dart', 'r') as file:
        content = file.read()
    
    # Add new imports
    import_section = '''import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';'''
    
    # Replace the old import section with the new one
    old_imports = '''import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';'''
    
    if old_imports in content:
        content = content.replace(old_imports, import_section)
        
        with open('lib/screens/record_view_screen.dart', 'w') as file:
            file.write(content)
        
        return "Imports updated successfully."
    else:
        return "Import section not found. No changes made."

print(update_imports())
