import 'package:flutter/material.dart';

class AppPageTransitions {
  // Simple fade transition
  static PageRouteBuilder fade(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  // Slide up from bottom
  static PageRouteBuilder slideUp(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end);
        final offsetAnimation = animation.drive(tween);
        
        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  // Horizontal slide (left to right or right to left, based on current route index)
  static PageRouteBuilder slideHorizontal(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end);
        final offsetAnimation = animation.drive(tween);
        
        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  // Scale and fade combined (good for dialogs or settings pages)
  static PageRouteBuilder scaleAndFade(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
        );
        
        final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ),
        );
        
        return FadeTransition(
          opacity: fadeAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }

  // Zoom in transition (good for detail views)
  static PageRouteBuilder zoomIn(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween<double>(begin: 0.0, end: 1.0).chain(
          CurveTween(curve: Curves.fastOutSlowIn),
        );
        
        return ScaleTransition(
          scale: animation.drive(tween),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  // Shared axis transition (horizontal)
  static PageRouteBuilder sharedAxisHorizontal(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
          ),
        );
        
        final fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
          CurvedAnimation(
            parent: secondaryAnimation,
            curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
          ),
        );
        
        final slideIn = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.fastOutSlowIn,
          ),
        );
        
        final slideOut = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-1.0, 0.0),
        ).animate(
          CurvedAnimation(
            parent: secondaryAnimation,
            curve: Curves.fastOutSlowIn,
          ),
        );
        
        return Stack(
          children: [
            FadeTransition(
              opacity: fadeOut,
              child: SlideTransition(
                position: slideOut,
                child: Container(color: Colors.transparent),
              ),
            ),
            FadeTransition(
              opacity: fadeIn,
              child: SlideTransition(
                position: slideIn,
                child: child,
              ),
            ),
          ],
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  // Custom transition for specific needs
  static PageRouteBuilder custom({
    required Widget page,
    required Widget Function(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) transitionsBuilder,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: transitionsBuilder,
      transitionDuration: duration,
    );
  }
}
