import 'package:flutter/material.dart';

class RouteAffinity<T> {
  const RouteAffinity({@required this.affinity, this.route});

  final double affinity;
  final PageRoute<T> route;
}

typedef RouteAffinityHandler<T> = RouteAffinity<T> Function(RouteSettings);

class Router {
  final List<RouteAffinityHandler<dynamic>> routeHandlers = List();

  PageRoute<T> routeFor<T>(RouteSettings routeSettings) {
    final RouteAffinity<dynamic> aff = routeHandlers.fold(null, (acc, x) {
      final result = x(routeSettings);
      if (acc == null) {
        return result;
      }

      return (acc.affinity >= result.affinity ? acc : result);
    });

    return (aff != null && aff.affinity > 0.0) ? aff.route : null;
  }

  Route<dynamic> generator(RouteSettings settings) {
    return this.routeFor(settings);
  }

  static RouteAffinityHandler<void> exactMatchFor(
      {@required String route,
      @required WidgetBuilder builder,
      WidgetBuilder bottomNavIcon,
      String bottomNavCaption,
      double affinity,
      bool maintainState = true,
      bool fullscreenDialog = false}) {
    return (settings) {
      if (settings.name != route) {
        return RouteAffinity(affinity: 0.0);
      }

      return RouteAffinity(
          affinity: affinity ?? 1.0,
          route: MaterialPageRoute(
              builder: builder,
              settings: settings,
              maintainState: maintainState,
              fullscreenDialog: fullscreenDialog));
    };
  }
}