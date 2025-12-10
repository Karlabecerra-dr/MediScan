import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
// 1. Imports necesarios para manejar las zonas horarias
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'firebase_options.dart';

// Imports de pantallas y modelo
import 'models/medication.dart';
import 'screens/home_screen.dart';
import 'screens/add_medication_screen.dart';
import 'screens/medication_detail_screen.dart';

// IMPORTANTE: Importar el servicio de notificaciones
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Cargar datos de formato de fechas en español
  await initializeDateFormatting('es');

  // 2. INICIALIZAR TIMEZONE (Obligatorio para que funcionen las alarmas)
  tz.initializeTimeZones();

  // Configuración para Chile (Correcto para Talca/Santiago)
  tz.setLocalLocation(tz.getLocation('America/Santiago'));

  debugPrint('🌍 Timezone configurado: ${tz.local.name}');

  // 🔔 3. INICIALIZAR SERVICIO DE NOTIFICACIONES
  // Esto crea los canales en Android y verifica permisos iniciales
  try {
    await NotificationService().init();
    debugPrint('✅ NotificationService inicializado correctamente');
  } catch (e) {
    debugPrint('❌ Error al inicializar NotificationService: $e');
  }

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

      initialRoute: HomeScreen.routeName,

      routes: {
        HomeScreen.routeName: (_) => const HomeScreen(),
        AddMedicationScreen.routeName: (_) => const AddMedicationScreen(),
        //ScanScreen.routeName: (_) => const ScanScreen(),
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
