import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'medication_channel';
  static const String _channelName = 'Recordatorios de medicamentos';
  static const String _channelDescription =
      'Notificaciones de toma de medicamentos';

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Crear canal de notificaciones con audio y vibración
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );

      // Solicitar permisos de notificación
      await androidPlugin.requestNotificationsPermission();
      debugPrint('Canal de notificaciones creado y permisos solicitados');
    }
  }

  Future<void> scheduleMedication({
    required String medicationId,
    required String name,
    required List<String> days,
    required List<String> times,
  }) async {
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
        final scheduledDate = _nextInstanceOfWeekdayTime(weekday, hour, minute);

        final androidDetails = AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        );

        final notifDetails = NotificationDetails(android: androidDetails);

        try {
          await _plugin.zonedSchedule(
            id,
            'Tomar medicamento',
            '$name · $t',
            scheduledDate,
            notifDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: jsonEncode({
              'medicationId': medicationId,
              'name': name,
              'time': t,
            }),
          );
          debugPrint('✓ Notificación programada para $scheduledDate (ID: $id)');
        } catch (e) {
          debugPrint('✗ Error al programar notificación: $e');
        }
      }
    }
  }

  Future<void> cancelMedicationNotifications(String medicationId) async {
    for (var weekday = 1; weekday <= 7; weekday++) {
      for (var i = 0; i < 10; i++) {
        final id = _notificationId(medicationId, weekday, i);
        try {
          await _plugin.cancel(id);
        } catch (e) {
          debugPrint('Error al cancelar notificación $id: $e');
        }
      }
    }
  }

  Future<void> _onNotificationResponse(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null) return;

    try {
      // Aquí puedes manejar acciones futuras (marcar como tomado, posponer, etc.)
      // jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {}
  }

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

  int _notificationId(String medId, int weekday, int index) {
    // Asegurar ID no negativo y dentro de 32 bits para evitar problemas en Android
    final base = medId.hashCode & 0x7fffffff;
    return base ^ (weekday * 100 + index);
  }

  /// Método de ayuda para pruebas: programa una notificación única dentro de [seconds]
  Future<void> scheduleTestNotification({
    required String medicationId,
    required String name,
    int seconds = 10,
  }) async {
    final id = (medicationId.hashCode & 0x7fffffff) ^ seconds;
    final scheduled = tz.TZDateTime.now(
      tz.local,
    ).add(Duration(seconds: seconds));

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    final notifDetails = NotificationDetails(android: androidDetails);

    try {
      await _plugin.zonedSchedule(
        id,
        'Test: Tomar medicamento',
        name,
        scheduled,
        notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: jsonEncode({'medicationId': medicationId, 'name': name}),
      );
      debugPrint(
        '✓ Notificación de prueba programada para $scheduled (ID: $id)',
      );
    } catch (e) {
      debugPrint('✗ Error al programar notificación de prueba: $e');
      // Fallback: si las alarmas exactas no están permitidas, mostrar una
      // notificación inmediata para ayudar en pruebas locales.
      if (e is PlatformException && e.code == 'exact_alarms_not_permitted') {
        try {
          await _plugin.show(
            id,
            'Test: Tomar medicamento',
            name,
            notifDetails,
            payload: jsonEncode({'medicationId': medicationId, 'name': name}),
          );
          debugPrint('✓ Fallback: notificación inmediata mostrada (ID: $id)');
        } catch (showErr) {
          debugPrint('✗ Error mostrando notificación de fallback: $showErr');
        }
      }
    }
  }

  /// Muestra inmediatamente una notificación (útil para pruebas rápidas)
  Future<void> showImmediateTestNotification({
    required String medicationId,
    required String name,
  }) async {
    final id = (medicationId.hashCode & 0x7fffffff) ^ 9999;

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    final notifDetails = NotificationDetails(android: androidDetails);

    try {
      await _plugin.show(
        id,
        'Test inmediato: Tomar medicamento',
        name,
        notifDetails,
        payload: jsonEncode({'medicationId': medicationId, 'name': name}),
      );
      debugPrint('✓ Notificación inmediata mostrada (ID: $id)');
    } catch (e) {
      debugPrint('✗ Error al mostrar notificación inmediata: $e');
    }
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
}
