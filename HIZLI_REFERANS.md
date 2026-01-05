# WebSocket Komut Referansı - Hızlı Kılavuz

## 🚀 Hızlı Başlat

### Bağlantı ve Giriş
```javascript
// WebSocket bağlantısı
const ws = new WebSocket('ws://localhost:8080/websocket');

// Admin girişi
ws.send('LOGIN "admin" "admin123"');

// Yardım alma
ws.send('USERHELP');
ws.send('GROUPHELP');
```

---

## 👤 KULLANICI KOMUTLARI

### Temel İşlemler
```javascript
// Giriş
ws.send('LOGIN "kullanici" "sifre"');

// Çıkış  
ws.send('LOGOUT');

// Kullanıcı listesi (sadece admin)
ws.send('GETUSERLIST');
```

### Kullanıcı Yönetimi (Sadece Admin)
```javascript
// Yeni kullanıcı oluştur
ws.send('CREATEUSER "johndoe" "secure123" "John Doe" "operator"');

// Kullanıcı sil
ws.send('DELETEUSER "johndoe"');

// Şifre değiştir
ws.send('CHANGEPASS "johndoe" "yeni_sifre"');

// Admin şifre sıfırla (acil durum)
ws.send('RESETADMIN');
```

---

ADD_GROUP_TO_CAM me8_b7_23_0f_7e_ee denetleme

ADD_GROUP_TO_CAM me8_b7_23_0f_7e_ee guvenlik

---

## ⚙️ MASTER CONFIG AYARLARI

### Kamera Dağıtım Ayarları
```javascript
// Master'a kamera ver (1: aktif, 0: pasif)
ws.send('SETINT ecs.bridge_auto_cam_sharing.masterhascams 1');

// Otomatik dağıtım aç/kapat
ws.send('SETINT ecs.bridge_auto_cam_sharing.auto_cam_share 1');

// Kamerayı dağıtıma dahil et
ws.send('SETINT all_cameras.<camera_mac>.sharing_active 1');

// Değişiklik beklemeden zorla dağıt
ws.send('SETINT all_cameras.<camera_mac>.share_force 1');

// Slave'ler arası kamera sayısı threshold eşiği (1-5 arası)
ws.send('SETINT ecs.bridge_auto_cam_sharing.last_scan_imbalance 2');
```

### bridge_auto_cam_sharing Yapısı
```json
{
  "masterhascams": 1,
  "auto_cam_share": 1,
  "last_scan_total_cameras": 9,
  "last_scan_connected_cameras": 9,
  "last_scan_active_slaves": 1,
  "last_scan_min_cameras_per_slave": 5,
  "last_scan_max_cameras_per_slave": 5,
  "last_scan_imbalance": 2,
  "share_force": 0,
  "last_cam_shared_at": "2026-01-05 - 14:27:59"
}
```

---

## 📷 KAMERA KULLANICI AYARLARI

### ARRAYADD - Array'e Eleman Ekle
```javascript
// ONVIF kullanıcı/şifre ekle
ws.send('ARRAYADD configuration.onvif.passwords admin:admin123');
ws.send('ARRAYADD configuration.onvif.passwords operator:secret456');
```

### ARRAYDEL - Array'den Eleman Sil
```javascript
// Index ile silme
ws.send('ARRAYDEL configuration.onvif.passwords 0');

// Değer ile silme
ws.send('ARRAYDEL configuration.onvif.passwords admin:admin123');
```

---

## 🌐 NETWORK AYARLARI

### SETSTRING - String Değer Ayarla
```javascript
// Varsayılan IP ayarları
ws.send('SETSTRING networking.default_ip 192.168.1.100');
ws.send('SETSTRING networking.default_gw 192.168.1.1');
ws.send('SETSTRING networking.default_netmask 255.255.255.0');
ws.send('SETSTRING networking.default_dns 8.8.8.8');

// DHCP IP aralığı
ws.send('SETSTRING networking.default_ip_start 192.168.1.100');
ws.send('SETSTRING networking.default_ip_end 192.168.1.200');
```

---

## 🔘 BOOLEAN AYARLARI

### SETBOOL - Boolean Değer Ayarla
```javascript
// Otomatik tarama aç/kapat (true/false veya 1/0 kullanılabilir)
ws.send('SETBOOL configuration.autoscan true');
ws.send('SETBOOL configuration.autoscan 0');
```

---

## 🏢 GRUP KOMUTLARI (Sadece Admin)

### Grup Yönetimi
```javascript
// Grup listesi
ws.send('GETGROUPLIST');

// Yeni grup oluştur
ws.send('CREATEGROUP "manager" "Proje Yöneticisi" "view,control,user_management"');

// Grubu güncelle
ws.send('MODIFYGROUP "manager" "Kıdemli Yönetici" "view,control,user_management,report_access"');

// Grup sil
ws.send('DELETEGROUP "manager"');
```

---

## 🔐 İZİN TÜRLERİ

### Temel İzinler
- `all` - Tüm yetkiler
- `view` - Görüntüleme 
- `control` - Kontrol
- `monitor` - İzleme
- `basic` - Temel işlemler

### Yönetim İzinleri
- `user_management` - Kullanıcı yönetimi
- `group_management` - Grup yönetimi  
- `system_control` - Sistem kontrolü

### Özel İzinler
- `camera_control` - Kamera kontrolü
- `report_access` - Rapor erişimi
- `backup_restore` - Yedekleme
- `device_config` - Cihaz ayarları

---

## 📋 HAZIR GRUP ŞABLONLARı

### Yönetici Grupları
```javascript
// Tam yetki
ws.send('CREATEGROUP "admin" "Sistem Yöneticisi" "all"');

// Üst yönetim
ws.send('CREATEGROUP "management" "Üst Yönetim" "all"');
```

### Operasyon Grupları  
```javascript
// Sistem operatörü
ws.send('CREATEGROUP "operator" "Sistem Operatörü" "view,control,monitor"');

// Teknik personel
ws.send('CREATEGROUP "technician" "Teknik Personel" "view,control,device_config,camera_control"');

// Güvenlik personeli
ws.send('CREATEGROUP "security" "Güvenlik" "view,monitor,camera_control,report_access"');
```

### Proje Grupları
```javascript
// Proje yöneticisi
ws.send('CREATEGROUP "project_manager" "Proje Yöneticisi" "view,control,user_management,report_access"');

// Geliştirici
ws.send('CREATEGROUP "developer" "Geliştirici" "view,control,device_config"');
```

### Sınırlı Gruplar
```javascript
// Sadece görüntüleme
ws.send('CREATEGROUP "viewer" "Görüntüleyici" "view,monitor"');

// Standart kullanıcı  
ws.send('CREATEGROUP "user" "Standart Kullanıcı" "basic,view"');

// Misafir
ws.send('CREATEGROUP "guest" "Misafir" "view"');
```

---

## 🎯 YAYGIN SENARYOLAR

### Yeni Çalışan Ekleme
```javascript
// 1. Gruba uygun kullanıcı oluştur
ws.send('CREATEUSER "yeni_calisan" "TempPass2025!" "Yeni Çalışan" "user"');

// 2. Kullanıcıya şifresini değiştirmesini söyle
// 3. Gerekirse grup değiştir (sil ve yeniden oluştur)
ws.send('DELETEUSER "yeni_calisan"');
ws.send('CREATEUSER "yeni_calisan" "UserPass2025!" "Yeni Çalışan" "operator"');
```

### Güvenlik Güncellemesi
```javascript
// 1. Şüpheli kullanıcıyı sil
ws.send('DELETEUSER "suspicious_user"');

// 2. Tüm şifreleri değiştir
ws.send('CHANGEPASS "user1" "NewSecure2025_1"');
ws.send('CHANGEPASS "user2" "NewSecure2025_2"');

// 3. İzinleri kısıtla
ws.send('MODIFYGROUP "guest" "Kısıtlı Misafir" "view"');
```

### Proje Ekibi Kurma
```javascript
// 1. Proje grubu oluştur
ws.send('CREATEGROUP "project_x" "X Projesi" "view,control,device_config"');

// 2. Ekip üyelerini ekle
ws.send('CREATEUSER "proj_lead" "ProjLead2025!" "Proje Lideri" "project_x"');
ws.send('CREATEUSER "proj_dev1" "ProjDev1_2025!" "Geliştirici 1" "project_x"');
ws.send('CREATEUSER "proj_dev2" "ProjDev2_2025!" "Geliştirici 2" "project_x"');
```

### Proje Tamamlama - Temizlik
```javascript
// 1. Proje kullanıcılarını sil
ws.send('DELETEUSER "proj_lead"');
ws.send('DELETEUSER "proj_dev1"'); 
ws.send('DELETEUSER "proj_dev2"');

// 2. Proje grubunu sil
ws.send('DELETEGROUP "project_x"');
```

---

## ❗ HATA MESAJLARI ve ÇÖZÜMLER

### "Kullanıcı zaten mevcut!"
```javascript
// Çözüm: Önce sil, sonra oluştur
ws.send('DELETEUSER "existing_user"');
ws.send('CREATEUSER "existing_user" "new_pass" "Name" "group"');
```

### "Grup bulunamadı!"
```javascript
// Çözüm: Önce grubu oluştur
ws.send('CREATEGROUP "missing_group" "Description" "view,control"');
```

### "Sadece admin kullanıcıları..."
```javascript
// Çözüm: Admin ile giriş yap
ws.send('LOGOUT');
ws.send('LOGIN "admin" "admin_password"');
```

### "Grup silinemez - kullanıcılar mevcut!"
```javascript
// Çözüm: Önce kullanıcıları sil/taşı
ws.send('GETUSERLIST'); // Kim bu grupta?
ws.send('DELETEUSER "user_in_group"');
ws.send('DELETEGROUP "empty_group"');
```

---

## 🔍 DEBUGLAマ ve TEST

### Sistem Durumu
```javascript
// Tüm listeleri kontrol et
ws.send('GETUSERLIST');
ws.send('GETGROUPLIST');

// Komut yardımı
ws.send('USERHELP');
ws.send('GROUPHELP');
```

### Bağlantı Testi
```javascript
// WebSocket durumu
console.log('WebSocket State:', ws.readyState);
// 0: CONNECTING, 1: OPEN, 2: CLOSING, 3: CLOSED

// Test mesajı
if (ws.readyState === 1) {
    ws.send('USERHELP');
}
```

### Yanıt Formatları
```javascript
ws.onmessage = function(event) {
    const data = JSON.parse(event.data);
    
    switch(data.c) {
        case 'success':
            console.log('✅ Başarılı:', data.msg);
            break;
        case 'error':
            console.log('❌ Hata:', data.msg);
            break;
        case 'login':
            console.log('🔐 Giriş:', data.user);
            break;
        case 'userlist':
            console.log('👥 Kullanıcılar:', data.users);
            break;
        case 'grouplist':
            console.log('🏢 Gruplar:', data.groups);
            break;
    }
};
```

---

## 📱 WEB ARAYÜZÜ

### HTML Test Sayfası
`user_test.html` dosyasını tarayıcıda açarak görsel arayüz ile test yapabilirsiniz.

### JavaScript Fonksiyonları
```javascript
// Kullanıcı işlemleri
login();
logout();
createUser();
deleteUser();
changePassword();
getUserList();

// Grup işlemleri  
createGroup();
deleteGroup();
modifyGroup();
sendMessage('GETGROUPLIST');
sendMessage('GROUPHELP');
```

---

## 🛡️ GÜVENLİK KONTROL LİSTESİ

### ✅ Yapılması Gerekenler
- [ ] Admin şifresini değiştir: `ws.send('CHANGEPASS "admin" "GucluSifre2025!"');`
- [ ] Test kullanıcılarını sil: `ws.send('DELETEUSER "test_user"');`
- [ ] İzinleri en az yetki ilkesine göre ayarla
- [ ] Güçlü şifreler kullan (min 8 karakter, karışık)
- [ ] Düzenli kullanıcı listesi kontrolü: `ws.send('GETUSERLIST');`

### ❌ Yapılmaması Gerekenler
- Zayıf şifreler: `123456`, `password`, `admin`
- Gereksiz yüksek yetkiler: Her gruba `all` izni verme
- Test hesaplarını production'da bırakma
- Varsayılan şifreleri değiştirmeme

---

Bu hızlı referans ile Movita WebSocket sistem yönetimini kolayca yapabilirsiniz! 🚀