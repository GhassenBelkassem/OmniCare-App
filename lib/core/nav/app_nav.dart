import 'package:flutter/foundation.dart';
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

  /// G-1 D2: true while the patient home ('/home') is in the root stack, so
  /// a window is never opened over the splash, login or onboarding screens.
  static ValueListenable<bool> get patientHomeInStack =>
      _routeObserver.homeInStack;
}

class _CurrentRouteObserver extends RouteObserver<ModalRoute<dynamic>> {
  String? currentRouteName;
  final ValueNotifier<bool> homeInStack = ValueNotifier<bool>(false);
  final List<Route<dynamic>> _stack = <Route<dynamic>>[];

  void _syncHome() {
    homeInStack.value = _stack.any((route) => route.settings.name == '/home');
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    currentRouteName = route.settings.name;
    _stack.add(route);
    _syncHome();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    currentRouteName = previousRoute?.settings.name;
    _stack.remove(route);
    _syncHome();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _stack.remove(route);
    _syncHome();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    currentRouteName = newRoute?.settings.name;
    final index = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (index >= 0) _stack.removeAt(index);
    if (newRoute != null) {
      _stack.insert(index >= 0 ? index : _stack.length, newRoute);
    }
    _syncHome();
  }
}
