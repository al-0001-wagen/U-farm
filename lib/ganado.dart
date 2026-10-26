// U Farm - Monitoreo del ganado en la aplicación
//
// Lee de Firebase los datos que sube el receptor de la granja
// y muestra temperatura, pulso, batería y alertas de cada animal.
//
// Requisito: el paquete http (ya instalado para el clima).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// CONFIGURACIÓN
// ---------------------------------------------------------------------------

/// La misma URL que pusieron en el receptor (sin "/" al final).
const String urlFirebase = 'https://TU-PROYECTO-default-rtdb.firebaseio.com';

/// Rangos normales de un conejo adulto. Confírmenlos con un veterinario
/// y ajústenlos si usan otro animal (por ejemplo, gallinas).
class RangosNormales {
  static const double temperaturaMin = 38.0; // °C
  static const double temperaturaMax = 40.0; // °C
  static const int pulsoMin = 130; // latidos por minuto
  static const int pulsoMax = 325;
  static const int bateriaBaja = 20; // %

  /// Si un collar no envía datos en este tiempo, se marca "sin señal".
  static const Duration tiempoSinSenal = Duration(minutes: 5);
}

// ---------------------------------------------------------------------------
// MODELO
// ---------------------------------------------------------------------------

enum EstadoAnimal { normal, alerta, sinSenal }

class LecturaAnimal {
  final String id;
  final double? temperatura;
  final int? pulso;
  final int? bateria;
  final int? rssi; // intensidad de la señal LoRa en dBm
  final DateTime? actualizado;

  const LecturaAnimal({
    required this.id,
    this.temperatura,
    this.pulso,
    this.bateria,
    this.rssi,
    this.actualizado,
  });

  factory LecturaAnimal.desdeJson(String id, Map<String, dynamic> j) {
    return LecturaAnimal(
      id: id,
      temperatura: (j['temperatura'] as num?)?.toDouble(),
      pulso: (j['pulso'] as num?)?.round(),
      bateria: (j['bateria'] as num?)?.round(),
      rssi: (j['rssi'] as num?)?.round(),
      actualizado: j['actualizado'] is num
          ? DateTime.fromMillisecondsSinceEpoch(
              (j['actualizado'] as num).toInt())
          : null,
    );
  }

  /// Lista de problemas detectados. Vacía si todo está bien.
  List<String> get alertas {
    final lista = <String>[];
    if (estaSinSenal) {
      lista.add('Sin señal del collar');
      return lista;
    }
    final t = temperatura;
    if (t == null) {
      lista.add('Sensor de temperatura sin lectura');
    } else if (t > RangosNormales.temperaturaMax) {
      lista.add('Temperatura alta: posible golpe de calor o fiebre');
    } else if (t < RangosNormales.temperaturaMin) {
      lista.add('Temperatura baja');
    }
    final p = pulso;
    if (p == null) {
      lista.add('Sin lectura de pulso (¿collar flojo?)');
    } else if (p > RangosNormales.pulsoMax) {
      lista.add('Pulso muy acelerado: posible estrés');
    } else if (p < RangosNormales.pulsoMin) {
      lista.add('Pulso bajo');
    }
    if ((bateria ?? 100) <= RangosNormales.bateriaBaja) {
      lista.add('Batería baja del collar');
    }
    return lista;
  }

  bool get estaSinSenal =>
      actualizado == null ||
      DateTime.now().difference(actualizado!) > RangosNormales.tiempoSinSenal;

  EstadoAnimal get estado {
    if (estaSinSenal) return EstadoAnimal.sinSenal;
    return alertas.isEmpty ? EstadoAnimal.normal : EstadoAnimal.alerta;
  }
}

// ---------------------------------------------------------------------------
// SERVICIO
// ---------------------------------------------------------------------------

class ServicioGanado {
  static Future<List<LecturaAnimal>> obtener() async {
    final respuesta = await http
        .get(Uri.parse('$urlFirebase/ganado.json'))
        .timeout(const Duration(seconds: 10));

    if (respuesta.statusCode != 200) {
      throw Exception('Firebase respondió ${respuesta.statusCode}');
    }

    final datos = jsonDecode(respuesta.body);
    if (datos == null) return []; // todavía no hay collares registrados

    final animales = (datos as Map<String, dynamic>)
        .entries
        .map((e) =>
            LecturaAnimal.desdeJson(e.key, e.value as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return animales;
  }
}

// ---------------------------------------------------------------------------
// TARJETA DEL GANADO (lo que se ve en la app)
// Se actualiza cada 30 segundos.
// ---------------------------------------------------------------------------

class TarjetaGanado extends StatefulWidget {
  const TarjetaGanado({super.key});

  @override
  State<TarjetaGanado> createState() => _TarjetaGanadoState();
}

class _TarjetaGanadoState extends State<TarjetaGanado> {
  late Future<List<LecturaAnimal>> _futuro;
  Timer? _temporizador;

  @override
  void initState() {
    super.initState();
    _futuro = ServicioGanado.obtener();
    _temporizador =
        Timer.periodic(const Duration(seconds: 30), (_) => _recargar());
  }

  void _recargar() => setState(() => _futuro = ServicioGanado.obtener());

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pets, color: Color(0xFF16A34A)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Mi ganado',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Actualizar',
                  onPressed: _recargar,
                ),
              ],
            ),
            FutureBuilder<List<LecturaAnimal>>(
              future: _futuro,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                        'No se pudieron leer los collares. Revisa tu conexión.'),
                  );
                }
                final animales = snapshot.data ?? [];
                if (animales.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Todavía no hay collares enviando datos.'),
                  );
                }
                return Column(
                  children: [for (final a in animales) _filaAnimal(a)],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _filaAnimal(LecturaAnimal a) {
    final (Color color, IconData icono, String texto) = switch (a.estado) {
      EstadoAnimal.normal => (Colors.green, Icons.check_circle, 'Sano'),
      EstadoAnimal.alerta => (Colors.orange, Icons.warning_amber, 'Revisar'),
      EstadoAnimal.sinSenal => (Colors.grey, Icons.signal_wifi_off, 'Sin señal'),
    };

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        color: color.withValues(alpha: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(a.id,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Icon(icono, size: 18, color: color),
              const SizedBox(width: 4),
              Text(texto, style: TextStyle(color: color)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _dato(Icons.thermostat,
                  a.temperatura == null ? '—' : '${a.temperatura!.toStringAsFixed(1)} °C'),
              _dato(Icons.favorite_border,
                  a.pulso == null ? '—' : '${a.pulso} lpm'),
              _dato(Icons.battery_std,
                  a.bateria == null ? '—' : '${a.bateria} %'),
              _dato(Icons.access_time, _haceCuanto(a.actualizado)),
            ],
          ),
          for (final alerta in a.alertas)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('• $alerta', style: TextStyle(color: color)),
            ),
        ],
      ),
    );
  }

  Widget _dato(IconData icono, String texto) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 16, color: Colors.black54),
        const SizedBox(width: 4),
        Text(texto),
      ],
    );
  }

  String _haceCuanto(DateTime? fecha) {
    if (fecha == null) return 'nunca';
    final d = DateTime.now().difference(fecha);
    if (d.inMinutes < 1) return 'hace ${d.inSeconds} s';
    if (d.inHours < 1) return 'hace ${d.inMinutes} min';
    if (d.inDays < 1) return 'hace ${d.inHours} h';
    return 'hace ${d.inDays} d';
  }
}
