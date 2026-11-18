import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Registra al profesor en Auth y guarda su perfil en Firestore
  Future<void> registrarProfesor(String nombre, String correo, String contrasena) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: correo, password: contrasena);

    await _db.collection('profesores').doc(cred.user!.uid).set({
      'nombre': nombre,
      'correo': correo,
      'creado': FieldValue.serverTimestamp(),
    });
  }

  // Inicia sesión detectando automáticamente si es profe o alumno
  Future<void> entrar(String usuario, String contrasena) {
    final correo = usuario.contains('@')
        ? usuario
        : '$usuario@alumnos.uaem.mx';

    return _auth.signInWithEmailAndPassword(
        email: correo, password: contrasena);
  }

  // Cierra la sesión activa
  Future<void> salir() => _auth.signOut();
}