import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/medication.dart';
import '../models/profile.dart';
import '../services/active_profile.dart';
import '../services/profile_service.dart';
import '../services/notification_service.dart';
import '../widgets/account_dialog.dart';
import '../widgets/day_strip.dart';
import '../widgets/medication_card.dart';

import 'add_medication_screen.dart';
import 'login_screen.dart';
import 'medication_detail_screen.dart';
import 'medications_screen.dart';
import 'profiles_screen.dart';

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Día seleccionado en el DayStrip (por defecto hoy)
  DateTime _selectedDay = DateTime.now();

  final _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
  }

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
    final activeId = ActiveProfile.activeProfileId.value;
    if (activeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cargando perfil activo...')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddMedicationScreen()),
    );
  }

  void _openScan() {
    if (ActiveProfile.activeProfileId.value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cargando perfil activo...')),
      );
      return;
    }

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

  Drawer _buildDrawer(User? user) {
    final displayName = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()
        : 'Mi cuenta';
    final email = user?.email ?? '';

    return Drawer(
      child: ListView(
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
            leading: const Icon(Icons.switch_account_outlined),
            title: const Text('Perfiles'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, ProfilesScreen.routeName);
            },
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

  Widget _profileHeader(String activeId) {
    return StreamBuilder<Profile?>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('profiles')
          .doc(activeId)
          .snapshots()
          .map((d) => d.exists ? Profile.fromMap(d.data()!, id: d.id) : null),
      builder: (context, snap) {
        final profileName = snap.data?.name ?? 'Perfil';

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              const Icon(Icons.person_pin_circle_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Perfil: $profileName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, ProfilesScreen.routeName),
                child: const Text('Cambiar'),
              ),
            ],
          ),
        );
      },
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
              final messenger = ScaffoldMessenger.of(context);

              messenger.showSnackBar(
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

            // Perfil activo (con Cambiar)
            ValueListenableBuilder<String?>(
              valueListenable: ActiveProfile.activeProfileId,
              builder: (context, activeId, _) {
                if (user == null) return const SizedBox.shrink();
                if (activeId == null) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: LinearProgressIndicator(minHeight: 2),
                  );
                }
                return _profileHeader(activeId);
              },
            ),

            const SizedBox(height: 4),

            // Fecha + botones (fecha izquierda, botones derecha, sin overflow)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
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
              // 🔥 Lista filtrada por perfil activo
              Expanded(
                child: ValueListenableBuilder<String?>(
                  valueListenable: ActiveProfile.activeProfileId,
                  builder: (context, activeProfileId, _) {
                    if (activeProfileId == null) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('medications')
                          .where('userId', isEqualTo: user.uid)
                          .where('profileId', isEqualTo: activeProfileId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error al cargar: ${snapshot.error}'),
                          );
                        }

                        final docs = snapshot.data?.docs ?? [];
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

                        final dosesToday = <_DoseItem>[];

                        for (final med in meds) {
                          if (!med.days.contains(selectedDayLabel) &&
                              !med.days.contains(legacyLabel)) {
                            continue;
                          }

                          for (final t in med.times) {
                            final key = _takenKeyFor(_selectedDay, t);
                            final isTaken = med.taken[key] == true;

                            dosesToday.add(
                              _DoseItem(
                                medication: med,
                                time: t,
                                isTaken: isTaken,
                              ),
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

                                        return Dismissible(
                                          key: Key(
                                            item.medication.id ??
                                                '${item.medication.name}-$index',
                                          ),
                                          direction:
                                              DismissDirection.endToStart,
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
                                              _confirmAndDelete(
                                                item.medication,
                                              ),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      MedicationDetailScreen(
                                                        medication:
                                                            item.medication,
                                                      ),
                                                ),
                                              );
                                            },
                                            child: MedicationCard(
                                              timeLabel: item.time,
                                              medicationName:
                                                  item.medication.name,
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
                                                final messenger =
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    );

                                                await NotificationService()
                                                    .schedulePostponedNotification(
                                                      medicationId:
                                                          item.medication.id ??
                                                          item.medication.name,
                                                      name:
                                                          item.medication.name,
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
