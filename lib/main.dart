import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:etecsa/config/config.dart';
import 'package:etecsa/config/theme/theme_preferences.dart';
import 'package:etecsa/config/theme/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Forzar portrait en toda la app (es un POS, no necesita landscape)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  try {
    await Environment.initEnvironment();
  } catch (e) {
    debugPrint('Error initEnvironment: $e');
  }

  // Seed la preferencia de tema persistida antes del primer frame:
  // evita el flash del tema incorrecto y alimenta el default del provider.
  try {
    ThemePrefs.initialMode = await ThemePreferenceStore.read();
  } catch (e) {
    debugPrint('Error reading theme preference: $e');
  }

  runApp(
    const ProviderScope(child: MainApp())
  );
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hamburguesaTheme = ref.watch(hamburguesaThemeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      routerConfig: appRouter,
      theme: hamburguesaTheme.light,
      darkTheme: hamburguesaTheme.dark,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es'),
        Locale('en'),
      ],
      locale: const Locale('es'),
    );
  }
}