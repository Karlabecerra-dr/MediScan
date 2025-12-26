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
import 'medications_screen.dart'; // Pantalla del listado total

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

  // Marca solo ESTA TOMA como "tomada" en Firestore usando el mapa `taken`
  Future<void> _markAsTaken(Medication med, String time) async {
    if (med.id == null) return;

    final key = _takenKeyFor(_selectedDay, time);

    await FirebaseFirestore.instance
        .collection('medications')
        .doc(med.id!)
        .update({'taken.$key': true});
  }

  // Elimina un medicamento en Firestore y cancela sus notificaciones
  Future<void> _deleteMedication(Medication med) async {
    if (med.id == null) return;

    final id = med.id!;

    await FirebaseFirestore.instance.collection('medications').doc(id).delete();
    await NotificationService().cancelMedicationNotifications(id);
  }

  // Confirmar y luego eliminar (para usar con Dismissible)
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

  void _openAddMedication() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddMedicationScreen()),
    );
  }

  void _openScan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddMedicationScreen(autoScanOnOpen: true),
      ),
    );
  }

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

  // Drawer del Home: por ahora solo una opción ("Medicamentos")
  Drawer _buildDrawer(User? user) {
    final displayName = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()
        : 'Mi cuenta';
    final email = user?.email ?? '';

    return Drawer(
      child: ListView(
        //Bloque: fecha + botones (sin overflow)
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(displayName),
            accountEmail: email.isEmpty ? null : Text(email),
            currentAccountPicture: const CircleAvatar(
              child: Icon(Icons.person),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.medication_outlined),
            title: const Text('Medicamentos'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, MedicationsScreen.routeName);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEE, d MMM', 'es').format(_selectedDay);
    final selectedDayLabel = _weekdayLabel(_selectedDay.weekday);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      drawer: _buildDrawer(user),
      appBar: AppBar(
        title: Row(
          children: [
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
          IconButton(
            icon: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.orange,
            ),
            tooltip: 'Probar notificaciones',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ejecutando pruebas de notificación...'),
                  duration: Duration(seconds: 2),
                ),
              );

              await NotificationService().showImmediateTestNotification(
                medicationId: 'test1',
                name: 'Prueba Inmediata',
              );

              await NotificationService().scheduleTestNotification(
                medicationId: 'test2',
                name: 'Prueba 10 seg',
                seconds: 10,
              );
            },
          ),
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

            // Franja de días (Lun..Dom)
            DayStrip(
              selectedDay: _selectedDay,
              onDaySelected: (day) => setState(() => _selectedDay = day),
            ),

            const SizedBox(height: 12),

            // Fecha + botones
            // Fecha + botones (fecha a la izquierda, botones a la derecha, sin overflow)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Fecha a la izquierda (se achica con ellipsis si falta espacio)
                  Expanded(
                    child: Text(
                      dateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Botones a la derecha (compactos). Si falta espacio, bajan sin romper.
                  Wrap(
                    spacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _openAddMedication,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text(
                          'Agregar',
                          style: TextStyle(fontSize: 13),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _openScan,
                        icon: const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          'Escanear',
                          style: TextStyle(fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // Si no hay usuario autenticado, mensaje (evita crasheos)
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
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('medications')
                      .where('userId', isEqualTo: user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error al cargar: ${snapshot.error}'),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    // Parse: documentos -> modelo Medication
                    final meds = docs
                        .map(
                          (d) => Medication.fromMap(
                            d.data() as Map<String, dynamic>,
                            id: d.id,
                          ),
                        )
                        .toList();

                    // Compatibilidad días: etiquetas nuevas y antiguas
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

                    // Construimos “tomas del día” (un medicamento puede tener varias horas)
                    final dosesToday = <_DoseItem>[];

                    for (final med in meds) {
                      // Filtra por día de la semana
                      if (!med.days.contains(selectedDayLabel) &&
                          !med.days.contains(legacyLabel)) {
                        continue;
                      }

                      // Por cada hora agregamos un item
                      for (final t in med.times) {
                        final key = _takenKeyFor(_selectedDay, t);
                        final isTaken = med.taken[key] == true;

                        dosesToday.add(
                          _DoseItem(medication: med, time: t, isTaken: isTaken),
                        );
                      }
                    }

                    dosesToday.sort((a, b) => a.time.compareTo(b.time));

                    final pendingCount = dosesToday
                        .where((d) => !d.isTaken)
                        .length;

                    final headerSubtitle =
                        'Hoy · $pendingCount tomas pendientes';

                    return Column(
                      children: [
                        // Subtítulo
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

                        // Lista de cards
                        Expanded(
                          child: dosesToday.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No hay tomas para este día.\nPulsa "Agregar" para registrar un medicamento.',
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    16,
                                  ),
                                  itemCount: dosesToday.length,
                                  itemBuilder: (context, index) {
                                    final item = dosesToday[index];

                                    // Dismissible para eliminar
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
                                      confirmDismiss: (_) =>
                                          _confirmAndDelete(item.medication),

                                      // ✅ AQUÍ iba el child (si no, se rompe todo)
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(18),
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
                                        child: MedicationCard(
                                          timeLabel: item.time,
                                          medicationName: item.medication.name,

                                          // ✅ Campos reales del modelo (según tu detail screen):
                                          dosageLabel:
                                              '${item.medication.dose} · ${item.medication.presentation}',

                                          statusLabel: item.isTaken
                                              ? 'Tomado'
                                              : 'Pendiente',

                                          onTake: () async {
                                            await _markAsTaken(
                                              item.medication,
                                              item.time,
                                            );
                                          },
                                          onSnooze: () async {
                                            // Captura antes del await para evitar el lint
                                            final messenger =
                                                ScaffoldMessenger.of(context);

                                            await NotificationService()
                                                .schedulePostponedNotification(
                                                  medicationId:
                                                      item.medication.id ??
                                                      item.medication.name,
                                                  name: item.medication.name,
                                                  minutes: 5,
                                                );

                                            if (!mounted) return;

                                            messenger.showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Recordatorio pospuesto 5 minutos',
                                                ),
                                              ),
                                            );
                                          },
                                        ),
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

// Estructura interna para “tomas del día”:
// un medicamento puede tener varias horas, por eso se separa en items por hora.
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
