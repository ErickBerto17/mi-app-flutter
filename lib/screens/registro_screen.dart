import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();

  final Color bgColor = const Color(0xFFF8FAFC);
  final Color textDark = const Color(0xFF1E293B);
  final Color colorProfesor = const Color(0xFF4F46E5);
  final Color colorExito = const Color(0xFF10B981);

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje, style: const TextStyle(fontFamily: 'FuenteSecundaria', color: Colors.white)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _crearCuenta() async {
    String nombre = _nombreCtrl.text.trim();
    String email = _emailCtrl.text.trim();
    String pass = _passCtrl.text.trim();

    if (nombre.isEmpty || email.isEmpty || pass.isEmpty) {
      _mostrarError("Todos los campos son obligatorios.");
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _mostrarError("Ingresa un correo electrónico válido.");
      return;
    }

    // --- NUEVA VALIDACIÓN: 1 Mayúscula, 1 Número, 8 caracteres ---
    if (!RegExp(r'^(?=.*[A-Z])(?=.*[0-9]).{8,}$').hasMatch(pass)) {
      _mostrarError("La contraseña requiere al menos 8 caracteres, un número y una mayúscula.");
      return;
    }

    try {
      UserCredential user = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );
      await user.user?.updateDisplayName(nombre);
      _mostrarDialogoExito();
    } on FirebaseAuthException catch (e) {
      // --- VALIDACIÓN DE CORREO YA EXISTENTE ---
      if (e.code == 'email-already-in-use') {
        _mostrarError("Este correo ya está registrado por otro profesor.");
      } else {
        _mostrarError("Ocurrió un error: ${e.message}");
      }
    }
  }

  void _mostrarDialogoExito() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: colorExito.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.check_circle_rounded, color: colorExito, size: 60)),
                const SizedBox(height: 20),
                const Text("¡Registro Exitoso!", style: TextStyle(fontFamily: 'FuentePrincipal', fontWeight: FontWeight.normal, fontSize: 22)),
                const SizedBox(height: 8),
                const Text("Tu cuenta de profesor ha sido creada.", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'FuenteSecundaria', fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: colorExito, padding: const EdgeInsets.symmetric(vertical: 16), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: const Text("Iniciar Sesión", style: TextStyle(fontFamily: 'FuenteSecundaria', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(backgroundColor: bgColor, elevation: 0, iconTheme: IconThemeData(color: textDark), centerTitle: true, title: Text("Crear Cuenta", style: TextStyle(fontFamily: 'FuentePrincipal', fontWeight: FontWeight.bold, color: textDark, fontSize: 18))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInputLabel("Nombre Completo"),
            _buildTextField(_nombreCtrl, "Ej. Juan Pérez", false),
            const SizedBox(height: 20),
            _buildInputLabel("Correo Electrónico"),
            _buildTextField(_emailCtrl, "profesor@escuela.com", false),
            const SizedBox(height: 20),
            _buildInputLabel("Contraseña"),
            _buildTextField(_passCtrl, "••••••••", true),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _crearCuenta,
              style: ElevatedButton.styleFrom(backgroundColor: colorProfesor, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text("Registrarse", style: TextStyle(fontFamily: 'FuenteSecundaria', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(String texto) {
    return Padding(padding: const EdgeInsets.only(bottom: 8.0, left: 4.0), child: Text(texto, style: TextStyle(fontFamily: 'FuenteSecundaria', fontSize: 14, color: textDark)));
  }

  Widget _buildTextField(TextEditingController controller, String hint, bool isPassword) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(fontFamily: 'FuenteSecundaria'),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colorProfesor, width: 2)),
      ),
    );
  }
}