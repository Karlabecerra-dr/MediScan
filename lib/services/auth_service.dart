import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/medication.dart';
import 'notification_service.dart';

// Servicio de autenticación.
// Encapsula login/registro/cierre de sesión y mantiene sincronizadas
// las notificaciones locales con los medicamentos del usuario.
class AuthService {
  // Instancia de FirebaseAuth usada en toda la app
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================
  //          LOGIN
  // ============================
  //
  // Inicia sesión con email y contraseña.
  // Al entrar, se resincronizan las notificaciones según los medicamentos del usuario.
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Refresca datos del usuario (por si se usa displayName u otros campos)
      await credential.user?.reload();

      // Resincroniza notificaciones para la cuenta actual
      await _resyncNotificationsForUser(_auth.currentUser);

      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Auth error (signIn): ${e.code} - ${e.message}');
      throw e;
    } catch (e) {
      debugPrint('Unknown auth error (signIn): $e');
      rethrow;
    }
  }

  // ============================
  //      LOGIN CON GOOGLE
  // ============================
  Future<UserCredential> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn();

      // (Opcional pero recomendado) para que siempre pregunte cuenta
      // Si lo encuentras molesto, borra estas 2 líneas.
      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // Usuario cerró/canceló el login
        throw FirebaseAuthException(
          code: 'ERROR_ABORTED_BY_USER',
          message: 'Inicio de sesión con Google cancelado.',
        );
      }

      final googleAuth = await googleUser.authentication;

      final oauthCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);

      // refrescar user
      await userCredential.user?.reload();

      final user = _auth.currentUser;
      if (user != null) {
        // Asegura documento en Firestore (sin pisar lo que exista)
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          'provider': 'google',
          'lastLoginAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // IMPORTANTÍSIMO: mantener tu lógica actual
      await _resyncNotificationsForUser(_auth.currentUser);

      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Auth error (Google): ${e.code} - ${e.message}');
      throw e;
    } catch (e) {
      debugPrint('Unknown auth error (Google): $e');
      rethrow;
    }
  }

  // ============================
  //         REGISTRO
  // ============================
  //
  // Crea cuenta con email y contraseña, guarda el nombre en Auth (displayName)
  // y crea/actualiza el perfil en Firestore.
  Future<UserCredential> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) return credential;

      // 1) Guardar nombre en FirebaseAuth (displayName)
      await user.updateDisplayName(name);
      await user.reload();

      // 2) Guardar/actualizar perfil en Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Auth error (signUp): ${e.code} - ${e.message}');
      throw e;
    } catch (e) {
      debugPrint('Unknown auth error (signUp): $e');
      rethrow;
    }
  }

  // ============================
  //        SIGN OUT
  // ============================
  //
  // Cierra sesión.
  // Antes de salir, se cancelan todas las notificaciones locales para evitar residuos.
  Future<void> signOut() async {
    try {
      // Antes de cerrar sesión, limpio notificaciones locales
      await NotificationService().cancelAllMedications();

      // Cierra sesión Google si estaba en uso
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}

      // Luego cierro sesión en FirebaseAuth
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error during signOut: $e');
      rethrow;
    }
  }

  // =========================================================
  //   Helpers internos: reprogramar notificaciones por usuario
  // =========================================================
  //
  // Al iniciar sesión, se cancela todo lo que exista y se vuelve a programar
  // según los medicamentos guardados en Firestore para el usuario actual.
  Future<void> _resyncNotificationsForUser(User? user) async {
    if (user == null) return;

    // Limpia cualquier notificación anterior (cambio de cuenta, reinstalación, etc.)
    await NotificationService().cancelAllMedications();

    // Trae medicamentos del usuario
    final query = await FirebaseFirestore.instance
        .collection('medications')
        .where('userId', isEqualTo: user.uid)
        .get();

    // Reprograma notificaciones por cada medicamento válido
    for (final doc in query.docs) {
      final med = Medication.fromMap(doc.data(), id: doc.id);

      // Validaciones mínimas
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
      'Notificaciones resincronizadas para usuario ${user.uid} (medicamentos: ${query.docs.length})',
    );
  }
}
