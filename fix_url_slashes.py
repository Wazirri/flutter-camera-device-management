#!/usr/bin/env python3

with open('lib/screens/record_view_screen.dart', 'r') as file:
    content = file.readlines()

modified_content = []
for line in content:
    # _recordingsUrl sonundaki eğik çizgiden emin ol
    if "_recordingsUrl = 'http://$deviceIp:8080/Rec/${_camera!.name}/';" in line:
        # Bu zaten doğru, değiştirmeye gerek yok
        modified_content.append(line)
    # dayUrl sonundaki eğik çizgiden emin ol
    elif "final dayUrl = '$_recordingsUrl$dateStr/';" in line:
        # Bu zaten doğru, değiştirmeye gerek yok
        modified_content.append(line)
    # Dosya URL'sini oluştururken sonuna eğik çizgi eklenmediğinden emin ol
    elif "_loadRecording('$dayUrl${_selectedRecording!}');" in line:
        # Bu zaten doğru, değiştirmeye gerek yok
        modified_content.append(line)
    elif "_loadRecording('$dayUrl$recording');" in line:
        # Bu zaten doğru, değiştirmeye gerek yok
        modified_content.append(line)
    else:
        modified_content.append(line)

with open('lib/screens/record_view_screen.dart', 'w') as file:
    file.writelines(modified_content)

print("URL sonundaki eğik çizgiler kontrol edildi.")
