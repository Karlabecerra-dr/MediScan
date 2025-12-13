// lib/services/notification_service.dart
//
// Servicio de notificaciones locales.
// Aquí centralizo todo lo relacionado a inicialización, canales Android,
// programación (semanal / pospuesta / test) y cancelación de recordatorios.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

/// Servicio singleton para manejar las notificaciones de MediScan.
/// La idea es tener una sola instancia viva durante toda la app.
class NotificationService {
  // Constructor privado para singleton
  NotificationService._internal();

  // Instancia única
  static final NotificationService _instance = NotificationService._internal();

  // Acceso público al singleton
  factory NotificationService() => _instance;

  // Plugin de notificaciones
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Config del canal Android
  static const String _channelId = 'medication_channel_v2';
  static const String _channelName = 'Recordatorios de medicamentos';
  static const String _channelDescription =
      'Notificaciones de toma de medicamentos';

  // Evita inicializar timezone más de una vez
  bool _tzInitialized = false;

  // ========================
  //       INICIALIZACIÓN
  // ========================
  //
  // Inicializa el plugin, configura timezone y crea el canal (Android).
  Future<void> init() async {
    debugPrint('Iniciando NotificationService...');

    // Timezone primero, porque todo lo programado depende de esto
    await _ensureTimeZoneInitialized();

    // Configuración base de inicialización (Android)
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidInit);

    // Inicializa el plugin y registra el callback para taps
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Implementación específica de Android (para permisos y canal)
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      // Android 13+: permiso explícito
      await androidPlugin.requestNotificationsPermission();

      // Canal con sonido/vibración personalizados (se reutiliza por toda la app)
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          sound: const RawResourceAndroidNotificationSound('sonido'),
          vibrationPattern: Int64List.fromList([
            0, // espera inicial
            500,
            250,
            700,
          ]),
          showBadge: true,
        ),
      );

      debugPrint('Canal de notificaciones creado ($_channelId)');
    }

    // Útil para verificar rápido que quedó todo programado bien
    await _printPendingNotifications();
  }

  // Inicializa la base de zonas horarias y fija la local (Chile).
  Future<void> _ensureTimeZoneInitialized() async {
    if (_tzInitialized) return;

    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Santiago'));
    _tzInitialized = true;

    debugPrint('Timezone inicializado: ${tz.local}');
  }

  // ============================
  //   DETALLES DE NOTIFICACIÓN
  // ============================
  //
  // Configuración por defecto que se aplica a todas las notificaciones.
  NotificationDetails _defaultDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('sonido'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 250, 700]),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        ticker: 'Recordatorio de medicamento',
        styleInformation: const BigTextStyleInformation(''),
      ),
    );
  }

  // ========================================
  //   PROGRAMAR NOTIFICACIONES DE MEDICINA
  // ========================================
  //
  // Programa una notificación semanal por cada día y hora indicados.
  Future<void> scheduleMedication({
    required String medicationId,
    required String name,
    required List<String> days,
    required List<String> times,
  }) async {
    await _ensureTimeZoneInitialized();

    debugPrint('Programando medicamento: $name');
    debugPrint('Días: $days');
    debugPrint('Horas: $times');

    // Días seleccionados (Lun/Mar/Mié...)
    for (final label in days) {
      final weekday = _weekdayFromLabel(label);
      if (weekday == null) continue;

      // Horas seleccionadas (08:00, 20:00, ...)
      for (var i = 0; i < times.length; i++) {
        final t = times[i];

        final parts = t.split(':');
        if (parts.length != 2) continue;

        final hour = int.tryParse(parts[0]) ?? 8;
        final minute = int.tryParse(parts[1]) ?? 0;

        // ID estable por medicamento + día + índice del horario
        final id = _notificationId(medicationId, weekday, i);

        // Próxima ocurrencia válida en el calendario
        final scheduled = _nextInstanceOfWeekdayTime(weekday, hour, minute);

        try {
          await _plugin.zonedSchedule(
            id,
            'Tomar medicamento 💊',
            '$name · $t',
            scheduled,
            _defaultDetails(),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: jsonEncode({
              'medicationId': medicationId,
              'name': name,
              'time': t,
            }),
          );

          debugPrint('Notificación programada ID $id → $scheduled');
        } catch (e) {
          debugPrint(
            'Error programando notificación (exactAllowWhileIdle): $e',
          );
        }
      }
    }

    await _printPendingNotifications();
  }

  // Programa un recordatorio extra dentro de X minutos desde ahora (posponer).
  Future<void> schedulePostponedNotification({
    required String medicationId,
    required String name,
    int minutes = 5,
  }) async {
    await _ensureTimeZoneInitialized();

    final scheduled = tz.TZDateTime.now(
      tz.local,
    ).add(Duration(minutes: minutes));

    // ID único usando hash del medicamento y timestamp
    final base = medicationId.hashCode & 0x7fffffff;
    final id = base ^ scheduled.millisecondsSinceEpoch;

    await _plugin.zonedSchedule(
      id,
      'Recordatorio pospuesto 💊',
      'Tomar $name',
      scheduled,
      _defaultDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: jsonEncode({
        'medicationId': medicationId,
        'name': name,
        'postponed': true,
      }),
    );

    debugPrint(
      'Notificación pospuesta: $name en $minutes min → $scheduled (id=$id)',
    );
  }

  // ============================
  //     NOTIFICACIONES DE PRUEBA
  // ============================

  // Notificación inmediata (para verificar que el canal/sonido funciona).
  Future<void> showImmediateTestNotification({
    required String medicationId,
    required String name,
  }) async {
    final id = (medicationId.hashCode & 0x7fffffff) ^ 9999;

    await _plugin.show(
      id,
      'Test inmediato 💊',
      '$name – ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      _defaultDetails(),
      payload: jsonEncode({'medicationId': medicationId, 'name': name}),
    );

    debugPrint('Notificación inmediata enviada');
  }

  // Notificación de prueba a X segundos en el futuro.
  Future<void> scheduleTestNotification({
    required String medicationId,
    required String name,
    int seconds = 10,
  }) async {
    await _ensureTimeZoneInitialized();

    final id = (medicationId.hashCode & 0x7fffffff) ^ seconds;

    final scheduled = tz.TZDateTime.now(
      tz.local,
    ).add(Duration(seconds: seconds));

    await _plugin.zonedSchedule(
      id,
      'Test programado',
      '$name – suena en $seconds segundos',
      scheduled,
      _defaultDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: jsonEncode({
        'medicationId': medicationId,
        'name': name,
        'test': true,
      }),
    );

    debugPrint('Notificación TEST programada → $scheduled (id=$id)');
  }

  // ============================
  //           CANCELAR
  // ============================

  // Cancela todas las notificaciones asociadas a un medicamento.
  // Se asume un máximo de 10 horarios por día (index 0..9).
  Future<void> cancelMedicationNotifications(String medicationId) async {
    debugPrint('Cancelando notificaciones de $medicationId');

    for (var weekday = 1; weekday <= 7; weekday++) {
      for (var i = 0; i < 10; i++) {
        final id = _notificationId(medicationId, weekday, i);
        await _plugin.cancel(id);
      }
    }

    await _printPendingNotifications();
  }

  // Cancela todas las notificaciones locales (útil al cerrar sesión).
  Future<void> cancelAllMedications() async {
    await _plugin.cancelAll();
    debugPrint('Todas las notificaciones fueron canceladas');
    await _printPendingNotifications();
  }

  // ============================
  //       CALLBACK DE TAP
  // ============================

  // Se ejecuta cuando el usuario toca una notificación.
  Future<void> _onNotificationResponse(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null) return;

    try {
      final data = jsonDecode(payload);
      debugPrint('Notificación tocada → ${data['name']}');
    } catch (e) {
      debugPrint('Payload inválido: $e');
    }
  }

  // ===================================
  //            HELPERS
  // ===================================

  // Convierte etiqueta de día (Lun/Mar/Mié o legado L/M/X) a weekday de DateTime.
  int? _weekdayFromLabel(String label) {
    switch (label) {
      case 'Lun':
      case 'L':
        return DateTime.monday;
      case 'Mar':
      case 'M':
        return DateTime.tuesday;
      case 'Mié':
      case 'X':
        return DateTime.wednesday;
      case 'Jue':
      case 'J':
        return DateTime.thursday;
      case 'Vie':
      case 'V':
        return DateTime.friday;
      case 'Sáb':
      case 'Sab':
      case 'S':
        return DateTime.saturday;
      case 'Dom':
      case 'D':
        return DateTime.sunday;
      default:
        return null;
    }
  }

  // Genera un ID estable para cada notificación del medicamento.
  int _notificationId(String medId, int weekday, int index) {
    final base = medId.hashCode & 0x7fffffff;
    return base ^ (weekday * 100 + index);
  }

  // Calcula la próxima fecha futura que coincida con el día y hora indicados.
  tz.TZDateTime _nextInstanceOfWeekdayTime(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);

    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  // Imprime notificaciones pendientes (debug rápido).
  Future<void> _printPendingNotifications() async {
    final pending = await _plugin.pendingNotificationRequests();
    debugPrint('Notificaciones pendientes: ${pending.length}');
    for (final n in pending) {
      debugPrint('→ ID ${n.id} | ${n.title}');
    }
  }
}
