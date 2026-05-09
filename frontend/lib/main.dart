import 'dart:async';

import 'package:flutter/material.dart';

import 'core/analysis_notification_service.dart';
import 'core/app_state.dart';
import 'core/auth_session_store.dart';
import 'core/cloud_backed_app_repository.dart';
import 'core/theme.dart';
import 'data/auth_api_client.dart';
import 'screen/base/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final analysisNotifications = AnalysisNotificationService();
  final sessionStore = await AuthSessionStore.create();
  await sessionStore.loadSession();
  final repository = await CloudBackedAppRepository.create(sessionStore);
  final store = await AppStore.bootstrap(
    repository,
    sessionStore: sessionStore,
    authApiClient: const AuthApiClient(),
    analysisCompletionNotifier: analysisNotifications.notifyAnalysisCompleted,
    analysisProgressNotifier: analysisNotifications.showAnalysisProgress,
    analysisFailureNotifier: analysisNotifications.notifyAnalysisFailed,
    analysisNotificationCanceller:
        analysisNotifications.cancelAnalysisNotification,
  );
  runApp(
    ZerrorApp(
      store: store,
      analysisNotifications: analysisNotifications,
    ),
  );
}

class ZerrorApp extends StatefulWidget {
  const ZerrorApp({
    super.key,
    required this.store,
    required this.analysisNotifications,
  });

  final AppStore store;
  final AnalysisNotificationService analysisNotifications;

  @override
  State<ZerrorApp> createState() => _ZerrorAppState();
}

class _ZerrorAppState extends State<ZerrorApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.store.updateAppLifecycleState(AppLifecycleState.resumed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.analysisNotifications.requestPermissions());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.store.updateAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      notifier: widget.store,
      child: MaterialApp(
        title: 'Zerror',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
