import 'package:flutter/material.dart';

class CrearClaseScreen extends StatefulWidget {
  const CrearClaseScreen({super.key});

  @override
  State<CrearClaseScreen> createState() => _CrearClaseScreenState();
}

class _CrearClaseScreenState extends State<CrearClaseScreen> {
  final TextEditingController _materiaCtrl = TextEditingController();
  
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color colorProfesor = const Color(0xFF4F46E5);
  final Color textDark = const Color(0xFF1E293B);
  final Color colorExito = const Color(0xFF10B981);

  // Variables de estado para los selectores
  String _nivelSeleccionado = "Preparatoria";
  final List<String> _niveles = ["Primaria", "Secundaria", "Preparatoria", "Universidad"];
  
  final List<Color> _colores = [Colors.red, Colors.green, Colors.blue, Colors.orange, Colors.purple];
  Color _colorSeleccionado = Colors.red;

  final List<String> _diasLetras = ['L', 'M', 'M', 'J', 'V'];
  final List<bool> _diasSeleccionados = [false, false, false, false, false];

  TimeOfDay? _horaInicio;
  TimeOfDay? _horaFin;

  Future<void> _seleccionarHora(bool esInicio) async {
    final TimeOfDay? seleccion = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: colorProfesor)),
          child: child!,
        );
      },
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

  void _guardarClase() {
    if (_materiaCtrl.text.isEmpty || _horaInicio == null || _horaFin == null || !_diasSeleccionados.contains(true)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Completa todos los campos"), backgroundColor: Colors.redAccent));
      return;
    }
    _mostrarDialogoExito();
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
                      Navigator.of(context).pop(); // Cierra diálogo
                      Navigator.of(context).pop(); // Regresa al Home
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
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textDark),
        title: Text("Nueva Clase", style: TextStyle(fontFamily: 'FuentePrincipal', fontWeight: FontWeight.bold, color: textDark, fontSize: 18)),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLabel("Materia"),
            TextField(
              controller: _materiaCtrl,
              style: const TextStyle(fontFamily: 'FuenteSecundaria'),
              decoration: _inputDecoration("Ej. Matemáticas"),
            ),
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Nivel"),
                      DropdownButtonFormField<String>(
                        initialValue: _nivelSeleccionado,
                        decoration: _inputDecoration(""),
                        items: _niveles.map((n) => DropdownMenuItem(value: n, child: Text(n, style: const TextStyle(fontFamily: 'FuenteSecundaria')))).toList(),
                        onChanged: (val) => setState(() => _nivelSeleccionado = val!),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Color"),
                      Container(
                        height: 55,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Color>(
                            isExpanded: true,
                            value: _colorSeleccionado,
                            icon: const SizedBox.shrink(), // Oculta la flecha para que se vea más limpio
                            items: _colores.map((c) => DropdownMenuItem(
                              value: c,
                              child: Center(child: Container(width: 24, height: 24, decoration: BoxDecoration(color: c, shape: BoxShape.circle))),
                            )).toList(),
                            onChanged: (val) => setState(() => _colorSeleccionado = val!),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            _buildLabel("Días de la semana"),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _diasSeleccionados[index] = !_diasSeleccionados[index]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: _diasSeleccionados[index] ? colorProfesor : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: _diasSeleccionados[index] ? colorProfesor : Colors.grey.shade300),
                    ),
                    child: Center(
                      child: Text(_diasLetras[index], style: TextStyle(fontFamily: 'FuenteSecundaria', fontWeight: FontWeight.bold, color: _diasSeleccionados[index] ? Colors.white : Colors.grey)),
                    ),
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
                      _buildLabel("Hora Inicio"),
                      GestureDetector(
                        onTap: () => _seleccionarHora(true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                          child: Text(_horaInicio?.format(context) ?? "--:--", style: TextStyle(fontFamily: 'FuenteSecundaria', color: _horaInicio == null ? Colors.grey : textDark)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Hora Fin"),
                      GestureDetector(
                        onTap: () => _seleccionarHora(false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                          child: Text(_horaFin?.format(context) ?? "--:--", style: TextStyle(fontFamily: 'FuenteSecundaria', color: _horaFin == null ? Colors.grey : textDark)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            
            ElevatedButton(
              onPressed: _guardarClase,
              style: ElevatedButton.styleFrom(backgroundColor: colorProfesor, padding: const EdgeInsets.symmetric(vertical: 18), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text("Guardar Clase", style: TextStyle(fontFamily: 'FuenteSecundaria', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar", style: TextStyle(fontFamily: 'FuenteSecundaria', fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String texto) {
    return Padding(padding: const EdgeInsets.only(bottom: 8.0, left: 4.0), child: Text(texto, style: TextStyle(fontFamily: 'FuenteSecundaria', fontSize: 14, color: textDark)));
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colorProfesor, width: 2)),
    );
  }
}