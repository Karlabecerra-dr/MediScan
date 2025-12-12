import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import 'home_screen.dart'; // 👈 IMPORTANTE para navegar al Home

class LoginScreen extends StatefulWidget {
  static const routeName = '/login';

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _isLoginMode = true; // true = Iniciar sesión, false = Crear cuenta
  bool _isLoading = false;
  bool _isPasswordVisible = false; // 👁 para mostrar/ocultar
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text.trim();

      final auth = AuthService();

      if (_isLoginMode) {
        await auth.signInWithEmail(email: email, password: password);
      } else {
        await auth.signUpWithEmail(email: email, password: password);
      }

      // ✅ Si llegó aquí, el login/registro fue exitoso.
      // Aunque tengas StreamBuilder en main.dart, esto asegura
      // que salgas de la pantalla de login:
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(HomeScreen.routeName);
    } catch (e) {
      String message = 'Ocurrió un error. Intenta nuevamente.';

      if (e is FirebaseAuthException) {
        // Para ver qué código llega realmente (opcional, pero útil)
        debugPrint('🔐 FirebaseAuthException code: ${e.code}');

        switch (e.code) {
          case 'wrong-password':
          case 'invalid-credential': // 👈 En SDK nuevos viene así
            message = 'La contraseña es incorrecta.';
            break;
          case 'user-not-found':
            message = 'No existe una cuenta con este correo.';
            break;
          case 'invalid-email':
            message = 'El correo no es válido.';
            break;
          case 'email-already-in-use':
            message = 'Este correo ya está registrado.';
            break;
          case 'weak-password':
            message = 'La contraseña es demasiado débil.';
            break;
          default:
            message = e.message ?? message;
        }
      } else {
        message = e.toString();
      }

      setState(() {
        _errorMessage = message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title = _isLoginMode ? 'Iniciar sesión' : 'Crear cuenta';
    final actionText = _isLoginMode ? 'Entrar' : 'Registrarme';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo / título
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/logo.png',
                          width: 48,
                          height: 48,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'MediScan',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                          fontSize: 13,
                        ),
                      ),
                    ),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Correo
                        TextFormField(
                          controller: _emailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Ingresa tu correo';
                            }
                            if (!value.contains('@')) {
                              return 'Ingresa un correo válido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Contraseña (con ojito)
                        TextFormField(
                          controller: _passwordCtrl,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                          ),
                          obscureText: !_isPasswordVisible,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Ingresa tu contraseña';
                            }
                            if (value.trim().length < 6) {
                              return 'Debe tener al menos 6 caracteres';
                            }
                            return null;
                          },
                        ),

                        // Confirmar contraseña SOLO en modo "Crear cuenta"
                        if (!_isLoginMode) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Confirmar contraseña',
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (!_isLoginMode) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Confirma tu contraseña';
                                }
                                if (value.trim() != _passwordCtrl.text.trim()) {
                                  return 'Las contraseñas no coinciden';
                                }
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(actionText),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _isLoginMode = !_isLoginMode;
                              _errorMessage = null;
                            });
                          },
                    child: Text(
                      _isLoginMode
                          ? '¿No tienes cuenta? Crear una'
                          : '¿Ya tienes cuenta? Inicia sesión',
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
