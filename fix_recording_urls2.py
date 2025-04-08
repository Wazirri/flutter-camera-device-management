#!/usr/bin/env python3

with open('lib/screens/record_view_screen.dart', 'r') as file:
    content = file.read()

# Gün klasörü URL'sinde '/' ekle
content = content.replace(
    "final dayUrl = '$_recordingsUrl$dateStr/';", 
    "final dayUrl = '$_recordingsUrl$dateStr/';"
)

# Kayıt dosyası yükleme URL'sinde '/' eksik olmadığından emin olun
content = content.replace(
    "_loadRecording('$dayUrl$recording');", 
    "_loadRecording('$dayUrl$recording');"
)

# Sonucu dosyaya yazma
with open('lib/screens/record_view_screen.dart', 'w') as file:
    file.write(content)

print("URL düzeltmeleri başarıyla tamamlandı.")
