import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'services/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/timeline_screen.dart';
import 'screens/family_screen.dart';
import 'screens/search_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/did_screen.dart';
import 'screens/dao_screen.dart';
import 'screens/darkweb_screen.dart';
import 'screens/smart_import_screen.dart';
import 'screens/reminders_screen.dart';
import 'screens/ar_scanner_screen.dart';
import 'screens/leak_check_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const PrivacyShieldApp());
}

class PrivacyShieldApp extends StatelessWidget {
  const PrivacyShieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'PrivacyShield',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        initialRoute: '/',
        routes: {
          '/': (_) => const SplashScreen(),
          '/login': (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
          '/home': (_) => const HomeScreen(),
          '/notifications': (_) => const NotificationsScreen(),
          '/timeline': (_) => const TimelineScreen(),
          '/family': (_) => const FamilyScreen(),
          '/search': (_) => const SearchScreen(),
          '/reports': (_) => const ReportsScreen(),
          '/did': (_) => const DIDScreen(),
          '/dao': (_) => const DAOScreen(),
          '/darkweb': (_) => const DarkWebScreen(),
          '/smart-import': (_) => const SmartImportScreen(),
          '/reminders': (_) => const RemindersScreen(),
          '/ar-scanner': (_) => const ARScannerScreen(),
          '/leak-check': (_) => const LeakCheckScreen(),
        },
      ),
    );
  }
}
