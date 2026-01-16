import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // [NEW]
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/language_service.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await initializeDateFormatting('tr_TR', null);
  
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: .env file not found");
  }

  await LanguageService().init();
  NotificationService().init(); // [FIX] Don't await, prevents hang on network error
  await ThemeService().init();

  runApp(const AllofCarApp());
}


class AllofCarApp extends StatefulWidget {
  const AllofCarApp({super.key});

  @override
  State<AllofCarApp> createState() => _AllofCarAppState();
}



// ... (existing imports)

class _AllofCarAppState extends State<AllofCarApp> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService().languageNotifier,
      builder: (context, languageCode, child) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeService().themeModeNotifier,
          builder: (context, themeMode, _) {
            return MaterialApp(
              navigatorKey: navigatorKey,
              debugShowCheckedModeBanner: false,
              title: 'AllofCar',
              themeMode: themeMode,
              // [NEW] Localization Setup
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('en', ''), // English
                Locale('tr', ''), // Turkish
              ],
              locale: Locale(languageCode), // Force current language
              theme: ThemeData(
                useMaterial3: true,
                scaffoldBackgroundColor: Colors.white,
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF0059BC),
                  secondary: Color(0xFF0059BC),
                  surface: Colors.white,
                  onPrimary: Colors.white,
                  onSurface: Colors.black,
                ),
                cardColor: Colors.white,
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                ),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
                scaffoldBackgroundColor: const Color(0xFF121212),
                colorScheme: const ColorScheme.dark(
                  primary: Color(0xFF0059BC),
                  secondary: Color(0xFF0059BC),
                  surface: Color(0xFF1E1E1E),
                  onPrimary: Colors.white,
                  onSurface: Colors.white,
                ),
                cardColor: const Color(0xFF1E1E1E),
                dividerColor: Colors.white24,
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF121212),
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                  backgroundColor: Color(0xFF1E1E1E),
                  selectedItemColor: Color(0xFF0059BC),
                  unselectedItemColor: Colors.grey,
                ),
              ),
              builder: (context, child) {
                return GestureDetector(
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                  child: child,
                );
              },
              home: const SplashScreen(),
            );
          },
        );
      },
    );
  }
}
