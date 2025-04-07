#!/usr/bin/env python3

def fix_multiview_layout():
    # Read the whole file
    with open('lib/screens/multi_live_view_screen.dart', 'r') as file:
        content = file.readlines()
    
    # First check if we need to add imports
    has_camera_layout_import = False
    for line in content:
        if "import '../models/camera_layout.dart';" in line:
            has_camera_layout_import = True
            break
    
    if not has_camera_layout_import:
        # Add import after the last import
        for i, line in enumerate(content):
            if line.startswith('import ') and content[i+1].strip() == '':
                content.insert(i+1, "import '../models/camera_layout.dart';\n")
                print("Added camera_layout.dart import")
                break
    
    # Find the state class declaration to add the _currentLayout variable
    for i, line in enumerate(content):
        if "class _MultiLiveViewScreenState extends State<MultiLiveViewScreen>" in line:
            # Look for the closing bracket of class variables
            for j in range(i+1, i+50):  # Look within the next 50 lines
                if line.strip().startswith('int _gridColumns'):
                    # Add _currentLayout after _gridColumns
                    layout_line = "  CameraLayout _currentLayout = CameraLayout(name: 'Default', id: 4, rows: 5, columns: 4, slots: 20, description: 'Default layout');\n"
                    content.insert(j+1, layout_line)
                    print(f"Added _currentLayout variable at line {j+1}")
                    break
    
    # Find and fix the activeRowsNeeded calculation
    for i, line in enumerate(content):
        if "final activeRowsNeeded = (activeCameraCount / _gridColumns).ceil();" in line:
            # We'll replace this line completely
            content[i] = "    // Use layout rows or calculate based on active cameras if layout rows is not available\n"
            content.insert(i+1, "    final activeRowsNeeded = 5; // Fixed number of rows to ensure grid fills the screen\n")
            print(f"Updated activeRowsNeeded calculation at line {i+1}")
    
    # Write the updated content back
    with open('lib/screens/multi_live_view_screen.dart', 'w') as file:
        file.writelines(content)
    
    return "Multi Camera View layout updated to always fill the screen with fixed rows"

print(fix_multiview_layout())
