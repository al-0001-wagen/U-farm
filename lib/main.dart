// U Farm - Aplicación principal
// Equipo 2, Grupo 211
//
// Instrucciones para compilar el APK: ver README.md en la carpeta del proyecto.

import 'package:flutter/material.dart';

import 'ajustes.dart';
import 'clima.dart';
import 'enciclopedia.dart';
import 'ganado.dart';
import 'riego.dart';
import 'vidrios.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Ajustes.i.cargar(); // tema, color, inicio y enciclopedia guardados
  runApp(const UFarmApp());
}

/// Colores de la pantalla de carga. Siguen al color elegido en Ajustes.
class UFarmColores {
  static Color get fondo => cBarra;
  static Color get verde => cPrincipal;
  static Color get verdeClaro => cPrincipalClaro;
  static const crema = Color(0xFFF1EFE8);
}

class UFarmApp extends StatefulWidget {
  const UFarmApp({super.key});

  @override
  State<UFarmApp> createState() => _UFarmAppState();
}

class _UFarmAppState extends State<UFarmApp> {
  @override
  void initState() {
    super.initState();
    Ajustes.i.addListener(_alCambiarAjustes);
  }

  @override
  void dispose() {
    Ajustes.i.removeListener(_alCambiarAjustes);
    super.dispose();
  }

  /// Cuando cambia un ajuste (color, tema, botones, enciclopedia), se
  /// vuelven a dibujar todas las pantallas abiertas para que lo muestren.
  void _alCambiarAjustes() {
    setState(() {});
    void redibujar(Element e) {
      e.markNeedsBuild();
      e.visitChildren(redibujar);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(redibujar);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'U Farm',
      debugShowCheckedModeBanner: false,
      theme: temaDeLaApp(),
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
                          valueColor: AlwaysStoppedAnimation(
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
// PANTALLA DE INICIO
// Las tarjetas, su orden y sus nombres se eligen en Ajustes (el engrane).
// ---------------------------------------------------------------------------

class PantallaInicio extends StatelessWidget {
  const PantallaInicio({super.key});

  void _abrir(BuildContext context, Widget pantalla) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));
  }

  @override
  Widget build(BuildContext context) {
    final visibles = Ajustes.i.tarjetas.where((t) => t.visible).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cBarra,
        foregroundColor: Colors.white,
        title: const Text('U Farm'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ajustes',
            onPressed: () => _abrir(context, const PantallaAjustes()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final t in visibles) ...[
            _tarjeta(context, t),
            const SizedBox(height: 16),
          ],
          if (visibles.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'Todas las tarjetas están ocultas.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Abrir Ajustes'),
                    onPressed: () => _abrir(context, const PantallaAjustes()),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _tarjeta(BuildContext context, TarjetaInicio t) {
    switch (t.id) {
      case 'clima':
        return const TarjetaClima();
      case 'ganado':
        return TarjetaGanado(titulo: t.nombre);
      case 'riego':
        return _acceso(
          context,
          icono: Icons.water_drop,
          color: const Color(0xFF0284C7),
          titulo: t.nombre,
          descripcion: 'Aspersores, horarios y humedad del suelo',
          pantalla: const PantallaRiego(),
        );
      case 'vidrios':
        return _acceso(
          context,
          icono: Icons.roofing,
          color: cContraste,
          titulo: t.nombre,
          descripcion: 'Abrir, cerrar y apertura automática por temperatura',
          pantalla: const PantallaVidrios(),
        );
      default:
        return _acceso(
          context,
          icono: Icons.menu_book,
          color: cPrincipal,
          titulo: t.nombre,
          descripcion: 'Cultivos, ganado, qué sembrar este mes y sinergias',
          pantalla: const PantallaEnciclopedia(),
        );
    }
  }

  Widget _acceso(
    BuildContext context, {
    required IconData icono,
    required Color color,
    required String titulo,
    required String descripcion,
    required Widget pantalla,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icono, color: color, size: 32),
        title:
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(descripcion),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _abrir(context, pantalla),
      ),
    );
  }
}
