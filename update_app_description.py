#!/usr/bin/env python3

def update_descriptions():
    try:
        with open('lib/screens/login_screen.dart', 'r') as file:
            content = file.read()
            
        # ECS açıklamasını ekleyelim, eğer movita logosu veya başlık içeren bir alan varsa
        if 'movita ECS' in content and 'Enterprise Camera System' not in content:
            # movita ECS yazısını güncelle
            content = content.replace('movita ECS', 'movita ECS\nEnterprise Camera System')
            
        with open('lib/screens/login_screen.dart', 'w') as file:
            file.write(content)
            
        return "Uygulama açıklaması 'Enterprise Camera System' olarak güncellendi."
    except Exception as e:
        return f"Hata oluştu: {str(e)}"

print(update_descriptions())
