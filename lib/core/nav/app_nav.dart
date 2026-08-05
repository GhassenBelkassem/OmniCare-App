import 'package:flutter/material.dart';

class AppNav {
  AppNav._();

  static const phoneChangeReversalRoute = '/security/phone-change/reverse';
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final _CurrentRouteObserver _routeObserver = _CurrentRouteObserver();

  static NavigatorObserver get routeObserver => _routeObserver;

  static bool get isOnPublicSecurityRoute =>
      _routeObserver.currentRouteName == phoneChangeReversalRoute;
}

class _CurrentRouteObserver extends NavigatorObserver {
  String? currentRouteName;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentRouteName = route.settings.name;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentRouteName = previousRoute?.settings.name;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    currentRouteName = newRoute?.settings.name;
  }
}
