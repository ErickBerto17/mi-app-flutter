import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart'; 

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final Color colorPrincipal = const Color(0xFF4F46E5);
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color textDark = const Color(0xFF1E293B);

  String nombreUsuario = "";
  
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _correoCtrl = TextEditingController();
  final TextEditingController _nuevaPassCtrl = TextEditingController();
  final TextEditingController _passActualCtrl = TextEditingController(); // Para la seguridad

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    nombreUsuario = user?.displayName ?? "Profesor";
    _nombreCtrl.text = nombreUsuario;
    _correoCtrl.text = user?.email ?? "";
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _nuevaPassCtrl.dispose();
    _passActualCtrl.dispose();
    super.dispose();
  }

  void _cerrarSesion() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  Future<void> _guardarCambios() async {
    if (_passActualCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa tu contraseña actual por seguridad.')));
      return;
    }

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        // 1. Reautenticar al usuario por seguridad
        AuthCredential cred = EmailAuthProvider.credential(email: user.email!, password: _passActualCtrl.text);
        await user.reauthenticateWithCredential(cred);

        // 2. Aplicar los cambios
        if (_nombreCtrl.text != user.displayName) await user.updateDisplayName(_nombreCtrl.text);
        if (_correoCtrl.text != user.email) await user.verifyBeforeUpdateEmail(_correoCtrl.text); // o user.updateEmail(_correoCtrl.text)
        if (_nuevaPassCtrl.text.isNotEmpty) await user.updatePassword(_nuevaPassCtrl.text);

        setState(() {
          nombreUsuario = _nombreCtrl.text;
          _passActualCtrl.clear();
          _nuevaPassCtrl.clear();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datos actualizados correctamente.')));
        }
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: Verifica que tu contraseña actual sea correcta. (${e.code})')));
    }
  }

  // --- NUEVA FUNCIÓN: Limpiar Caché Local ---
  Future<void> _limpiarCache() async {
    try {
      // Limpia SharedPreferences (suele usarse para caché de variables de la app)
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Caché local limpiado con éxito.', style: TextStyle(fontFamily: 'FuenteSecundaria', color: Colors.white)),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al limpiar el caché.'), backgroundColor: Colors.redAccent)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: colorPrincipal,
          elevation: 0,
          title: Row(
            children: [
              const Icon(Icons.adb, color: Colors.white),
              const SizedBox(width: 10),
              // Título dinámico con el nombre del profe
              Expanded(child: Text('Configuración de $nombreUsuario', style: const TextStyle(fontSize: 16, color: Colors.white, fontFamily: 'FuentePrincipal'), overflow: TextOverflow.ellipsis)),
            ],
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [Tab(text: 'Cuenta'), Tab(text: 'General')],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: TabBarView(
            children: [_buildCuentaTab(), _buildGeneralTab()],
          ),
        ),
      ),
    );
  }

  Widget _buildCuentaTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person, color: colorPrincipal),
                    const SizedBox(width: 8),
                    Text('EDITAR CREDENCIALES', style: TextStyle(color: colorPrincipal, fontWeight: FontWeight.bold, fontFamily: 'FuentePrincipal')),
                  ],
                ),
                const SizedBox(height: 15),
                _customTextField('Nombre de usuario', _nombreCtrl),
                const SizedBox(height: 10),
                _customTextField('Correo electrónico', _correoCtrl),
                const SizedBox(height: 10),
                _customTextField('Nueva contraseña (opcional)', _nuevaPassCtrl, obscureText: true),
                const Divider(height: 30, thickness: 1),
                _customTextField('Contraseña actual (OBLIGATORIA para guardar)', _passActualCtrl, obscureText: true),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: colorPrincipal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: _guardarCambios,
                    child: const Text('Guardar Cambios', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildBotonCerrarSesion(),
        ],
      ),
    );
  }

  Widget _buildGeneralTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Configuración General de AsistApp', style: TextStyle(color: colorPrincipal, fontWeight: FontWeight.bold, fontFamily: 'FuentePrincipal')),
              const SizedBox(height: 10),
              Text('Versión: 1.1', style: TextStyle(color: textDark, fontSize: 13, fontFamily: 'FuenteSecundaria')),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity, 
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300], 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0
                  ), 
                  onPressed: _limpiarCache, // Conectado a la nueva función
                  child: Text('Limpiar Caché Local', style: TextStyle(color: textDark, fontWeight: FontWeight.bold))
                )
              ),
            ],
          ),
        ),
        const Spacer(),
        _buildBotonCerrarSesion(),
      ],
    );
  }

  Widget _customTextField(String label, TextEditingController controller, {bool obscureText = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: textDark, fontSize: 12, fontFamily: 'FuenteSecundaria', fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: TextStyle(color: textDark),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: colorPrincipal, width: 2), borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
      ],
    );
  }

  Widget _buildBotonCerrarSesion() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: _cerrarSesion,
        icon: const Icon(Icons.logout, color: Colors.white),
        label: const Text('Cerrar Sesión', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'FuentePrincipal')),
      ),
    );
  }
}