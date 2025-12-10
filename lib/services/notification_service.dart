import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Cambié el id para forzar un canal nuevo con el sonido correcto
  static const String _channelId = 'medication_channel_v2';
  static const String _channelName = 'Recordatorios de medicamentos';
  static const String _channelDescription =
      'Notificaciones de toma de medicamentos';

  bool _initialized = false;
  bool _tzInitialized = false;

  // ====== TIMEZONE ======
  Future<void> _ensureTimeZoneInitialized() async {
    if (_tzInitialized) return;

    // Inicializa todas las zonas horarias conocidas
    tzdata.initializeTimeZones();

    // Para Chile continental usamos America/Santiago
    const String timeZoneName = 'America/Santiago';
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    _tzInitialized = true;
    debugPrint('🕒 Timezone inicializado: $timeZoneName');
  }

  // ====== INIT ======
  Future<void> init() async {
    if (_initialized) return;

    debugPrint('🔧 Iniciando NotificationService...');

    // IMPORTANTE: inicializar timezone antes de usar tz.local
    await _ensureTimeZoneInitialized();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      // Android 13+
      await androidPlugin.requestNotificationsPermission();

      // Canal con sonido personalizado + vibración fuerte
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          sound: const RawResourceAndroidNotificationSound('sonido'),
          vibrationPattern: Int64List.fromList([0, 1200, 300, 1500]),
          showBadge: true,
        ),
      );

      debugPrint('✅ Canal de notificaciones creado ($_channelId)');
    }

    _initialized = true;
  }

  // ========================================
  //      MÉTODO PRINCIPAL PARA MEDICINAS
  // ========================================
  Future<void> scheduleMedication({
    required String medicationId,
    required String name,
    required List<String> days,
    required List<String> times,
  }) async {
    await init(); // 👈 asegura plugin + timezone

    debugPrint('📅 Programando medicamento: $name');
    debugPrint('   Días: $days');
    debugPrint('   Horas: $times');

    for (final label in days) {
      final weekday = _weekdayFromLabel(label);
      if (weekday == null) continue;

      for (var i = 0; i < times.length; i++) {
        final t = times[i];
        final parts = t.split(':');
        if (parts.length != 2) continue;

        final hour = int.tryParse(parts[0]) ?? 8;
        final minute = int.tryParse(parts[1]) ?? 0;

        final id = _notificationId(medicationId, weekday, i);
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
          debugPrint('✅ Notificación programada para ID $id → $scheduled');
        } catch (e) {
          debugPrint('❌ Error exactAllowWhileIdle → $e');
        }
      }
    }

    await _printPendingNotifications();
  }

  // ============================
  //     DETALLES DE NOTIFICACIÓN
  // ============================
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
        vibrationPattern: Int64List.fromList([
          0, // espera inicial
          1200, // vibra 1.2s
          300, // pausa
          1500, // vibra 1.5s
        ]),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        ticker: 'Recordatorio de medicamento',
        styleInformation: const BigTextStyleInformation(''),
      ),
    );
  }

  // ============================
  //     NOTIFICACIONES DE PRUEBA
  // ============================
  Future<void> showImmediateTestNotification({
    required String medicationId,
    required String name,
  }) async {
    await init();

    final id = (medicationId.hashCode & 0x7fffffff) ^ 9999;

    await _plugin.show(
      id,
      'Test inmediato 💊',
      '$name – ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      _defaultDetails(),
      payload: jsonEncode({'medicationId': medicationId, 'name': name}),
    );

    debugPrint('✅ Notificación inmediata enviada');
  }

  Future<void> scheduleTestNotification({
    required String medicationId,
    required String name,
    int seconds = 10,
  }) async {
    await init();

    final id = (medicationId.hashCode & 0x7fffffff) ^ seconds;

    final scheduled = tz.TZDateTime.now(
      tz.local,
    ).add(Duration(seconds: seconds));

    await _plugin.zonedSchedule(
      id,
      '⏱ Test programado',
      '$name – suena en $seconds segundos',
      scheduled,
      _defaultDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: jsonEncode({'medicationId': medicationId, 'name': name}),
    );

    debugPrint('🧪 Notificación programada → $scheduled');
  }

  // ============================
  //         CANCELAR
  // ============================
  Future<void> cancelMedicationNotifications(String medicationId) async {
    await init();

    debugPrint('🗑 Cancelando notificaciones de $medicationId');

    for (var weekday = 1; weekday <= 7; weekday++) {
      for (var i = 0; i < 10; i++) {
        final id = _notificationId(medicationId, weekday, i);
        await _plugin.cancel(id);
      }
    }

    await _printPendingNotifications();
  }

  // ============================
  //       CALLBACK DE TAP
  // ============================
  Future<void> _onNotificationResponse(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null) return;

    try {
      final data = jsonDecode(payload);
      debugPrint('🔔 Notificación tocada → ${data['name']}');
    } catch (e) {
      debugPrint('⚠ Payload inválido: $e');
    }
  }

  // ===================================
  //      HELPERS INTERNOS
  // ===================================
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
      case 'S':
        return DateTime.saturday;
      case 'Dom':
      case 'D':
        return DateTime.sunday;
      default:
        return null;
    }
  }

  int _notificationId(String medId, int weekday, int index) {
    final base = medId.hashCode & 0x7fffffff;
    return base ^ (weekday * 100 + index);
  }

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

  Future<void> _printPendingNotifications() async {
    final pending = await _plugin.pendingNotificationRequests();
    debugPrint('📊 Notificaciones pendientes: ${pending.length}');
    for (final n in pending) {
      debugPrint('   → ID ${n.id} | ${n.title}');
    }
  }
}
