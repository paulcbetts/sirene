import 'dart:io' show Platform;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:fluro/fluro.dart';
import 'package:sirene/debug-analytics.dart';

import 'package:sirene/interfaces.dart';
import 'package:sirene/services/login.dart';
import 'package:sirene/services/theming.dart';

import './pages/hello.dart';

class App extends State<AppWidget> {
  static GetIt locator;

  App() {
    locator = App.setupRegistration(GetIt());
  }

  static get analytics => App.locator<FirebaseAnalytics>();

  static setupRegistration(GetIt l) {
    final isTestMode = Platform.resolvedExecutable.contains("_tester");
    var isDebugMode = false;

    // NB: Assert statements are stripped from release mode. Clever!
    assert(isDebugMode = true);

    l.registerSingleton<Router>(setupRoutes(new Router()));
    l.registerSingleton<LoginManager>(new FirebaseLoginManager());

    final appMode = isTestMode
        ? ApplicationMode.Test
        : isDebugMode ? ApplicationMode.Debug : ApplicationMode.Production;

    l.registerSingleton<ApplicationMode>(appMode);

    if (appMode == ApplicationMode.Production) {
      l.registerSingleton<FirebaseAnalytics>(FirebaseAnalytics());
    } else {
      l.registerSingleton<FirebaseAnalytics>(DebugFirebaseAnalytics());
    }

    l.registerSingleton<RouteObserver>(
        new FirebaseAnalyticsObserver(analytics: l<FirebaseAnalytics>()));

    return l;
  }

  static setupRoutes(Router r) {
    HelloPage.setupRoutes(r);

    return r;
  }

  @override
  Widget build(BuildContext context) {
    final routeObserver = App.locator<RouteObserver>();

    return MaterialApp(
      title: 'Sirene',
      theme: ThemeMetrics.fullTheme(),
      initialRoute: '/',
      onGenerateRoute: App.locator<Router>().generator,
      navigatorObservers: routeObserver != null ? [routeObserver] : [],
    );
  }
}

class AppWidget extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => new App();
}
