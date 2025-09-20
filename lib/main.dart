import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'api_service.dart';
import 'job_offer.dart';
import 'job_offer.g.dart';
import 'job_offers_list_screen.dart';
import 'job_offer_detail_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();
  Hive.registerAdapter(JobOfferAdapter());
  await Hive.openBox<JobOffer>('job_offers');
  await Hive.openBox<int>('saved_offer_ids');
  await initializeDateFormatting('pl', null);

  final api = await ApiService.create();

  runApp(ChangeNotifierProvider<ApiService>.value(
    value: api,
    child: const MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;
  void _onThemeChanged(ThemeMode mode) => setState(() => _themeMode = mode);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JobSeeker',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.light)),
      darkTheme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark)),
      initialRoute: '/jobs',
      routes: {
        '/': (_) => const LoginScreen(),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/jobs': (_) => const JobOffersListScreen(),
        '/settings': (_) => SettingsScreen(onTheme: _onThemeChanged),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/detail') {
          final args = settings.arguments;
          if (args is JobOffer) {
            return MaterialPageRoute(builder: (_) => JobOfferDetailScreen(offer: args));
          }
          return MaterialPageRoute(builder: (_) => const JobOffersListScreen());
        }
        return null;
      },
      onUnknownRoute: (settings) => MaterialPageRoute(builder: (_) => const JobOffersListScreen()),
    );
  }
}
