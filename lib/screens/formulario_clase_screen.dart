import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FormularioClaseScreen extends StatefulWidget {
  final Map<String, dynamic>? claseAEditar;
  const FormularioClaseScreen({super.key, this.claseAEditar});

  @override
  State<FormularioClaseScreen> createState() => _FormularioClaseScreenState();
}

class _FormularioClaseScreenState extends State<FormularioClaseScreen> {
  final TextEditingController _materiaCtrl = TextEditingController();
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color colorProfesor = const Color(0xFF4F46E5);
  final Color textDark = const Color(0xFF1E293B);
  final Color colorExito = const Color(0xFF10B981);

  String _nivelSeleccionado = "Preparatoria";
  final List<String> _niveles = ["Primaria", "Secundaria", "Preparatoria", "Universidad"];
  
  final List<Color> _coloresDefault = [
    const Color(0xFFEF4444), // Rojo
    const Color(0xFF3B82F6), // Azul
    const Color(0xFF10B981), // Verde
    const Color(0xFFF59E0B), // Naranja
  ];
  
  late Color _colorSeleccionado = _coloresDefault[0];

  final List<String> _diasLetras = ['L', 'M', 'M', 'J', 'V'];
  final List<bool> _diasSeleccionados = [false, false, false, false, false];

  TimeOfDay? _horaInicio;
  TimeOfDay? _horaFin;

  void _abrirSelectorColor() {
    double r = _colorSeleccionado.red.toDouble();
    double g = _colorSeleccionado.green.toDouble();
    double b = _colorSeleccionado.blue.toDouble();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Color colorActual = Color.fromRGBO(r.toInt(), g.toInt(), b.toInt(), 1);
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Seleccionar Color", style: TextStyle(fontFamily: 'FuentePrincipal', fontWeight: FontWeight.bold, fontSize: 18, color: textDark)),
                    const SizedBox(height: 16),
                    Container(height: 80, width: double.infinity, decoration: BoxDecoration(color: colorActual, borderRadius: BorderRadius.circular(16))),
                    const SizedBox(height: 16),
                    _buildColorSlider("R", r, Colors.red, (val) => setStateDialog(() => r = val)),
                    _buildColorSlider("G", g, Colors.green, (val) => setStateDialog(() => g = val)),
                    _buildColorSlider("B", b, Colors.blue, (val) => setStateDialog(() => b = val)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() => _colorSeleccionado = colorActual);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: colorProfesor, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text("Aplicar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildColorSlider(String label, double value, Color color, ValueChanged<double> onChanged) {
    return Row(
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        Expanded(child: Slider(value: value, min: 0, max: 255, activeColor: color, onChanged: onChanged)),
        Text(value.toInt().toString(), style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Future<void> _seleccionarHora(bool esInicio) async {
    final TimeOfDay? seleccion = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (seleccion != null) {
      setState(() {
        if (esInicio) {
          _horaInicio = seleccion;
        } else {
          _horaFin = seleccion;
        }
      });
    }
  }

  Future<void> _guardarClase() async {
    if (_materiaCtrl.text.isEmpty || _horaInicio == null || _horaFin == null || !_diasSeleccionados.contains(true)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Completa todos los campos"), backgroundColor: Colors.redAccent));
      return;
    }

    // 1. Obtenemos al profesor logueado
    User? profeActual = FirebaseAuth.instance.currentUser;
    if (profeActual == null) return; // Por seguridad

    String uid = profeActual.uid;
    
    // 2. Extraemos su nombre o la primera parte de su correo
    String nombreProfe = profeActual.displayName ?? profeActual.email?.split('@')[0] ?? "Profesor";

    String horaI = "${_horaInicio!.hour.toString().padLeft(2, '0')}:${_horaInicio!.minute.toString().padLeft(2, '0')}";
    String horaF = "${_horaFin!.hour.toString().padLeft(2, '0')}:${_horaFin!.minute.toString().padLeft(2, '0')}";

    try {
      // 3. Guardamos la materia incluyendo el nombre del profesor
      await FirebaseFirestore.instance.collection('materias').add({
        'profesorId': uid,
        'nombreProfesor': nombreProfe, // <-- LÍNEA AGREGADA
        'materia': _materiaCtrl.text.trim(),
        'nivel': _nivelSeleccionado,
        'color': _colorSeleccionado.value,
        'horaInicio': horaI,
        'horaFin': horaF,
        'dias': _diasSeleccionados, 
        'fechaCreacion': FieldValue.serverTimestamp(),
      });
      _mostrarDialogoExito();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent));
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
                const Text("¡Éxito!", style: TextStyle(fontFamily: 'FuentePrincipal', fontWeight: FontWeight.bold, fontSize: 22)),
                const SizedBox(height: 8),
                const Text("Clase creada exitosamente", style: TextStyle(fontFamily: 'FuenteSecundaria', fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: colorExito, padding: const EdgeInsets.symmetric(vertical: 16), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: const Text("Aceptar", style: TextStyle(fontFamily: 'FuenteSecundaria', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
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
    bool esColorPersonalizado = !_coloresDefault.map((c) => c.value).contains(_colorSeleccionado.value);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(backgroundColor: bgColor, elevation: 0, iconTheme: IconThemeData(color: textDark), title: Text("Nueva Clase", style: TextStyle(fontFamily: 'FuentePrincipal', fontWeight: FontWeight.bold, color: textDark, fontSize: 18))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Materia", style: TextStyle(fontFamily: 'FuenteSecundaria', fontSize: 14)),
            const SizedBox(height: 8),
            TextField(controller: _materiaCtrl, decoration: InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
            const SizedBox(height: 24),
            
            const Text("Nivel", style: TextStyle(fontFamily: 'FuenteSecundaria', fontSize: 14)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _nivelSeleccionado,
              decoration: InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
              items: _niveles.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
              onChanged: (val) => setState(() => _nivelSeleccionado = val!),
            ),
            const SizedBox(height: 24),

            const Text("Color de la materia", style: TextStyle(fontFamily: 'FuenteSecundaria', fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ..._coloresDefault.map((color) {
                  bool seleccionado = _colorSeleccionado.value == color.value;
                  return GestureDetector(
                    onTap: () => setState(() => _colorSeleccionado = color),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: seleccionado ? colorProfesor : Colors.transparent,
                          width: seleccionado ? 3 : 0,
                        ),
                      ),
                      child: seleccionado ? const Icon(Icons.check, color: Colors.white) : null,
                    ),
                  );
                }),
                GestureDetector(
                  onTap: _abrirSelectorColor,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: esColorPersonalizado ? _colorSeleccionado : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: esColorPersonalizado ? colorProfesor : Colors.grey.shade300,
                        width: esColorPersonalizado ? 3 : 1,
                      ),
                    ),
                    child: Icon(
                      Icons.palette_rounded,
                      color: esColorPersonalizado ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Text("Días de la semana", style: TextStyle(fontFamily: 'FuenteSecundaria', fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _diasSeleccionados[index] = !_diasSeleccionados[index]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 45, height: 45,
                    decoration: BoxDecoration(color: _diasSeleccionados[index] ? colorProfesor : Colors.white, shape: BoxShape.circle, border: Border.all(color: _diasSeleccionados[index] ? colorProfesor : Colors.grey.shade300)),
                    child: Center(child: Text(_diasLetras[index], style: TextStyle(fontFamily: 'FuenteSecundaria', fontWeight: FontWeight.bold, color: _diasSeleccionados[index] ? Colors.white : Colors.grey))),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Hora Inicio", style: TextStyle(fontFamily: 'FuenteSecundaria', fontSize: 14)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _seleccionarHora(true),
                        child: Container(padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Text(_horaInicio?.format(context) ?? "--:--", style: TextStyle(fontFamily: 'FuenteSecundaria', color: _horaInicio == null ? Colors.grey : textDark))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Hora Fin", style: TextStyle(fontFamily: 'FuenteSecundaria', fontSize: 14)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _seleccionarHora(false),
                        child: Container(padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Text(_horaFin?.format(context) ?? "--:--", style: TextStyle(fontFamily: 'FuenteSecundaria', color: _horaFin == null ? Colors.grey : textDark))),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _guardarClase,
              style: ElevatedButton.styleFrom(backgroundColor: colorProfesor, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text("Guardar Clase", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}