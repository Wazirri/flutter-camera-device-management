#!/usr/bin/env python3

def fix_imports():
    with open('lib/screens/record_view_screen.dart', 'r') as file:
        content = file.read()
    
    # Fix duplicate imports
    imports_section = '''import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';'''
    
    fixed_imports = '''import 'package:flutter/material.dart';
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
    
    content = content.replace(imports_section, fixed_imports)
    
    with open('lib/screens/record_view_screen.dart', 'w') as file:
        file.write(content)
    
    return "Duplicate imports fixed in record_view_screen.dart"

print(fix_imports())
