import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/medication.dart';
import '../models/profile.dart';
import '../services/active_profile.dart';
import '../services/profile_service.dart';
import 'medication_detail_screen.dart';
import 'profiles_screen.dart';

class MedicationsScreen extends StatelessWidget {
  static const routeName = '/medications';

  const MedicationsScreen({super.key});

  String _formatDays(List<String> days) {
    if (days.isEmpty) return '—';
    const order = [
      'Lun',
      'Mar',
      'Mié',
      'Jue',
      'Vie',
      'Sáb',
      'Dom',
      'L',
      'M',
      'X',
      'J',
      'V',
      'S',
      'D',
    ];
    final sorted = [...days]
      ..sort((a, b) {
        final ia = order.indexOf(a);
        final ib = order.indexOf(b);
        if (ia == -1 && ib == -1) return a.compareTo(b);
        if (ia == -1) return 1;
        if (ib == -1) return -1;
        return ia.compareTo(ib);
      });
    return sorted.join(', ');
  }

  String _formatTimes(List<String> times) {
    if (times.isEmpty) return '—';
    final sorted = [...times]..sort();
    return sorted.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final profileService = ProfileService();

    return Scaffold(
      appBar: AppBar(title: const Text('Medicamentos')),
      body: SafeArea(
        child: user == null
            ? const Center(
                child: Text(
                  'No hay usuario autenticado.\nVuelve a iniciar sesión.',
                  textAlign: TextAlign.center,
                ),
              )
            : FutureBuilder<void>(
                // ✅ asegura perfil activo incluso si entran directo a esta pantalla
                future: ActiveProfile.initAndEnsure(),
                builder: (context, initSnap) {
                  if (initSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return ValueListenableBuilder<String?>(
                    valueListenable: ActiveProfile.activeProfileId,
                    builder: (context, activeProfileId, _) {
                      if (activeProfileId == null) {
                        return const Center(
                          child: Text('No hay perfil activo. Ve a “Perfiles”.'),
                        );
                      }

                      return Column(
                        children: [
                          // Header de perfil activo
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: FutureBuilder<Profile?>(
                                    future: profileService.getProfileById(
                                      activeProfileId,
                                    ),
                                    builder: (context, snap) {
                                      final name = snap.data?.name ?? 'Perfil';
                                      return Text(
                                        'Perfil: $name',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    ProfilesScreen.routeName,
                                  ),
                                  child: const Text('Cambiar'),
                                ),
                              ],
                            ),
                          ),

                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('medications')
                                  .where('userId', isEqualTo: user.uid)
                                  .where(
                                    'profileId',
                                    isEqualTo: activeProfileId,
                                  )
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
                                    child: Text(
                                      'Error al cargar: ${snapshot.error}',
                                    ),
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

                                meds.sort(
                                  (a, b) => a.name.toLowerCase().compareTo(
                                    b.name.toLowerCase(),
                                  ),
                                );

                                if (meds.isEmpty) {
                                  return const Center(
                                    child: Text(
                                      'Aún no tienes medicamentos en este perfil.\nVuelve al Home y presiona "Agregar".',
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                }

                                return ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: meds.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final med = meds[index];

                                    final daysText = _formatDays(med.days);
                                    final timesText = _formatTimes(med.times);

                                    return Card(
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        side: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 8,
                                            ),
                                        leading: const Icon(
                                          Icons.medication_outlined,
                                        ),
                                        title: Text(
                                          med.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        subtitle: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 6,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('Días: $daysText'),
                                              const SizedBox(height: 2),
                                              Text('Horarios: $timesText'),
                                            ],
                                          ),
                                        ),
                                        trailing: const Icon(
                                          Icons.chevron_right,
                                        ),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  MedicationDetailScreen(
                                                    medication: med,
                                                  ),
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  },
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
    );
  }
}
