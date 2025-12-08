import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';

// 👉 imports de tus pantallas y modelo
import 'models/medication.dart';
import 'screens/home_screen.dart';
import 'screens/add_medication_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/medication_detail_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Cargar datos de formato de fechas en español
  await initializeDateFormatting('es');

  runApp(const MediScanApp());
}

class MediScanApp extends StatelessWidget {
  const MediScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediScan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0083B0)),
        useMaterial3: true,
      ),

      // 👇 Asegúrate que en HomeScreen tengas:
      // static const routeName = '/';
      initialRoute: HomeScreen.routeName,

      routes: {
        HomeScreen.routeName: (_) => const HomeScreen(),
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
