import 'dart:core';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:qr_flutter/qr_flutter.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; 
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';
import 'dart:typed_data';

import 'editar_clase_screen.dart';

class DetalleClaseScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> materiaData;

  const DetalleClaseScreen({super.key, required this.docId, required this.materiaData});

  @override
  State<DetalleClaseScreen> createState() => _DetalleClaseScreenState();
}

class _DetalleClaseScreenState extends State<DetalleClaseScreen> {
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color textDark = const Color(0xFF1E293B);
  final Color greenAccent = const Color(0xFF22C55E); 
  
  late Color colorMateria;

  // Controladores Alumnos
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _cuentaCtrl = TextEditingController();
  
  // Archivos Masivos
  String? _archivoSeleccionadoPath;
  String _archivoSeleccionadoNombre = "Sin archivos seleccionados";
  Uint8List? _archivoBytes; 

  // Controladores Tareas y Rúbricas
  final TextEditingController _tituloTareaCtrl = TextEditingController();
  String _tipoTareaSeleccionado = 'Entregable (Sí/No)';
  final List<String> _tiposTarea = ['Entregable (Sí/No)', 'Calificación numérica (0-10)', 'Rúbrica'];

  // Variables para Configuración de Rúbrica
  int _numAspectosRubrica = 3;
  bool _rubricaPartesIguales = true;
  final List<TextEditingController> _pesosRubricaCtrls = [];
  final List<TextEditingController> _titulosAspectosCtrls = [];

  // Controladores Evaluar
  String? _tareaAEvaluarId;
  String? _tareaAEvaluarTipo;
  Map<String, dynamic>? _tareaAEvaluarData; // <--- Guarda toda la info de la tarea (incluyendo rúbrica)

  late String hoyString;
  late String hoyFormatoVisual;

  @override
  void initState() {
    super.initState();
    colorMateria = Color(widget.materiaData['color']);
    DateTime now = DateTime.now();
    hoyString = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    hoyFormatoVisual = "${now.day}/${now.month}/${now.year}";
    _actualizarControladoresRubrica();
  }

  void _actualizarControladoresRubrica() {
    int currentLen = _pesosRubricaCtrls.length;
    double valorInicial = 100 / _numAspectosRubrica;
    
    if (_numAspectosRubrica > currentLen) {
      for (int i = currentLen; i < _numAspectosRubrica; i++) {
        _pesosRubricaCtrls.add(TextEditingController(text: valorInicial.toStringAsFixed(1)));
        _titulosAspectosCtrls.add(TextEditingController());
      }
    } else if (_numAspectosRubrica < currentLen) {
      _pesosRubricaCtrls.removeRange(_numAspectosRubrica, currentLen);
      _titulosAspectosCtrls.removeRange(_numAspectosRubrica, currentLen);
    }
    
    if (_rubricaPartesIguales) {
      for (var ctrl in _pesosRubricaCtrls) {
        ctrl.text = valorInicial.toStringAsFixed(1);
      }
    }
  }

  // ==========================================
  // COMPONENTES GLOBALES Y ALERTAS
  // ==========================================

  void _mostrarExito(String titulo, String mensaje) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 40)),
            const SizedBox(height: 20),
            Text(titulo, style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'FuentePrincipal')),
            const SizedBox(height: 8),
            Text(mensaje, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'FuenteSecundaria')),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () => Navigator.pop(context),
                child: const Text('Aceptar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _verificarPassword(VoidCallback onAutorizado) async {
    TextEditingController passCtrl = TextEditingController();
    bool ocultarPass = true;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Column(
                children: [
                  const Icon(Icons.lock, color: Colors.orange, size: 40),
                  const SizedBox(height: 10),
                  Text('Contraseña Requerida', style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontFamily: 'FuentePrincipal', fontSize: 18)),
                  const Text('Acción protegida. Ingresa tu contraseña.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              content: TextField(
                controller: passCtrl,
                obscureText: ocultarPass,
                style: TextStyle(color: textDark),
                decoration: InputDecoration(
                  hintText: 'Contraseña',
                  filled: true, fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  suffixIcon: IconButton(icon: Icon(ocultarPass ? Icons.visibility_off : Icons.visibility, color: Colors.grey), onPressed: () { setStateDialog(() { ocultarPass = !ocultarPass; }); }),
                ),
              ),
              actionsAlignment: MainAxisAlignment.spaceEvenly,
              actions: [
                ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: () => Navigator.pop(context), child: Text('Cancelar', style: TextStyle(color: textDark))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () async {
                    try {
                      User? user = FirebaseAuth.instance.currentUser;
                      AuthCredential cred = EmailAuthProvider.credential(email: user!.email!, password: passCtrl.text);
                      await user.reauthenticateWithCredential(cred);
                      Navigator.pop(context); 
                      onAutorizado(); 
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña incorrecta')));
                    }
                  },
                  child: const Text('Autorizar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  // ==========================================
  // PESTAÑA 1: ALUMNOS
  // ==========================================
  void _mostrarQR(String nombre, String cuenta) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 24), 
                    Text("Credencial QR", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'FuentePrincipal')),
                    GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.grey, size: 24))
                  ],
                ),
                const SizedBox(height: 8),
                Text(nombre, textAlign: TextAlign.center, style: TextStyle(color: colorMateria, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'FuenteSecundaria')),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200, width: 2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
                  child: QrImageView(data: cuenta, version: QrVersions.auto, size: 160.0, foregroundColor: textDark),
                ),
                const SizedBox(height: 24),
                Text("Cta: $cuenta", style: const TextStyle(color: Colors.grey, fontSize: 14, fontFamily: 'FuenteSecundaria')),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: colorMateria, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cerrar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        );
      }
    );
  }

  Future<void> _eliminarAlumno(String cuenta) async {
    await FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('alumnos').doc(cuenta).delete();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alumno eliminado')));
  }

  Future<void> _registrarManual() async {
    if (_nombreCtrl.text.trim().isEmpty || _cuentaCtrl.text.trim().isEmpty) return;
    await FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('alumnos').doc(_cuentaCtrl.text.trim()).set({'nombre': _nombreCtrl.text.trim(), 'cuenta': _cuentaCtrl.text.trim()});
    _nombreCtrl.clear();
    _cuentaCtrl.clear();
    if (mounted) _mostrarExito('Éxito', 'Alumno registrado correctamente.');
  }

  Future<void> _seleccionarArchivo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx'], withData: true);
    if (result != null) {
      setState(() { _archivoBytes = result.files.single.bytes; _archivoSeleccionadoPath = result.files.single.path; _archivoSeleccionadoNombre = result.files.single.name; });
    }
  }

  Future<void> _procesarArchivo() async {
    if (_archivoBytes == null && _archivoSeleccionadoPath == null) return;
    try {
      var bytes = _archivoBytes ?? File(_archivoSeleccionadoPath!).readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);
      WriteBatch batch = FirebaseFirestore.instance.batch();
      int count = 0;

      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet == null || sheet.rows.isEmpty) continue;
        int colNombre = 0, colCuenta = 1, filaInicio = 1; 

        for (int i = 0; i < sheet.rows.length && i < 5; i++) {
          var row = sheet.rows[i];
          int tempColNombre = -1, tempColCuenta = -1;
          for (int c = 0; c < row.length; c++) {
            var cell = row[c];
            if (cell != null && cell.value != null) {
              String val = cell.value.toString().toLowerCase();
              if (val.contains('nombre')) tempColNombre = c;
              if (val.contains('cuenta') || val.contains('cta') || val.contains('matrícula')) tempColCuenta = c;
            }
          }
          if (tempColNombre != -1 && tempColCuenta != -1) { colNombre = tempColNombre; colCuenta = tempColCuenta; filaInicio = i + 1; break; }
        }

        for (int i = filaInicio; i < sheet.rows.length; i++) { 
          var row = sheet.rows[i];
          if (colNombre >= row.length || colCuenta >= row.length) continue;
          var celdaNombre = row[colNombre], celdaCuenta = row[colCuenta];

          if (celdaNombre != null && celdaCuenta != null && celdaNombre.value != null && celdaCuenta.value != null) {
            String limpiarCelda(String texto) {
              texto = texto.replaceAll(RegExp(r'^(Text|Int|Double|SharedString)CellValue\('), '').replaceAll(RegExp(r'\)$'), '');
              if (texto.startsWith("'") && texto.endsWith("'") && texto.length >= 2) texto = texto.substring(1, texto.length - 1);
              return texto.replaceAll(RegExp(r'\.0$'), '').trim();
            }

            String nombre = limpiarCelda(celdaNombre.value.toString()), cuenta = limpiarCelda(celdaCuenta.value.toString());
            if (nombre.isNotEmpty && cuenta.isNotEmpty && !cuenta.toLowerCase().contains('cuenta')) {
              var docRef = FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('alumnos').doc(cuenta);
              batch.set(docRef, {'nombre': nombre, 'cuenta': cuenta});
              count++;
            }
          }
        }
        if (count > 0) break; 
      }

      if (count > 0) {
        await batch.commit();
        setState(() { _archivoSeleccionadoPath = null; _archivoBytes = null; _archivoSeleccionadoNombre = "Sin archivos seleccionados"; });
        if (mounted) _mostrarExito('Importación Exitosa', 'Se han cargado $count alumnos.');
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se encontraron alumnos válidos.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al leer Excel: $e', maxLines: 3)));
    }
  }

  Widget _buildAlumnosTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Registrar Alumno Manual', style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontFamily: 'FuentePrincipal')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(flex: 3, child: TextField(controller: _nombreCtrl, style: TextStyle(color: textDark, fontSize: 13), decoration: InputDecoration(hintText: 'Nombre', hintStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)))),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: TextField(controller: _cuentaCtrl, keyboardType: TextInputType.number, style: TextStyle(color: textDark, fontSize: 13), decoration: InputDecoration(hintText: 'Cuenta', hintStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)))),
                    const SizedBox(width: 8),
                    GestureDetector(onTap: _registrarManual, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.add, color: Colors.white, size: 22)))
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.green.withOpacity(0.3), width: 1), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [const Icon(Icons.feed_outlined, color: Colors.green, size: 20), const SizedBox(width: 8), const Text('Carga Masiva (Excel / CSV)', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontFamily: 'FuentePrincipal'))]),
                const SizedBox(height: 12),
                Row(children: [const Text('Columnas requeridas: ', style: TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'FuenteSecundaria')), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: const Text('nombre', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green))), const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: const Text('cuenta', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)))]),
                const SizedBox(height: 16),
                Row(children: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0), onPressed: _seleccionarArchivo, child: const Text('Seleccionar archivo', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))), const SizedBox(width: 12), Expanded(child: Text(_archivoSeleccionadoNombre, style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis))]),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _archivoSeleccionadoPath != null || _archivoBytes != null ? Colors.green : Colors.grey[300], padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), onPressed: (_archivoSeleccionadoPath != null || _archivoBytes != null) ? _procesarArchivo : null, child: Text('Procesar Archivo', style: TextStyle(color: (_archivoSeleccionadoPath != null || _archivoBytes != null) ? Colors.white : Colors.grey[600], fontWeight: FontWeight.bold))))
              ],
            ),
          ),
          const SizedBox(height: 30),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('alumnos').orderBy('nombre').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text("Aún no hay alumnos.", style: TextStyle(color: Colors.grey))));
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var alumno = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(alumno['nombre'], style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)), const SizedBox(width: 4), Icon(Icons.check_circle, color: Colors.green.withOpacity(0.5), size: 14)]), const SizedBox(height: 4), Text("Cta: ${alumno['cuenta']}", style: const TextStyle(fontSize: 12, color: Colors.grey))])),
                        Row(
                          children: [
                            GestureDetector(onTap: () => _mostrarQR(alumno['nombre'], alumno['cuenta']), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle), child: const Icon(Icons.qr_code_2, color: Colors.grey, size: 22))),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => _verificarPassword(() => _eliminarAlumno(alumno['cuenta'])), 
                              child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.delete, color: Colors.red, size: 22))
                            ),
                          ],
                        )
                      ],
                    ),
                  );
                },
              );
            },
          )
        ],
      ),
    );
  }

  // ==========================================
  // PESTAÑA 2: ASISTENCIA
  // ==========================================

  void _abrirEscanerAsistencia() {
    String cuentaEscaneada = "";
    bool procesando = false;
    String mensajeEscaner = "Apunta la cámara al código QR";
    Color colorMensaje = Colors.grey;
    IconData iconoMensaje = Icons.qr_code_scanner;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: StatefulBuilder( 
            builder: (context, setStateEscaner) {
              return Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 24),
                        Text("Registrar Asistencia", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 16)),
                        GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.grey, size: 20))
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      height: 250, width: double.infinity,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: colorMensaje == Colors.green ? Colors.green : (colorMensaje == Colors.orange ? Colors.orange : Colors.grey.shade300), width: 2)),
                      clipBehavior: Clip.hardEdge,
                      child: MobileScanner(
                        onDetect: (capture) async {
                          if (procesando) return; 
                          final List<Barcode> barcodes = capture.barcodes;
                          
                          if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                            procesando = true;
                            cuentaEscaneada = barcodes.first.rawValue!;
                            DocumentSnapshot docHoy = await FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('asistencias').doc(hoyString).get();
                            
                            if (docHoy.exists && (docHoy.data() as Map<String, dynamic>).containsKey(cuentaEscaneada) && (docHoy.data() as Map<String, dynamic>)[cuentaEscaneada] == true) {
                              setStateEscaner(() { mensajeEscaner = "¡Ya se registró: $cuentaEscaneada!"; colorMensaje = Colors.orange; iconoMensaje = Icons.info; });
                            } else {
                              await FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('asistencias').doc(hoyString).set({cuentaEscaneada: true}, SetOptions(merge: true));
                              setStateEscaner(() { mensajeEscaner = "¡Asistencia: $cuentaEscaneada!"; colorMensaje = Colors.green; iconoMensaje = Icons.check_circle; });
                            }
                            await Future.delayed(const Duration(milliseconds: 1800)); 
                            if (mounted) { setStateEscaner(() { mensajeEscaner = "Apunta la cámara al código QR"; colorMensaje = Colors.grey; iconoMensaje = Icons.qr_code_scanner; procesando = false; }); }
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(color: colorMensaje == Colors.green ? Colors.green.withOpacity(0.1) : (colorMensaje == Colors.orange ? Colors.orange.withOpacity(0.1) : Colors.grey[100]), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(iconoMensaje, color: colorMensaje, size: 20),
                          const SizedBox(width: 8),
                          Text(mensajeEscaner, style: TextStyle(color: colorMensaje, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      )
                    ),
                  ],
                ),
              );
            }
          ),
        );
      }
    );
  }

  Widget _buildAsistenciaTab() {
    return Container(
      color: bgColor, 
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: greenAccent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              onPressed: () => _verificarPassword(_abrirEscanerAsistencia), 
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
              label: const Text('Pasar Lista por QR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'FuentePrincipal')),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              width: double.infinity, padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Nombre de Alumno', style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'FuentePrincipal'))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: colorMateria.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text("Fecha: $hoyFormatoVisual", style: TextStyle(color: colorMateria, fontWeight: FontWeight.bold, fontSize: 12)),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(color: Colors.grey.shade200, thickness: 1),
                  const SizedBox(height: 8),
                  
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('alumnos').orderBy('nombre').snapshots(),
                      builder: (context, snapshotAlumnos) {
                        if (!snapshotAlumnos.hasData) return const Center(child: CircularProgressIndicator());
                        var alumnos = snapshotAlumnos.data!.docs;
                        return StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('asistencias').doc(hoyString).snapshots(),
                          builder: (context, snapshotAsistencia) {
                            Map<String, dynamic> asistenciasDeHoy = {};
                            if (snapshotAsistencia.hasData && snapshotAsistencia.data!.exists) asistenciasDeHoy = snapshotAsistencia.data!.data() as Map<String, dynamic>;

                            return ListView.separated(
                              itemCount: alumnos.length,
                              separatorBuilder: (context, index) => Divider(color: Colors.grey.shade100, height: 24),
                              itemBuilder: (context, index) {
                                var dataAlumno = alumnos[index].data() as Map<String, dynamic>;
                                String numCuenta = dataAlumno['cuenta'];
                                String nombre = dataAlumno['nombre'];
                                bool asistio = asistenciasDeHoy.containsKey(numCuenta) && asistenciasDeHoy[numCuenta] == true;

                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text(nombre, style: TextStyle(color: textDark, fontSize: 14), overflow: TextOverflow.ellipsis)),
                                    GestureDetector(
                                      onTap: () {
                                        _verificarPassword(() async {
                                          await FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('asistencias').doc(hoyString).set({
                                            numCuenta: !asistio
                                          }, SetOptions(merge: true));
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(color: asistio ? Colors.green : Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                                        child: Row(
                                          children: [
                                            Icon(asistio ? Icons.check : Icons.close, color: asistio ? Colors.white : Colors.grey.shade600, size: 14),
                                            const SizedBox(width: 6),
                                            Text(asistio ? 'Sí' : 'No', style: TextStyle(color: asistio ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    )
                                  ],
                                );
                              },
                            );
                          }
                        );
                      }
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // ==========================================
  // PESTAÑA 3: TAREAS (ACTIVIDADES)
  // ==========================================

  Future<void> _crearTarea() async {
    if (_tituloTareaCtrl.text.trim().isEmpty) return;
    
    Map<String, dynamic> datosTarea = {
      'titulo': _tituloTareaCtrl.text.trim(),
      'tipo': _tipoTareaSeleccionado,
      'fechaCreacion': FieldValue.serverTimestamp(),
    };

    if (_tipoTareaSeleccionado == 'Rúbrica') {
      if (!_rubricaPartesIguales) {
        double sum = 0;
        for (var ctrl in _pesosRubricaCtrls) {
          sum += double.tryParse(ctrl.text) ?? 0;
        }
        if ((sum - 100).abs() > 0.1) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Los pesos deben sumar exactamente 100%'), backgroundColor: Colors.redAccent));
          return;
        }
      }

      datosTarea['numAspectos'] = _numAspectosRubrica;
      datosTarea['partesIguales'] = _rubricaPartesIguales;
      
      List<Map<String, dynamic>> aspectos = [];
      for (int i = 0; i < _numAspectosRubrica; i++) {
        aspectos.add({
          'titulo': _titulosAspectosCtrls[i].text.trim().isEmpty ? "Aspecto ${i+1}" : _titulosAspectosCtrls[i].text.trim(),
          'peso': double.tryParse(_pesosRubricaCtrls[i].text) ?? (100 / _numAspectosRubrica)
        });
      }
      datosTarea['aspectos'] = aspectos;
    }

    await FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('tareas').add(datosTarea);
    _tituloTareaCtrl.clear();
    setState(() {
      _tipoTareaSeleccionado = 'Entregable (Sí/No)';
      _numAspectosRubrica = 3;
      _rubricaPartesIguales = true;
      _actualizarControladoresRubrica();
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Actividad creada correctamente'), backgroundColor: Colors.green));
  }

  Future<void> _eliminarTarea(String idTarea) async {
    await FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('tareas').doc(idTarea).delete();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Actividad eliminada')));
  }

  void _mostrarModalEditarTarea(String idTarea, Map<String, dynamic> dataActual) {
    TextEditingController editTituloCtrl = TextEditingController(text: dataActual['titulo']);
    String editTipoSeleccionado = dataActual['tipo'] ?? 'Entregable (Sí/No)';
    
    int editNumAspectos = dataActual['numAspectos'] ?? 3;
    bool editPartesIguales = dataActual['partesIguales'] ?? true;
    
    List<TextEditingController> editTitulosCtrls = [];
    List<TextEditingController> editPesosCtrls = [];

    if (editTipoSeleccionado == 'Rúbrica' && dataActual.containsKey('aspectos')) {
      List aspectos = dataActual['aspectos'];
      editNumAspectos = aspectos.length;
      for (var a in aspectos) {
        editTitulosCtrls.add(TextEditingController(text: a['titulo']));
        editPesosCtrls.add(TextEditingController(text: a['peso'].toString()));
      }
    } else {
      for(int i=0; i<editNumAspectos; i++) {
        editTitulosCtrls.add(TextEditingController());
        editPesosCtrls.add(TextEditingController(text: (100/editNumAspectos).toStringAsFixed(1)));
      }
    }

    void recalcularRubricaLocal() {
      int len = editPesosCtrls.length;
      double valor = 100 / editNumAspectos;
      if (editNumAspectos > len) {
        for (int i = len; i < editNumAspectos; i++) {
          editTitulosCtrls.add(TextEditingController());
          editPesosCtrls.add(TextEditingController(text: valor.toStringAsFixed(1)));
        }
      } else if (editNumAspectos < len) {
        editTitulosCtrls.removeRange(editNumAspectos, len);
        editPesosCtrls.removeRange(editNumAspectos, len);
      }
      if (editPartesIguales) {
        for (var c in editPesosCtrls) {
          c.text = valor.toStringAsFixed(1);
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Editar Actividad', style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontFamily: 'FuentePrincipal')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Título de la tarea', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: editTituloCtrl, 
                      style: TextStyle(color: textDark, fontSize: 14), 
                      decoration: InputDecoration(filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14))
                    ),
                    const SizedBox(height: 16),
                    const Text('Tipo', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: editTipoSeleccionado,
                      decoration: InputDecoration(filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
                      items: _tiposTarea.map((t) => DropdownMenuItem(value: t, child: Text(t, style: TextStyle(fontSize: 13, color: textDark)))).toList(),
                      onChanged: (val) {
                        setStateModal(() {
                          editTipoSeleccionado = val!;
                          if (editTipoSeleccionado == 'Rúbrica') recalcularRubricaLocal();
                        });
                      },
                    ),

                    if (editTipoSeleccionado == 'Rúbrica') ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withOpacity(0.3))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Aspectos a evaluar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange)),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Text('Cantidad:', style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SpinBoxSimple(
                                    valor: editNumAspectos,
                                    onChanged: (val) => setStateModal(() { editNumAspectos = val; recalcularRubricaLocal(); }),
                                  ),
                                ),
                              ],
                            ),
                            SwitchListTile(
                              title: const Text('Dividir 100% en partes iguales', style: TextStyle(fontSize: 12)),
                              value: editPartesIguales,
                              activeColor: Colors.orange,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) => setStateModal(() { editPartesIguales = val; recalcularRubricaLocal(); }),
                            ),
                            const SizedBox(height: 8),
                            ...List.generate(editNumAspectos, (index) => Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: editTitulosCtrls[index],
                                      decoration: InputDecoration(hintText: 'Título aspecto ${index + 1}', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 1,
                                    child: TextField(
                                      controller: editPesosCtrls[index],
                                      enabled: !editPartesIguales,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(suffixText: '%', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              actionsAlignment: MainAxisAlignment.spaceEvenly,
              actions: [
                ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: () => Navigator.pop(context), child: Text('Cancelar', style: TextStyle(color: textDark))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () async {
                    if (editTituloCtrl.text.trim().isEmpty) return;

                    Map<String, dynamic> actualizacion = {
                      'titulo': editTituloCtrl.text.trim(),
                      'tipo': editTipoSeleccionado,
                    };

                    if (editTipoSeleccionado == 'Rúbrica') {
                      if (!editPartesIguales) {
                        double sum = 0;
                        for (var ctrl in editPesosCtrls) sum += double.tryParse(ctrl.text) ?? 0;
                        if ((sum - 100).abs() > 0.1) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Los pesos deben sumar 100%'), backgroundColor: Colors.redAccent));
                          return;
                        }
                      }

                      actualizacion['numAspectos'] = editNumAspectos;
                      actualizacion['partesIguales'] = editPartesIguales;
                      List<Map<String, dynamic>> aspectos = [];
                      for (int i = 0; i < editNumAspectos; i++) {
                        aspectos.add({
                          'titulo': editTitulosCtrls[i].text.trim().isEmpty ? "Aspecto ${i+1}" : editTitulosCtrls[i].text.trim(),
                          'peso': double.tryParse(editPesosCtrls[i].text) ?? (100 / editNumAspectos)
                        });
                      }
                      actualizacion['aspectos'] = aspectos;
                    }

                    await FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('tareas').doc(idTarea).update(actualizacion);
                    Navigator.pop(context);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Actividad actualizada'), backgroundColor: Colors.green));
                  },
                  child: const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildTareasTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nueva Actividad', style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontFamily: 'FuentePrincipal')),
                const SizedBox(height: 12),
                TextField(
                  controller: _tituloTareaCtrl,
                  style: TextStyle(color: textDark, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Título de la tarea', hintStyle: const TextStyle(color: Colors.grey),
                    filled: true, fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _tipoTareaSeleccionado,
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                  decoration: InputDecoration(
                    filled: true, fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  items: _tiposTarea.map((t) => DropdownMenuItem(value: t, child: Text(t, style: TextStyle(fontSize: 13, color: textDark)))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _tipoTareaSeleccionado = val);
                  },
                ),
                if (_tipoTareaSeleccionado == 'Rúbrica') ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Configuración de Rúbrica (Suma 100%)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Text('Número de aspectos:', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SpinBoxSimple(
                                valor: _numAspectosRubrica,
                                onChanged: (val) {
                                  setState(() { _numAspectosRubrica = val; _actualizarControladoresRubrica(); });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          title: const Text('Dividir en partes iguales', style: TextStyle(fontSize: 12)),
                          value: _rubricaPartesIguales,
                          activeColor: Colors.orange,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) {
                            setState(() { _rubricaPartesIguales = val; _actualizarControladoresRubrica(); });
                          },
                        ),
                        const SizedBox(height: 8),
                        ...List.generate(
                          _numAspectosRubrica,
                          (index) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: _titulosAspectosCtrls[index],
                                    decoration: InputDecoration(
                                      hintText: 'Descripción del aspecto ${index + 1}',
                                      filled: true, fillColor: Colors.white,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 1,
                                  child: TextField(
                                    controller: _pesosRubricaCtrls[index],
                                    enabled: !_rubricaPartesIguales,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      suffixText: '%',
                                      filled: true, fillColor: Colors.white,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: greenAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _crearTarea,
                    child: const Text('Crear Actividad', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('tareas').orderBy('fechaCreacion', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text('No hay actividades creadas.', style: TextStyle(color: Colors.grey))));

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var tarea = snapshot.data!.docs[index];
                  var data = tarea.data() as Map<String, dynamic>;

                  String tipoAbrev = data['tipo'] == 'Entregable (Sí/No)' ? 'ENTREGABLE' : (data['tipo'] == 'Rúbrica' ? 'RÚBRICA (${data['numAspectos']} aspec.)' : 'CALIFICACIÓN');
                  Color colorEtiqueta = data['tipo'] == 'Entregable (Sí/No)' ? Colors.blue.shade600 : (data['tipo'] == 'Rúbrica' ? Colors.orange.shade600 : Colors.purple.shade600);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['titulo'] ?? 'Sin título', style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: colorEtiqueta.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                child: Text(tipoAbrev, style: TextStyle(color: colorEtiqueta, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _verificarPassword(() => _mostrarModalEditarTarea(tarea.id, data)),
                              child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle), child: const Icon(Icons.edit, color: Colors.grey, size: 20)),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _verificarPassword(() => _eliminarTarea(tarea.id)),
                              child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.delete, color: Colors.red, size: 20)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PESTAÑA 4: EVALUAR (CON QR Y RÚBRICA)
  // ==========================================

  void _abrirEscanerEvaluacion(List<QueryDocumentSnapshot> alumnosList) {
    String cuentaEscaneada = "";
    bool procesando = false;
    bool pidiendoCalificacion = false; 
    String mensajeEscaner = "Apunta la cámara al código QR";
    Color colorMensaje = Colors.grey;
    IconData iconoMensaje = Icons.qr_code_scanner;
    String nombreAlumnoDetectado = "";

    // Controladores para evaluación
    TextEditingController califCtrl = TextEditingController();
    List<TextEditingController> rubricaEvalsCtrls = [];
    List aspectosRubrica = [];

    Map<String, String> mapaNombres = {};
    for (var doc in alumnosList) {
      mapaNombres[(doc.data() as Map<String, dynamic>)['cuenta']] = (doc.data() as Map<String, dynamic>)['nombre'];
    }

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: StatefulBuilder( 
            builder: (context, setStateEscaner) {
              return Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 24),
                        Text("Evaluar Tarea", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 16)),
                        GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.grey, size: 20))
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    Container(
                      height: 250, width: double.infinity,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: colorMensaje == Colors.green ? Colors.green : (colorMensaje == Colors.orange ? Colors.orange : Colors.grey.shade300), width: 2)),
                      clipBehavior: Clip.hardEdge,
                      child: Stack(
                        children: [
                          MobileScanner(
                            onDetect: (capture) async {
                              if (procesando || pidiendoCalificacion) return; 
                              final List<Barcode> barcodes = capture.barcodes;
                              
                              if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                                procesando = true;
                                cuentaEscaneada = barcodes.first.rawValue!;
                                nombreAlumnoDetectado = mapaNombres[cuentaEscaneada] ?? "Alumno Desconocido";
                                
                                DocumentReference docEval = FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('tareas').doc(_tareaAEvaluarId).collection('evaluaciones').doc(cuentaEscaneada);
                                DocumentSnapshot docGet = await docEval.get();
                                bool yaEvaluado = docGet.exists;

                                if (_tareaAEvaluarTipo == 'Entregable (Sí/No)') {
                                  // --- LÓGICA ENTREGABLE SIMPLE ---
                                  if (yaEvaluado && docGet['entregado'] == true) {
                                    setStateEscaner(() { mensajeEscaner = "¡Ya entregó: $cuentaEscaneada!"; colorMensaje = Colors.orange; iconoMensaje = Icons.info; });
                                  } else {
                                    await docEval.set({'entregado': true}, SetOptions(merge: true));
                                    setStateEscaner(() { mensajeEscaner = "¡Entregado: $cuentaEscaneada!"; colorMensaje = Colors.green; iconoMensaje = Icons.check_circle; });
                                  }
                                  await Future.delayed(const Duration(milliseconds: 1500)); 
                                  if (mounted) { setStateEscaner(() { mensajeEscaner = "Apunta la cámara al código QR"; colorMensaje = Colors.grey; iconoMensaje = Icons.qr_code_scanner; procesando = false; }); }
                                
                                } else {
                                  // --- LÓGICA CALIFICACIÓN / RÚBRICA ---
                                  setStateEscaner(() {
                                    pidiendoCalificacion = true; 
                                    
                                    if (_tareaAEvaluarTipo == 'Rúbrica') {
                                      aspectosRubrica = _tareaAEvaluarData?['aspectos'] ?? [];
                                      rubricaEvalsCtrls = List.generate(aspectosRubrica.length, (index) => TextEditingController());
                                      
                                      if (yaEvaluado && docGet.data().toString().contains('detalleRubrica')) {
                                         var detalle = docGet['detalleRubrica'] as Map<String, dynamic>;
                                         for (int i=0; i<aspectosRubrica.length; i++) {
                                           rubricaEvalsCtrls[i].text = detalle[aspectosRubrica[i]['titulo']]?.toString() ?? '';
                                         }
                                         mensajeEscaner = "Evaluado previamente. Modificar:";
                                         colorMensaje = Colors.orange;
                                         iconoMensaje = Icons.info;
                                      } else {
                                         mensajeEscaner = "Califica los aspectos (0-10)";
                                         colorMensaje = Colors.blue;
                                         iconoMensaje = Icons.edit;
                                      }
                                    } else {
                                      if (yaEvaluado && docGet.data().toString().contains('calificacion')) {
                                        califCtrl.text = docGet['calificacion'].toString();
                                        mensajeEscaner = "Ya evaluado. Puedes modificar.";
                                        colorMensaje = Colors.orange;
                                        iconoMensaje = Icons.info;
                                      } else {
                                        califCtrl.clear();
                                        mensajeEscaner = "Ingresa la calificación";
                                        colorMensaje = Colors.blue;
                                        iconoMensaje = Icons.edit;
                                      }
                                    }
                                  });
                                }
                              }
                            },
                          ),
                          // CAPA TRANSLÚCIDA PARA "PAUSAR" LA CÁMARA
                          if (pidiendoCalificacion)
                            Container(color: Colors.white.withOpacity(0.9), child: const Center(child: Icon(Icons.pause_circle_outline, size: 50, color: Colors.grey))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    if (!pidiendoCalificacion)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(color: colorMensaje == Colors.green ? Colors.green.withOpacity(0.1) : (colorMensaje == Colors.orange ? Colors.orange.withOpacity(0.1) : Colors.grey[100]), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(iconoMensaje, color: colorMensaje, size: 20),
                            const SizedBox(width: 8),
                            Text(mensajeEscaner, style: TextStyle(color: colorMensaje, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        )
                      )
                    else
                      // INTERFAZ DE EVALUACIÓN
                      Column(
                        children: [
                          Text(nombreAlumnoDetectado, style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text("Cta: $cuentaEscaneada", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 12),
                          
                          if (_tareaAEvaluarTipo == 'Rúbrica')
                            Container(
                              constraints: const BoxConstraints(maxHeight: 150),
                              child: SingleChildScrollView(
                                child: Column(
                                  children: List.generate(aspectosRubrica.length, (index) {
                                    var aspecto = aspectosRubrica[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: Row(
                                        children: [
                                          Expanded(child: Text("${aspecto['titulo']} (${aspecto['peso']}%)", style: TextStyle(color: textDark, fontSize: 12))),
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: 60,
                                            child: TextField(
                                              controller: rubricaEvalsCtrls[index],
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.bold),
                                              decoration: InputDecoration(hintText: '0-10', filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 8)),
                                            )
                                          )
                                        ]
                                      )
                                    );
                                  })
                                )
                              )
                            )
                          else
                            TextField(
                              controller: califCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: textDark, fontSize: 16, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(hintText: '0 - 10', filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
                            ),

                          const SizedBox(height: 12),
                          
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              onPressed: () async {
                                double finalCalificacion = 0;
                                Map<String, dynamic> datosParaGuardar = {};

                                if (_tareaAEvaluarTipo == 'Rúbrica') {
                                  double total = 0;
                                  Map<String, dynamic> detalle = {};
                                  for(int i=0; i<aspectosRubrica.length; i++) {
                                    double val = double.tryParse(rubricaEvalsCtrls[i].text) ?? -1;
                                    if (val < 0 || val > 10) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Las calificaciones deben ser de 0 a 10')));
                                      return;
                                    }
                                    double peso = (aspectosRubrica[i]['peso'] as num).toDouble();
                                    total += val * (peso / 100);
                                    detalle[aspectosRubrica[i]['titulo']] = val;
                                  }
                                  finalCalificacion = double.parse(total.toStringAsFixed(1));
                                  datosParaGuardar = {'calificacion': finalCalificacion, 'detalleRubrica': detalle};
                                } else {
                                  double? val = double.tryParse(califCtrl.text);
                                  if (val == null || val < 0 || val > 10) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa un valor válido de 0 a 10')));
                                    return;
                                  }
                                  finalCalificacion = val;
                                  datosParaGuardar = {'calificacion': finalCalificacion};
                                }

                                await FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('tareas').doc(_tareaAEvaluarId).collection('evaluaciones').doc(cuentaEscaneada).set(datosParaGuardar, SetOptions(merge: true));
                                
                                setStateEscaner(() {
                                  pidiendoCalificacion = false;
                                  mensajeEscaner = "¡Calificado: $finalCalificacion!";
                                  colorMensaje = Colors.green;
                                  iconoMensaje = Icons.check_circle;
                                });
                                
                                await Future.delayed(const Duration(milliseconds: 1500)); 
                                if (mounted) {
                                  setStateEscaner(() { mensajeEscaner = "Apunta la cámara al código QR"; colorMensaje = Colors.grey; iconoMensaje = Icons.qr_code_scanner; procesando = false; });
                                }
                              },
                              child: const Text("Guardar Evaluación", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          )
                        ],
                      )
                  ],
                ),
              );
            }
          ),
        );
      }
    );
  }

  void _mostrarDialogoEditarCalificacion(String numCuenta, String nombre, Map<String, dynamic>? datosEval) {
    TextEditingController editCalifCtrl = TextEditingController();
    List<TextEditingController> rubricaCtrls = [];
    List aspectosRubrica = [];
    
    if (_tareaAEvaluarTipo == 'Rúbrica') {
       aspectosRubrica = _tareaAEvaluarData?['aspectos'] ?? [];
       for(var a in aspectosRubrica) {
          String val = '';
          if (datosEval != null && datosEval.containsKey('detalleRubrica')) {
             val = datosEval['detalleRubrica'][a['titulo']]?.toString() ?? '';
          }
          rubricaCtrls.add(TextEditingController(text: val));
       }
    } else {
      if (datosEval != null && datosEval.containsKey('calificacion')) {
        editCalifCtrl.text = datosEval['calificacion'].toString();
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Editar Calificación', style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontFamily: 'FuentePrincipal')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre, style: TextStyle(color: colorMateria, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                if (_tareaAEvaluarTipo == 'Rúbrica')
                  Column(
                    children: List.generate(aspectosRubrica.length, (index) {
                      var aspecto = aspectosRubrica[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(child: Text("${aspecto['titulo']} (${aspecto['peso']}%)", style: TextStyle(color: textDark, fontSize: 12))),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 60,
                              child: TextField(
                                controller: rubricaCtrls[index],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.center,
                                style: TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(hintText: '0-10', filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 8)),
                              )
                            )
                          ]
                        )
                      );
                    })
                  )
                else
                  TextField(
                    controller: editCalifCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(hintText: '0 - 10', filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
                  ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: () => Navigator.pop(context), child: Text('Cancelar', style: TextStyle(color: textDark))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () async {
                Map<String, dynamic> datosParaGuardar = {};

                if (_tareaAEvaluarTipo == 'Rúbrica') {
                  double total = 0;
                  Map<String, dynamic> detalle = {};
                  for(int i=0; i<aspectosRubrica.length; i++) {
                    double val = double.tryParse(rubricaCtrls[i].text) ?? -1;
                    if (val < 0 || val > 10) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Valor de 0 a 10'))); return; }
                    double peso = (aspectosRubrica[i]['peso'] as num).toDouble();
                    total += val * (peso / 100);
                    detalle[aspectosRubrica[i]['titulo']] = val;
                  }
                  total = double.parse(total.toStringAsFixed(1));
                  datosParaGuardar = {'calificacion': total, 'detalleRubrica': detalle};
                } else {
                  double? val = double.tryParse(editCalifCtrl.text);
                  if (val == null || val < 0 || val > 10) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Valor inválido'))); return; }
                  datosParaGuardar = {'calificacion': val};
                }
                
                await FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('tareas').doc(_tareaAEvaluarId).collection('evaluaciones').doc(numCuenta).set(datosParaGuardar, SetOptions(merge: true));
                Navigator.pop(context);
              },
              child: const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    );
  }

  Widget _buildEvaluarTab() {
    return Container(
      color: bgColor,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('tareas').orderBy('fechaCreacion', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              var tareas = snapshot.data!.docs;
              if (tareas.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text("No hay actividades para evaluar.", style: TextStyle(color: Colors.grey))));

              if (_tareaAEvaluarId != null && !tareas.any((t) => t.id == _tareaAEvaluarId)) _tareaAEvaluarId = null;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true, hint: Text("-- Elige una actividad --", style: TextStyle(color: textDark, fontFamily: 'FuenteSecundaria')), value: _tareaAEvaluarId, icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                        items: tareas.map((doc) {
                          var data = doc.data() as Map<String, dynamic>;
                          String tipoAbrev = data['tipo'] == 'Entregable (Sí/No)' ? 'entregable' : (data['tipo'] == 'Rúbrica' ? 'rúbrica' : 'calificación');
                          return DropdownMenuItem<String>(value: doc.id, child: Text("${data['titulo']} ($tipoAbrev)", style: TextStyle(fontSize: 14, color: textDark)));
                        }).toList(),
                        onChanged: (val) {
                          setState(() { 
                            _tareaAEvaluarId = val; 
                            var tareaSeleccionada = tareas.firstWhere((t) => t.id == val); 
                            _tareaAEvaluarData = tareaSeleccionada.data() as Map<String, dynamic>;
                            _tareaAEvaluarTipo = _tareaAEvaluarData!['tipo']; 
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('alumnos').snapshots(),
                    builder: (context, snapshotAlumnos) {
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: _tareaAEvaluarId != null ? colorMateria : Colors.grey[400], padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                          onPressed: _tareaAEvaluarId != null ? () => _verificarPassword(() => _abrirEscanerEvaluacion(snapshotAlumnos.data?.docs ?? [])) : null,
                          icon: const Icon(Icons.qr_code_scanner, color: Colors.white), label: const Text('Evaluar con QR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'FuentePrincipal')),
                        ),
                      );
                    }
                  ),
                ],
              );
            }
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _tareaAEvaluarId == null 
              ? const Center(child: Text("Selecciona una actividad para evaluar.", style: TextStyle(color: Colors.grey)))
              : Container(
                  width: double.infinity, padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('alumnos').orderBy('nombre').snapshots(),
                    builder: (context, snapshotAlumnos) {
                      if (!snapshotAlumnos.hasData) return const Center(child: CircularProgressIndicator());
                      var alumnos = snapshotAlumnos.data!.docs;

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('tareas').doc(_tareaAEvaluarId).collection('evaluaciones').snapshots(),
                        builder: (context, snapshotEvals) {
                          Map<String, dynamic> evaluaciones = {};
                          if (snapshotEvals.hasData) { for (var doc in snapshotEvals.data!.docs) { evaluaciones[doc.id] = doc.data(); } }

                          return ListView.separated(
                            itemCount: alumnos.length,
                            separatorBuilder: (context, index) => Divider(color: Colors.grey.shade100, height: 16),
                            itemBuilder: (context, index) {
                              var dataAlumno = alumnos[index].data() as Map<String, dynamic>;
                              String numCuenta = dataAlumno['cuenta'], nombre = dataAlumno['nombre'];
                              bool evaluado = evaluaciones.containsKey(numCuenta);
                              var datosEval = evaluado ? evaluaciones[numCuenta] : null;

                              Widget badgeEstado;
                              if (!evaluado) {
                                badgeEstado = Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), child: Text('Pendiente', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold)));
                              } else {
                                if (_tareaAEvaluarTipo == 'Entregable (Sí/No)') {
                                  bool entrego = datosEval['entregado'] == true;
                                  badgeEstado = Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: entrego ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(entrego ? 'Entregado' : 'Falta', style: TextStyle(color: entrego ? Colors.green : Colors.red, fontSize: 12, fontWeight: FontWeight.bold)));
                                } else {
                                  String califStr = datosEval['calificacion'].toString();
                                  badgeEstado = Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), decoration: BoxDecoration(color: colorMateria.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(califStr, style: TextStyle(color: colorMateria, fontSize: 14, fontWeight: FontWeight.bold)));
                                }
                              }

                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(nombre, style: TextStyle(color: textDark, fontSize: 14), overflow: TextOverflow.ellipsis)),
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          _verificarPassword(() {
                                            if (_tareaAEvaluarTipo == 'Entregable (Sí/No)') {
                                              bool currentState = evaluado && datosEval['entregado'] == true;
                                              FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('tareas').doc(_tareaAEvaluarId).collection('evaluaciones').doc(numCuenta).set({'entregado': !currentState}, SetOptions(merge: true));
                                            } else {
                                              _mostrarDialogoEditarCalificacion(numCuenta, nombre, datosEval);
                                            }
                                          });
                                        },
                                        child: badgeEstado
                                      ),
                                      if (_tareaAEvaluarTipo != 'Entregable (Sí/No)') ...[
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () => _verificarPassword(() => _mostrarDialogoEditarCalificacion(numCuenta, nombre, datosEval)),
                                          child: Icon(Icons.edit, color: Colors.grey.shade400, size: 18)
                                        )
                                      ]
                                    ],
                                  )
                                ],
                              );
                            },
                          );
                        }
                      );
                    }
                  ),
                )
          )
        ],
      ),
    );
  }

  // ==========================================
  // PESTAÑA 5: HISTORIAL DE ASISTENCIAS 
  // ==========================================

  Future<Map<String, dynamic>> _cargarHistorialAsistencias() async {
    var alumnosSnap = await FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('alumnos').orderBy('nombre').get();
    var asistenciasSnap = await FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('asistencias').get();
    
    List<String> fechas = asistenciasSnap.docs.map((doc) => doc.id).toList();
    fechas.sort();

    Map<String, Map<String, bool>> matrizAsistencias = {};
    for (var doc in asistenciasSnap.docs) {
      String fecha = doc.id;
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      data.forEach((cuenta, asistencia) {
        matrizAsistencias.putIfAbsent(cuenta, () => {})[fecha] = asistencia == true;
      });
    }

    return {
      'alumnos': alumnosSnap.docs,
      'fechas': fechas,
      'matriz': matrizAsistencias,
    };
  }

  Widget _buildHistorialAsistenciasTab() {
    return Container(
      color: bgColor,
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _cargarHistorialAsistencias(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || (snapshot.data!['alumnos'] as List).isEmpty) {
            return const Center(child: Text("No hay alumnos registrados.", style: TextStyle(color: Colors.grey)));
          }

          var datos = snapshot.data!;
          var alumnos = datos['alumnos'] as List<QueryDocumentSnapshot>;
          var fechas = datos['fechas'] as List<String>;
          var matriz = datos['matriz'] as Map<String, Map<String, bool>>;

          if (fechas.isEmpty) return const Center(child: Text("No hay pases de lista registrados todavía.", style: TextStyle(color: Colors.grey)));

          return Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                  columns: [
                    DataColumn(label: Text('ALUMNO', style: TextStyle(fontWeight: FontWeight.bold, color: textDark))),
                    ...fechas.map((f) {
                      List<String> partes = f.split('-');
                      String fechaVisual = partes.length == 3 ? "${partes[2]}/${partes[1]}" : f;
                      return DataColumn(label: Text(fechaVisual, style: TextStyle(fontWeight: FontWeight.bold, color: colorMateria)));
                    }),
                  ],
                  rows: alumnos.map((doc) {
                    var alumnoData = doc.data() as Map<String, dynamic>;
                    String cuenta = alumnoData['cuenta'];
                    String nombre = alumnoData['nombre'];
                    var asistenciasAlumno = matriz[cuenta] ?? {};

                    return DataRow(
                      cells: [
                        DataCell(Text(nombre, style: TextStyle(fontWeight: FontWeight.w500, color: textDark))),
                        ...fechas.map((fecha) {
                          bool asistio = asistenciasAlumno[fecha] ?? false;
                          return DataCell(
                            Center(child: Icon(asistio ? Icons.check_circle : Icons.cancel_outlined, color: asistio ? Colors.green : Colors.red.shade300, size: 20)),
                          );
                        }),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // PESTAÑA 6: HISTORIAL DE ACTIVIDADES 
  // ==========================================

  Future<Map<String, dynamic>> _cargarHistorialActividades() async {
    var alumnosSnap = await FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('alumnos').orderBy('nombre').get();
    var tareasSnap = await FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('tareas').orderBy('fechaCreacion').get();

    Map<String, Map<String, dynamic>> calificacionesAlumno = {};

    for (var tarea in tareasSnap.docs) {
      var evalsSnap = await FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('tareas').doc(tarea.id).collection('evaluaciones').get();
      for (var eval in evalsSnap.docs) {
        String cuenta = eval.id;
        var evalData = eval.data();
        calificacionesAlumno.putIfAbsent(cuenta, () => {})[tarea.id] = evalData['calificacion'] ?? (evalData['entregado'] == true ? 'Entregado' : '-');
      }
    }

    return {
      'alumnos': alumnosSnap.docs,
      'tareas': tareasSnap.docs,
      'calificaciones': calificacionesAlumno,
    };
  }

  Widget _buildHistorialActividadesTab() {
    return Container(
      color: bgColor,
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _cargarHistorialActividades(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || (snapshot.data!['alumnos'] as List).isEmpty) {
            return const Center(child: Text("No hay alumnos registrados.", style: TextStyle(color: Colors.grey)));
          }

          var datos = snapshot.data!;
          var alumnos = datos['alumnos'] as List<QueryDocumentSnapshot>;
          var tareas = datos['tareas'] as List<QueryDocumentSnapshot>;
          var calificaciones = datos['calificaciones'] as Map<String, Map<String, dynamic>>;

          if (tareas.isEmpty) return const Center(child: Text("No hay actividades creadas todavía.", style: TextStyle(color: Colors.grey)));

          return Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                  columns: [
                    DataColumn(label: Text('ALUMNO', style: TextStyle(fontWeight: FontWeight.bold, color: textDark))),
                    ...tareas.map((t) => DataColumn(label: Text((t.data() as Map<String, dynamic>)['titulo'], style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)))),
                  ],
                  rows: alumnos.map((doc) {
                    var alumnoData = doc.data() as Map<String, dynamic>;
                    String cuenta = alumnoData['cuenta'];
                    String nombre = alumnoData['nombre'];
                    var califsAlumno = calificaciones[cuenta] ?? {};

                    return DataRow(
                      cells: [
                        DataCell(Text(nombre, style: TextStyle(fontWeight: FontWeight.w500, color: textDark))),
                        ...tareas.map((t) {
                          dynamic calif = califsAlumno[t.id] ?? '-';
                          return DataCell(
                            Center(child: Text(calif.toString(), style: TextStyle(fontWeight: FontWeight.bold, color: calif == '-' ? Colors.grey : colorMateria))),
                          );
                        }),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // PESTAÑA 7: REPORTE GENERAL
  // ==========================================

  Future<Map<String, dynamic>> _cargarDatosReporte() async {
    var alumnosSnap = await FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('alumnos').orderBy('nombre').get();
    var asistenciasSnap = await FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('asistencias').get();
    var tareasSnap = await FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('tareas').get();

    int totalDias = asistenciasSnap.docs.length;
    int totalTareas = tareasSnap.docs.length;

    Map<String, int> asistenciasCount = {};
    for (var doc in asistenciasSnap.docs) {
      var data = doc.data() as Map<String, dynamic>;
      data.forEach((cuenta, val) {
        if (val == true) asistenciasCount[cuenta] = (asistenciasCount[cuenta] ?? 0) + 1;
      });
    }

    Map<String, double> promediosMap = {};
    Map<String, int> trabajosEntregadosMap = {};

    for (var alumnoDoc in alumnosSnap.docs) {
      String cuenta = (alumnoDoc.data() as Map<String, dynamic>)['cuenta'];
      double sumaCalif = 0;
      int countCalif = 0;
      int entregas = 0;

      for (var tarea in tareasSnap.docs) {
        var evalDoc = await FirebaseFirestore.instance.collection('materias').doc(widget.docId).collection('tareas').doc(tarea.id).collection('evaluaciones').doc(cuenta).get();
        if (evalDoc.exists) {
          var evData = evalDoc.data()!;
          if (evData.containsKey('calificacion')) {
            double? c = double.tryParse(evData['calificacion'].toString());
            if (c != null) { sumaCalif += c; countCalif++; }
          }
          if (evData['entregado'] == true || evData.containsKey('calificacion')) entregas++;
        }
      }
      promediosMap[cuenta] = countCalif > 0 ? (sumaCalif / countCalif) : 0.0;
      trabajosEntregadosMap[cuenta] = entregas;
    }

    return {
      'alumnos': alumnosSnap.docs,
      'totalDias': totalDias,
      'totalTareas': totalTareas,
      'asistenciasCount': asistenciasCount,
      'promedios': promediosMap,
      'trabajos': trabajosEntregadosMap,
    };
  }

  Future<void> _generarPDF(Map<String, dynamic> datos) async {
    final pdf = pw.Document();
    final alumnos = datos['alumnos'] as List<QueryDocumentSnapshot>;
    final int tDias = datos['totalDias'];
    final int tTareas = datos['totalTareas'];
    var asistenciasCount = datos['asistenciasCount'] as Map<String, int>;
    var promedios = datos['promedios'] as Map<String, double>;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Reporte General: ${widget.materiaData['materia']}', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 15),
              pw.Table.fromTextArray(
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                headers: ['Alumno', 'Matrícula', 'Asistencias', 'Promedio'],
                data: alumnos.map((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String cuenta = data['cuenta'];
                  int asist = asistenciasCount[cuenta] ?? 0;
                  double prom = promedios[cuenta] ?? 0.0;
                  return [data['nombre'], cuenta, '$asist / $tDias', prom.toStringAsFixed(1)];
                }).toList(),
              ),
            ]
          );
        }
      )
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Widget _buildReporteTab() {
    return Container(
      color: bgColor,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _cargarDatosReporte(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || (snapshot.data!['alumnos'] as List).isEmpty) {
            return const Center(child: Text("No hay datos para generar el reporte.", style: TextStyle(color: Colors.grey)));
          }

          var datos = snapshot.data!;
          var alumnos = datos['alumnos'] as List<QueryDocumentSnapshot>;
          int tDias = datos['totalDias'];
          int tTareas = datos['totalTareas'];
          var asistenciasCount = datos['asistenciasCount'] as Map<String, int>;
          var promedios = datos['promedios'] as Map<String, double>;
          var trabajos = datos['trabajos'] as Map<String, int>;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                    onPressed: () => _generarPDF(datos),
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                    label: const Text('Descargar Reporte en PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
                  child: SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                        columns: [
                          DataColumn(label: Text('ALUMNO', style: TextStyle(fontWeight: FontWeight.bold, color: textDark))),
                          DataColumn(label: Text('MATRÍCULA', style: TextStyle(fontWeight: FontWeight.bold, color: textDark))),
                          DataColumn(label: Text('ASISTENCIAS', style: TextStyle(fontWeight: FontWeight.bold, color: textDark))),
                          DataColumn(label: Text('TRABAJOS', style: TextStyle(fontWeight: FontWeight.bold, color: textDark))),
                          DataColumn(label: Text('PROMEDIO', style: TextStyle(fontWeight: FontWeight.bold, color: textDark))),
                        ],
                        rows: alumnos.map((doc) {
                          var data = doc.data() as Map<String, dynamic>;
                          String cuenta = data['cuenta'];
                          int asist = asistenciasCount[cuenta] ?? 0;
                          int trab = trabajos[cuenta] ?? 0;
                          double prom = promedios[cuenta] ?? 0.0;

                          return DataRow(
                            cells: [
                              DataCell(Text(data['nombre'], style: TextStyle(fontWeight: FontWeight.w500, color: textDark))),
                              DataCell(Text(cuenta, style: const TextStyle(color: Colors.grey))),
                              DataCell(Text('$asist / $tDias', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                              DataCell(Text('$trab / $tTareas', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
                              DataCell(Text(prom.toStringAsFixed(1), style: TextStyle(color: colorMateria, fontWeight: FontWeight.bold))),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // BUILD PRINCIPAL
  // ==========================================

  @override
  Widget build(BuildContext context) {
    String horaInicio = widget.materiaData.containsKey('horaInicio') ? widget.materiaData['horaInicio'] : "00:00";
    String horaFin = widget.materiaData.containsKey('horaFin') ? widget.materiaData['horaFin'] : "00:00";

    return DefaultTabController(
      length: 7, 
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: colorMateria,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white), 
              onPressed: () {
                _verificarPassword(() {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => EditarClaseScreen(docId: widget.docId, datosActuales: widget.materiaData)));
                });
              }
            ),
            const SizedBox(width: 10),
          ],
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(32))),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(100),
            child: Column(
              children: [
                Text(widget.materiaData['materia'], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'FuentePrincipal')),
                const SizedBox(height: 4),
                Text("${widget.materiaData['nivel']} | $horaInicio - $horaFin", style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'FuenteSecundaria')),
                const SizedBox(height: 20),
                const TabBar(
                  isScrollable: true, indicatorColor: Colors.white, indicatorWeight: 3, labelColor: Colors.white, unselectedLabelColor: Colors.white60,
                  labelStyle: TextStyle(fontFamily: 'FuentePrincipal', fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(text: 'Alumnos'), 
                    Tab(text: 'Asistencia'), 
                    Tab(text: 'Tareas'), 
                    Tab(text: 'Evaluar'),
                    Tab(text: 'Hist. Asistencias'),
                    Tab(text: 'Hist. Actividades'),
                    Tab(text: 'Reporte General'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildAlumnosTab(),
            _buildAsistenciaTab(), 
            _buildTareasTab(), 
            _buildEvaluarTab(), 
            _buildHistorialAsistenciasTab(), 
            _buildHistorialActividadesTab(),
            _buildReporteTab(),
          ],
        ),
      ),
    );
  }
}

class SpinBoxSimple extends StatelessWidget {
  final int valor;
  final ValueChanged<int> onChanged;

  const SpinBoxSimple({super.key, required this.valor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(icon: const Icon(Icons.remove_circle_outline, size: 20), onPressed: valor > 1 ? () => onChanged(valor - 1) : null),
        Text('$valor', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        IconButton(icon: const Icon(Icons.add_circle_outline, size: 20), onPressed: valor < 10 ? () => onChanged(valor + 1) : null),
      ],
    );
  }
}