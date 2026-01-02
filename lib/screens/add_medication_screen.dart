import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/medication.dart';
import '../services/active_profile.dart';
import '../services/notification_service.dart';
import 'scan_screen.dart';

// Pantalla para crear o editar un medicamento.
// - Si llega un Medication => modo edición
// - Si no llega => modo creación
// - autoScanOnOpen permite abrir el escáner automáticamente al entrar
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
  // Key del formulario para validar antes de guardar
  final _formKey = GlobalKey<FormState>();

  // Controllers para inputs del formulario
  final _medIdCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _doseCtrl = TextEditingController();
  final _presentationCtrl = TextEditingController(text: 'Tableta');
  final _descriptionCtrl = TextEditingController();

  // Días seleccionados y horas de toma
  late List<String> _selectedDays;
  late List<TimeOfDay> _times;

  // ---- MODO INTERVALO "Cada X horas" ----
  // Si _intervalMode = true, se generan automáticamente las horas desde una hora inicial
  bool _intervalMode = false; // false = horas específicas, true = cada X horas
  int _intervalHours = 8; // intervalos permitidos (4, 6, 8, 12...)
  TimeOfDay _intervalStart = const TimeOfDay(hour: 8, minute: 0);

  // Atajo para saber si esta pantalla está editando o creando
  bool get _isEditing => widget.medication != null;

  @override
  void initState() {
    super.initState();

    // Lista base para inicializar selección por defecto
    const allDays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

    // Si llega un medicamento, se cargan los datos en el formulario
    final med = widget.medication;

    if (med != null) {
      // ---------- MODO EDICIÓN ----------
      _medIdCtrl.text = med.medId ?? '';
      _nameCtrl.text = med.name;
      _doseCtrl.text = med.dose;
      _presentationCtrl.text = med.presentation;
      _descriptionCtrl.text = med.description ?? '';

      // Copia de días para poder modificar sin tocar el original
      _selectedDays = List<String>.from(med.days);

      // Convierte strings tipo "08:00" a TimeOfDay
      _times = med.times.map((t) {
        final parts = t.split(':');
        final hour = int.tryParse(parts.first) ?? 0;
        final minute = int.tryParse(parts.last) ?? 0;
        return TimeOfDay(hour: hour, minute: minute);
      }).toList();

      // Si viene vacío por algún motivo, deja un valor seguro
      if (_times.isEmpty) {
        _times = [const TimeOfDay(hour: 8, minute: 0)];
      }

      // En edición se parte en modo horas específicas
      _intervalMode = false;
      _intervalStart = _times.first;
    } else {
      // ---------- NUEVO MEDICAMENTO ----------
      // Por defecto: todos los días seleccionados y una toma a las 08:00
      _selectedDays = List<String>.from(allDays);
      _times = [const TimeOfDay(hour: 8, minute: 0)];
      _intervalStart = _times.first;
    }

    // Si se abrió desde el botón "Escanear" del Home y NO es edición,
    // se lanza el escaneo automáticamente
    if (widget.autoScanOnOpen && !_isEditing) {
      Future.microtask(_handleScan);
    }
  }

  @override
  void dispose() {
    // Limpieza de controllers para evitar leaks
    _medIdCtrl.dispose();
    _nameCtrl.dispose();
    _doseCtrl.dispose();
    _presentationCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  // Convierte un TimeOfDay a "HH:mm" para guardar en Firestore
  String _timeToString(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ================== ESCANEO ==================

  // Abre la pantalla de escaneo y retorna el código leído
  Future<void> _handleScan() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );

    // Si la pantalla ya no existe, no sigo
    if (!mounted) return;

    // Si no viene nada del escáner, no hago cambios
    if (code == null || code.isEmpty) return;

    // Seteo el medId leído en el input
    setState(() {
      _medIdCtrl.text = code;
    });

    // Intenta autocompletar con catálogo colaborativo
    await _loadFromCatalog(code);
  }

  // Carga datos de un catálogo en Firestore para autocompletar el formulario
  // Solo rellena campos si están vacíos (para no pisar lo que ya escribió el usuario)
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
      // Mensaje simple para que el usuario entienda qué pasó
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar desde el catálogo: $e')),
      );
    }
  }

  // Actualiza/crea el registro del catálogo colaborativo (merge para no borrar info existente)
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
      // No bloqueo el guardado del medicamento si falla el catálogo
      debugPrint('Error actualizando catálogo: $e');
    }
  }

  // ================== HORAS ESPECÍFICAS ==================

  // Abre selector de hora para un índice específico del arreglo _times
  Future<void> _pickTime(int index) async {
    final current = _times[index];

    final picked = await showTimePicker(context: context, initialTime: current);

    if (picked != null) {
      setState(() {
        _times[index] = picked;
      });
    }
  }

  // Agrega una hora extra al listado (valor por defecto)
  void _addTime() {
    setState(() {
      _times.add(const TimeOfDay(hour: 12, minute: 0));
    });
  }

  // Elimina una hora del listado, pero manteniendo al menos una
  void _removeTime(int index) {
    setState(() {
      if (_times.length > 1) {
        _times.removeAt(index);
      }
    });
  }

  // ================== MODO "CADA X HORAS" ==================

  // Genera _times automáticamente en base a _intervalStart y _intervalHours
  void _rebuildTimesFromInterval() {
    final List<TimeOfDay> generated = [];

    // Convierte hora inicial a minutos del día
    int startMinutes = _intervalStart.hour * 60 + _intervalStart.minute;

    // Seguridad mínima (por si alguien cambia el valor manualmente)
    if (_intervalHours <= 0) _intervalHours = 4;

    final int step = _intervalHours * 60;

    // Genera horas hasta completar el día
    int current = startMinutes;
    while (current < 24 * 60) {
      final h = current ~/ 60;
      final m = current % 60;
      generated.add(TimeOfDay(hour: h, minute: m));
      current += step;
    }

    // Si por algún caso raro queda vacío, dejo un valor seguro
    setState(() {
      _times = generated.isEmpty
          ? [const TimeOfDay(hour: 8, minute: 0)]
          : generated;
    });
  }

  // Selector de hora inicial para el modo intervalo
  Future<void> _pickIntervalStart() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _intervalStart,
    );

    if (picked != null) {
      setState(() {
        _intervalStart = picked;
      });
      _rebuildTimesFromInterval();
    }
  }

  // ================== GUARDAR ==================

  // Valida y guarda el medicamento en Firestore:
  // - si es edición => update
  // - si es creación => add
  // Además: reprograma notificaciones y actualiza catálogo colaborativo si corresponde
  Future<void> _saveMedicationToFirestore() async {
    // Valida el formulario
    if (!_formKey.currentState!.validate()) return;

    // Verifica sesión activa
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión para guardar medicamentos.'),
        ),
      );
      return;
    }

    // Perfil activo (persona)
    final activeProfileId = ActiveProfile.activeProfileId.value;
    if (activeProfileId == null) {
      // Si por alguna razón aún no está inicializado, asegurar
      await ActiveProfile.initAndEnsure();
    }
    final profileId = ActiveProfile.activeProfileId.value;
    if (profileId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo cargar el perfil activo. Intenta de nuevo.',
          ),
        ),
      );
      return;
    }

    // Al menos un día seleccionado
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un día.')),
      );
      return;
    }

    // En ambos modos, _times ya representa la lista final que se va a guardar
    final timesStr = _times.map(_timeToString).toList();

    // medId es opcional (si el usuario no escaneó, queda null)
    final medId = _medIdCtrl.text.trim().isEmpty
        ? null
        : _medIdCtrl.text.trim();

    // Normalización básica de campos
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
      // Se usa para actualizar el catálogo si existe medId
      Medication finalMed;

      if (_isEditing) {
        // -------- EDITAR --------
        final original = widget.medication!;

        // Se mantiene status y taken del original
        final updated = Medication(
          id: original.id,
          userId: original.userId ?? user.uid, // seguridad: siempre tener dueño
          profileId:
              original.profileId ??
              profileId, // NUEVO: mantener o actualizar profileId
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

        // Si por alguna razón no hay id, no se puede actualizar doc
        if (original.id != null) {
          // Actualiza documento
          await medsCollection.doc(original.id).update(updated.toMap());

          // Reprograma notificaciones:
          // 1) cancelo las antiguas
          // 2) creo las nuevas con la info actualizada
          await NotificationService().cancelMedicationNotifications(
            original.id!,
          );

          await NotificationService().scheduleMedication(
            medicationId: original.id!,
            name: updated.name,
            days: updated.days,
            times: updated.times,
          );
        }

        finalMed = updated;
      } else {
        // -------- CREAR --------
        final newMed = Medication(
          userId: user.uid, // dueño del medicamento
          profileId: profileId, // NUEVO: amarrar al perfil activo
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

        // Crea documento
        final docRef = await medsCollection.add(newMed.toMap());

        // Crea una versión con id para trabajar localmente (y para notificaciones)
        final created = Medication(
          id: docRef.id,
          userId: newMed.userId,
          profileId: newMed.profileId,
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

        // Programa notificaciones del nuevo medicamento
        await NotificationService().scheduleMedication(
          medicationId: docRef.id,
          name: created.name,
          days: created.days,
          times: created.times,
        );

        finalMed = created;
      }

      // Actualiza catálogo colaborativo si hay medId (viene del escaneo)
      if (medId != null) {
        await _upsertCatalog(medId, finalMed);
      }

      if (!mounted) return;

      // Mensaje simple de confirmación
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Medicamento actualizado correctamente'
                : 'Medicamento creado correctamente',
          ),
        ),
      );

      // Vuelve a la pantalla anterior
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      // Error visible al usuario
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================== UI ==================

  @override
  Widget build(BuildContext context) {
    // Variable local para no recalcular getter y para legibilidad
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
            // Campo de ID escaneado (solo lectura)
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

            // Nombre (obligatorio)
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

            // Dosis (obligatorio)
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

            // Presentación (opcional)
            TextFormField(
              controller: _presentationCtrl,
              decoration: const InputDecoration(labelText: 'Presentación'),
            ),
            const SizedBox(height: 16),

            // Descripción (opcional)
            TextFormField(
              controller: _descriptionCtrl,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Selector de días
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

            // Selector de modo de horario
            const Text(
              'Horario de toma',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            // Chips para alternar entre horas específicas vs intervalo
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Horas específicas'),
                  selected: !_intervalMode,
                  onSelected: (selected) {
                    if (!selected) return;
                    setState(() {
                      _intervalMode = false;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Cada X horas'),
                  selected: _intervalMode,
                  onSelected: (selected) {
                    if (!selected) return;
                    setState(() {
                      _intervalMode = true;

                      // Tomo la primera hora actual como base (si existe)
                      _intervalStart = _times.isNotEmpty
                          ? _times.first
                          : const TimeOfDay(hour: 8, minute: 0);
                    });

                    // Al activar intervalo, regenero la lista de horas
                    _rebuildTimesFromInterval();
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // UI del modo intervalo
            if (_intervalMode) ...[
              Row(
                children: [
                  const Text('Cada'),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _intervalHours,
                    items: const [
                      DropdownMenuItem(value: 4, child: Text('4')),
                      DropdownMenuItem(value: 6, child: Text('6')),
                      DropdownMenuItem(value: 8, child: Text('8')),
                      DropdownMenuItem(value: 12, child: Text('12')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _intervalHours = value;
                      });
                      _rebuildTimesFromInterval();
                    },
                  ),
                  const SizedBox(width: 8),
                  const Text('horas'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Hora inicial:'),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _pickIntervalStart,
                    icon: const Icon(Icons.access_time),
                    label: Text(_intervalStart.format(context)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Vista previa de horas generadas
              const Text(
                'Se generarán las tomas de este día según el intervalo elegido:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _times
                    .map((t) => Chip(label: Text(_timeToString(t))))
                    .toList(),
              ),
            ] else ...[
              // UI del modo "horas específicas"
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
              }),

              // Botón para agregar otra hora
              TextButton.icon(
                onPressed: _addTime,
                icon: const Icon(Icons.add),
                label: const Text('Agregar hora'),
              ),
            ],

            const SizedBox(height: 24),

            // Botones de acción
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
