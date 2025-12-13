import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/medication.dart';
import '../widgets/account_dialog.dart';
import '../widgets/day_strip.dart';
import '../widgets/medication_card.dart';
import '../services/notification_service.dart';

import 'add_medication_screen.dart';
import 'medication_detail_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Día seleccionado en el DayStrip (por defecto hoy)
  DateTime _selectedDay = DateTime.now();

  // Convierte weekday (1–7) a etiqueta corta usada en la app ("Lun", "Mar", ...)
  String _weekdayLabel(int weekday) {
    const labels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return labels[weekday - 1];
  }

  // Construye la clave usada en el mapa `taken` del medicamento
  // Formato: yyyy-MM-dd_HH:mm  (ej: 2025-12-12_08:00)
  String _takenKeyFor(DateTime day, String time) {
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    return '${dateStr}_$time';
  }

  // Marca solo la toma de esa hora como "tomada" (se guarda en medications/{id}.taken.{key} = true)
  Future<void> _markAsTaken(Medication med, String time) async {
    if (med.id == null) return;

    final key = _takenKeyFor(_selectedDay, time);

    await FirebaseFirestore.instance
        .collection('medications')
        .doc(med.id!)
        .update({'taken.$key': true});
  }

  // Elimina el medicamento y además cancela todas sus notificaciones programadas
  Future<void> _deleteMedication(Medication med) async {
    if (med.id == null) return;

    final id = med.id!;

    await FirebaseFirestore.instance.collection('medications').doc(id).delete();
    await NotificationService().cancelMedicationNotifications(id);
  }

  // Diálogo de confirmación antes de eliminar (se usa con Dismissible)
  Future<bool> _confirmAndDelete(Medication med) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Eliminar medicamento'),
        content: const Text('¿Seguro que deseas eliminar este medicamento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return false;

    try {
      await _deleteMedication(med);

      if (!mounted) return false;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Medicamento eliminado')));
      return true;
    } catch (e) {
      if (!mounted) return false;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      return false;
    }
  }

  // Abre pantalla para agregar medicamento manualmente
  void _openAddMedication() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddMedicationScreen()),
    );
  }

  // Abre pantalla para agregar medicamento pero disparando escaneo al entrar
  void _openScan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddMedicationScreen(autoScanOnOpen: true),
      ),
    );
  }

  // Confirma cierre de sesión y redirige al login
  Future<void> _confirmAndLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres cerrar tu sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Etiquetas para el header (fecha y día seleccionado)
    final dateLabel = DateFormat('EEE, d MMM', 'es').format(_selectedDay);
    final selectedDayLabel = _weekdayLabel(_selectedDay.weekday);

    // Usuario actual (si no existe, se muestra aviso)
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      // AppBar principal de la pantalla Home
      appBar: AppBar(
        title: Row(
          children: [
            // Logo pequeño (con fallback si falla el asset)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.local_hospital),
              ),
            ),
            const SizedBox(width: 8),
            const Text('MediScan'),
          ],
        ),
        actions: [
          // Botón para pruebas rápidas de notificaciones
          IconButton(
            icon: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.orange,
            ),
            tooltip: 'Probar notificaciones',
            onPressed: () async {
              // Aviso rápido (no bloqueante) para indicar que se ejecutarán pruebas
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🚀 Ejecutando pruebas de notificación...'),
                  duration: Duration(seconds: 2),
                ),
              );

              // Notificación inmediata
              await NotificationService().showImmediateTestNotification(
                medicationId: 'test1',
                name: 'Prueba Inmediata',
              );

              // Notificación programada a 10 segundos
              await NotificationService().scheduleTestNotification(
                medicationId: 'test2',
                name: 'Prueba 10 seg',
                seconds: 10,
              );
            },
          ),

          // Diálogo de cuenta (nombre/correo + reset password)
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Mi cuenta',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const AccountDialog(),
              );
            },
          ),

          // Cierre de sesión con confirmación
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: _confirmAndLogout,
          ),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Barra de selección de días (hoy, mañana, etc.)
            DayStrip(
              selectedDay: _selectedDay,
              onDaySelected: (day) {
                setState(() => _selectedDay = day);
              },
            ),

            const SizedBox(height: 12),

            // Header: fecha + botones de agregar/escanear
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _openAddMedication,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _openScan,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Escanear'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // Si no hay usuario autenticado, se muestra un mensaje simple
            if (user == null)
              const Expanded(
                child: Center(
                  child: Text(
                    'No hay usuario autenticado.\nVuelve a iniciar sesión.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Expanded(
                // StreamBuilder que escucha los medicamentos del usuario
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('medications')
                      .where('userId', isEqualTo: user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    // Estado de carga
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Estado de error
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error al cargar: ${snapshot.error}'),
                      );
                    }

                    // Documentos recibidos
                    final docs = snapshot.data?.docs ?? [];

                    // Parseo de Firestore -> Medication
                    final meds = docs
                        .map(
                          (d) => Medication.fromMap(
                            d.data() as Map<String, dynamic>,
                            id: d.id,
                          ),
                        )
                        .toList();

                    // Compatibilidad con etiquetas antiguas (L, M, X...) y nuevas (Lun, Mar, Mié...)
                    const legacyMap = {
                      'Lun': 'L',
                      'Mar': 'M',
                      'Mié': 'X',
                      'Jue': 'J',
                      'Vie': 'V',
                      'Sab': 'S',
                      'Sáb': 'S',
                      'Dom': 'D',
                    };
                    final legacyLabel =
                        legacyMap[selectedDayLabel] ?? selectedDayLabel;

                    // Lista final de tomas del día (medicamento + hora)
                    final dosesToday = <_DoseItem>[];

                    // Arma las tomas del día filtrando por día seleccionado
                    for (final med in meds) {
                      // Si el medicamento no aplica al día actual, se omite
                      if (!med.days.contains(selectedDayLabel) &&
                          !med.days.contains(legacyLabel)) {
                        continue;
                      }

                      // Para cada hora del medicamento, se crea una "toma" independiente
                      for (final t in med.times) {
                        final key = _takenKeyFor(_selectedDay, t);
                        final isTaken = med.taken[key] == true;

                        dosesToday.add(
                          _DoseItem(medication: med, time: t, isTaken: isTaken),
                        );
                      }
                    }

                    // Ordena por hora (string "HH:mm" funciona bien lexicográficamente)
                    dosesToday.sort((a, b) => a.time.compareTo(b.time));

                    // Conteo simple de pendientes para el subtitle del header
                    final pendingCount = dosesToday
                        .where((d) => !d.isTaken)
                        .length;

                    final headerSubtitle =
                        'Hoy · $pendingCount tomas pendientes';

                    return Column(
                      children: [
                        // Subtitle superior (pendientes del día)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              headerSubtitle,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),

                        // Lista de tomas (vacía o con cards)
                        Expanded(
                          child: dosesToday.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No hay tomas para este día.\nPulsa "Agregar" para registrar un medicamento.',
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: dosesToday.length,
                                  itemBuilder: (context, index) {
                                    final item = dosesToday[index];

                                    // Dismissible para eliminar (swipe a la izquierda)
                                    return Dismissible(
                                      key: Key(
                                        item.medication.id ??
                                            '${item.medication.name}-$index',
                                      ),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(
                                          right: 16,
                                        ),
                                        color: Colors.redAccent,
                                        child: const Icon(
                                          Icons.delete,
                                          color: Colors.white,
                                        ),
                                      ),

                                      // Confirma antes de eliminar
                                      confirmDismiss: (_) =>
                                          _confirmAndDelete(item.medication),

                                      // Card principal de la toma
                                      child: MedicationCard(
                                        medication: item.medication,
                                        time: item.time,
                                        isTaken: item.isTaken,

                                        // Abre detalle del medicamento
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  MedicationDetailScreen(
                                                    medication: item.medication,
                                                  ),
                                            ),
                                          );
                                        },

                                        // Marca como tomada la hora específica
                                        onTaken: () async {
                                          await _markAsTaken(
                                            item.medication,
                                            item.time,
                                          );
                                        },

                                        // Posponer: agenda recordatorio extra en 5 minutos
                                        onPostpone: () async {
                                          await NotificationService()
                                              .schedulePostponedNotification(
                                                medicationId:
                                                    item.medication.id ??
                                                    item.medication.name,
                                                name: item.medication.name,
                                                minutes: 5,
                                              );

                                          if (!mounted) return;

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Recordatorio pospuesto 5 minutos',
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Estructura interna para trabajar "tomas del día":
// Un medicamento puede tener varias horas, por eso se separa en items por hora.
class _DoseItem {
  final Medication medication;
  final String time;
  final bool isTaken;

  _DoseItem({
    required this.medication,
    required this.time,
    required this.isTaken,
  });
}
