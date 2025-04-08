#!/usr/bin/env python3

with open('lib/main.dart', 'r') as file:
    content = file.read()

# Fix indentation in MaterialApp
fixed_app_start = """  @override
  Widget build(BuildContext context) {
    return KeyboardFixWrapper(
      child: MaterialApp(
        title: 'movita ECS',
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        initialRoute: '/login',
        onGenerateRoute: (settings) {
          // Define custom page transitions for different routes
          Widget page;
          
          switch(settings.name) {"""

old_app_start = """  @override
  Widget build(BuildContext context) {
    return KeyboardFixWrapper(
      child: MaterialApp(
      title: 'movita ECS',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      onGenerateRoute: (settings) {
        // Define custom page transitions for different routes
        Widget page;
        
        switch(settings.name) {"""

# Fix the excessive closing parentheses at the end
old_app_end = """        }
      },
    ),
    ),
    );
  }
}"""

fixed_app_end = """        }
      },
    ),
    );
  }
}"""

# Apply fixes
content = content.replace(old_app_start, fixed_app_start)
content = content.replace(old_app_end, fixed_app_end)

# Write the fixed content back to the file
with open('lib/main.dart', 'w') as file:
    file.write(content)

print("Fixed indentation and parentheses in main.dart")
