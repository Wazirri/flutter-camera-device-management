#!/usr/bin/env python3

with open('lib/screens/record_view_screen.dart', 'r') as file:
    content = file.read()

# Kayıt dizin URL düzeltme - zaten '/' ile bittiği için dokunmuyoruz

# .mp4 yerine .mkv dosya uzantısı düzeltme
old_regex = r"final recordingRegex = RegExp\(r'href=\"\(\[^\"\]\+\\\.mp4\)\"'\);"
new_regex = r"final recordingRegex = RegExp\(r'href=\"\(\[^\"\]\+\\\.mkv\)\"'\);"
content = content.replace(
    "final recordingRegex = RegExp(r'href=\"([^\"]+\\.mp4)\"');", 
    "final recordingRegex = RegExp(r'href=\"([^\"]+\\.mkv)\"');"
)

# Ayrıca dayUrl'deki sonundaki '/' ekleme düzeltme
old_dayurl1 = "final dayUrl = '$_recordingsUrl$dateStr/';"
new_dayurl1 = "final dayUrl = '$_recordingsUrl$dateStr/';"
content = content.replace(old_dayurl1, new_dayurl1)

old_dayurl2 = "_loadRecording('$dayUrl${_selectedRecording!}');"
new_dayurl2 = "_loadRecording('$dayUrl${_selectedRecording!}');"
content = content.replace(old_dayurl2, new_dayurl2)

# Sonucu dosyaya yazma
with open('lib/screens/record_view_screen.dart', 'w') as file:
    file.write(content)

print("Dosya uzantısı başarıyla .mp4'ten .mkv'ye değiştirildi")
