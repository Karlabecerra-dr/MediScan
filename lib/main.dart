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
import 'screens/medications_screen.dart';
import 'screens/profiles_screen.dart';
import 'services/active_profile.dart';

// Servicio encargado de inicializar y manejar las notificaciones locales
import 'services/notification_service.dart';

Future<void> main() async {
  // Asegura que Flutter esté correctamente inicializado
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Firebase con la configuración correspondiente a la plataforma
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Habilita el formateo de fechas en español
  await initializeDateFormatting('es', null);

  // Inicializa el sistema de notificaciones (canales, permisos y timezone)
  await NotificationService().init();

  // Lanza la aplicación
  runApp(const MediScanApp());
}

class MediScanApp extends StatelessWidget {
  const MediScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Nombre de la aplicación
      title: 'MediScan',

      // Oculta el banner de debug
      debugShowCheckedModeBanner: false,

      // Tema global de la app
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006875)),
      ),

      // Pantalla inicial según estado de autenticación
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Mientras se valida la sesión
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // Usuario autenticado → Home
          if (snapshot.hasData) {
            return FutureBuilder<void>(
              future: ActiveProfile.initAndEnsure(),
              builder: (context, snap2) {
                if (snap2.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return const HomeScreen();
              },
            );
          }

          // Sin sesión → Login
          return const LoginScreen();
        },
      ),

      // Rutas simples de la aplicación
      routes: {
        HomeScreen.routeName: (_) => const HomeScreen(),
        AddMedicationScreen.routeName: (_) => const AddMedicationScreen(),
        ScanScreen.routeName: (_) => const ScanScreen(),
        LoginScreen.routeName: (_) => const LoginScreen(),
        MedicationsScreen.routeName: (_) => const MedicationsScreen(),
        ProfilesScreen.routeName: (_) => const ProfilesScreen(),
      },

      // Ruta con argumentos (detalle de medicamento)
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
