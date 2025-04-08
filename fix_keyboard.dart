// Klavye hatalarını düzeltmek için oluşturulan dosya
// Bu dosyayı lib/main.dart dosyasına entegre etmek gerekiyor

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KeyboardFixWrapper extends StatefulWidget {
  final Widget child;

  const KeyboardFixWrapper({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<KeyboardFixWrapper> createState() => _KeyboardFixWrapperState();
}

class _KeyboardFixWrapperState extends State<KeyboardFixWrapper> {
  // Klavye olaylarını takip etmek için HardwareKeyboard'u kullanacağız
  final Set<PhysicalKeyboardKey> _physicalKeysPressed = <PhysicalKeyboardKey>{};
  
  @override
  void initState() {
    super.initState();
    
    // Klavye olay dinleyicisini ekle
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    // Klavye olay dinleyicisini kaldır
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }
  
  // Klavye olaylarını işleyen fonksiyon
  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      // Eğer tuş zaten basılı olarak işaretliyse, bu tuşun basılmasını yoksay
      if (_physicalKeysPressed.contains(event.physicalKey)) {
        return true; // Olayı tükettik ve uygulamaya gitmesini engelledik
      }
      // Değilse, tuşu basılı olarak işaretle
      _physicalKeysPressed.add(event.physicalKey);
    } else if (event is KeyUpEvent) {
      // Tuşun bırakıldığını işaretle
      _physicalKeysPressed.remove(event.physicalKey);
    }
    return false; // Olayı normal şekilde işle
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
