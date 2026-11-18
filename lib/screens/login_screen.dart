import 'package:asistencia_app/screens/home_profesor_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'registro_screen.dart';
import 'home_alumno_screen.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailProfesor = TextEditingController();
  final TextEditingController _passProfesor = TextEditingController();
  final TextEditingController _cuentaAlumno = TextEditingController();

  // --- Variable para controlar la visibilidad de la contraseña ---
  bool _ocultarPassword = true;

  // --- Mantener sesión iniciada (la revisión al abrir la hace la splash) ---
  bool _mantenerSesion = false;

  final Color bgColor = const Color(0xFFF8FAFC);
  final Color textDark = const Color(0xFF1E293B);
  final Color textLight = const Color(0xFF64748B);
  final Color colorProfesor = const Color(0xFF4F46E5);
  final Color colorAlumno = const Color(0xFF0EA5E9);

  void _mostrarMensaje(String mensaje, Color colorFondo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje, style: const TextStyle(fontFamily: 'FuenteSecundaria', color: Colors.white)),
        backgroundColor: colorFondo,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _loginProfesor() async {
    if (_emailProfesor.text.trim().isEmpty || _passProfesor.text.trim().isEmpty) {
      _mostrarMensaje("Por favor, llena todos los campos.", Colors.redAccent);
      return;
    }
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailProfesor.text.trim(),
        password: _passProfesor.text.trim(),
      );
      // Guardar la opción elegida
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('mantener_sesion', _mantenerSesion);

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeProfesorScreen()));
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        _mostrarMensaje("Correo o contraseña incorrectos.", Colors.redAccent);
      } else {
        _mostrarMensaje("Error al iniciar sesión: ${e.message}", Colors.redAccent);
      }
    }
  }

  // --- Diálogo Flotante para Recuperar Contraseña ---
  void _mostrarDialogoRecuperacion() {
    final TextEditingController emailRecuperacion = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_reset_rounded, size: 60, color: colorProfesor),
                const SizedBox(height: 16),
                Text("Recuperar Contraseña", style: TextStyle(fontFamily: 'FuentePrincipal', fontWeight: FontWeight.bold, fontSize: 20, color: textDark)),
                const SizedBox(height: 8),
                Text("Ingresa tu correo para recibir un enlace de recuperación.", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'FuenteSecundaria', fontSize: 14, color: textLight)),
                const SizedBox(height: 24),
                TextField(
                  controller: emailRecuperacion,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontFamily: 'FuenteSecundaria'),
                  decoration: InputDecoration(
                    hintText: "profesor@escuela.com",
                    hintStyle: TextStyle(color: textLight.withOpacity(0.5)),
                    filled: true,
                    fillColor: bgColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("Cancelar", style: TextStyle(fontFamily: 'FuenteSecundaria', fontWeight: FontWeight.bold, color: textLight)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          String email = emailRecuperacion.text.trim();
                          if (email.isEmpty) {
                            _mostrarMensaje("Escribe un correo válido.", Colors.redAccent);
                            return;
                          }
                          Navigator.pop(context); // Cierra el diálogo
                          try {
                            await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                            _mostrarMensaje("Enlace enviado a $email", Colors.green);
                          } catch (e) {
                            _mostrarMensaje("Error: Revisa que el correo esté registrado.", Colors.redAccent);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorProfesor,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text("Enviar", style: TextStyle(fontFamily: 'FuenteSecundaria', fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loginAlumno() async {
    String numeroCuenta = _cuentaAlumno.text.trim();
    if (numeroCuenta.isEmpty) {
      _mostrarMensaje("Ingresa tu número de cuenta.", Colors.redAccent);
      return;
    }
    
    try {
      // 1. Buscamos en TODAS las materias de la base de datos
      var materiasSnap = await FirebaseFirestore.instance.collection('materias').get();
      bool cuentaEncontrada = false;

      // 2. Revisamos si el alumno está inscrito en al menos una
      for (var mat in materiasSnap.docs) {
        var alumnoDoc = await mat.reference.collection('alumnos').doc(numeroCuenta).get();
        if (alumnoDoc.exists) {
          cuentaEncontrada = true;
          break; 
        }
      }

      // 3. Decidimos qué hacer
      if (cuentaEncontrada) {
        // Guardar la opción elegida en caché local
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('mantener_sesion', _mantenerSesion);
        await prefs.setString('cuenta_alumno', numeroCuenta); // Se guarda para que el splash sepa quién es

        if (mounted) {
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (context) => HomeAlumnoScreen(numeroCuenta: numeroCuenta))
          );
        }
      } else {
        _mostrarMensaje("Este número de cuenta no está registrado en ninguna materia.", Colors.redAccent);
      }
    } catch (e) {
      _mostrarMensaje("Error de conexión, intenta de nuevo.", Colors.redAccent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              children: [
                const SizedBox(height: 50),
                // Aquí se cambió el icono por la imagen icon.jpeg
                Container(
                  padding: const EdgeInsets.all(8), // Se ajustó el padding
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    shape: BoxShape.circle, 
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05), 
                        blurRadius: 20, 
                        offset: const Offset(0, 10)
                      )
                    ]
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/icon.jpeg',
                      width: 80, // Puedes ajustar este tamaño
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text("AsistApp", style: TextStyle(fontFamily: 'FuentePrincipal', fontWeight: FontWeight.normal, fontSize: 32, color: textDark)),
                Text("Gestión Escolar Inteligente", style: TextStyle(fontFamily: 'FuentePrincipal', fontWeight: FontWeight.bold, fontSize: 14, color: textLight)),
                const SizedBox(height: 40),
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: TabBar(
                    labelColor: colorProfesor,
                    unselectedLabelColor: textLight,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(color: colorProfesor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                    labelStyle: const TextStyle(fontFamily: 'FuentePrincipal', fontWeight: FontWeight.bold),
                    tabs: const [Tab(text: "Profesor"), Tab(text: "Alumno")],
                  ),
                ),
                const SizedBox(height: 30),
                Expanded(child: TabBarView(children: [_formularioProfesor(), _formularioAlumno()])),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _formularioProfesor() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInputLabel("Correo Electrónico"),
          _buildTextField(_emailProfesor, "profesor@escuela.com", false),
          const SizedBox(height: 20),
          _buildInputLabel("Contraseña"),
          _buildTextField(_passProfesor, "••••••••", true),
          const SizedBox(height: 12),
          _buildMantenerSesion(colorProfesor),
          const SizedBox(height: 18),
          _buildBoton("Ingresar como Profesor", colorProfesor, _loginProfesor),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _mostrarDialogoRecuperacion,
            child: Text("¿Olvidaste tu contraseña?", style: TextStyle(fontFamily: 'FuenteSecundaria', color: textLight)),
          ),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegistroScreen())),
            child: Text("¿Primera vez? Regístrate aquí", style: TextStyle(fontFamily: 'FuenteSecundaria', fontWeight: FontWeight.bold, color: colorProfesor)),
          ),
        ],
      ),
    );
  }

  Widget _formularioAlumno() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInputLabel("Número de Cuenta"),
          _buildTextField(_cuentaAlumno, "Ej. 20261234", false, isNumber: true),
          const SizedBox(height: 12),
          _buildMantenerSesion(colorAlumno),
          const SizedBox(height: 18),
          _buildBoton("Ingresar como Alumno", colorAlumno, _loginAlumno),
        ],
      ),
    );
  }

  // --- Casilla "Mantener sesión iniciada" ---
  Widget _buildMantenerSesion(Color color) {
    return CheckboxListTile(
      value: _mantenerSesion,
      onChanged: (v) => setState(() => _mantenerSesion = v ?? false),
      title: Text("Mantener sesión iniciada",
          style: TextStyle(fontFamily: 'FuenteSecundaria', fontSize: 14, color: textDark)),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      activeColor: color,
      dense: true,
    );
  }

  Widget _buildInputLabel(String texto) {
    return Padding(padding: const EdgeInsets.only(bottom: 8.0, left: 4.0), child: Text(texto, style: TextStyle(fontFamily: 'FuenteSecundaria', fontSize: 14, color: textDark)));
  }

  // --- Lógica del Icono y visibilidad ---
  Widget _buildTextField(TextEditingController controller, String hint, bool isPassword, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      // Si es contraseña, usamos la variable de estado. Si no, nunca ocultamos el texto.
      obscureText: isPassword ? _ocultarPassword : false,
      keyboardType: isNumber ? TextInputType.number : TextInputType.emailAddress,
      style: const TextStyle(fontFamily: 'FuenteSecundaria'),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: textLight.withOpacity(0.5)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colorProfesor, width: 2)),

        // Icono (suffixIcon) si el campo es de tipo contraseña
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _ocultarPassword ? Icons.visibility_off : Icons.visibility,
                  color: textLight,
                ),
                onPressed: () {
                  // Actualizamos el estado para redibujar el widget
                  setState(() {
                    _ocultarPassword = !_ocultarPassword;
                  });
                },
              )
            : null,
      ),
    );
  }

  Widget _buildBoton(String texto, Color color, VoidCallback accion) {
    return ElevatedButton(
      onPressed: accion,
      style: ElevatedButton.styleFrom(backgroundColor: color, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      child: Text(texto, style: const TextStyle(fontFamily: 'FuenteSecundaria', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
    );
  }
}