import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/supabase_service.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'screens/app_root.dart';

void main() async {
  // 1. Ensure Flutter is ready
  WidgetsFlutterBinding.ensureInitialized();

  // Avoid runtime font downloads (prevents crashes when offline)
  GoogleFonts.config.allowRuntimeFetching = false;

  // 2. Initialize Supabase (Your primary backend)
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint("Supabase Init Error: $e");
  }

  // 3. Initialize Notifications safely
  // This prevents the "PlatformException" from crashing the whole app
  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint("Notification Service Error: $e");
    debugPrint("Skipping notification init - app will still run.");
  }

  // 4. Initialize Background Tasks
  try {
    await BackgroundService.initialize();
    await BackgroundService.registerPeriodicTask();
  } catch (e) {
    debugPrint("Background Service Error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF2563EB);
    const Color bgLight = Color(0xFFF8FAFC);
    const Color surfaceWhite = Colors.white;
    const Color textDark = Color(0xFF0F172A);

    return MaterialApp(
      title: 'FidelShare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,

        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          primary: primaryBlue,
          surface: surfaceWhite,
        ),

        scaffoldBackgroundColor: bgLight,

        textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
          titleLarge: TextStyle(
            fontWeight: FontWeight.bold,
            color: textDark,
            fontSize: 22,
          ),
          bodyMedium: const TextStyle(color: Color(0xFF475569)),
        ),

        cardTheme: CardThemeData(
          color: surfaceWhite,
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.black.withOpacity(0.05)),
          ),
        ),

        appBarTheme: AppBarTheme(
          backgroundColor: bgLight,
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceWhite,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
          ),
        ),

        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: surfaceWhite,
          indicatorColor: primaryBlue.withOpacity(0.1),
          height: 70,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryBlue);
            }
            return const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey);
          }),
        ),
      ),
      home: const AppRoot(),
    );
  }
}