import 'package:flutter/material.dart';

class AppNav {
  AppNav._();

  static const phoneChangeReversalRoute = '/security/phone-change/reverse';
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  static final _CurrentRouteObserver _routeObserver = _CurrentRouteObserver();

  static RouteObserver<ModalRoute<dynamic>> get routeObserver => _routeObserver;

  static bool get isOnPublicSecurityRoute =>
      _routeObserver.currentRouteName == phoneChangeReversalRoute;
}

class _CurrentRouteObserver extends RouteObserver<ModalRoute<dynamic>> {
  String? currentRouteName;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    currentRouteName = route.settings.name;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    currentRouteName = previousRoute?.settings.name;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    currentRouteName = newRoute?.settings.name;
  }
}
