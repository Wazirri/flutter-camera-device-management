#!/usr/bin/env python3

def fix_websocket_provider():
    with open('lib/screens/record_view_screen.dart', 'r') as file:
        content = file.readlines()

    modified_content = []
    for line in content:
        # .mp4'ten .mkv'ye değiştirme
        if "RegExp(r'href=\"([^\"]+\\.mp4)\"');" in line:
            modified_line = line.replace(".mp4", ".mkv")
            modified_content.append(modified_line)
        else:
            modified_content.append(line)

    with open('lib/screens/record_view_screen.dart', 'w') as file:
        file.writelines(modified_content)

fix_websocket_provider()
print("Kayıt görüntüleme sayfasındaki dosya uzantısı düzeltildi.")
