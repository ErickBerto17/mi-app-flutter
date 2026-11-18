import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_screen.dart'; // Para cerrar sesión

class HomeAlumnoScreen extends StatefulWidget {
  final String numeroCuenta;

  const HomeAlumnoScreen({super.key, required this.numeroCuenta});

  @override
  State<HomeAlumnoScreen> createState() => _HomeAlumnoScreenState();
}

class _HomeAlumnoScreenState extends State<HomeAlumnoScreen> {
  // --- PALETA CLARA ---
  final Color bgColor = const Color(0xFFF8FAFC); 
  final Color textDark = const Color(0xFF1E293B); 
  final Color colorHeader = const Color(0xFF4F46E5); 

  late String numeroCuenta;
  String nombreAlumno = "Cargando...";

  @override
  void initState() {
    super.initState();
    numeroCuenta = widget.numeroCuenta;
    _buscarNombreReal();
  }

  Future<void> _buscarNombreReal() async {
    var materiasSnap = await FirebaseFirestore.instance.collection('materias').get();
    for (var mat in materiasSnap.docs) {
      var alumnoDoc = await mat.reference.collection('alumnos').doc(numeroCuenta).get();
      if (alumnoDoc.exists) {
        if (mounted) {
          setState(() => nombreAlumno = alumnoDoc.data()?['nombre'] ?? "Alumno");
        }
        break;
      }
    }
    if (nombreAlumno == "Cargando...") {
      if (mounted) setState(() => nombreAlumno = "Alumno");
    }
  }

  void _cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cuenta_alumno');
    await prefs.remove('mantener_sesion');
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
    }
  }

  void _mostrarConfigQR() {
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
                    Text("Mi Credencial QR", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'FuentePrincipal')),
                    GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.grey, size: 24))
                  ],
                ),
                const SizedBox(height: 8),
                Text(nombreAlumno, textAlign: TextAlign.center, style: TextStyle(color: colorHeader, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'FuenteSecundaria')),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200, width: 2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
                  child: QrImageView(data: numeroCuenta, version: QrVersions.auto, size: 160.0, foregroundColor: textDark),
                ),
                const SizedBox(height: 24),
                Text("Cta: $numeroCuenta", style: const TextStyle(color: Colors.grey, fontSize: 14, fontFamily: 'FuenteSecundaria')),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () {
                      Navigator.pop(context);
                      _cerrarSesion();
                    },
                    icon: const Icon(Icons.logout, color: Colors.white),
                    label: const Text("Cerrar Sesión", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        );
      }
    );
  }

  Future<void> _exportarPDF(
  String nombreMateria,
  String asistenciaTxt,
  List<Map<String, dynamic>> tareasList,
) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Reporte Individual', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Alumno: $nombreAlumno', style: const pw.TextStyle(fontSize: 14)),
              pw.Text('Cuenta: $numeroCuenta', style: const pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 20),
              pw.Text('Materia: $nombreMateria', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text('Asistencia General: $asistenciaTxt', style: const pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 20),
              
              if (tareasList.isNotEmpty)
                pw.Table.fromTextArray( 
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  headers: ['Actividad', 'Calificación / Estado'],
                  data: tareasList.map((t) => [t['titulo'] ?? '', t['estado'] ?? '']).toList(),
                )
              else
                pw.Text('No hay actividades evaluadas.', style: const pw.TextStyle(color: PdfColors.grey)),
            ]
          );
        }
      )
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 30),
            decoration: BoxDecoration(color: colorHeader, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Hola, ${nombreAlumno.split(' ')[0]}", style: const TextStyle(fontFamily: 'FuentePrincipal', fontWeight: FontWeight.bold, fontSize: 26, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text("N° Cuenta: $numeroCuenta", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontFamily: 'FuenteSecundaria')),
                  ],
                ),
                IconButton(icon: const Icon(Icons.settings, color: Colors.white, size: 28), padding: EdgeInsets.zero, onPressed: _mostrarConfigQR),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
            child: Row(
              children: [
                Icon(Icons.menu_book_rounded, color: colorHeader, size: 22),
                const SizedBox(width: 8),
                Text("Mis Clases", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'FuentePrincipal')),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('materias').snapshots(),
              builder: (context, snapshotMaterias) {
                if (snapshotMaterias.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: colorHeader));
                if (!snapshotMaterias.hasData) return const SizedBox();

                var todasLasMaterias = snapshotMaterias.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: todasLasMaterias.length,
                  itemBuilder: (context, index) {
                    var matDoc = todasLasMaterias[index];
                    var matData = matDoc.data() as Map<String, dynamic>;
                    String horaI = matData['horaInicio'] ?? "00:00";
                    String horaF = matData['horaFin'] ?? "00:00";
                    
                    // --- AQUÍ EXTRAEMOS EL NOMBRE DEL PROFESOR DE LA BASE DE DATOS ---
                    String nombreProfesor = matData['nombreProfesor'] ?? "Sin asignar"; 
                    
                    Color colorBorde = Color(matData['color']);

                    return FutureBuilder<DocumentSnapshot>(
                      future: matDoc.reference.collection('alumnos').doc(numeroCuenta).get(),
                      builder: (context, snapshotAlumno) {
                        if (!snapshotAlumno.hasData || !snapshotAlumno.data!.exists) return const SizedBox.shrink();

                        return FutureBuilder<QuerySnapshot>(
                          future: matDoc.reference.collection('asistencias').get(),
                          builder: (context, snapAsist) {
                            int totalClases = snapAsist.data?.docs.length ?? 0;
                            int asistio = 0;
                            if (snapAsist.hasData) {
                              for (var dia in snapAsist.data!.docs) {
                                var dataDia = dia.data() as Map<String, dynamic>;
                                if (dataDia.containsKey(numeroCuenta) && dataDia[numeroCuenta] == true) asistio++;
                              }
                            }
                            String porcentajeAsist = totalClases == 0 ? "100%" : "${((asistio / totalClases) * 100).toInt()}%";

                            return FutureBuilder<QuerySnapshot>(
                              future: matDoc.reference.collection('tareas').orderBy('fechaCreacion', descending: true).get(),
                              builder: (context, snapTareas) {
                                List<Map<String, dynamic>> tareasParaPDF = [];
                                List<Widget> tareasUI = [];

                                if (snapTareas.hasData && snapTareas.data!.docs.isNotEmpty) {
                                  for (var tarea in snapTareas.data!.docs) {
                                    var tareaData = tarea.data() as Map<String, dynamic>;
                                    String titulo = tareaData['titulo'];
                                    
                                    tareasUI.add(
                                      FutureBuilder<DocumentSnapshot>(
                                        future: tarea.reference.collection('evaluaciones').doc(numeroCuenta).get(),
                                        builder: (ctx, snapEval) {
                                          String txtEstado = "pendiente";
                                          Color colorEstado = Colors.grey;

                                          if (snapEval.hasData && snapEval.data!.exists) {
                                            var eData = snapEval.data!.data() as Map<String, dynamic>;
                                            if (tareaData['tipo'] == 'Entregable (Sí/No)') {
                                              bool ent = eData['entregado'] == true;
                                              txtEstado = ent ? "entregado" : "falta";
                                              colorEstado = ent ? Colors.green : Colors.red;
                                            } else {
                                              txtEstado = eData['calificacion']?.toString() ?? "0";
                                              colorEstado = Colors.green;
                                            }
                                          }

                                          bool yaExiste = tareasParaPDF.any((t) => t['titulo'] == titulo);
                                          if (!yaExiste) tareasParaPDF.add({'titulo': titulo, 'estado': txtEstado});

                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 8.0),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(child: Text(titulo, style: TextStyle(color: textDark.withOpacity(0.8), fontSize: 13), overflow: TextOverflow.ellipsis)),
                                                Text(txtEstado, style: TextStyle(color: colorEstado, fontSize: 13, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          );
                                        }
                                      )
                                    );
                                  }
                                } else {
                                  tareasUI.add(const Text("No hay actividades recientes.", style: TextStyle(color: Colors.grey, fontSize: 12)));
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 20),
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white, 
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                                    border: Border(top: BorderSide(color: colorBorde, width: 4))
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(matData['materia'], style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'FuentePrincipal')),
                                              const SizedBox(height: 4),
                                              // --- AQUÍ APARECE EL NOMBRE DEL PROFESOR CON EL FORMATO QUE PEDISTE ---
                                              Row(
                                                children: [
                                                  const Icon(Icons.person, color: Colors.grey, size: 14),
                                                  const SizedBox(width: 4),
                                                  Text("Profesor: $nombreProfesor", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(Icons.access_time, color: Colors.grey, size: 14),
                                                  const SizedBox(width: 4),
                                                  Text("$horaI - $horaF", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                                ],
                                              )
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              const Text("Asistencia", style: TextStyle(color: Colors.grey, fontSize: 10)),
                                              Text(porcentajeAsist, style: TextStyle(color: colorBorde, fontWeight: FontWeight.bold, fontSize: 16)),
                                            ],
                                          )
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      const Divider(color: Color(0xFFF1F5F9), thickness: 1),
                                      const SizedBox(height: 12),
                                      
                                      ...tareasUI,

                                      const SizedBox(height: 16),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), elevation: 0),
                                          onPressed: () => _exportarPDF(matData['materia'], porcentajeAsist, tareasParaPDF),
                                          icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 16),
                                          label: const Text("Exportar PDF", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                      )
                                    ],
                                  ),
                                );
                              }
                            );
                          }
                        );
                      }
                    );
                  },
                );
              }
            ),
          )
        ],
      ),
    );
  }
}