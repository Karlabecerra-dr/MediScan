import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Diálogo simple para mostrar información de la cuenta del usuario
// y permitir el envío del correo de recuperación de contraseña.
class AccountDialog extends StatelessWidget {
  const AccountDialog({super.key});

  // Envía un correo para restablecer la contraseña del usuario actual
  Future<void> _sendPasswordReset(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;

    // Validación básica: el usuario debe tener un correo asociado
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró el correo del usuario.')),
      );
      return;
    }

    try {
      // Envía el correo de recuperación usando FirebaseAuth
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      // Mensaje de confirmación para el usuario
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Te enviamos un correo para cambiar tu contraseña.'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      // Manejo de errores específicos de FirebaseAuth
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.message ?? e.code}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Nombre mostrado: displayName si existe, sino un fallback
    final name = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()
        : 'Sin nombre';

    // Correo mostrado: email si existe, sino un fallback
    final email = user?.email ?? 'Sin correo';

    return AlertDialog(
      title: const Text('Mi cuenta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Información básica del usuario
          Text('Nombre: $name'),
          const SizedBox(height: 6),
          Text('Correo: $email'),
        ],
      ),
      actions: [
        // Acción para enviar correo de recuperación de contraseña
        TextButton(
          onPressed: () => _sendPasswordReset(context),
          child: const Text('Cambiar contraseña'),
        ),

        // Cierra el diálogo
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
