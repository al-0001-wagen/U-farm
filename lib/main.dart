// U Farm - Aplicación principal
// Equipo 2, Grupo 211
//
// Instrucciones para compilar el APK: ver README.md en la carpeta del proyecto.

import 'package:flutter/material.dart';

import 'clima.dart';
import 'enciclopedia.dart';
import 'ganado.dart';
import 'riego.dart';
import 'vidrios.dart';

void main() => runApp(const UFarmApp());

/// Colores tomados de la presentación del proyecto.
class UFarmColores {
  static const fondo = Color(0xFF0E3B34); // verde oscuro de las diapositivas
  static const verde = Color(0xFF16A34A); // verde de los recuadros
  static const verdeClaro = Color(0xFF86EFAC);
  static const crema = Color(0xFFF1EFE8);
}

class UFarmApp extends StatelessWidget {
  const UFarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'U Farm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: UFarmColores.verde),
      ),
      home: const PantallaCarga(),
    );
  }
}

// ---------------------------------------------------------------------------
// PANTALLA DE CARGA
// ---------------------------------------------------------------------------

class PantallaCarga extends StatefulWidget {
  const PantallaCarga({super.key});

  @override
  State<PantallaCarga> createState() => _PantallaCargaState();
}

class _PantallaCargaState extends State<PantallaCarga>
    with TickerProviderStateMixin {
  // Mensajes que se muestran mientras avanza la barra.
  // Corresponden a las funciones de la app descritas en el proyecto.
  static const List<String> _mensajes = [
    'Conectando con el clima local…',
    'Revisando sensores del huerto…',
    'Sincronizando el estado del ganado…',
    'Calculando la posición de los vidrios…',
    'Preparando tu granja…',
  ];

  // Duración total de la carga.
  static const Duration _duracionCarga = Duration(seconds: 5);

  late final AnimationController _entrada; // aparición del logo
  late final AnimationController _pulso; // latido suave del logo
  late final AnimationController _progreso; // barra de carga

  late final Animation<double> _opacidadLogo;
  late final Animation<double> _escalaEntrada;
  late final Animation<double> _escalaPulso;
  late final Animation<double> _avance;

  @override
  void initState() {
    super.initState();

    _entrada = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _pulso = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _progreso = AnimationController(vsync: this, duration: _duracionCarga)
      ..addStatusListener((estado) {
        if (estado == AnimationStatus.completed) _irAInicio();
      })
      ..forward();

    _opacidadLogo = CurvedAnimation(parent: _entrada, curve: Curves.easeOut);
    _escalaEntrada = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _entrada, curve: Curves.easeOutBack),
    );
    _escalaPulso = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulso, curve: Curves.easeInOut),
    );
    _avance = CurvedAnimation(parent: _progreso, curve: Curves.easeInOut);
  }

  void _irAInicio() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => const PantallaInicio(),
        transitionsBuilder: (_, animacion, __, hijo) =>
            FadeTransition(opacity: animacion, child: hijo),
      ),
    );
  }

  @override
  void dispose() {
    _entrada.dispose();
    _pulso.dispose();
    _progreso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UFarmColores.fondo,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 3),

              // Logo
              FadeTransition(
                opacity: _opacidadLogo,
                child: ScaleTransition(
                  scale: _escalaEntrada,
                  child: ScaleTransition(
                    scale: _escalaPulso,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: UFarmColores.verde,
                        boxShadow: [
                          BoxShadow(
                            color: UFarmColores.verde.withValues(alpha: 0.45),
                            blurRadius: 36,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.eco,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Nombre y lema
              FadeTransition(
                opacity: _opacidadLogo,
                child: const Column(
                  children: [
                    Text(
                      'U FARM',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tu granja urbana, en tu bolsillo',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: UFarmColores.crema,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // Mensaje de estado + barra de progreso
              AnimatedBuilder(
                animation: _avance,
                builder: (context, _) {
                  final valor = _avance.value;
                  final indice = (valor * _mensajes.length)
                      .floor()
                      .clamp(0, _mensajes.length - 1);

                  return Column(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _mensajes[indice],
                          key: ValueKey(indice),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: UFarmColores.crema,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: valor,
                          minHeight: 8,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.15),
                          valueColor: const AlwaysStoppedAnimation(
                            UFarmColores.verdeClaro,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(valor * 100).round()} %',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PANTALLA DE INICIO (provisional)
// Aquí irá el menú principal: clima, riego, luz, conejeras y vidrios.
// ---------------------------------------------------------------------------

class PantallaInicio extends StatelessWidget {
  const PantallaInicio({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UFarmColores.crema,
      appBar: AppBar(
        backgroundColor: UFarmColores.fondo,
        foregroundColor: Colors.white,
        title: const Text('U Farm'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const TarjetaClima(),
          const SizedBox(height: 16),
          const TarjetaGanado(),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: const Icon(Icons.water_drop,
                  color: Color(0xFF0284C7), size: 32),
              title: const Text('Riego',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text(
                  'Aspersores, horarios y humedad del suelo'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PantallaRiego()),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: const Icon(Icons.roofing,
                  color: UFarmColores.fondo, size: 32),
              title: const Text('Vidrios del techo',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text(
                  'Abrir, cerrar y apertura automática por temperatura'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PantallaVidrios()),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: const Icon(Icons.menu_book,
                  color: UFarmColores.verde, size: 32),
              title: const Text('Enciclopedia de la granja',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text(
                  'Cultivos, ganado, qué sembrar este mes y sinergias'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const PantallaEnciclopedia()),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Aquí irá el control de luz',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
