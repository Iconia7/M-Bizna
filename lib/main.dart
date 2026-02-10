import 'package:duka_manager/firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:duka_manager/providers/customer_provider.dart';
import 'package:duka_manager/providers/wallet_provider.dart';
import 'package:duka_manager/screens/setup_screen.dart';
import 'package:duka_manager/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/inventory_provider.dart';
import 'providers/sales_provider.dart';
import 'providers/report_provider.dart';
import 'providers/shop_provider.dart';
import 'screens/home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:duka_manager/providers/auth_provider.dart';
import 'package:duka_manager/providers/expense_provider.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'dart:ui';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Load .env
  await dotenv.load(fileName: "assets/.env");

  // 2. Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🚀 Pass all uncaught "fatal" errors from the framework to Crashlytics
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };
  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // 3. Initialize Notifications
  await NotificationService.initialize();

  // 4. Check if it's the first time running the app
  final prefs = await SharedPreferences.getInstance();
  bool isFirstRun = prefs.getBool('is_first_run') ?? true;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => SalesProvider()),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
        ChangeNotifierProvider(create: (_) => ShopProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProxyProvider<ShopProvider, WalletProvider>(
          create: (_) => WalletProvider(),
          update: (_, shop, wallet) {
            // Trigger listeners only if shopId is ready
            if (shop.shopId.isNotEmpty) {
              wallet!.startBalanceListener(shop.shopId);
              wallet.startHistoryListener(shop.shopId); // 👈 Added history listener
            }
            return wallet!;
          },
        ),
      ],
      // Pass isFirstRun to MyApp
      child: MyApp(isFirstRun: isFirstRun),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool isFirstRun; // 👈 Added this variable

  // Constructor updated to receive isFirstRun
  const MyApp({super.key, required this.isFirstRun});

  static const Color primaryOrange = Color(0xFFFF6B00);
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color cardGray = Color(0xFFF5F6F9);
  static const Color textDark = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'M-Bizna',
      theme: ThemeData(
        scaffoldBackgroundColor: backgroundWhite,
        primaryColor: primaryOrange,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryOrange,
          primary: primaryOrange,
          secondary: primaryOrange,
          surface: backgroundWhite, // Updated for Material 3
        ),
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: textDark,
          displayColor: textDark,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: backgroundWhite,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.poppins(
            color: textDark,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: const IconThemeData(color: textDark),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryOrange,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cardGray,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: primaryOrange,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryOrange,
          brightness: Brightness.dark,
          primary: primaryOrange,
          surface: const Color(0xFF1E1E1E),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF121212),
          elevation: 0,
          titleTextStyle: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system, // Auto-switch based on system settings
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      ],
      // Use the isFirstRun variable to decide initial screen
      home: isFirstRun ? SetupScreen() :  HomeScreen(),
    );
  }
}