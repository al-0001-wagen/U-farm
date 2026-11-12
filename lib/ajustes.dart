// U Farm - Ajustes de la app
//
// Guarda en el teléfono lo que cada persona personaliza:
//   - tema claro u oscuro y color de los botones
//   - qué tarjetas aparecen en el inicio, en qué orden y con qué nombre
//   - los tiempos de los botones de "Regar ahora"
//   - los botones rápidos del vidrio (por ejemplo "50 %")
//   - los cambios hechos a la enciclopedia
//
// Requisito: el paquete shared_preferences (ya está en pubspec.yaml).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'enciclopedia_datos.dart';

// ---------------------------------------------------------------------------
// COLORES DISPONIBLES
// Para agregar otro color, copien una línea y cambien los tres valores:
// nombre, color de los botones y color (más oscuro) de la barra de arriba.
// ---------------------------------------------------------------------------

class OpcionColor {
  final String nombre;
  final Color principal;
  final Color barra;
  const OpcionColor(this.nombre, this.principal, this.barra);
}

const List<OpcionColor> opcionesColor = [
  OpcionColor('Verde', Color(0xFF16A34A), Color(0xFF0E3B34)),
  OpcionColor('Turquesa', Color(0xFF0D9488), Color(0xFF134E4A)),
  OpcionColor('Azul', Color(0xFF2563EB), Color(0xFF172554)),
  OpcionColor('Morado', Color(0xFF7C3AED), Color(0xFF2E1065)),
  OpcionColor('Rosa', Color(0xFFDB2777), Color(0xFF831843)),
  OpcionColor('Naranja', Color(0xFFEA580C), Color(0xFF7C2D12)),
];

// ---------------------------------------------------------------------------
// TARJETAS DE LA PANTALLA DE INICIO
// ---------------------------------------------------------------------------

class TarjetaInicio {
  final String id;
  String nombre;
  bool visible;
  TarjetaInicio(this.id, this.nombre, {this.visible = true});

  Map<String, dynamic> aJson() =>
      {'id': id, 'nombre': nombre, 'visible': visible};
}

/// Nombres originales de cada tarjeta, en su orden original.
const Map<String, String> nombresDeFabrica = {
  'clima': 'Clima',
  'ganado': 'Mi ganado',
  'riego': 'Riego',
  'vidrios': 'Vidrios del techo',
  'enciclopedia': 'Enciclopedia de la granja',
};

List<TarjetaInicio> _tarjetasDeFabrica() => [
      for (final e in nombresDeFabrica.entries) TarjetaInicio(e.key, e.value),
    ];

// ---------------------------------------------------------------------------
// AJUSTES
// ---------------------------------------------------------------------------

class Ajustes extends ChangeNotifier {
  Ajustes._();

  /// La única copia de los ajustes; se usa como `Ajustes.i`.
  static final Ajustes i = Ajustes._();

  static const List<int> tiemposRiegoDeFabrica = [3, 5, 10, 20];
  static const List<int> atajosVidrioDeFabrica = [25, 50, 75];

  SharedPreferences? _prefs;

  bool oscuro = false;
  int indiceColor = 0;
  List<TarjetaInicio> tarjetas = _tarjetasDeFabrica();
  List<int> tiemposRiego = [...tiemposRiegoDeFabrica]; // segundos
  List<int> atajosVidrio = [...atajosVidrioDeFabrica]; // porcentajes

  OpcionColor get color => opcionesColor[indiceColor];

  // ----- Cargar y guardar -----

  Future<void> cargar() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final texto = _prefs!.getString('ajustes');
      if (texto != null) _leer(jsonDecode(texto) as Map<String, dynamic>);
      cargarEnciclopedia(_prefs!.getString('enciclopedia'));
    } catch (_) {
      // Si algo guardado está dañado, la app arranca con los valores de fábrica.
    }
  }

  void _leer(Map<String, dynamic> j) {
    oscuro = j['oscuro'] == true;
    final c = (j['color'] as num?)?.toInt() ?? 0;
    indiceColor = c >= 0 && c < opcionesColor.length ? c : 0;

    // Tarjetas: se respeta el orden guardado y se agregan las que falten.
    final guardadas = <TarjetaInicio>[];
    for (final t in (j['tarjetas'] as List? ?? const [])) {
      if (t is! Map) continue;
      final id = t['id'];
      if (id is! String || !nombresDeFabrica.containsKey(id)) continue;
      if (guardadas.any((g) => g.id == id)) continue;
      guardadas.add(TarjetaInicio(
        id,
        (t['nombre'] as String?) ?? nombresDeFabrica[id]!,
        visible: t['visible'] != false,
      ));
    }
    for (final e in nombresDeFabrica.entries) {
      if (!guardadas.any((g) => g.id == e.key)) {
        guardadas.add(TarjetaInicio(e.key, e.value));
      }
    }
    tarjetas = guardadas;

    tiemposRiego = _enteros(j['tiemposRiego'], 1, 60, tiemposRiegoDeFabrica);
    atajosVidrio = _enteros(j['atajosVidrio'], 0, 100, atajosVidrioDeFabrica);
  }

  static List<int> _enteros(dynamic lista, int min, int max, List<int> base) {
    if (lista is! List) return [...base];
    final valores = <int>{
      for (final v in lista)
        if (v is num && v >= min && v <= max) v.round(),
    }.toList()
      ..sort();
    return valores.isEmpty ? [...base] : valores;
  }

  void _guardar() {
    _prefs?.setString(
      'ajustes',
      jsonEncode({
        'oscuro': oscuro,
        'color': indiceColor,
        'tarjetas': [for (final t in tarjetas) t.aJson()],
        'tiemposRiego': tiemposRiego,
        'atajosVidrio': atajosVidrio,
      }),
    );
    notifyListeners();
  }

  /// Guarda los cambios hechos a la enciclopedia (fichas y sinergias).
  void guardarEnciclopedia() {
    _prefs?.setString('enciclopedia', exportarEnciclopedia());
    notifyListeners();
  }

  // ----- Apariencia -----

  void ponerOscuro(bool valor) {
    oscuro = valor;
    _guardar();
  }

  void ponerColor(int indice) {
    indiceColor = indice;
    _guardar();
  }

  // ----- Pantalla de inicio -----

  void moverTarjeta(int de, int a) {
    if (a > de) a -= 1;
    tarjetas.insert(a, tarjetas.removeAt(de));
    _guardar();
  }

  void mostrarTarjeta(String id, bool visible) {
    tarjetas.firstWhere((t) => t.id == id).visible = visible;
    _guardar();
  }

  void renombrarTarjeta(String id, String nombre) {
    final limpio = nombre.trim();
    tarjetas.firstWhere((t) => t.id == id).nombre =
        limpio.isEmpty ? nombresDeFabrica[id]! : limpio;
    _guardar();
  }

  // ----- Botones de acción -----

  void agregarTiempoRiego(int segundos) {
    if (tiemposRiego.contains(segundos)) return;
    tiemposRiego = [...tiemposRiego, segundos]..sort();
    _guardar();
  }

  void quitarTiempoRiego(int segundos) {
    tiemposRiego = tiemposRiego.where((s) => s != segundos).toList();
    _guardar();
  }

  void agregarAtajoVidrio(int porcentaje) {
    if (atajosVidrio.contains(porcentaje)) return;
    atajosVidrio = [...atajosVidrio, porcentaje]..sort();
    _guardar();
  }

  void quitarAtajoVidrio(int porcentaje) {
    atajosVidrio = atajosVidrio.where((p) => p != porcentaje).toList();
    _guardar();
  }

  // ----- Restablecer -----

  void restablecerAjustes() {
    oscuro = false;
    indiceColor = 0;
    tarjetas = _tarjetasDeFabrica();
    tiemposRiego = [...tiemposRiegoDeFabrica];
    atajosVidrio = [...atajosVidrioDeFabrica];
    _guardar();
  }

  void restablecerEnciclopedia() {
    cargarEnciclopedia(null);
    guardarEnciclopedia();
  }
}

// ---------------------------------------------------------------------------
// COLORES DE LA APP
// Todas las pantallas toman sus colores de aquí, así cambian juntas con
// el tema y con el color elegido en Ajustes.
// ---------------------------------------------------------------------------

bool get _oscuro => Ajustes.i.oscuro;

/// Color de los botones y los acentos.
Color get cPrincipal => Ajustes.i.color.principal;

/// Color de la barra de arriba (versión oscura del principal).
Color get cBarra => Ajustes.i.color.barra;

/// Versión clara del color principal (barras de progreso sobre fondo oscuro).
Color get cPrincipalClaro => Color.lerp(cPrincipal, Colors.white, 0.55)!;

/// Fondo de las pantallas.
Color get cFondo => _oscuro ? const Color(0xFF121614) : const Color(0xFFF1EFE8);

/// Fondo de recuadros y campos de texto.
Color get cSuperficie => _oscuro ? const Color(0xFF232A27) : Colors.white;

/// Texto secundario.
Color get cTenue => _oscuro ? Colors.white70 : Colors.black54;

/// Texto de notas pequeñas.
Color get cMuyTenue => _oscuro ? Colors.white54 : Colors.black45;

/// Bordes y líneas suaves.
Color get cLinea => _oscuro ? Colors.white24 : Colors.black12;

/// Color fuerte para íconos y bordes que deben resaltar sobre el fondo.
Color get cContraste => _oscuro ? cPrincipalClaro : cBarra;

/// Tema de Material con el color y el modo elegidos.
ThemeData temaDeLaApp() {
  final brillo = _oscuro ? Brightness.dark : Brightness.light;
  return ThemeData(
    useMaterial3: true,
    brightness: brillo,
    colorScheme:
        ColorScheme.fromSeed(seedColor: cPrincipal, brightness: brillo),
    scaffoldBackgroundColor: cFondo,
  );
}

// ---------------------------------------------------------------------------
// PANTALLA DE AJUSTES
// ---------------------------------------------------------------------------

class PantallaAjustes extends StatelessWidget {
  const PantallaAjustes({super.key});

  @override
  Widget build(BuildContext context) {
    final a = Ajustes.i;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cBarra,
        foregroundColor: Colors.white,
        title: const Text('Ajustes'),
      ),
      body: ListenableBuilder(
        listenable: a,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _seccion(
              icono: Icons.palette_outlined,
              titulo: 'Apariencia',
              hijos: [
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                          value: false,
                          icon: Icon(Icons.light_mode_outlined),
                          label: Text('Claro')),
                      ButtonSegment(
                          value: true,
                          icon: Icon(Icons.dark_mode_outlined),
                          label: Text('Oscuro')),
                    ],
                    selected: {a.oscuro},
                    onSelectionChanged: (s) => a.ponerOscuro(s.first),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Color de los botones: ${a.color.nombre}'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (var n = 0; n < opcionesColor.length; n++)
                      _circuloColor(n, a.indiceColor == n),
                  ],
                ),
              ],
            ),
            _seccion(
              icono: Icons.dashboard_customize_outlined,
              titulo: 'Pantalla de inicio',
              hijos: [
                Text(
                  'Arrastra desde las rayitas para cambiar el orden. '
                  'Apaga las tarjetas que no quieras ver.',
                  style: TextStyle(color: cTenue),
                ),
                const SizedBox(height: 8),
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorder: a.moverTarjeta,
                  children: [
                    for (var n = 0; n < a.tarjetas.length; n++)
                      _filaTarjeta(context, a.tarjetas[n], n),
                  ],
                ),
              ],
            ),
            _seccion(
              icono: Icons.water_drop_outlined,
              titulo: 'Botones de "Regar ahora"',
              hijos: [
                Text('Segundos que ofrece la app al regar a mano.',
                    style: TextStyle(color: cTenue)),
                const SizedBox(height: 8),
                _chips(
                  context,
                  valores: a.tiemposRiego,
                  etiqueta: (v) => '$v s',
                  alQuitar: a.quitarTiempoRiego,
                  alAgregar: a.agregarTiempoRiego,
                  tituloDialogo: 'Nuevo tiempo de riego',
                  ayuda: 'Segundos, de 1 a 60',
                  min: 1,
                  max: 60,
                  maximoDeBotones: 6,
                ),
              ],
            ),
            _seccion(
              icono: Icons.roofing,
              titulo: 'Botones rápidos del vidrio',
              hijos: [
                Text(
                    'Aperturas que aparecen como botones, además de '
                    'Abrir y Cerrar.',
                    style: TextStyle(color: cTenue)),
                const SizedBox(height: 8),
                _chips(
                  context,
                  valores: a.atajosVidrio,
                  etiqueta: (v) => '$v %',
                  alQuitar: a.quitarAtajoVidrio,
                  alAgregar: a.agregarAtajoVidrio,
                  tituloDialogo: 'Nuevo botón del vidrio',
                  ayuda: 'Porcentaje de apertura, de 0 a 100',
                  min: 0,
                  max: 100,
                  maximoDeBotones: 6,
                ),
              ],
            ),
            _seccion(
              icono: Icons.restart_alt,
              titulo: 'Restablecer',
              hijos: [
                Text(
                  hayCambiosEnEnciclopedia
                      ? 'La enciclopedia tiene cambios hechos en este teléfono.'
                      : 'La enciclopedia está como venía de fábrica.',
                  style: TextStyle(color: cTenue),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Restaurar la enciclopedia original'),
                  onPressed: hayCambiosEnEnciclopedia
                      ? () => _confirmar(
                            context,
                            titulo: '¿Restaurar la enciclopedia?',
                            texto: 'Se borrarán las fichas y sinergias que '
                                'agregaste o cambiaste en este teléfono.',
                            accion: a.restablecerEnciclopedia,
                          )
                      : null,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.settings_backup_restore),
                  label: const Text('Volver a los ajustes de fábrica'),
                  onPressed: () => _confirmar(
                    context,
                    titulo: '¿Restablecer los ajustes?',
                    texto: 'El color, el tema, la pantalla de inicio y los '
                        'botones volverán a como estaban al instalar la app. '
                        'La enciclopedia no cambia.',
                    accion: a.restablecerAjustes,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Estos ajustes se guardan solo en este teléfono.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cMuyTenue, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccion({
    required IconData icono,
    required String titulo,
    required List<Widget> hijos,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, color: cPrincipal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(titulo,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...hijos,
          ],
        ),
      ),
    );
  }

  Widget _circuloColor(int n, bool elegido) {
    final opcion = opcionesColor[n];
    return Tooltip(
      message: opcion.nombre,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Ajustes.i.ponerColor(n),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: opcion.principal,
            shape: BoxShape.circle,
            border: Border.all(
              color: elegido ? cContraste : Colors.transparent,
              width: 3,
            ),
          ),
          child: elegido
              ? const Icon(Icons.check, color: Colors.white, size: 22)
              : null,
        ),
      ),
    );
  }

  Widget _filaTarjeta(BuildContext context, TarjetaInicio t, int n) {
    return ListTile(
      key: ValueKey(t.id),
      contentPadding: EdgeInsets.zero,
      leading: ReorderableDragStartListener(
        index: n,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(Icons.drag_handle, color: cTenue),
        ),
      ),
      title: Text(t.nombre),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (t.id != 'clima')
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Cambiar nombre',
              onPressed: () => _renombrar(context, t),
            ),
          Switch(
            value: t.visible,
            activeTrackColor: cPrincipal,
            onChanged: (v) => Ajustes.i.mostrarTarjeta(t.id, v),
          ),
        ],
      ),
    );
  }

  Widget _chips(
    BuildContext context, {
    required List<int> valores,
    required String Function(int) etiqueta,
    required void Function(int) alQuitar,
    required void Function(int) alAgregar,
    required String tituloDialogo,
    required String ayuda,
    required int min,
    required int max,
    required int maximoDeBotones,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in valores)
          InputChip(
            label: Text(etiqueta(v)),
            // Siempre debe quedar al menos un botón.
            onDeleted: valores.length > 1 ? () => alQuitar(v) : null,
          ),
        if (valores.length < maximoDeBotones)
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('Agregar'),
            onPressed: () async {
              final nuevo = await _pedirNumero(context,
                  titulo: tituloDialogo, ayuda: ayuda, min: min, max: max);
              if (nuevo != null) alAgregar(nuevo);
            },
          ),
      ],
    );
  }

  Future<void> _renombrar(BuildContext context, TarjetaInicio t) async {
    final control = TextEditingController(text: t.nombre);
    final nuevo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nombre de la tarjeta'),
        content: TextField(
          controller: control,
          autofocus: true,
          maxLength: 40,
          decoration: InputDecoration(
            hintText: nombresDeFabrica[t.id],
            helperText: 'Déjalo vacío para volver al nombre original',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, control.text),
              child: const Text('Guardar')),
        ],
      ),
    );
    if (nuevo != null) Ajustes.i.renombrarTarjeta(t.id, nuevo);
  }

  Future<int?> _pedirNumero(
    BuildContext context, {
    required String titulo,
    required String ayuda,
    required int min,
    required int max,
  }) {
    final control = TextEditingController();
    String? error;
    return showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ponerEstado) {
          void aceptar() {
            final n = int.tryParse(control.text.trim());
            if (n == null || n < min || n > max) {
              ponerEstado(() => error = 'Escribe un número de $min a $max');
              return;
            }
            Navigator.pop(ctx, n);
          }

          return AlertDialog(
            title: Text(titulo),
            content: TextField(
              controller: control,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(helperText: ayuda, errorText: error),
              onSubmitted: (_) => aceptar(),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar')),
              FilledButton(onPressed: aceptar, child: const Text('Agregar')),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmar(
    BuildContext context, {
    required String titulo,
    required String texto,
    required VoidCallback accion,
  }) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sí, restablecer')),
        ],
      ),
    );
    if (si == true) accion();
  }
}
