// U Farm - Control de riego (aspersores)
//
// La app escribe en Firebase la configuración de cada zona y las órdenes
// ("Regar ahora" / "Detener"). El controlador de riego (ESP32) las lee
// cada 10 segundos, abre o cierra las válvulas y publica su estado.
//
// Ruta en Firebase:  /riego/zonas/<zona>/{config, comando, estado}
// Requisito: el paquete http (ya instalado).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'ganado.dart' show urlFirebase;

const _verde = Color(0xFF16A34A);
const _verdeOscuro = Color(0xFF0E3B34);
const _azul = Color(0xFF0284C7);

// ---------------------------------------------------------------------------
// MODELOS
// ---------------------------------------------------------------------------

class ConfigZona {
  String nombre;
  String modo; // 'manual', 'horario' o 'auto'
  List<String> horarios; // 'HH:MM'
  int duracionMin;
  int umbralHumedad;
  bool saltarSiLlueve;
  double caudalLpm;

  ConfigZona({
    required this.nombre,
    required this.modo,
    required this.horarios,
    required this.duracionMin,
    required this.umbralHumedad,
    required this.saltarSiLlueve,
    required this.caudalLpm,
  });

  factory ConfigZona.desdeJson(String id, Map<String, dynamic>? j) {
    j ??= {};
    final horarios = j['horarios'];
    return ConfigZona(
      nombre: (j['nombre'] as String?) ?? id,
      modo: (j['modo'] as String?) ?? 'horario',
      horarios: horarios is List
          ? horarios.whereType<String>().toList()
          : <String>[],
      duracionMin: (j['duracionMin'] as num?)?.round() ?? 10,
      umbralHumedad: (j['umbralHumedad'] as num?)?.round() ?? 35,
      saltarSiLlueve: (j['saltarSiLlueve'] as bool?) ?? true,
      caudalLpm: (j['caudalLpm'] as num?)?.toDouble() ?? 8,
    );
  }

  Map<String, dynamic> aJson() => {
        'nombre': nombre,
        'modo': modo,
        'horarios': horarios,
        'duracionMin': duracionMin,
        'umbralHumedad': umbralHumedad,
        'saltarSiLlueve': saltarSiLlueve,
        'caudalLpm': caudalLpm,
      };
}

class EstadoZona {
  final bool regando;
  final bool enEspera;
  final int? humedad;
  final int restanteSeg;
  final String motivo;
  final int? lluviaHoy;
  final DateTime? ultimoRiego;
  final double? ultimoMin;
  final int? ultimoLitros;
  final DateTime? actualizado;

  const EstadoZona({
    this.regando = false,
    this.enEspera = false,
    this.humedad,
    this.restanteSeg = 0,
    this.motivo = '',
    this.lluviaHoy,
    this.ultimoRiego,
    this.ultimoMin,
    this.ultimoLitros,
    this.actualizado,
  });

  factory EstadoZona.desdeJson(Map<String, dynamic>? j) {
    if (j == null) return const EstadoZona();
    DateTime? fecha(dynamic v) =>
        v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;
    return EstadoZona(
      regando: j['regando'] == true,
      enEspera: j['enEspera'] == true,
      humedad: (j['humedad'] as num?)?.round(),
      restanteSeg: (j['restanteSeg'] as num?)?.round() ?? 0,
      motivo: (j['motivo'] as String?) ?? '',
      lluviaHoy: (j['lluviaHoy'] as num?)?.round(),
      ultimoRiego: fecha(j['ultimoRiego']),
      ultimoMin: (j['ultimoMin'] as num?)?.toDouble(),
      ultimoLitros: (j['ultimoLitros'] as num?)?.round(),
      actualizado: fecha(j['actualizado']),
    );
  }

  /// El controlador publica cada minuto; si pasan más de 3, algo falla.
  bool get controladorDesconectado =>
      actualizado == null ||
      DateTime.now().difference(actualizado!) > const Duration(minutes: 3);
}

class ZonaRiego {
  final String id;
  final ConfigZona config;
  final EstadoZona estado;
  final bool ordenPendiente;
  ZonaRiego(this.id, this.config, this.estado, this.ordenPendiente);
}

// ---------------------------------------------------------------------------
// SERVICIO
// ---------------------------------------------------------------------------

class ServicioRiego {
  static String _url(String ruta) => '$urlFirebase/riego/zonas$ruta.json';

  static Future<List<ZonaRiego>> obtener() async {
    final r = await http
        .get(Uri.parse(_url('')))
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) {
      throw Exception('Firebase respondió ${r.statusCode}');
    }
    final datos = jsonDecode(r.body);
    if (datos == null) return [];

    final zonas = <ZonaRiego>[];
    (datos as Map<String, dynamic>).forEach((id, valor) {
      final nodo = valor as Map<String, dynamic>;
      zonas.add(ZonaRiego(
        id,
        ConfigZona.desdeJson(id, nodo['config'] as Map<String, dynamic>?),
        EstadoZona.desdeJson(nodo['estado'] as Map<String, dynamic>?),
        nodo['comando'] != null,
      ));
    });
    zonas.sort((a, b) => a.id.compareTo(b.id));
    return zonas;
  }

  static Future<void> guardarConfig(String id, ConfigZona config) =>
      _enviar(_url('/$id/config'), config.aJson());

  static Future<void> regar(String id, int minutos) =>
      _enviar(_url('/$id/comando'), {'accion': 'regar', 'minutos': minutos});

  static Future<void> detener(String id) =>
      _enviar(_url('/$id/comando'), {'accion': 'detener'});

  static Future<void> _enviar(String url, Map<String, dynamic> datos) async {
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
// PANTALLA DE RIEGO
// ---------------------------------------------------------------------------

class PantallaRiego extends StatefulWidget {
  const PantallaRiego({super.key});

  @override
  State<PantallaRiego> createState() => _PantallaRiegoState();
}

class _PantallaRiegoState extends State<PantallaRiego> {
  List<ZonaRiego>? _zonas;
  String? _error;
  Timer? _temporizador;

  @override
  void initState() {
    super.initState();
    _cargar();
    _temporizador =
        Timer.periodic(const Duration(seconds: 5), (_) => _cargar());
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final zonas = await ServicioRiego.obtener();
      if (!mounted) return;
      setState(() {
        _zonas = zonas;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo conectar con el sistema de riego.');
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

  Future<void> _guardar(ZonaRiego zona) => _ejecutar(
        () => ServicioRiego.guardarConfig(zona.id, zona.config),
        'Cambios guardados',
      );

  @override
  Widget build(BuildContext context) {
    final zonas = _zonas;
    final litrosHoy = zonas == null ? 0 : _litrosDeHoy(zonas);

    return Scaffold(
      backgroundColor: const Color(0xFFF1EFE8),
      appBar: AppBar(
        backgroundColor: _verdeOscuro,
        foregroundColor: Colors.white,
        title: const Text('Riego'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _cargar,
          ),
        ],
      ),
      body: zonas == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Text(_error!, textAlign: TextAlign.center),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  _aviso(Icons.cloud_off, _error!, Colors.red.shade700),
                if (zonas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Todavía no hay zonas. Enciende el controlador de riego: '
                      'él mismo las registra al conectarse.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (zonas.isNotEmpty) ...[
                  _resumenLluvia(zonas),
                  if (litrosHoy > 0)
                    _aviso(Icons.water, 'Agua usada en los últimos riegos de hoy: '
                        '$litrosHoy L aprox.', _azul),
                ],
                for (final z in zonas)
                  _TarjetaZona(
                    zona: z,
                    alCambiar: () => _guardar(z),
                    alRegar: (min) => _ejecutar(
                      () => ServicioRiego.regar(z.id, min),
                      'Orden enviada: regar $min min. '
                      'El controlador la aplicará en unos segundos.',
                    ),
                    alDetener: () => _ejecutar(
                      () => ServicioRiego.detener(z.id),
                      'Orden enviada: detener.',
                    ),
                  ),
              ],
            ),
    );
  }

  int _litrosDeHoy(List<ZonaRiego> zonas) {
    final hoy = DateTime.now();
    var total = 0;
    for (final z in zonas) {
      final f = z.estado.ultimoRiego;
      if (f != null &&
          f.year == hoy.year &&
          f.month == hoy.month &&
          f.day == hoy.day) {
        total += z.estado.ultimoLitros ?? 0;
      }
    }
    return total;
  }

  Widget _resumenLluvia(List<ZonaRiego> zonas) {
    final prob = zonas
        .map((z) => z.estado.lluviaHoy)
        .whereType<int>()
        .fold<int?>(null, (a, b) => a == null || b > a ? b : a);
    if (prob == null) return const SizedBox.shrink();
    final saltara = prob >= 60;
    return _aviso(
      saltara ? Icons.umbrella : Icons.wb_sunny_outlined,
      saltara
          ? 'Probabilidad de lluvia hoy: $prob %. Las zonas con "No regar si '
              'se espera lluvia" se saltarán su riego programado.'
          : 'Probabilidad de lluvia hoy: $prob %. Los riegos programados '
              'se harán normalmente.',
      saltara ? _azul : _verde,
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
// TARJETA DE UNA ZONA
// ---------------------------------------------------------------------------

class _TarjetaZona extends StatelessWidget {
  final ZonaRiego zona;
  final VoidCallback alCambiar;
  final void Function(int minutos) alRegar;
  final VoidCallback alDetener;

  const _TarjetaZona({
    required this.zona,
    required this.alCambiar,
    required this.alRegar,
    required this.alDetener,
  });

  ConfigZona get c => zona.config;
  EstadoZona get e => zona.estado;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: e.regando
            ? const BorderSide(color: _azul, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _encabezado(context),
            const SizedBox(height: 4),
            _lineaEstado(),
            const SizedBox(height: 14),
            _humedad(),
            const SizedBox(height: 14),
            _botones(context),
            const Divider(height: 32),
            _selectorModo(),
            const SizedBox(height: 12),
            ..._opcionesDelModo(context),
          ],
        ),
      ),
    );
  }

  Widget _encabezado(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.water_drop,
            color: e.regando ? _azul : Colors.black26, size: 28),
        const SizedBox(width: 8),
        Expanded(
          child: Text(c.nombre,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Cambiar nombre',
          onPressed: () => _cambiarNombre(context),
        ),
      ],
    );
  }

  Widget _lineaEstado() {
    String texto;
    Color color = Colors.black54;

    if (e.controladorDesconectado) {
      texto = 'Controlador sin conexión';
      color = Colors.red.shade700;
    } else if (e.regando) {
      final m = e.restanteSeg ~/ 60;
      final s = (e.restanteSeg % 60).toString().padLeft(2, '0');
      texto = 'Regando · quedan $m:$s · ${e.motivo}';
      color = _azul;
    } else if (e.enEspera || zona.ordenPendiente) {
      texto = 'Orden en camino o esperando turno…';
      color = Colors.orange.shade800;
    } else if (e.ultimoRiego != null) {
      texto = 'Apagada · último riego ${_haceCuanto(e.ultimoRiego!)}';
      if (e.ultimoMin != null) texto += ' (${e.ultimoMin} min';
      if (e.ultimoLitros != null) texto += ', ${e.ultimoLitros} L';
      if (e.ultimoMin != null) texto += ')';
      if (e.motivo.startsWith('omitido')) texto += '\nÚltimo programado: ${e.motivo}';
    } else {
      texto = 'Apagada';
    }
    return Text(texto, style: TextStyle(color: color));
  }

  Widget _humedad() {
    final h = e.humedad;
    if (h == null) {
      return const Text('Sin sensor de humedad en esta zona',
          style: TextStyle(color: Colors.black45));
    }
    final seco = h < c.umbralHumedad;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Humedad del suelo'),
            const Spacer(),
            Text('$h %',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: seco ? Colors.orange.shade800 : _verde)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: h / 100,
            minHeight: 10,
            backgroundColor: Colors.black12,
            valueColor: AlwaysStoppedAnimation(
                seco ? Colors.orange.shade700 : _azul),
          ),
        ),
        if (c.modo == 'auto')
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Riega automáticamente por debajo de ${c.umbralHumedad} %',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ),
      ],
    );
  }

  Widget _botones(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _azul),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Regar ahora'),
            onPressed: e.regando ? null : () => _elegirMinutos(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.stop),
            label: const Text('Detener'),
            onPressed: (e.regando || e.enEspera) ? alDetener : null,
          ),
        ),
      ],
    );
  }

  Widget _selectorModo() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(
              value: 'manual', icon: Icon(Icons.touch_app), label: Text('Manual')),
          ButtonSegment(
              value: 'horario', icon: Icon(Icons.schedule), label: Text('Horario')),
          ButtonSegment(
              value: 'auto', icon: Icon(Icons.sensors), label: Text('Auto')),
        ],
        selected: {c.modo},
        onSelectionChanged: (s) {
          c.modo = s.first;
          alCambiar();
        },
      ),
    );
  }

  List<Widget> _opcionesDelModo(BuildContext context) {
    switch (c.modo) {
      case 'manual':
        return const [
          Text('Solo riega cuando presionas "Regar ahora".',
              style: TextStyle(color: Colors.black54)),
        ];

      case 'horario':
        return [
          const Text('Horarios', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final h in c.horarios)
                InputChip(
                  avatar: const Icon(Icons.schedule, size: 18),
                  label: Text(h),
                  onDeleted: () {
                    c.horarios.remove(h);
                    alCambiar();
                  },
                ),
              if (c.horarios.length < 6)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar'),
                  onPressed: () => _agregarHorario(context),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Lo mejor es regar temprano o al atardecer: con el sol fuerte '
            'se evapora mucha agua.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          _deslizadorDuracion(),
          _interruptorLluvia(),
        ];

      default: // auto
        return [
          _SliderGuardable(
            titulo: (v) => 'Regar cuando la humedad baje de $v %',
            valor: c.umbralHumedad,
            min: 10,
            max: 80,
            alSoltar: (v) {
              c.umbralHumedad = v;
              alCambiar();
            },
          ),
          if (e.humedad == null)
            Text('Esta zona no tiene sensor de humedad; el modo automático no funcionará.',
                style: TextStyle(color: Colors.red.shade700)),
          _deslizadorDuracion(),
          _interruptorLluvia(),
        ];
    }
  }

  Widget _deslizadorDuracion() {
    return _SliderGuardable(
      titulo: (v) => 'Duración de cada riego: $v min',
      valor: c.duracionMin,
      min: 1,
      max: 60,
      alSoltar: (v) {
        c.duracionMin = v;
        alCambiar();
      },
    );
  }

  Widget _interruptorLluvia() {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('No regar si se espera lluvia'),
      subtitle: const Text('Usa el pronóstico del día'),
      value: c.saltarSiLlueve,
      activeTrackColor: _verde,
      onChanged: (v) {
        c.saltarSiLlueve = v;
        alCambiar();
      },
    );
  }

  // ----- Diálogos -----

  Future<void> _elegirMinutos(BuildContext context) async {
    final minutos = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('¿Cuánto tiempo regar?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            for (final m in [5, 10, 15, 30])
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text('$m minutos'),
                subtitle: Text('≈ ${(m * c.caudalLpm).round()} litros'),
                onTap: () => Navigator.pop(ctx, m),
              ),
          ],
        ),
      ),
    );
    if (minutos != null) alRegar(minutos);
  }

  Future<void> _agregarHorario(BuildContext context) async {
    final hora = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 6, minute: 0),
      helpText: 'Hora de riego',
    );
    if (hora == null) return;
    final texto =
        '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';
    if (c.horarios.contains(texto)) return;
    c.horarios
      ..add(texto)
      ..sort();
    alCambiar();
  }

  Future<void> _cambiarNombre(BuildContext context) async {
    final control = TextEditingController(text: c.nombre);
    final nuevo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nombre de la zona'),
        content: TextField(
          controller: control,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ej. Lechugas, Alfalfa'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, control.text.trim()),
              child: const Text('Guardar')),
        ],
      ),
    );
    if (nuevo != null && nuevo.isNotEmpty) {
      c.nombre = nuevo;
      alCambiar();
    }
  }

  String _haceCuanto(DateTime fecha) {
    final d = DateTime.now().difference(fecha);
    if (d.inMinutes < 1) return 'hace un momento';
    if (d.inHours < 1) return 'hace ${d.inMinutes} min';
    if (d.inDays < 1) return 'hace ${d.inHours} h';
    return 'hace ${d.inDays} d';
  }
}

/// Deslizador que se mueve libremente y solo guarda al soltarlo,
/// para no mandar una orden a Firebase por cada pixel.
class _SliderGuardable extends StatefulWidget {
  final String Function(int valor) titulo;
  final int valor;
  final int min;
  final int max;
  final void Function(int valor) alSoltar;

  const _SliderGuardable({
    required this.titulo,
    required this.valor,
    required this.min,
    required this.max,
    required this.alSoltar,
  });

  @override
  State<_SliderGuardable> createState() => _SliderGuardableState();
}

class _SliderGuardableState extends State<_SliderGuardable> {
  late double _valor = widget.valor.toDouble();
  bool _arrastrando = false;

  @override
  void didUpdateWidget(covariant _SliderGuardable anterior) {
    super.didUpdateWidget(anterior);
    // Si llegó un valor nuevo de Firebase y no lo están moviendo, actualizar
    if (!_arrastrando) _valor = widget.valor.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(widget.titulo(_valor.round()),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        Slider(
          value: _valor,
          min: widget.min.toDouble(),
          max: widget.max.toDouble(),
          divisions: widget.max - widget.min,
          label: '${_valor.round()}',
          onChangeStart: (_) => _arrastrando = true,
          onChanged: (v) => setState(() => _valor = v),
          onChangeEnd: (v) {
            _arrastrando = false;
            widget.alSoltar(v.round());
          },
        ),
      ],
    );
  }
}
