import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asistencia_app/screens/home_profesor_screen.dart';
import 'package:asistencia_app/screens/home_alumno_screen.dart';
import 'package:asistencia_app/screens/login_screen.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // El logo aparece con un rebote suave
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
    ));
    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    );

    // El texto sube y aparece después del logo
    _textFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
    );
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });

    _iniciar();
  }

  Future<void> _iniciar() async {
    _controller.forward();

    // Tiempo mínimo para que se vea la animación (ajústalo a tu gusto)
    final espera = Future.delayed(const Duration(milliseconds: 2800));
    final destino = await _decidirDestino();
    await espera;

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => destino,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  /// Decide a qué pantalla ir según la sesión guardada
  Future<Widget> _decidirDestino() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mantener = prefs.getBool('mantener_sesion') ?? false;
      final user = FirebaseAuth.instance.currentUser;
      final cuentaAlumno = prefs.getString('cuenta_alumno');

      // Sesión de profesor (Firebase Auth)
      if (user != null) {
        if (!mantener) {
          await FirebaseAuth.instance.signOut();
          await prefs.remove('cuenta_alumno');
          return const LoginScreen();
        }
        return const HomeProfesorScreen();
      }

      // Sesión de alumno (solo se guarda su número de cuenta)
      if (cuentaAlumno != null) {
        if (!mantener) {
          await prefs.remove('cuenta_alumno');
          return const LoginScreen();
        }
        return HomeAlumnoScreen(numeroCuenta: cuentaAlumno);
      }

      return const LoginScreen();
    } catch (_) {
      return const LoginScreen();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _circulo(double size, double opacidad) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacidad),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4F46E5), Color(0xFF6366F1), Color(0xFF0EA5E9)],
          ),
        ),
        child: Stack(
          children: [
            // Círculos decorativos de fondo
            Positioned(top: -80, right: -60, child: _circulo(260, 0.08)),
            Positioned(bottom: -100, left: -80, child: _circulo(320, 0.07)),
            Positioned(top: 160, left: -40, child: _circulo(110, 0.06)),
            Positioned(bottom: 180, right: -30, child: _circulo(90, 0.06)),

            // CENTRADO: Positioned.fill hace que la columna ocupe todo el ancho
            Positioned.fill(
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),

                    // Logo animado usando la imagen en lugar del icono
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: Container(
                          padding: const EdgeInsets.all(8), // Reducido el padding para que la imagen resalte más
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.18),
                                blurRadius: 40,
                                offset: const Offset(0, 18),
                              ),
                              BoxShadow(
                                color: Colors.white.withOpacity(0.25),
                                blurRadius: 0,
                                spreadRadius: 14,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/icon.jpeg', // Ruta actualizada a la imagen
                              width: 110, // Ajusta el tamaño según sea necesario
                              height: 110,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 44),

                    // Nombre y lema
                    FadeTransition(
                      opacity: _textFade,
                      child: SlideTransition(
                        position: _textSlide,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // El padding izquierdo compensa el espacio que
                              // deja el letterSpacing al final del texto
                              const Padding(
                                padding: EdgeInsets.only(left: 1.5),
                                child: Text(
                                  'AsistApp',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'FuentePrincipal',
                                    fontSize: 40,
                                    letterSpacing: 1.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.only(left: 0.8),
                                child: Text(
                                  'Gestión Escolar Inteligente',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'FuentePrincipal',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    letterSpacing: 0.8,
                                    color: Colors.white.withOpacity(0.85),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const Spacer(flex: 3),

                    // Indicador de carga y versión
                    FadeTransition(
                      opacity: _textFade,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white.withOpacity(0.9)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Versión 1.1',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'FuenteSecundaria',
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}