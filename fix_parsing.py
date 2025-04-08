#!/usr/bin/env python3

with open('lib/screens/record_view_screen.dart', 'r') as file:
    content = file.readlines()

modified_content = []
for line in content:
    # 1. Tarih Regex'ini Düzelt: HTML a href içindeki tarih klasörlerini bul
    if "final dateRegex = RegExp(r'(\d{4}_\d{2}_\d{2})');" in line:
        modified_line = line.replace(
            "final dateRegex = RegExp(r'(\d{4}_\d{2}_\d{2})');" ,
            "final dateRegex = RegExp(r'href=\"(\\d{4}_\\d{2}_\\d{2})/\"');"
        )
        modified_content.append(modified_line)
    # 2. Kayıt dosyaları regex düzeltme - zaten yapmıştık bu kısmı
    elif "RegExp(r'href=\"([^\"]+\\.mkv)\"');" in line:
        modified_content.append(line)  # Bunu zaten düzeltmiştik
    # Diğer satırları olduğu gibi bırak
    else:
        modified_content.append(line)

with open('lib/screens/record_view_screen.dart', 'w') as file:
    file.writelines(modified_content)

print("HTML ayrıştırma düzenli ifadeleri güncellendi.")
