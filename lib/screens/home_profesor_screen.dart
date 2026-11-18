import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'formulario_clase_screen.dart';
import 'configuracion_screen.dart';
import 'editar_clase_screen.dart';
// Asegúrate de que el nombre de este archivo coincida con el tuyo
import 'detalle_clase_screen.dart'; 

class HomeProfesorScreen extends StatefulWidget {
  const HomeProfesorScreen({super.key});

  @override
  State<HomeProfesorScreen> createState() => _HomeProfesorScreenState();
}

class _HomeProfesorScreenState extends State<HomeProfesorScreen> {
  final Color colorPrincipal = const Color(0xFF4F46E5);
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color textDark = const Color(0xFF1E293B);

  String _obtenerFechaActual() {
    final meses = ['ENERO', 'FEBRERO', 'MARZO', 'ABRIL', 'MAYO', 'JUNIO', 'JULIO', 'AGOSTO', 'SEPTIEMBRE', 'OCTUBRE', 'NOVIEMBRE', 'DICIEMBRE'];
    final dias = ['LUNES', 'MARTES', 'MIÉRCOLES', 'JUEVES', 'VIERNES', 'SÁBADO', 'DOMINGO'];
    DateTime hoy = DateTime.now();
    return "${dias[hoy.weekday - 1]},${hoy.day} DE ${meses[hoy.month - 1]} DE${hoy.year}";
  }

  bool _estaEnCurso(String horaInicio, String horaFin) {
    if (horaInicio.isEmpty || horaFin.isEmpty) return false;
    
    TimeOfDay now = TimeOfDay.now();
    int nowMinutes = now.hour * 60 + now.minute;

    List<String> partesInicio = horaInicio.split(":");
    List<String> partesFin = horaFin.split(":");
    
    if (partesInicio.length != 2 || partesFin.length != 2) return false;

    int inicioMinutes = int.parse(partesInicio[0]) * 60 + int.parse(partesInicio[1]);
    int finMinutes = int.parse(partesFin[0]) * 60 + int.parse(partesFin[1]);

    return nowMinutes >= inicioMinutes && nowMinutes <= finMinutes;
  }

  Future<void> _verificarPassword(BuildContext context, Function onAutorizado) async {
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
                  const Text('Acción protegida. Ingresa tu contraseña para autorizar.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              content: TextField(
                controller: passCtrl,
                obscureText: ocultarPass,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  hintText: 'Contraseña de profesor',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  suffixIcon: IconButton(
                    icon: Icon(ocultarPass ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                    onPressed: () {
                      setStateDialog(() {
                        ocultarPass = !ocultarPass;
                      });
                    },
                  ),
                ),
              ),
              actionsAlignment: MainAxisAlignment.spaceEvenly,
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar', style: TextStyle(color: textDark)),
                ),
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña incorrecta, verifica que esté bien escrita.')));
                    }
                  },
                  child: const Text('Autorizar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  void _mostrarExito(BuildContext context, String mensaje) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 16),
            Text('Eliminado', style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 8),
            Text(mensaje, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () => Navigator.pop(context),
                child: const Text('Aceptar', style: TextStyle(color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _eliminarClase(String docId) async {
    await FirebaseFirestore.instance.collection('materias').doc(docId).delete();
    if (mounted) _mostrarExito(context, 'La clase ha sido eliminada con éxito');
  }

  Widget _buildClaseHoyCard(String materia, String horario, Color color, {bool activo = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: activo ? Border.all(color: color, width: 1.5) : Border.all(color: Colors.transparent),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(width: 4, height: 40, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(materia, style: TextStyle(fontFamily: 'FuentePrincipal', fontWeight: FontWeight.bold, fontSize: 16, color: textDark)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(horario, style: const TextStyle(fontFamily: 'FuenteSecundaria', fontSize: 12, color: Colors.grey)),
                  ],
                )
              ],
            ),
          ),
          if (activo)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
              child: Row(
                children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  const Text("Curso", style: TextStyle(fontFamily: 'FuentePrincipal', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
            )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    String nombre = FirebaseAuth.instance.currentUser?.displayName ?? "Profesor";

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FormularioClaseScreen())),
        backgroundColor: const Color(0xFF10B981), 
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CABECERA
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 50, left: 24, right: 24, bottom: 20),
            decoration: BoxDecoration(color: colorPrincipal, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // AQUÍ ESTÁ EL CAMBIO: Se reemplazó el CircleAvatar con el Icon por el de la imagen
                    Container(
                      padding: const EdgeInsets.all(2), // Borde blanco pequeño si quieres, o 0
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/icon.jpeg',
                          width: 36, // Ajusta el tamaño de la imagen (radio 18 = diametro 36)
                          height: 36,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text("Hola, $nombre", style: const TextStyle(fontFamily: 'FuentePrincipal', fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white))),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ConfiguracionScreen())),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Text(_obtenerFechaActual(), style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          
          // CUERPO DINÁMICO
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('materias').where('profesorId', isEqualTo: uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Aún no tienes clases registradas."));

                final materias = snapshot.data!.docs;

                // FILTRAR CLASES DE HOY
                int diaSemana = DateTime.now().weekday; 
                List<QueryDocumentSnapshot> clasesHoy = [];
                
                if (diaSemana >= 1 && diaSemana <= 5) {
                  clasesHoy = materias.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    List<dynamic> dias = data['dias'] ?? [false, false, false, false, false];
                    return dias[diaSemana - 1] == true;
                  }).toList();
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 80), 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Clases de Hoy", style: TextStyle(fontFamily: 'FuentePrincipal', fontWeight: FontWeight.bold, fontSize: 16, color: textDark)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: clasesHoy.isEmpty
                          ? const Text("No tienes clases programadas para hoy.", style: TextStyle(color: Colors.grey, fontFamily: 'FuenteSecundaria'))
                          : Column(
                              children: clasesHoy.map((doc) {
                                var data = doc.data() as Map<String, dynamic>;
                                Color colorMateria = Color(data['color']);
                                
                                String horaInicio = data.containsKey('horaInicio') ? data['horaInicio'] : "00:00";
                                String horaFin = data.containsKey('horaFin') ? data['horaFin'] : "00:00";
                                String horario = "$horaInicio -$horaFin";
                                
                                bool enCurso = _estaEnCurso(horaInicio, horaFin);
                                
                                // --- NAVEGACIÓN DESDE CLASES DE HOY TAMBIÉN ---
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (context) => DetalleClaseScreen(docId: doc.id, materiaData: data)
                                    ));
                                  },
                                  child: _buildClaseHoyCard(data['materia'], horario, colorMateria, activo: enCurso),
                                );
                              }).toList(),
                            ),
                      ),

                      // SECCIÓN: TODAS MIS MATERIAS
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                        child: Text("Todas mis materias", style: TextStyle(fontFamily: 'FuentePrincipal', fontWeight: FontWeight.bold, fontSize: 16, color: textDark)),
                      ),
                      GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                        shrinkWrap: true, 
                        physics: const NeverScrollableScrollPhysics(), 
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, 
                          crossAxisSpacing: 16, 
                          mainAxisSpacing: 16, 
                          childAspectRatio: 0.85
                        ),
                        itemCount: materias.length,
                        itemBuilder: (context, index) {
                          var doc = materias[index];
                          var materiaData = doc.data() as Map<String, dynamic>;
                          Color colorDecodificado = Color(materiaData['color']);
                          
                          // --- NAVEGACIÓN DESDE EL GRID DE MATERIAS ---
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (context) => DetalleClaseScreen(docId: doc.id, materiaData: materiaData)
                              ));
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white, 
                                borderRadius: BorderRadius.circular(16), 
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                                      onSelected: (value) {
                                        if (value == 'editar') {
                                          _verificarPassword(context, () {
                                            Navigator.push(context, MaterialPageRoute(builder: (context) => EditarClaseScreen(docId: doc.id, datosActuales: materiaData)));
                                          });
                                        } else if (value == 'eliminar') {
                                          _verificarPassword(context, () => _eliminarClase(doc.id));
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(value: 'editar', child: Row(children: [Icon(Icons.edit, color: Colors.blue, size: 20), SizedBox(width: 8), Text('Editar')])),
                                        const PopupMenuItem(value: 'eliminar', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 8), Text('Eliminar')])),
                                      ],
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.center,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: colorDecodificado, 
                                          radius: 28, 
                                          child: Text(materiaData['materia'][0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24))
                                        ),
                                        const SizedBox(height: 12),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                          child: Text(
                                            materiaData['materia'], 
                                            maxLines: 1, 
                                            overflow: TextOverflow.ellipsis, 
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontFamily: 'FuentePrincipal', fontWeight: FontWeight.bold, fontSize: 16, color: textDark)
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(materiaData['nivel'], style: const TextStyle(fontFamily: 'FuenteSecundaria', fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}