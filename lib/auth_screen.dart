import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const _fondo = Color(0xFF0B1019);
const _panel = Color(0xFF192231);
const _rojo = Color(0xFFF04452);
const _gris = Color(0xFFB1BAC9);

// Muestra el catalogo solo cuando haya una cuenta registrada.
// Una cuenta anonima existente puede convertirse a correo y contrasena.
class AuthGate extends StatelessWidget {
  final Widget child;

  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: _rojo)),
          );
        }
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Error al verificar la sesión.')),
          );
        }
        final usuario = snapshot.data;
        if (usuario == null || usuario.isAnonymous) {
          return const AuthScreen();
        }
        return child;
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  bool _crearCuenta = false;
  bool _ocultar = true;
  bool _cargando = false;
  String? _mensajeError;

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  String _mensajeFirebase(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
      case 'credential-already-in-use':
        return 'Este correo ya tiene una cuenta. Usa Iniciar sesión.';
      case 'invalid-email':
        return 'Escribe un correo electrónico válido.';
      case 'weak-password':
        return 'La contraseña es demasiado débil.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Correo o contraseña incorrectos.';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta más tarde.';
      case 'network-request-failed':
        return 'No hay conexión a Internet.';
      case 'operation-not-allowed':
        return 'Activa Correo electrónico/Contraseña en Firebase Authentication.';
      default:
        return 'No se pudo continuar: ${error.message ?? error.code}';
    }
  }

  Future<void> _enviar() async {
    if (_cargando || !_formKey.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _mensajeError = null;
    });

    final correo = _correo.text.trim();
    final contrasena = _contrasena.text;

    try {
      if (_crearCuenta) {
        final actual = FirebaseAuth.instance.currentUser;
        if (actual != null && actual.isAnonymous) {
          // Conserva los favoritos de la sesion anonima al registrarse.
          await actual.linkWithCredential(
            EmailAuthProvider.credential(
              email: correo,
              password: contrasena,
            ),
          );
        } else {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: correo,
            password: contrasena,
          );
        }
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: correo,
          password: contrasena,
        );
      }
      // AuthGate actualiza automaticamente la pantalla.
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _mensajeError = _mensajeFirebase(error));
    } catch (_) {
      if (mounted) {
        setState(() => _mensajeError = 'Ocurrió un problema. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.local_movies_rounded, size: 72, color: _rojo),
                    const SizedBox(height: 12),
                    const Text(
                      'CineApp',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tu próxima gran película comienza aquí.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _gris),
                    ),
                    const SizedBox(height: 35),
                    Text(
                      _crearCuenta ? 'Crear cuenta' : 'Iniciar sesión',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 22),
                    TextFormField(
                      controller: _correo,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: const Icon(Icons.email_outlined),
                        filled: true,
                        fillColor: _panel,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      validator: (valor) {
                        final texto = valor?.trim() ?? '';
                        if (!texto.contains('@') || !texto.contains('.')) {
                          return 'Escribe un correo válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _contrasena,
                      obscureText: _ocultar,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _enviar(),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        filled: true,
                        fillColor: _panel,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        suffixIcon: IconButton(
                          tooltip: _ocultar ? 'Mostrar contraseña' : 'Ocultar contraseña',
                          onPressed: () => setState(() => _ocultar = !_ocultar),
                          icon: Icon(_ocultar ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        ),
                      ),
                      validator: (valor) {
                        if ((valor ?? '').length < 6) {
                          return 'Mínimo 6 caracteres';
                        }
                        return null;
                      },
                    ),
                    if (_mensajeError != null) ...[
                      const SizedBox(height: 14),
                      Text(_mensajeError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.orangeAccent)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _cargando ? null : _enviar,
                      style: FilledButton.styleFrom(
                        backgroundColor: _rojo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 17),
                      ),
                      child: _cargando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_crearCuenta ? 'Registrarme' : 'Entrar a CineApp'),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _cargando
                          ? null
                          : () => setState(() {
                                _crearCuenta = !_crearCuenta;
                                _mensajeError = null;
                              }),
                      child: Text(
                        _crearCuenta
                            ? '¿Ya tienes cuenta? Inicia sesión'
                            : '¿No tienes cuenta? Regístrate',
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Películas e imágenes: TMDB. Este producto utiliza la API de TMDB, '
                      'pero no está avalado ni certificado por TMDB.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: _gris),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
