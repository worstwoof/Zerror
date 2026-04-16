import 'package:flutter/material.dart';

import 'core/app_state.dart';
import 'core/auth_session_store.dart';
import 'core/cloud_backed_app_repository.dart';
import 'core/theme.dart';
import 'data/auth_api_client.dart';
import 'screen/base/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sessionStore = await AuthSessionStore.create();
  await sessionStore.loadSession();
  final repository = await CloudBackedAppRepository.create(sessionStore);
  final store = await AppStore.bootstrap(
    repository,
    sessionStore: sessionStore,
    authApiClient: const AuthApiClient(),
  );
  runApp(ZerrorApp(store: store));
}

class ZerrorApp extends StatelessWidget {
  const ZerrorApp({
    super.key,
    required this.store,
  });

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      notifier: store,
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
