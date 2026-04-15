import 'package:flutter/material.dart';

import 'core/app_state.dart';
import 'core/cloud_backed_app_repository.dart';
import 'core/theme.dart';
import 'screen/base/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await CloudBackedAppRepository.create();
  final store = await AppStore.bootstrap(repository);
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
