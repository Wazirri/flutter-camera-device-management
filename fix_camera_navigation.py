#!/usr/bin/env python3

def fix_camera_navigation():
    # Kamera ekranlarındaki navigasyon yöntemlerini düzenle
    
    # 1. cameras_screen.dart dosyasında kameraya tıklama ile açılan sayfayı düzenle
    try:
        with open('lib/screens/cameras_screen.dart', 'r') as file:
            content = file.read()
        
        # Kameraya tıklama yöntemini güncelle
        if "Navigator.of(context).pushNamed('/live-view', arguments: {'camera': camera});" in content:
            # Zaten doğru
            pass
        elif "Navigator.pushNamed(context, '/live-view', arguments: {'camera': camera});" in content:
            # Zaten doğru
            pass
        else:
            # Muhtemelen pushReplacement kullanılıyor, düzelt
            old_code = "Navigator.pushReplacementNamed(context, '/live-view', arguments: {'camera': camera});"
            new_code = "Navigator.pushNamed(context, '/live-view', arguments: {'camera': camera});"
            content = content.replace(old_code, new_code)
            
            # Yazma
            with open('lib/screens/cameras_screen.dart', 'w') as file:
                file.write(content)
    except FileNotFoundError:
        print("cameras_screen.dart dosyası bulunamadı, atlıyorum")
    
    # 2. live_view_screen.dart dosyasında kayıtlara gitme butonunu düzenle
    try:
        with open('lib/screens/live_view_screen.dart', 'r') as file:
            content = file.read()
        
        # Kayıtlar sayfasına gitme butonunu güncelle
        if "Navigator.of(context).pushNamed('/recordings', arguments: {'camera': widget.camera});" in content:
            # Zaten doğru
            pass
        elif "Navigator.pushNamed(context, '/recordings', arguments: {'camera': widget.camera});" in content:
            # Zaten doğru
            pass
        else:
            # Muhtemelen pushReplacement kullanılıyor, düzelt
            old_code = "Navigator.pushReplacementNamed(context, '/recordings', arguments: {'camera': widget.camera});"
            new_code = "Navigator.pushNamed(context, '/recordings', arguments: {'camera': widget.camera});"
            content = content.replace(old_code, new_code)
            
            # Yazma
            with open('lib/screens/live_view_screen.dart', 'w') as file:
                file.write(content)
    except FileNotFoundError:
        print("live_view_screen.dart dosyası bulunamadı, atlıyorum")
    
    # 3. multi_live_view_screen.dart dosyasında kameraya çift tıklama yöntemini düzenle
    try:
        with open('lib/screens/multi_live_view_screen.dart', 'r') as file:
            content = file.read()
        
        # Kamera detay sayfasına gitme yöntemini güncelle
        if "Navigator.of(context).pushNamed('/live-view', arguments: {'camera': camera});" in content:
            # Zaten doğru
            pass
        elif "Navigator.pushNamed(context, '/live-view', arguments: {'camera': camera});" in content:
            # Zaten doğru
            pass
        else:
            # Muhtemelen pushReplacement kullanılıyor, düzelt
            old_code = "Navigator.pushReplacementNamed(context, '/live-view', arguments: {'camera': camera});"
            new_code = "Navigator.pushNamed(context, '/live-view', arguments: {'camera': camera});"
            content = content.replace(old_code, new_code)
            
            # Yazma
            with open('lib/screens/multi_live_view_screen.dart', 'w') as file:
                file.write(content)
    except FileNotFoundError:
        print("multi_live_view_screen.dart dosyası bulunamadı, atlıyorum")
    
    return "Alt sayfalar arasındaki navigasyon yöntemleri düzeltildi"

print(fix_camera_navigation())
