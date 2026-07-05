import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'core/analysis_notification_service.dart';
import 'core/app_state.dart';
import 'core/auth_session.dart';
import 'core/auth_session_store.dart';
import 'core/cloud_backed_app_repository.dart';
import 'core/theme.dart';
import 'data/auth_api_client.dart';
import 'screen/base/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _preferAndroidPhotoPicker();
  final analysisNotifications = AnalysisNotificationService();
  final sessionStore = await AuthSessionStore.create();
  await sessionStore.loadSession();
  const authApiClient = AuthApiClient();
  await _ensureZanderSession(sessionStore, authApiClient);
  final repository = await CloudBackedAppRepository.create(sessionStore);
  final store = await AppStore.bootstrap(
    repository,
    sessionStore: sessionStore,
    authApiClient: authApiClient,
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

void _preferAndroidPhotoPicker() {
  final implementation = ImagePickerPlatform.instance;
  if (implementation is ImagePickerAndroid) {
    implementation.useAndroidPhotoPicker = true;
  }
}

Future<void> _ensureZanderSession(
  AuthSessionStore sessionStore,
  AuthApiClient authApiClient,
) async {
  final current = sessionStore.currentSession;
  if (current != null &&
      !current.isExpired &&
      !current.isLocalOnly &&
      current.username == 'zander') {
    return;
  }

  try {
    final session = await authApiClient.loginDefaultZander();
    await sessionStore.saveSession(session);
  } catch (error) {
    debugPrint('Default zander login failed, using local session: $error');
    await sessionStore.saveSession(AuthSession.localZander());
  }
  await sessionStore.clearRememberedLogin();
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
