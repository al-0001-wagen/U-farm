// U Farm - Conexión con el pronóstico del tiempo
//
// Usa la API gratuita de Open-Meteo (https://open-meteo.com).
// No necesita registro ni clave.
//
// Requisito: agrega el paquete http al proyecto con
//     flutter pub add http

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// UBICACIÓN DE LA GRANJA
// Cambien estos valores por las coordenadas reales del prototipo.
// (En Google Maps: clic derecho sobre el lugar y copiar las coordenadas.)
// ---------------------------------------------------------------------------

class UbicacionGranja {
  static const String nombre = 'Monterrey, N.L.';
  static const double latitud = 25.6866;
  static const double longitud = -100.3161;
}

// ---------------------------------------------------------------------------
// MODELOS DE DATOS
// ---------------------------------------------------------------------------

class ClimaActual {
  final double temperatura; // °C
  final int humedad; // %
  final double precipitacion; // mm
  final double viento; // km/h
  final int codigo; // código del clima (WMO)
  final bool esDeDia;

  const ClimaActual({
    required this.temperatura,
    required this.humedad,
    required this.precipitacion,
    required this.viento,
    required this.codigo,
    required this.esDeDia,
  });
}

class PronosticoDia {
  final DateTime fecha;
  final int codigo;
  final double maxima; // °C
  final double minima; // °C
  final int probabilidadLluvia; // %
  final double indiceUV;

  const PronosticoDia({
    required this.fecha,
    required this.codigo,
    required this.maxima,
    required this.minima,
    required this.probabilidadLluvia,
    required this.indiceUV,
  });
}

class DatosClima {
  final ClimaActual actual;
  final List<PronosticoDia> dias;
  final DateTime consultado;

  const DatosClima({
    required this.actual,
    required this.dias,
    required this.consultado,
  });

  PronosticoDia get hoy => dias.first;
}

// ---------------------------------------------------------------------------
// SERVICIO: pide el pronóstico a internet
// ---------------------------------------------------------------------------

class ServicioClima {
  static Future<DatosClima> obtener({
    double latitud = UbicacionGranja.latitud,
    double longitud = UbicacionGranja.longitud,
  }) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '$latitud',
      'longitude': '$longitud',
      'current': 'temperature_2m,relative_humidity_2m,precipitation,'
          'weather_code,wind_speed_10m,is_day',
      'daily': 'weather_code,temperature_2m_max,temperature_2m_min,'
          'precipitation_probability_max,uv_index_max',
      'timezone': 'auto', // usa la zona horaria de la granja
      'forecast_days': '7',
    });

    final respuesta =
        await http.get(uri).timeout(const Duration(seconds: 10));

    if (respuesta.statusCode != 200) {
      throw Exception(
          'El servicio del clima respondió con el código ${respuesta.statusCode}');
    }

    final json = jsonDecode(respuesta.body) as Map<String, dynamic>;

    final c = json['current'] as Map<String, dynamic>;
    final actual = ClimaActual(
      temperatura: _decimal(c['temperature_2m']),
      humedad: _decimal(c['relative_humidity_2m']).round(),
      precipitacion: _decimal(c['precipitation']),
      viento: _decimal(c['wind_speed_10m']),
      codigo: _decimal(c['weather_code']).toInt(),
      esDeDia: c['is_day'] == 1,
    );

    final d = json['daily'] as Map<String, dynamic>;
    final fechas = (d['time'] as List).cast<String>();
    final dias = <PronosticoDia>[
      for (var i = 0; i < fechas.length; i++)
        PronosticoDia(
          fecha: DateTime.parse(fechas[i]),
          codigo: _decimal(d['weather_code'][i]).toInt(),
          maxima: _decimal(d['temperature_2m_max'][i]),
          minima: _decimal(d['temperature_2m_min'][i]),
          probabilidadLluvia:
              _decimal(d['precipitation_probability_max'][i]).round(),
          indiceUV: _decimal(d['uv_index_max'][i]),
        ),
    ];

    return DatosClima(actual: actual, dias: dias, consultado: DateTime.now());
  }

  // Algunos valores pueden venir vacíos (null); en ese caso se usa 0.
  static double _decimal(dynamic valor) =>
      valor == null ? 0 : (valor as num).toDouble();
}

// ---------------------------------------------------------------------------
// RECOMENDACIONES PARA LA GRANJA
// Aquí se conecta el clima con las funciones de U Farm:
// riego, vidrios del techo y cuidado de los conejos.
// ---------------------------------------------------------------------------

List<String> recomendacionesGranja(DatosClima clima) {
  final hoy = clima.hoy;
  final actual = clima.actual;
  final recomendaciones = <String>[];

  // Riego
  if (actual.precipitacion > 0 || hoy.probabilidadLluvia >= 60) {
    recomendaciones.add(
        'Probabilidad de lluvia de ${hoy.probabilidadLluvia} %: puedes saltarte el riego de hoy.');
  }

  // Vidrios del techo y conejos
  if (actual.viento >= 40) {
    recomendaciones.add(
        'Viento fuerte (${actual.viento.round()} km/h): mantén cerrados los vidrios del techo.');
  } else if (hoy.maxima >= 30) {
    recomendaciones.add(
        'Hará calor (${hoy.maxima.round()} °C): abre los vidrios para ventilar. '
        'Los conejos sufren con más de 30 °C; revisa su agua y su sombra.');
  }

  if (hoy.minima <= 5) {
    recomendaciones.add(
        'Noche fría (${hoy.minima.round()} °C): cierra los vidrios para conservar el calor.');
  }

  if (hoy.indiceUV >= 8) {
    recomendaciones.add(
        'Índice UV muy alto (${hoy.indiceUV.round()}): cierra parcialmente los vidrios al mediodía.');
  }

  if (recomendaciones.isEmpty) {
    recomendaciones
        .add('Clima estable: sigue el horario de riego programado.');
  }

  return recomendaciones;
}

// ---------------------------------------------------------------------------
// TRADUCCIÓN DE LOS CÓDIGOS DEL CLIMA (estándar WMO)
// ---------------------------------------------------------------------------

String descripcionClima(int codigo) {
  if (codigo == 0) return 'Despejado';
  if (codigo <= 2) return 'Parcialmente nublado';
  if (codigo == 3) return 'Nublado';
  if (codigo == 45 || codigo == 48) return 'Niebla';
  if (codigo >= 51 && codigo <= 57) return 'Llovizna';
  if (codigo >= 61 && codigo <= 67) return 'Lluvia';
  if (codigo >= 71 && codigo <= 77) return 'Nieve';
  if (codigo >= 80 && codigo <= 82) return 'Chubascos';
  if (codigo >= 85 && codigo <= 86) return 'Chubascos de nieve';
  if (codigo >= 95) return 'Tormenta';
  return 'Sin datos';
}

IconData iconoClima(int codigo, {bool esDeDia = true}) {
  if (codigo == 0) return esDeDia ? Icons.wb_sunny : Icons.nightlight_round;
  if (codigo <= 2) return Icons.cloud_queue;
  if (codigo == 3) return Icons.cloud;
  if (codigo == 45 || codigo == 48) return Icons.blur_on;
  if (codigo >= 51 && codigo <= 67) return Icons.water_drop;
  if (codigo >= 71 && codigo <= 77) return Icons.ac_unit;
  if (codigo >= 80 && codigo <= 86) return Icons.umbrella;
  if (codigo >= 95) return Icons.thunderstorm;
  return Icons.help_outline;
}

const List<String> _diasSemana = [
  'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'
];

// ---------------------------------------------------------------------------
// TARJETA DEL CLIMA (lo que se ve en la app)
// Se actualiza sola cada 30 minutos y con el botón de recargar.
// ---------------------------------------------------------------------------

class TarjetaClima extends StatefulWidget {
  const TarjetaClima({super.key});

  @override
  State<TarjetaClima> createState() => _TarjetaClimaState();
}

class _TarjetaClimaState extends State<TarjetaClima> {
  static const Color _verdeOscuro = Color(0xFF0E3B34);
  static const Color _verde = Color(0xFF16A34A);

  late Future<DatosClima> _futuro;
  Timer? _temporizador;

  @override
  void initState() {
    super.initState();
    _futuro = ServicioClima.obtener();
    _temporizador =
        Timer.periodic(const Duration(minutes: 30), (_) => _recargar());
  }

  void _recargar() {
    setState(() => _futuro = ServicioClima.obtener());
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<DatosClima>(
          future: _futuro,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return _error();
            }
            return _contenido(snapshot.data!);
          },
        ),
      ),
    );
  }

  Widget _error() {
    return SizedBox(
      height: 160,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 40, color: Colors.grey),
          const SizedBox(height: 8),
          const Text(
            'No se pudo obtener el clima.\nRevisa tu conexión a internet.',
            textAlign: TextAlign.center,
          ),
          TextButton(onPressed: _recargar, child: const Text('Reintentar')),
        ],
      ),
    );
  }

  Widget _contenido(DatosClima clima) {
    final a = clima.actual;
    final hora =
        '${clima.consultado.hour.toString().padLeft(2, '0')}:${clima.consultado.minute.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado
        Row(
          children: [
            const Icon(Icons.place, size: 18, color: _verde),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                UbicacionGranja.nombre,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text('Actualizado $hora',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar',
              onPressed: _recargar,
            ),
          ],
        ),

        // Clima actual
        Row(
          children: [
            Icon(iconoClima(a.codigo, esDeDia: a.esDeDia),
                size: 56, color: _verdeOscuro),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${a.temperatura.round()} °C',
                    style: const TextStyle(
                        fontSize: 36, fontWeight: FontWeight.w700)),
                Text(descripcionClima(a.codigo)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Datos rápidos
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _dato(Icons.water_drop_outlined, 'Humedad ${a.humedad} %'),
            _dato(Icons.air, 'Viento ${a.viento.round()} km/h'),
            _dato(Icons.umbrella_outlined,
                'Lluvia ${clima.hoy.probabilidadLluvia} %'),
            _dato(Icons.wb_sunny_outlined,
                'UV ${clima.hoy.indiceUV.round()}'),
          ],
        ),

        const Divider(height: 28),

        // Recomendaciones
        const Text('Recomendaciones para tu granja',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final r in recomendacionesGranja(clima))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.eco, size: 18, color: _verde),
                const SizedBox(width: 8),
                Expanded(child: Text(r)),
              ],
            ),
          ),

        const Divider(height: 28),

        // Pronóstico de 7 días
        const Text('Próximos 7 días',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: clima.dias.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => _dia(clima.dias[i], esHoy: i == 0),
          ),
        ),
      ],
    );
  }

  Widget _dato(IconData icono, String texto) {
    return Chip(
      avatar: Icon(icono, size: 16),
      label: Text(texto, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _dia(PronosticoDia dia, {required bool esHoy}) {
    return Container(
      width: 70,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: esHoy ? _verde.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(esHoy ? 'Hoy' : _diasSemana[dia.fecha.weekday - 1],
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Icon(iconoClima(dia.codigo), color: _verdeOscuro),
          Text('${dia.maxima.round()}° / ${dia.minima.round()}°',
              style: const TextStyle(fontSize: 12)),
          Text('${dia.probabilidadLluvia} %',
              style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
        ],
      ),
    );
  }
}
