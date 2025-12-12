import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/medication.dart';
import 'notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Iniciar sesión con email/contraseña
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 🔁 Resincronizar notificaciones para ESTA cuenta
      await _resyncNotificationsForUser(credential.user);

      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Auth error (signIn): ${e.code} - ${e.message}');
      throw e; // El LoginScreen se encarga de mostrar el mensaje amigable
    } catch (e) {
      debugPrint('Unknown auth error (signIn): $e');
      rethrow;
    }
  }

  /// Crear cuenta con email/contraseña
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Al crear cuenta nueva aún no hay medicamentos → no hace falta programar nada
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Auth error (signUp): ${e.code} - ${e.message}');
      throw e;
    } catch (e) {
      debugPrint('Unknown auth error (signUp): $e');
      rethrow;
    }
  }

  /// Cerrar sesión
  Future<void> signOut() async {
    try {
      // 🗑 Antes de salir, cancelamos TODAS las notificaciones locales
      await NotificationService().cancelAllMedications();

      await _auth.signOut();
    } catch (e) {
      debugPrint('Error during signOut: $e');
      rethrow;
    }
  }

  // =========================================================
  //   Helpers internos
  //   - Cancela todo
  //   - Relee los medicamentos del usuario
  //   - Vuelve a programar notificaciones sólo para esa cuenta
  // =========================================================
  Future<void> _resyncNotificationsForUser(User? user) async {
    if (user == null) return;

    // Primero borramos todo lo que hubiera
    await NotificationService().cancelAllMedications();

    // Cargamos medicamentos de este usuario
    final query = await FirebaseFirestore.instance
        .collection('medications')
        .where('userId', isEqualTo: user.uid)
        .get();

    for (final doc in query.docs) {
      final med = Medication.fromMap(doc.data(), id: doc.id);

      if (med.id == null) continue;
      if (med.days.isEmpty || med.times.isEmpty) continue;

      await NotificationService().scheduleMedication(
        medicationId: med.id!,
        name: med.name,
        days: med.days,
        times: med.times,
      );
    }

    debugPrint(
      '🔁 Notificaciones resincronizadas para usuario ${user.uid} (medicamentos: ${query.docs.length})',
    );
  }
}
