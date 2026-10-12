import 'package:flutter/material.dart';

import '../../../core/nav/app_nav.dart';

/// Tracks whether a scheduled-care surface is the top-most route.
///
/// Navigator keeps covered routes mounted, so widget lifetime alone is not a
/// sufficient signal for targeted realtime refreshes.
mixin ScheduledCareRouteVisibility<T extends StatefulWidget> on State<T>
    implements RouteAware {
  ModalRoute<dynamic>? _realtimeRoute;

  void onScheduledCareRouteVisibilityChanged(bool visible);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextRoute = ModalRoute.of(context);
    if (!identical(nextRoute, _realtimeRoute)) {
      if (_realtimeRoute != null) {
        AppNav.routeObserver.unsubscribe(this);
      }
      _realtimeRoute = nextRoute;
      if (nextRoute != null) AppNav.routeObserver.subscribe(this, nextRoute);
    }
    onScheduledCareRouteVisibilityChanged(nextRoute?.isCurrent ?? true);
  }

  @override
  void didPush() => onScheduledCareRouteVisibilityChanged(true);

  @override
  void didPopNext() => onScheduledCareRouteVisibilityChanged(true);

  @override
  void didPushNext() => onScheduledCareRouteVisibilityChanged(false);

  @override
  void didPop() => onScheduledCareRouteVisibilityChanged(false);

  @override
  void dispose() {
    if (_realtimeRoute != null) AppNav.routeObserver.unsubscribe(this);
    super.dispose();
  }
}
