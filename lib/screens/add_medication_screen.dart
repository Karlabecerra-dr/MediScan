import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/medication.dart';
import '../services/notification_service.dart';
import 'scan_screen.dart';

class AddMedicationScreen extends StatefulWidget {
  static const routeName = '/add-medication';

  final Medication? medication;
  final bool autoScanOnOpen;

  const AddMedicationScreen({
    super.key,
    this.medication,
    this.autoScanOnOpen = false,
  });

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _medIdCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _doseCtrl = TextEditingController();
  final _presentationCtrl = TextEditingController(text: 'Tableta');
  final _descriptionCtrl = TextEditingController();

  late List<String> _selectedDays;
  late List<TimeOfDay> _times;

  bool get _isEditing => widget.medication != null;

  @override
  void initState() {
    super.initState();

    const allDays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

    final med = widget.medication;

    if (med != null) {
      // MODO EDICIÓN
      _medIdCtrl.text = med.medId ?? '';
      _nameCtrl.text = med.name;
      _doseCtrl.text = med.dose;
      _presentationCtrl.text = med.presentation;
      _descriptionCtrl.text = med.description ?? '';

      _selectedDays = List<String>.from(med.days);

      _times = med.times.map((t) {
        final parts = t.split(':');
        final hour = int.tryParse(parts.first) ?? 0;
        final minute = int.tryParse(parts.last) ?? 0;
        return TimeOfDay(hour: hour, minute: minute);
      }).toList();

      if (_times.isEmpty) {
        _times = [const TimeOfDay(hour: 8, minute: 0)];
      }
    } else {
      // NUEVO
      _selectedDays = List<String>.from(allDays);
      _times = [const TimeOfDay(hour: 8, minute: 0)];
    }

    // Si venimos desde el botón "Escanear" del Home,
    // abrimos la cámara automáticamente al entrar (solo en modo nuevo).
    if (widget.autoScanOnOpen && !_isEditing) {
      // microtask para que espere a que se construya el widget
      Future.microtask(_handleScan);
    }
  }

  @override
  void dispose() {
    _medIdCtrl.dispose();
    _nameCtrl.dispose();
    _doseCtrl.dispose();
    _presentationCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  String _timeToString(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _handleScan() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );

    if (!mounted) return;
    if (code == null || code.isEmpty) return;

    setState(() {
      _medIdCtrl.text = code;
    });

    // Intentar autocompletar desde catálogo
    await _loadFromCatalog(code);
  }

  Future<void> _loadFromCatalog(String medId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('med_catalog')
          .doc(medId)
          .get();

      if (!doc.exists) return;

      final data = doc.data() ?? {};

      if (!mounted) return;

      setState(() {
        if (_nameCtrl.text.trim().isEmpty) {
          _nameCtrl.text = data['name'] ?? '';
        }
        if (_doseCtrl.text.trim().isEmpty) {
          _doseCtrl.text = data['dose'] ?? '';
        }
        if (_presentationCtrl.text.trim().isEmpty) {
          _presentationCtrl.text = data['presentation'] ?? 'Tableta';
        }
        if (_descriptionCtrl.text.trim().isEmpty) {
          _descriptionCtrl.text = data['description'] ?? '';
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar desde el catálogo: $e')),
      );
    }
  }

  Future<void> _upsertCatalog(String medId, Medication med) async {
    try {
      await FirebaseFirestore.instance
          .collection('med_catalog')
          .doc(medId)
          .set({
            'name': med.name,
            'dose': med.dose,
            'presentation': med.presentation,
            'description': med.description,
          }, SetOptions(merge: true));
    } catch (e) {
      // No rompemos el flujo si el catálogo falla, solo log / snackbar opcional
      debugPrint('Error actualizando catálogo: $e');
    }
  }

  Future<void> _pickTime(int index) async {
    final current = _times[index];

    final picked = await showTimePicker(context: context, initialTime: current);

    if (picked != null) {
      setState(() {
        _times[index] = picked;
      });
    }
  }

  void _addTime() {
    setState(() {
      _times.add(const TimeOfDay(hour: 12, minute: 0));
    });
  }

  void _removeTime(int index) {
    setState(() {
      if (_times.length > 1) {
        _times.removeAt(index);
      }
    });
  }

  Future<void> _saveMedicationToFirestore() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un día.')),
      );
      return;
    }

    // Por ahora SOLO soportamos "Horas específicas"
    // Si en el futuro agregamos "Cada X horas", aquí habrá lógica extra.

    final timesStr = _times.map(_timeToString).toList();

    final medId = _medIdCtrl.text.trim().isEmpty
        ? null
        : _medIdCtrl.text.trim();

    final name = _nameCtrl.text.trim();
    final dose = _doseCtrl.text.trim();
    final presentation = _presentationCtrl.text.trim().isEmpty
        ? 'Tableta'
        : _presentationCtrl.text.trim();
    final description = _descriptionCtrl.text.trim().isEmpty
        ? null
        : _descriptionCtrl.text.trim();

    final medsCollection = FirebaseFirestore.instance.collection('medications');

    try {
      Medication finalMed;

      if (_isEditing) {
        // EDITAR
        final original = widget.medication!;

        final updated = Medication(
          id: original.id,
          medId: medId,
          name: name,
          dose: dose,
          presentation: presentation,
          days: List<String>.from(_selectedDays),
          times: timesStr,
          status: original.status,
          description: description,
          taken: original.taken,
        );

        if (original.id != null) {
          await medsCollection.doc(original.id).update(updated.toMap());

          // Reprogramar notificaciones
          await NotificationService().cancelMedicationNotifications(
            original.id!,
          );

          await NotificationService().scheduleMedication(
            medicationId: updated.id!,
            name: updated.name,
            days: updated.days,
            times: updated.times,
          );
        }

        finalMed = updated;
      } else {
        // CREAR
        final newMed = Medication(
          medId: medId,
          name: name,
          dose: dose,
          presentation: presentation,
          days: List<String>.from(_selectedDays),
          times: timesStr,
          status: 'pendiente',
          description: description,
          taken: const {},
        );

        final docRef = await medsCollection.add(newMed.toMap());

        final created = Medication(
          id: docRef.id,
          medId: newMed.medId,
          name: newMed.name,
          dose: newMed.dose,
          presentation: newMed.presentation,
          days: newMed.days,
          times: newMed.times,
          status: newMed.status,
          description: newMed.description,
          taken: newMed.taken,
        );

        await NotificationService().scheduleMedication(
          medicationId: created.id!,
          name: created.name,
          days: created.days,
          times: created.times,
        );

        finalMed = created;
      }

      // Actualizar catálogo colaborativo si hay medId
      if (medId != null) {
        await _upsertCatalog(medId, finalMed);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Medicamento actualizado correctamente'
                : 'Medicamento creado correctamente',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _isEditing;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar medicamento' : 'Agregar medicamento'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ID de medicamento (escaneo)
            TextFormField(
              controller: _medIdCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'ID del medicamento (escaneo)',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  onPressed: _handleScan,
                  tooltip: 'Escanear código',
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Nombre
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del medicamento *',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa el nombre del medicamento';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Dosis
            TextFormField(
              controller: _doseCtrl,
              decoration: const InputDecoration(labelText: 'Dosis *'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa la dosis';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Presentación
            TextFormField(
              controller: _presentationCtrl,
              decoration: const InputDecoration(labelText: 'Presentación'),
            ),
            const SizedBox(height: 16),

            // Descripción
            TextFormField(
              controller: _descriptionCtrl,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Días de la semana
            const Text(
              'Días de la semana',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'].map((
                day,
              ) {
                final selected = _selectedDays.contains(day);
                return ChoiceChip(
                  label: Text(day),
                  selected: selected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        if (!_selectedDays.contains(day)) {
                          _selectedDays.add(day);
                        }
                      } else {
                        _selectedDays.remove(day);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Horario de toma
            const Text(
              'Horario de toma',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                ChoiceChip(
                  label: const Text('Horas específicas'),
                  selected: true, // por ahora siempre este modo
                  onSelected: (_) {},
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Cada X horas'),
                  selected: false,
                  onSelected: (_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'El modo "Cada X horas" aún no está implementado.',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Lista de horas específicas
            ..._times.asMap().entries.map((entry) {
              final index = entry.key;
              final time = entry.value;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.access_time),
                      onPressed: () => _pickTime(index),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time.format(context),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removeTime(index),
                    ),
                  ],
                ),
              );
            }).toList(),

            TextButton.icon(
              onPressed: _addTime,
              icon: const Icon(Icons.add),
              label: const Text('Agregar hora'),
            ),

            const SizedBox(height: 24),

            // Botones Guardar / Cancelar
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saveMedicationToFirestore,
                    child: const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
