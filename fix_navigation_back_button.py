#!/usr/bin/env python3

def fix_navigation():
    # Ana ekranlarda geri butonunu kaldır
    # record_view_screen.dart'taki geri butonunu düzelt
    with open('lib/screens/record_view_screen.dart', 'r') as file:
        content = file.read()
    
    # AppBar leading widget'ını değiştir
    old_code = '''                AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back, color: AppTheme.primaryColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ),'''
    
    new_code = '''                AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  automaticallyImplyLeading: false, // Ana menülerden geliyorsa geri butonu olmayacak
                  leading: Navigator.of(context).canPop() ? IconButton(
                    icon: Icon(Icons.arrow_back, color: AppTheme.primaryColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ) : null,'''
    
    content = content.replace(old_code, new_code)
    
    with open('lib/screens/record_view_screen.dart', 'w') as file:
        file.write(content)
    
    # Diğer ekranlar AppShell içinde yer aldığından, AppShell widget'ını düzelt
    with open('lib/main.dart', 'r') as file:
        content = file.read()
    
    # AppShell Scaffold'unu değiştir
    old_code = '''    return Scaffold(
      key: _scaffoldKey,
      drawer: isMobile
          ? SizedBox(
              width: 250,
              child: DesktopSideMenu(
                currentRoute: widget.currentRoute,
                onDestinationSelected: _navigateToRoute,
              ),
            )
          : null,'''
    
    new_code = '''    return Scaffold(
      key: _scaffoldKey,
      // Ana menülerden otomatik geri butonunu devre dışı bırak
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // Ana menülerde geri butonu gösterme
        toolbarHeight: 0, // AppBar görünmez yap ama kontrolü sağla
      ),
      drawer: isMobile
          ? SizedBox(
              width: 250,
              child: DesktopSideMenu(
                currentRoute: widget.currentRoute,
                onDestinationSelected: _navigateToRoute,
              ),
            )
          : null,'''
    
    content = content.replace(old_code, new_code)
    
    with open('lib/main.dart', 'w') as file:
        file.write(content)
    
    return "Navigation back buttons fixed for main menu screens"

print(fix_navigation())
