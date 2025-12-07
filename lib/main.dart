import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart'; // 👈 NUEVO

import 'screens/home_screen.dart';
import 'screens/add_medication_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/medication_detail_screen.dart';
import 'models/medication.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MediScanApp());
}

class MediScanApp extends StatelessWidget {
  const MediScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData.light(useMaterial3: true);

    return MaterialApp(
      title: 'MediScan',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        colorScheme: baseTheme.colorScheme.copyWith(
          primary: const Color(0xFF1E88E5),
          secondary: const Color(0xFF26C6DA),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.black,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        AddMedicationScreen.routeName: (_) => const AddMedicationScreen(),
        ScanScreen.routeName: (_) => const ScanScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == MedicationDetailScreen.routeName) {
          final med = settings.arguments as Medication;
          return MaterialPageRoute(
            builder: (_) => MedicationDetailScreen(medication: med),
          );
        }
        return null;
      },
    );
  }
}
