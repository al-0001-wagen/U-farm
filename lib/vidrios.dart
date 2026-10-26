// U Farm - Control de los vidrios del techo
//
// La app escribe en Firebase la configuración y las órdenes; el
// controlador de vidrios (ESP32) mueve el motor y publica su estado.
//
// Ruta en Firebase:  /vidrios/techo/{config, comando, estado}
// Requisito: el paquete http (ya instalado).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'ganado.dart' show urlFirebase;

const _verde = Color(0xFF16A34A);
const _verdeOscuro = Color(0xFF0E3B34);
const _cielo = Color(0xFF7DD3FC);
const _vidrio = Color(0xFF94A3B8);

// Medidas de la estructura (de su tabla de mediciones), solo para el dibujo
const _largoEstructura = 18.7;
const _anchoEstructura = 6.8;
const _largoVidrio = 14.3;
const _anchoVidrio = 4.5;

// ---------------------------------------------------------------------------
// MODELOS
// ---------------------------------------------------------------------------

class ConfigVidrios {
  String modo; // 'manual' o 'auto'
  double tempCerrar;
  double tempAbrir;
  double vientoMax;
  bool cerrarPorClima;

  ConfigVidrios({
    required this.modo,
    required this.tempCerrar,
    required this.tempAbrir,
    required this.vientoMax,
    required this.cerrarPorClima,
  });

  factory ConfigVidrios.desdeJson(Map<String, dynamic>? j) {
    j ??= {};
    return ConfigVidrios(
      modo: (j['modo'] as String?) ?? 'manual',
      tempCerrar: (j['tempCerrar'] as num?)?.toDouble() ?? 18,
      tempAbrir: (j['tempAbrir'] as num?)?.toDouble() ?? 30,
      vientoMax: (j['vientoMax'] as num?)?.toDouble() ?? 40,
      cerrarPorClima: (j['cerrarPorClima'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> aJson() => {
        'modo': modo,
        'tempCerrar': tempCerrar,
        'tempAbrir': tempAbrir,
        'vientoMax': vientoMax,
        'cerrarPorClima': cerrarPorClima,
      };
}

class EstadoVidrios {
  final int apertura; // %
  final String moviendo; // 'abriendo', 'cerrando' o ''
  final String motivo;
  final bool calibrado;
  final double? tempInterior;
  final int? humedadInterior;
  final int? viento;
  final bool lloviendo;
  final double recorridoM;
  final double velocidadMs;
  final DateTime? actualizado;

  const EstadoVidrios({
    this.apertura = 0,
    this.moviendo = '',
    this.motivo = '',
    this.calibrado = false,
    this.tempInterior,
    this.humedadInterior,
    this.viento,
    this.lloviendo = false,
    this.recorridoM = 4.5,
    this.velocidadMs = 0.1,
    this.actualizado,
  });

  factory EstadoVidrios.desdeJson(Map<String, dynamic>? j) {
    if (j == null) return const EstadoVidrios();
    final act = j['actualizado'];
    return EstadoVidrios(
      apertura: (j['apertura'] as num?)?.round() ?? 0,
      moviendo: (j['moviendo'] as String?) ?? '',
      motivo: (j['motivo'] as String?) ?? '',
      calibrado: j['calibrado'] == true,
      tempInterior: (j['tempInterior'] as num?)?.toDouble(),
      humedadInterior: (j['humedadInterior'] as num?)?.round(),
      viento: (j['viento'] as num?)?.round(),
      lloviendo: j['lloviendo'] == true,
      recorridoM: (j['recorridoM'] as num?)?.toDouble() ?? 4.5,
      velocidadMs: (j['velocidadMs'] as num?)?.toDouble() ?? 0.1,
      actualizado: act is num
          ? DateTime.fromMillisecondsSinceEpoch(act.toInt())
          : null,
    );
  }

  bool get desconectado =>
      actualizado == null ||
      DateTime.now().difference(actualizado!) > const Duration(minutes: 2);
}

// ---------------------------------------------------------------------------
// SERVICIO
// ---------------------------------------------------------------------------

class ServicioVidrios {
  static String _url(String ruta) => '$urlFirebase/vidrios/techo$ruta.json';

  static Future<(ConfigVidrios, EstadoVidrios, bool)?> obtener() async {
    final r = await http
        .get(Uri.parse(_url('')))
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) {
      throw Exception('Firebase respondió ${r.statusCode}');
    }
    final datos = jsonDecode(r.body);
    if (datos == null) return null; // el controlador aún no se conecta
    final m = datos as Map<String, dynamic>;
    return (
      ConfigVidrios.desdeJson(m['config'] as Map<String, dynamic>?),
      EstadoVidrios.desdeJson(m['estado'] as Map<String, dynamic>?),
      m['comando'] != null,
    );
  }

  static Future<void> guardarConfig(ConfigVidrios c) =>
      _put(_url('/config'), c.aJson());

  static Future<void> mover(int porcentaje) =>
      _put(_url('/comando'), {'accion': 'mover', 'objetivo': porcentaje});

  static Future<void> detener() =>
      _put(_url('/comando'), {'accion': 'detener'});

  static Future<void> _put(String url, Map<String, dynamic> datos) async {
    final r = await http
        .put(Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(datos))
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) {
      throw Exception('Firebase respondió ${r.statusCode}');
    }
  }
}

// ---------------------------------------------------------------------------
// PANTALLA
// ---------------------------------------------------------------------------

class PantallaVidrios extends StatefulWidget {
  const PantallaVidrios({super.key});

  @override
  State<PantallaVidrios> createState() => _PantallaVidriosState();
}

class _PantallaVidriosState extends State<PantallaVidrios> {
  ConfigVidrios? _config;
  EstadoVidrios _estado = const EstadoVidrios();
  bool _ordenPendiente = false;
  bool _sinControlador = false;
  bool _cargado = false;
  String? _error;
  Timer? _temporizador;

  @override
  void initState() {
    super.initState();
    _cargar();
    _temporizador =
        Timer.periodic(const Duration(seconds: 2), (_) => _cargar());
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final r = await ServicioVidrios.obtener();
      if (!mounted) return;
      setState(() {
        _cargado = true;
        _error = null;
        _sinControlador = r == null;
        if (r != null) {
          _config = r.$1;
          _estado = r.$2;
          _ordenPendiente = r.$3;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargado = true;
        _error = 'No se pudo conectar con el controlador de vidrios.';
      });
    }
  }

  Future<void> _ejecutar(Future<void> Function() accion, String mensaje) async {
    final avisos = ScaffoldMessenger.of(context);
    try {
      await accion();
      avisos.showSnackBar(SnackBar(content: Text(mensaje)));
      await _cargar();
    } catch (_) {
      avisos.showSnackBar(const SnackBar(
          content: Text('No se pudo enviar. Revisa tu conexión.')));
    }
  }

  void _mover(int pct) => _ejecutar(
      () => ServicioVidrios.mover(pct), 'Orden enviada: llevar a $pct %');

  void _guardar() {
    final c = _config;
    if (c == null) return;
    _ejecutar(() => ServicioVidrios.guardarConfig(c), 'Cambios guardados');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1EFE8),
      appBar: AppBar(
        backgroundColor: _verdeOscuro,
        foregroundColor: Colors.white,
        title: const Text('Vidrios del techo'),
      ),
      body: !_cargado
          ? const Center(child: CircularProgressIndicator())
          : _sinControlador
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Todavía no hay un controlador de vidrios conectado. '
                      'Al encenderlo por primera vez se registra solo.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _contenido(),
    );
  }

  Widget _contenido() {
    final e = _estado;
    final c = _config;
    final bloqueado =
        (c?.cerrarPorClima ?? true) && (e.lloviendo || (e.viento ?? 0) >= (c?.vientoMax ?? 40));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_error != null) _aviso(Icons.cloud_off, _error!, Colors.red.shade700),
        if (e.desconectado && _error == null)
          _aviso(Icons.link_off, 'El controlador no ha reportado en los últimos minutos.',
              Colors.red.shade700),
        if (bloqueado)
          _aviso(Icons.umbrella,
              e.lloviendo
                  ? 'Está lloviendo: el techo se mantiene cerrado.'
                  : 'Viento fuerte (${e.viento} km/h): el techo se mantiene cerrado.',
              const Color(0xFF0284C7)),

        // Dibujo y estado
        _tarjeta(
          children: [
            _DiagramaTecho(apertura: e.apertura / 100),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('${e.apertura} %',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                const SizedBox(width: 12),
                Expanded(child: Text(_textoEstado(e))),
              ],
            ),
            if (!e.calibrado)
              const Text('Calibrando: cerrando hasta el tope…',
                  style: TextStyle(color: Colors.orange)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: _verde),
                    icon: const Icon(Icons.open_in_full),
                    label: const Text('Abrir'),
                    onPressed: bloqueado ? null : () => _mover(100),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: _verdeOscuro),
                    icon: const Icon(Icons.close_fullscreen),
                    label: const Text('Cerrar'),
                    onPressed: () => _mover(0),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  icon: const Icon(Icons.stop),
                  tooltip: 'Detener',
                  onPressed: () => _ejecutar(ServicioVidrios.detener, 'Orden enviada: detener'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _SliderAlSoltar(
              titulo: (v) => 'Llevar a $v %',
              valor: e.apertura,
              min: 0,
              max: 100,
              divisiones: 10,
              habilitado: !bloqueado,
              alSoltar: _mover,
            ),
            if (_ordenPendiente)
              const Text('Orden en camino…',
                  style: TextStyle(color: Colors.orange)),
          ],
        ),

        // Sensores
        _tarjeta(
          titulo: 'Condiciones',
          icono: Icons.thermostat,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _dato(Icons.thermostat, 'Adentro',
                    e.tempInterior == null ? '—' : '${e.tempInterior} °C'),
                _dato(Icons.water_drop_outlined, 'Humedad',
                    e.humedadInterior == null ? '—' : '${e.humedadInterior} %'),
                _dato(Icons.air, 'Viento', e.viento == null ? '—' : '${e.viento} km/h'),
                _dato(Icons.umbrella_outlined, 'Lluvia', e.lloviendo ? 'Sí' : 'No'),
              ],
            ),
          ],
        ),

        // Modo y ajustes
        if (c != null) _ajustes(c),

        // La matemática
        _tarjetaMatematica(e, c),
      ],
    );
  }

  String _textoEstado(EstadoVidrios e) {
    if (e.moviendo == 'abriendo') return 'Abriendo…\n${e.motivo}';
    if (e.moviendo == 'cerrando') return 'Cerrando…\n${e.motivo}';
    final base = e.apertura == 0
        ? 'Cerrado'
        : e.apertura == 100
            ? 'Abierto por completo'
            : 'Abierto parcialmente';
    return e.motivo.isEmpty ? base : '$base\n${e.motivo}';
  }

  Widget _ajustes(ConfigVidrios c) {
    return _tarjeta(
      titulo: 'Modo',
      icono: Icons.tune,
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'manual', icon: Icon(Icons.touch_app), label: Text('Manual')),
              ButtonSegment(value: 'auto', icon: Icon(Icons.auto_mode), label: Text('Automático')),
            ],
            selected: {c.modo},
            onSelectionChanged: (s) {
              setState(() => c.modo = s.first);
              _guardar();
            },
          ),
        ),
        const SizedBox(height: 12),
        if (c.modo == 'auto') ...[
          Text(
            'Cerrado con ${c.tempCerrar.round()} °C o menos, abierto por completo '
            'con ${c.tempAbrir.round()} °C o más, y en medio se abre poco a poco.',
          ),
          RangeSlider(
            values: RangeValues(c.tempCerrar, c.tempAbrir),
            min: 5,
            max: 40,
            divisions: 35,
            labels: RangeLabels('${c.tempCerrar.round()} °C', '${c.tempAbrir.round()} °C'),
            activeColor: _verde,
            onChanged: (v) {
              if (v.end - v.start < 2) return;
              setState(() {
                c.tempCerrar = v.start.roundToDouble();
                c.tempAbrir = v.end.roundToDouble();
              });
            },
            onChangeEnd: (_) => _guardar(),
          ),
        ] else
          const Text('El techo solo se mueve cuando tú lo ordenas.',
              style: TextStyle(color: Colors.black54)),
        const Divider(height: 24),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Cerrar con lluvia o viento fuerte'),
          subtitle: const Text('Funciona en ambos modos'),
          value: c.cerrarPorClima,
          activeTrackColor: _verde,
          onChanged: (v) {
            setState(() => c.cerrarPorClima = v);
            _guardar();
          },
        ),
        if (c.cerrarPorClima)
          _SliderAlSoltar(
            titulo: (v) => 'Cerrar con viento de $v km/h o más',
            valor: c.vientoMax.round(),
            min: 20,
            max: 80,
            divisiones: 12,
            habilitado: true,
            alSoltar: (v) {
              c.vientoMax = v.toDouble();
              _guardar();
            },
          ),
      ],
    );
  }

  /// Muestra las dos funciones lineales del proyecto con los datos reales.
  Widget _tarjetaMatematica(EstadoVidrios e, ConfigVidrios? c) {
    final v = e.velocidadMs;
    final l = e.recorridoM;
    final tTotal = l / v;
    final xActual = l * e.apertura / 100;
    String n(double x, [int d = 2]) => x.toStringAsFixed(d);

    final filas = <Widget>[
      const Text('1. Posición del vidrio en el tiempo',
          style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      _formula('x(t) = v · t'),
      Text('v = ${n(v)} m/s (velocidad del motor)'),
      Text('Dominio: 0 ≤ t ≤ ${n(tTotal, 1)} s   (T = L / v)'),
      Text('Rango: 0 ≤ x ≤ ${n(l)} m   (L = recorrido)'),
      const SizedBox(height: 4),
      Text('Ahora: x = ${n(xActual)} m, se llegó en t = ${n(xActual / v, 1)} s desde cerrado.',
          style: const TextStyle(color: Colors.black54)),
    ];

    if (c != null) {
      final tc = c.tempCerrar;
      final ta = c.tempAbrir;
      final pendiente = 100 / (ta - tc);
      filas.addAll([
        const Divider(height: 24),
        const Text('2. Apertura según la temperatura (modo automático)',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        _formula('A(T) = 100 · (T − ${tc.round()}) / (${ta.round()} − ${tc.round()})'),
        Text('Pendiente: ${n(pendiente, 1)} % por cada °C'),
        Text('Dominio útil: ${tc.round()} ≤ T ≤ ${ta.round()} °C   Rango: 0 ≤ A ≤ 100 %'),
        if (e.tempInterior != null) ...[
          const SizedBox(height: 4),
          Text(
            'Con ${e.tempInterior} °C adentro: '
            'A = ${n((100 * (e.tempInterior! - tc) / (ta - tc)).clamp(0.0, 100.0), 0)} %',
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ]);
    }

    return _tarjeta(titulo: 'La matemática', icono: Icons.functions, children: filas);
  }

  // ----- Piezas de interfaz -----

  Widget _formula(String texto) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: _verde.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(texto,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
    );
  }

  Widget _tarjeta({String? titulo, IconData? icono, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (titulo != null) ...[
              Row(
                children: [
                  Icon(icono, color: _verde),
                  const SizedBox(width: 8),
                  Text(titulo,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
            ],
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _dato(IconData icono, String etiqueta, String valor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 18, color: Colors.black54),
        const SizedBox(width: 4),
        Text('$etiqueta: ', style: const TextStyle(color: Colors.black54)),
        Text(valor, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _aviso(IconData icono, String texto, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icono, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DIBUJO DEL TECHO (vista desde arriba, a escala con sus medidas)
// ---------------------------------------------------------------------------

class _DiagramaTecho extends StatelessWidget {
  final double apertura; // 0 a 1
  const _DiagramaTecho({required this.apertura});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Vista desde arriba',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 6),
        AspectRatio(
          aspectRatio: _largoEstructura / _anchoEstructura,
          child: LayoutBuilder(builder: (context, caja) {
            final anchoVidrio = caja.maxWidth * _largoVidrio / _largoEstructura;
            final altoVidrio = caja.maxHeight * _anchoVidrio / _anchoEstructura;
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE7E5E4),
                border: Border.all(color: _verdeOscuro, width: 2),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: SizedBox(
                width: anchoVidrio,
                height: altoVidrio,
                child: Stack(
                  children: [
                    // Hueco del techo: se ve el cielo
                    Container(color: _cielo),
                    // El vidrio se desliza hacia la izquierda al abrir
                    AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 800),
                      alignment: Alignment.centerRight,
                      widthFactor: (1 - apertura).clamp(0.0, 1.0),
                      heightFactor: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _vidrio.withValues(alpha: 0.85),
                          border: Border.all(color: Colors.white70),
                        ),
                      ),
                    ),
                    if (apertura > 0.15)
                      const Positioned(
                        left: 8,
                        top: 0,
                        bottom: 0,
                        child: Icon(Icons.wb_sunny, color: Colors.amber),
                      ),
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        const Text(
          'Estructura 18.7 × 6.8 m · vidrio 14.3 × 4.5 m',
          style: TextStyle(fontSize: 11, color: Colors.black45),
        ),
      ],
    );
  }
}

/// Deslizador que solo envía el valor al soltarlo.
class _SliderAlSoltar extends StatefulWidget {
  final String Function(int valor) titulo;
  final int valor;
  final int min;
  final int max;
  final int divisiones;
  final bool habilitado;
  final void Function(int valor) alSoltar;

  const _SliderAlSoltar({
    required this.titulo,
    required this.valor,
    required this.min,
    required this.max,
    required this.divisiones,
    required this.habilitado,
    required this.alSoltar,
  });

  @override
  State<_SliderAlSoltar> createState() => _SliderAlSoltarState();
}

class _SliderAlSoltarState extends State<_SliderAlSoltar> {
  late double _valor = widget.valor.toDouble();
  bool _arrastrando = false;

  @override
  void didUpdateWidget(covariant _SliderAlSoltar anterior) {
    super.didUpdateWidget(anterior);
    if (!_arrastrando) _valor = widget.valor.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.titulo(_valor.round()),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        Slider(
          value: _valor.clamp(widget.min.toDouble(), widget.max.toDouble()),
          min: widget.min.toDouble(),
          max: widget.max.toDouble(),
          divisions: widget.divisiones,
          label: '${_valor.round()}',
          activeColor: _verde,
          onChangeStart: (_) => _arrastrando = true,
          onChanged: widget.habilitado
              ? (double v) => setState(() => _valor = v)
              : null,
          onChangeEnd: (v) {
            _arrastrando = false;
            widget.alSoltar(v.round());
          },
        ),
      ],
    );
  }
}
