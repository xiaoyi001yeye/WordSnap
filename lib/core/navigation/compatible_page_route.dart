import 'package:flutter/material.dart';

class CompatiblePageRoute<T> extends PageRouteBuilder<T> {
  CompatiblePageRoute({
    required Widget child,
    PageTransitionType transitionType = PageTransitionType.fade,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            switch (transitionType) {
              case PageTransitionType.fade:
                return FadeTransition(
                  opacity: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOut,
                  ),
                  child: child,
                );
              case PageTransitionType.slide:
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: child,
                );
              case PageTransitionType.slideUp:
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              case PageTransitionType.none:
                return child;
            }
          },
        );
}

enum PageTransitionType {
  fade,
  slide,
  slideUp,
  none,
}

class CompatibleNavigator {
  static Future<T?> push<T>(
    BuildContext context,
    Widget child, {
    PageTransitionType transitionType = PageTransitionType.fade,
  }) {
    return Navigator.of(context).push<T>(
      CompatiblePageRoute<T>(
        child: child,
        transitionType: transitionType,
      ),
    );
  }

  static Future<T?> pushReplacement<T, TO>(
    BuildContext context,
    Widget child, {
    PageTransitionType transitionType = PageTransitionType.fade,
    TO? result,
  }) {
    return Navigator.of(context).pushReplacement<T, TO>(
      CompatiblePageRoute<T>(
        child: child,
        transitionType: transitionType,
      ),
      result: result,
    );
  }
}
