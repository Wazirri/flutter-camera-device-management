import 'package:flutter/material.dart';

// Custom page transitions for smooth navigation
class AppPageTransitions {
  static const Duration defaultDuration = Duration(milliseconds: 300);

  // Slide up transition (for modals and detail pages)
  static Route<T> slideUp<T>(Widget page, {Duration? duration}) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration ?? defaultDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeOutQuint;
        
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);
        
        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    );
  }
  
  // Slide horizontal transition (for normal navigation)
  static Route<T> slideHorizontal<T>(Widget page, {Duration? duration, bool left = true}) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration ?? defaultDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var begin = Offset(left ? 1.0 : -1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;
        
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);
        
        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    );
  }
  
  // Fade transition (for less intrusive transitions)
  static Route<T> fade<T>(Widget page, {Duration? duration}) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration ?? defaultDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }
  
  // Scale and fade transition (for highlighting new content)
  static Route<T> scaleAndFade<T>(Widget page, {Duration? duration}) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration ?? defaultDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = 0.9;
        const end = 1.0;
        const curve = Curves.easeOutQuint;
        
        var scaleTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var scaleAnimation = animation.drive(scaleTween);
        
        return ScaleTransition(
          scale: scaleAnimation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }
  
  // Custom transition for camera views (zoom in effect)
  static Route<T> zoomIn<T>(Widget page, {Duration? duration, Offset? center}) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration ?? defaultDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeOutExpo;
        
        var scaleAnimation = Tween(begin: 0.0, end: 1.0)
          .chain(CurveTween(curve: curve))
          .animate(animation);
        
        return ScaleTransition(
          scale: scaleAnimation,
          alignment: center != null ? Alignment(center.dx, center.dy) : Alignment.center,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }
  
  // Shared axis transition (horizontal) for related content
  static Route<T> sharedAxisHorizontal<T>(Widget page, {Duration? duration}) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration ?? defaultDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const fadeCurve = Interval(0.0, 0.5, curve: Curves.easeInOut);
        const slideCurve = Curves.easeInOut;
        
        var fadeInAnimation = Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: fadeCurve))
            .animate(animation);
        
        var slideAnimation = Tween(begin: begin, end: end)
            .chain(CurveTween(curve: slideCurve))
            .animate(animation);
        
        return FadeTransition(
          opacity: fadeInAnimation,
          child: SlideTransition(
            position: slideAnimation,
            child: child,
          ),
        );
      },
    );
  }
}

// Extension for BuildContext to make navigation with transitions easier
extension NavigatorExtension on BuildContext {
  // Push with transition
  Future<T?> pushWithTransition<T>(Widget page, {
    PageTransitionType type = PageTransitionType.rightToLeft,
    Duration? duration,
    Offset? center,
  }) {
    switch (type) {
      case PageTransitionType.fadeIn:
        return Navigator.of(this).push(AppPageTransitions.fade<T>(page, duration: duration));
      case PageTransitionType.slideUp:
        return Navigator.of(this).push(AppPageTransitions.slideUp<T>(page, duration: duration));
      case PageTransitionType.rightToLeft:
        return Navigator.of(this).push(AppPageTransitions.slideHorizontal<T>(page, duration: duration));
      case PageTransitionType.leftToRight:
        return Navigator.of(this).push(AppPageTransitions.slideHorizontal<T>(page, duration: duration, left: false));
      case PageTransitionType.scaleAndFade:
        return Navigator.of(this).push(AppPageTransitions.scaleAndFade<T>(page, duration: duration));
      case PageTransitionType.zoomIn:
        return Navigator.of(this).push(AppPageTransitions.zoomIn<T>(page, duration: duration, center: center));
      case PageTransitionType.sharedAxis:
        return Navigator.of(this).push(AppPageTransitions.sharedAxisHorizontal<T>(page, duration: duration));
    }
  }
  
  // Push replacement with transition
  Future<T?> pushReplacementWithTransition<T, TO>(Widget page, {
    PageTransitionType type = PageTransitionType.rightToLeft,
    Duration? duration,
    Offset? center,
  }) {
    switch (type) {
      case PageTransitionType.fadeIn:
        return Navigator.of(this).pushReplacement(AppPageTransitions.fade<T>(page, duration: duration));
      case PageTransitionType.slideUp:
        return Navigator.of(this).pushReplacement(AppPageTransitions.slideUp<T>(page, duration: duration));
      case PageTransitionType.rightToLeft:
        return Navigator.of(this).pushReplacement(AppPageTransitions.slideHorizontal<T>(page, duration: duration));
      case PageTransitionType.leftToRight:
        return Navigator.of(this).pushReplacement(AppPageTransitions.slideHorizontal<T>(page, duration: duration, left: false));
      case PageTransitionType.scaleAndFade:
        return Navigator.of(this).pushReplacement(AppPageTransitions.scaleAndFade<T>(page, duration: duration));
      case PageTransitionType.zoomIn:
        return Navigator.of(this).pushReplacement(AppPageTransitions.zoomIn<T>(page, duration: duration, center: center));
      case PageTransitionType.sharedAxis:
        return Navigator.of(this).pushReplacement(AppPageTransitions.sharedAxisHorizontal<T>(page, duration: duration));
    }
  }
}

// Enum for different transition types
enum PageTransitionType {
  fadeIn,
  slideUp,
  rightToLeft,
  leftToRight,
  scaleAndFade,
  zoomIn,
  sharedAxis,
}
