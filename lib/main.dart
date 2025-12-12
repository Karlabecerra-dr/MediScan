import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'models/medication.dart';
import 'screens/home_screen.dart';
import 'screens/add_medication_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/medication_detail_screen.dart';
import 'screens/login_screen.dart';

// 👇 IMPORTA EL SERVICIO DE NOTIFICACIONES
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Necesario para usar DateFormat con 'es'
  await initializeDateFormatting('es', null);

  // 👇 INICIALIZAR NOTIFICACIONES (canal, timezone, permisos, etc.)
  await NotificationService().init();

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
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006875)),
      ),

      // Pantalla según si hay usuario logueado o no
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData) {
            return const HomeScreen();
          } else {
            return const LoginScreen();
          }
        },
      ),

      routes: {
        HomeScreen.routeName: (_) => const HomeScreen(),
        AddMedicationScreen.routeName: (_) => const AddMedicationScreen(),
        ScanScreen.routeName: (_) => const ScanScreen(),
        LoginScreen.routeName: (_) => const LoginScreen(),
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
