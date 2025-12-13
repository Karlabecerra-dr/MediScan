import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  static const routeName = '/login';

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Key del formulario para validar antes de enviar
  final _formKey = GlobalKey<FormState>();

  // Controllers de los campos
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  // Estado de la UI
  bool _isLoginMode = true; // true = login, false = registro
  bool _isLoading = false; // deshabilita botones y muestra spinner
  bool _isPasswordVisible = false; // controla el "ojito" de contraseña
  String? _errorMessage; // mensaje de error visible arriba del form

  @override
  void dispose() {
    // Limpieza de controllers
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  // Envía el formulario:
  // - Login: email + password
  // - Registro: name + email + password (y confirmación)
  Future<void> _submit() async {
    // Validación local del formulario
    if (!_formKey.currentState!.validate()) return;

    // Estado "cargando" + limpia errores anteriores
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Normaliza textos
      final name = _nameCtrl.text.trim();
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text.trim();

      // Servicio de autenticación (encapsula FirebaseAuth)
      final auth = AuthService();

      if (_isLoginMode) {
        // LOGIN: solo email + password
        await auth.signInWithEmail(email: email, password: password);
      } else {
        // REGISTRO: name + email + password
        await auth.signUpWithEmail(
          name: name,
          email: email,
          password: password,
        );
      }

      // Si se autentica ok, redirige al Home
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(HomeScreen.routeName);
    } catch (e) {
      // Mensaje base por si no calza con ningún caso
      String message = 'Ocurrió un error. Intenta nuevamente.';

      // Errores típicos de FirebaseAuth
      if (e is FirebaseAuthException) {
        debugPrint('FirebaseAuthException code: ${e.code}');

        switch (e.code) {
          case 'wrong-password':
          case 'invalid-credential':
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
        // Cualquier otro error
        message = e.toString();
      }

      // Muestra el error arriba del formulario
      setState(() {
        _errorMessage = message;
      });
    } finally {
      // Vuelve a habilitar UI si la pantalla sigue montada
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

    // Textos que cambian según modo
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
                  // Header con logo + nombre de la app
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

                  // Título (login / registro)
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Caja de error (si existe)
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

                  // Formulario principal
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Nombre solo en modo registro
                        if (!_isLoginMode) ...[
                          TextFormField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nombre',
                            ),
                            validator: (value) {
                              if (!_isLoginMode) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Ingresa tu nombre';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Email
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

                        // Password con toggle de visibilidad
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

                        // Confirmación solo en registro
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

                  // Botón principal (entrar / registrarme)
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

                  // Toggle entre login y registro
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _isLoginMode = !_isLoginMode;
                              _errorMessage = null;

                              // Limpieza mínima al cambiar de modo
                              _confirmPasswordCtrl.clear();
                              if (_isLoginMode) _nameCtrl.clear();
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
