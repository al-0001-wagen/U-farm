// U Farm - Pantallas de la enciclopedia
//
// - Lista con buscador y filtros (Todo / Cultivos / Ganado)
// - "Para sembrar este mes" según la fecha del teléfono
// - Ficha de cada cultivo o animal, con su calendario y sus sinergias
// - Agregar, editar y borrar fichas y sinergias (se guardan en el teléfono)

import 'package:flutter/material.dart';

import 'ajustes.dart';
import 'enciclopedia_datos.dart';
import 'tecnicas_datos.dart';

Color get _verde => cPrincipal;
Color get _verdeOscuro => cBarra;

const _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// Quita acentos y mayúsculas para que "maiz" encuentre "Maíz".
String _normalizar(String texto) {
  const conAcento = 'áéíóúü';
  const sinAcento = 'aeiouu';
  var resultado = texto.toLowerCase();
  for (var i = 0; i < conAcento.length; i++) {
    resultado = resultado.replaceAll(conAcento[i], sinAcento[i]);
  }
  return resultado;
}

void _abrirFicha(BuildContext context, Entrada entrada) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => PantallaFicha(entrada: entrada)),
  );
}

void _abrirTecnica(BuildContext context, Tecnica tecnica) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => PantallaTecnica(tecnica: tecnica)),
  );
}

// ---------------------------------------------------------------------------
// LISTA PRINCIPAL
// ---------------------------------------------------------------------------

class PantallaEnciclopedia extends StatefulWidget {
  const PantallaEnciclopedia({super.key});

  @override
  State<PantallaEnciclopedia> createState() => _PantallaEnciclopediaState();
}

class _PantallaEnciclopediaState extends State<PantallaEnciclopedia> {
  String _busqueda = '';
  TipoEntrada? _filtro; // null = todo

  bool _coincide(Entrada e) {
    if (_filtro != null && e.tipo != _filtro) return false;
    if (_busqueda.isEmpty) return true;
    final q = _normalizar(_busqueda);
    return _normalizar(e.nombre).contains(q) ||
        _normalizar(e.cientifico).contains(q) ||
        _normalizar(e.resumen).contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final mes = DateTime.now().month;
    final resultados = entradas.where(_coincide).toList();
    final paraSembrar =
        entradas.where((e) => e.mesesSiembra.contains(mes)).toList();
    final mostrarTemporada =
        _busqueda.isEmpty && _filtro != TipoEntrada.ganado;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
      backgroundColor: cFondo,
      appBar: AppBar(
        backgroundColor: _verdeOscuro,
        foregroundColor: Colors.white,
        title: Text('Enciclopedia de la granja'),
        bottom: TabBar(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: cPrincipalClaro,
          tabs: [
            Tab(icon: Icon(Icons.eco), text: 'Fichas'),
            Tab(icon: Icon(Icons.handyman), text: 'Técnicas'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
      ListView(
        padding: EdgeInsets.all(16),
        children: [
          TextField(
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar cultivo o animal',
              filled: true,
              fillColor: cSuperficie,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (texto) => setState(() => _busqueda = texto.trim()),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _filtroChip('Todo', null),
              _filtroChip('Cultivos', TipoEntrada.cultivo),
              _filtroChip('Ganado', TipoEntrada.ganado),
              ActionChip(
                avatar: Icon(Icons.add, size: 18),
                label: Text('Agregar ficha'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PantallaEditarFicha()),
                ),
              ),
            ],
          ),

          if (mostrarTemporada && paraSembrar.isNotEmpty) ...[
            SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.calendar_month, color: _verde),
                SizedBox(width: 8),
                Text('Para sembrar en ${_meses[mes - 1]}',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in paraSembrar)
                  ActionChip(
                    avatar: Text(e.emoji),
                    label: Text(e.nombre),
                    backgroundColor: _verde.withValues(alpha: 0.12),
                    onPressed: () => _abrirFicha(context, e),
                  ),
              ],
            ),
          ],

          SizedBox(height: 20),
          if (resultados.isEmpty)
            Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No se encontró nada con ese nombre.')),
            ),
          for (final e in resultados)
            Card(
              margin: EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Text(e.emoji, style: TextStyle(fontSize: 32)),
                title: Text(e.nombre,
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(e.resumen),
                trailing: Icon(Icons.chevron_right),
                onTap: () => _abrirFicha(context, e),
              ),
            ),
        ],
      ),
          _ListaTecnicas(),
        ],
      ),
      ),
    );
  }

  Widget _filtroChip(String texto, TipoEntrada? tipo) {
    return ChoiceChip(
      label: Text(texto),
      selected: _filtro == tipo,
      selectedColor: _verde.withValues(alpha: 0.25),
      onSelected: (_) => setState(() => _filtro = tipo),
    );
  }
}

// ---------------------------------------------------------------------------
// FICHA DE UN CULTIVO O ANIMAL
// ---------------------------------------------------------------------------

class PantallaFicha extends StatelessWidget {
  final Entrada entrada;
  const PantallaFicha({super.key, required this.entrada});

  @override
  Widget build(BuildContext context) {
    // Se busca la versión más reciente, por si la ficha se acaba de editar.
    final entrada = entradaPorId(this.entrada.id) ?? this.entrada;
    final relaciones = sinergiasDe(entrada.id);
    final siembra = datosSiembra[entrada.id];
    final tecnicasUtiles = tecnicasPara(entrada.id);

    return Scaffold(
      backgroundColor: cFondo,
      appBar: AppBar(
        backgroundColor: _verdeOscuro,
        foregroundColor: Colors.white,
        title: Text(entrada.nombre),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined),
            tooltip: 'Editar ficha',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => PantallaEditarFicha(original: entrada)),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (opcion) {
              if (opcion == 'restaurar') _restaurar(context, entrada);
              if (opcion == 'borrar') _borrar(context, entrada);
            },
            itemBuilder: (_) => [
              if (fichaCambiada(entrada.id))
                PopupMenuItem(
                    value: 'restaurar', child: Text('Restaurar la original')),
              PopupMenuItem(value: 'borrar', child: Text('Borrar ficha')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Encabezado
          Row(
            children: [
              Text(entrada.emoji, style: TextStyle(fontSize: 56)),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entrada.nombre,
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800)),
                    Text(entrada.cientifico,
                        style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: cTenue)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(entrada.resumen, style: TextStyle(fontSize: 16)),

          // Calendario de siembra
          if (entrada.mesesSiembra.isNotEmpty) ...[
            SizedBox(height: 20),
            Text('Meses de siembra',
                style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            _Calendario(meses: entrada.mesesSiembra),
          ],

          // Cómo sembrar
          if (siembra != null) _tarjetaSiembra(siembra),

          // Técnicas relacionadas
          if (tecnicasUtiles.isNotEmpty) ...[
            SizedBox(height: 16),
            Text('Técnicas útiles',
                style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in tecnicasUtiles)
                  ActionChip(
                    avatar: Text(t.emoji),
                    label: Text(t.titulo),
                    onPressed: () => _abrirTecnica(context, t),
                  ),
              ],
            ),
          ],

          // Secciones de cuidados
          SizedBox(height: 12),
          for (final s in entrada.secciones) _tarjetaSeccion(s),

          // Sinergias
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text('Sinergias',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              TextButton.icon(
                icon: Icon(Icons.add),
                label: Text('Agregar'),
                onPressed: () => _agregarSinergia(context, entrada),
              ),
            ],
          ),
          Text(
            relaciones.isEmpty
                ? 'Esta ficha todavía no tiene sinergias.'
                : 'Mantén presionada una sinergia para borrarla.',
            style: TextStyle(fontSize: 12, color: cMuyTenue),
          ),
          for (final tipo in TipoSinergia.values)
            ..._grupoSinergias(context, tipo, relaciones),
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _tarjetaSiembra(DatosSiembra s) {
    Widget fila(IconData icono, String etiqueta, String valor) {
      return Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 18, color: cTenue),
            SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: Text(etiqueta,
                  style: TextStyle(color: cTenue)),
            ),
            Expanded(
              child: Text(valor,
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: EdgeInsets.only(top: 16),
      color: Color.alphaBlend(_verde.withValues(alpha: 0.08), cSuperficie),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.spa, color: _verde),
                SizedBox(width: 8),
                Text('Cómo sembrar',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            SizedBox(height: 12),
            fila(Icons.call_split, 'Método', s.metodo),
            fila(Icons.vertical_align_bottom, 'Profundidad', s.profundidad),
            fila(Icons.straighten, 'Distancia', s.distancia),
            fila(Icons.timer_outlined, 'Germinación', s.germinacion),
            if (s.trasplante != null)
              fila(Icons.move_down, 'Trasplante', s.trasplante!),
            SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline,
                    size: 18, color: Colors.amber),
                SizedBox(width: 8),
                Expanded(child: Text(s.consejo)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaSeccion(Seccion s) {
    return Card(
      margin: EdgeInsets.only(top: 8),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(s.icono, color: _verde),
                SizedBox(width: 8),
                Text(s.titulo,
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            SizedBox(height: 8),
            for (final p in s.puntos)
              Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•  '),
                    Expanded(child: Text(p)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _grupoSinergias(BuildContext context, TipoSinergia tipo,
      List<(Sinergia, Entrada)> relaciones) {
    final delTipo = relaciones.where((r) => r.$1.tipo == tipo).toList();
    if (delTipo.isEmpty) return [];

    final (String titulo, Color color, IconData icono) = switch (tipo) {
      TipoSinergia.beneficiosa =>
        ('Buenas compañías', Colors.green.shade700, Icons.favorite),
      TipoSinergia.precaucion =>
        ('Con precaución', Colors.orange.shade800, Icons.warning_amber),
      TipoSinergia.evitar => ('Evitar', Colors.red.shade700, Icons.block),
    };

    return [
      SizedBox(height: 12),
      Row(
        children: [
          Icon(icono, color: color, size: 20),
          SizedBox(width: 6),
          Text(titulo,
              style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
      for (final (sinergia, otra) in delTipo)
        Card(
          margin: EdgeInsets.only(top: 6),
          color: Color.alphaBlend(color.withValues(alpha: 0.06), cSuperficie),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withValues(alpha: 0.4)),
          ),
          child: ListTile(
            leading: Text(otra.emoji, style: TextStyle(fontSize: 28)),
            title: Text(otra.nombre,
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(sinergia.razon),
            trailing: Icon(Icons.chevron_right),
            onTap: () => _abrirFicha(context, otra),
            onLongPress: () => _borrarSinergia(context, sinergia, otra),
          ),
        ),
    ];
  }

  // ----- Editar -----

  Future<void> _borrar(BuildContext context, Entrada ficha) async {
    final si = await _confirmar(
      context,
      titulo: '¿Borrar "${ficha.nombre}"?',
      texto: esFichaDeFabrica(ficha.id)
          ? 'Dejará de aparecer en la enciclopedia. Puedes recuperarla en '
              'Ajustes, con "Restaurar la enciclopedia original".'
          : 'Esta ficha la agregaste tú y no se podrá recuperar.',
      boton: 'Borrar',
    );
    if (!si || !context.mounted) return;
    borrarFicha(ficha.id);
    Ajustes.i.guardarEnciclopedia();
    Navigator.of(context).pop();
  }

  Future<void> _restaurar(BuildContext context, Entrada ficha) async {
    final si = await _confirmar(
      context,
      titulo: '¿Restaurar "${ficha.nombre}"?',
      texto: 'Se perderán los cambios que le hiciste a esta ficha.',
      boton: 'Restaurar',
    );
    if (!si) return;
    restaurarFicha(ficha.id);
    Ajustes.i.guardarEnciclopedia();
  }

  Future<void> _borrarSinergia(
      BuildContext context, Sinergia sinergia, Entrada otra) async {
    final si = await _confirmar(
      context,
      titulo: '¿Borrar la sinergia con ${otra.nombre}?',
      texto: sinergia.razon,
      boton: 'Borrar',
    );
    if (!si) return;
    borrarSinergia(sinergia.a, sinergia.b);
    Ajustes.i.guardarEnciclopedia();
  }

  Future<void> _agregarSinergia(BuildContext context, Entrada ficha) async {
    final otras = entradas.where((e) => e.id != ficha.id).toList();
    if (otras.isEmpty) return;

    var otraId = otras.first.id;
    var tipo = TipoSinergia.beneficiosa;
    final razon = TextEditingController();

    final guardar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ponerEstado) => AlertDialog(
          title: Text('Sinergia de ${ficha.nombre}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Con'),
                DropdownButton<String>(
                  isExpanded: true,
                  value: otraId,
                  items: [
                    for (final o in otras)
                      DropdownMenuItem(
                          value: o.id, child: Text('${o.emoji}  ${o.nombre}')),
                  ],
                  onChanged: (v) => ponerEstado(() => otraId = v ?? otraId),
                ),
                SizedBox(height: 12),
                SegmentedButton<TipoSinergia>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                        value: TipoSinergia.beneficiosa, label: Text('Buena')),
                    ButtonSegment(
                        value: TipoSinergia.precaucion, label: Text('Cuidado')),
                    ButtonSegment(
                        value: TipoSinergia.evitar, label: Text('Evitar')),
                  ],
                  selected: {tipo},
                  onSelectionChanged: (s) => ponerEstado(() => tipo = s.first),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: razon,
                  maxLines: 3,
                  maxLength: 200,
                  decoration: InputDecoration(
                    labelText: '¿Por qué?',
                    hintText: 'Ej. El frijol le aporta nitrógeno al maíz.',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Guardar')),
          ],
        ),
      ),
    );
    if (guardar != true) return;
    guardarSinergia(Sinergia(ficha.id, otraId, tipo, razon.text.trim()));
    Ajustes.i.guardarEnciclopedia();
  }
}

Future<bool> _confirmar(
  BuildContext context, {
  required String titulo,
  required String texto,
  required String boton,
}) async {
  final si = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(texto),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true), child: Text(boton)),
      ],
    ),
  );
  return si == true;
}

// ---------------------------------------------------------------------------
// AGREGAR O EDITAR UNA FICHA
// ---------------------------------------------------------------------------

class _SeccionEditable {
  final TextEditingController titulo;
  final TextEditingController puntos;
  String icono;
  _SeccionEditable({String titulo = '', String puntos = '', this.icono = 'nota'})
      : titulo = TextEditingController(text: titulo),
        puntos = TextEditingController(text: puntos);

  void liberar() {
    titulo.dispose();
    puntos.dispose();
  }
}

class PantallaEditarFicha extends StatefulWidget {
  /// La ficha a cambiar, o null para crear una nueva.
  final Entrada? original;
  const PantallaEditarFicha({super.key, this.original});

  @override
  State<PantallaEditarFicha> createState() => _PantallaEditarFichaState();
}

class _PantallaEditarFichaState extends State<PantallaEditarFicha> {
  static const _mesesCortos = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];

  late final TextEditingController _nombre;
  late final TextEditingController _emoji;
  late final TextEditingController _cientifico;
  late final TextEditingController _resumen;
  late TipoEntrada _tipo;
  late Set<int> _meses;
  final List<_SeccionEditable> _secciones = [];
  String? _errorNombre;

  @override
  void initState() {
    super.initState();
    final o = widget.original;
    _nombre = TextEditingController(text: o?.nombre ?? '');
    _emoji = TextEditingController(text: o?.emoji ?? '');
    _cientifico = TextEditingController(text: o?.cientifico ?? '');
    _resumen = TextEditingController(text: o?.resumen ?? '');
    _tipo = o?.tipo ?? TipoEntrada.cultivo;
    _meses = {...?o?.mesesSiembra};
    for (final s in o?.secciones ?? <Seccion>[]) {
      _secciones.add(_SeccionEditable(
        titulo: s.titulo,
        puntos: s.puntos.join('\n'),
        icono: nombreDeIcono(s.icono),
      ));
    }
    if (o == null) _secciones.add(_SeccionEditable(titulo: 'Cuidados'));
  }

  @override
  void dispose() {
    _nombre.dispose();
    _emoji.dispose();
    _cientifico.dispose();
    _resumen.dispose();
    for (final s in _secciones) {
      s.liberar();
    }
    super.dispose();
  }

  void _guardar() {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) {
      setState(() => _errorNombre = 'Escribe el nombre de la ficha');
      return;
    }

    final secciones = <Seccion>[];
    for (final s in _secciones) {
      final titulo = s.titulo.text.trim();
      final puntos = [
        for (final linea in s.puntos.text.split('\n'))
          if (linea.trim().isNotEmpty) linea.trim(),
      ];
      if (titulo.isEmpty && puntos.isEmpty) continue; // sección vacía
      secciones.add(Seccion(
        titulo.isEmpty ? 'Notas' : titulo,
        iconosSeccion[s.icono] ?? Icons.notes,
        puntos,
      ));
    }

    final emoji = _emoji.text.trim();
    final esCultivo = _tipo == TipoEntrada.cultivo;
    guardarFicha(Entrada(
      id: widget.original?.id ??
          'propia-${DateTime.now().millisecondsSinceEpoch}',
      nombre: nombre,
      cientifico: _cientifico.text.trim(),
      emoji: emoji.isNotEmpty ? emoji : (esCultivo ? '🌱' : '🐾'),
      tipo: _tipo,
      resumen: _resumen.text.trim(),
      mesesSiembra: esCultivo ? (_meses.toList()..sort()) : <int>[],
      secciones: secciones,
    ));
    Ajustes.i.guardarEnciclopedia();
    Navigator.of(context).pop();
  }

  InputDecoration _campo(String etiqueta, {String? ayuda, String? error}) {
    return InputDecoration(
      labelText: etiqueta,
      hintText: ayuda,
      errorText: error,
      filled: true,
      fillColor: cSuperficie,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esNueva = widget.original == null;

    return Scaffold(
      backgroundColor: cFondo,
      appBar: AppBar(
        backgroundColor: _verdeOscuro,
        foregroundColor: Colors.white,
        title: Text(esNueva ? 'Nueva ficha' : 'Editar ficha'),
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            tooltip: 'Guardar',
            onPressed: _guardar,
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<TipoEntrada>(
              segments: [
                ButtonSegment(
                    value: TipoEntrada.cultivo,
                    icon: Icon(Icons.eco),
                    label: Text('Cultivo')),
                ButtonSegment(
                    value: TipoEntrada.ganado,
                    icon: Icon(Icons.pets),
                    label: Text('Ganado')),
              ],
              selected: {_tipo},
              onSelectionChanged: (s) => setState(() => _tipo = s.first),
            ),
          ),
          SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 84,
                child: TextField(
                  controller: _emoji,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24),
                  decoration: _campo('Emoji', ayuda: '🌱'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _nombre,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _campo('Nombre', error: _errorNombre),
                  onChanged: (_) {
                    if (_errorNombre != null) {
                      setState(() => _errorNombre = null);
                    }
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          TextField(
            controller: _cientifico,
            decoration: _campo('Nombre científico (opcional)'),
          ),
          SizedBox(height: 12),
          TextField(
            controller: _resumen,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: _campo('Resumen',
                ayuda: 'Una o dos frases que describan la ficha'),
          ),

          if (_tipo == TipoEntrada.cultivo) ...[
            SizedBox(height: 20),
            Text('Meses de siembra',
                style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var m = 1; m <= 12; m++)
                  FilterChip(
                    label: Text(_mesesCortos[m - 1]),
                    selected: _meses.contains(m),
                    selectedColor: _verde.withValues(alpha: 0.25),
                    onSelected: (si) => setState(() {
                      if (si) {
                        _meses.add(m);
                      } else {
                        _meses.remove(m);
                      }
                    }),
                  ),
              ],
            ),
          ],

          SizedBox(height: 20),
          Text('Secciones', style: TextStyle(fontWeight: FontWeight.w700)),
          Text('En cada sección, escribe un punto por renglón.',
              style: TextStyle(fontSize: 12, color: cMuyTenue)),
          for (final s in _secciones) _tarjetaSeccion(s),
          SizedBox(height: 8),
          OutlinedButton.icon(
            icon: Icon(Icons.add),
            label: Text('Agregar sección'),
            onPressed: () =>
                setState(() => _secciones.add(_SeccionEditable())),
          ),
          SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _verde,
              padding: EdgeInsets.symmetric(vertical: 14),
            ),
            icon: Icon(Icons.check),
            label: Text('Guardar ficha'),
            onPressed: _guardar,
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _tarjetaSeccion(_SeccionEditable s) {
    return Card(
      margin: EdgeInsets.only(top: 10),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 8, 8, 12),
        child: Column(
          children: [
            Row(
              children: [
                PopupMenuButton<String>(
                  tooltip: 'Cambiar ícono',
                  icon: Icon(iconosSeccion[s.icono] ?? Icons.notes,
                      color: _verde),
                  onSelected: (clave) => setState(() => s.icono = clave),
                  itemBuilder: (_) => [
                    for (final e in iconosSeccion.entries)
                      PopupMenuItem(
                        value: e.key,
                        child: Row(
                          children: [
                            Icon(e.value, color: _verde),
                            SizedBox(width: 12),
                            Text(e.key),
                          ],
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: TextField(
                    controller: s.titulo,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Título (ej. Riego, Alimentación)',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline),
                  tooltip: 'Quitar sección',
                  onPressed: () => setState(() => _secciones.remove(s)),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: TextField(
                controller: s.puntos,
                minLines: 3,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Un punto por renglón',
                  filled: true,
                  fillColor: cSuperficie,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Doce casillas (E F M A M J J A S O N D); se pintan los meses de siembra
/// y se marca el mes actual con un borde.
class _Calendario extends StatelessWidget {
  final List<int> meses;
  const _Calendario({required this.meses});

  @override
  Widget build(BuildContext context) {
    const iniciales = 'EFMAMJJASOND';
    final mesActual = DateTime.now().month;

    return Row(
      children: [
        for (var m = 1; m <= 12; m++)
          Expanded(
            child: Container(
              height: 36,
              margin: EdgeInsets.symmetric(horizontal: 1.5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: meses.contains(m) ? _verde : cSuperficie,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: m == mesActual ? cContraste : cLinea,
                  width: m == mesActual ? 2 : 1,
                ),
              ),
              child: Text(
                iniciales[m - 1],
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: meses.contains(m) ? Colors.white : cTenue,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// PESTAÑA DE TÉCNICAS
// ---------------------------------------------------------------------------

class _ListaTecnicas extends StatelessWidget {
  const _ListaTecnicas();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        Text(
          'Guías paso a paso para sembrar, cuidar y abonar tu granja.',
          style: TextStyle(color: cTenue),
        ),
        SizedBox(height: 12),
        for (final t in tecnicas)
          Card(
            margin: EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Text(t.emoji, style: TextStyle(fontSize: 30)),
              title: Text(t.titulo,
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(t.resumen),
              trailing: Icon(Icons.chevron_right),
              onTap: () => _abrirTecnica(context, t),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// GUÍA DE UNA TÉCNICA
// ---------------------------------------------------------------------------

class PantallaTecnica extends StatelessWidget {
  final Tecnica tecnica;
  const PantallaTecnica({super.key, required this.tecnica});

  @override
  Widget build(BuildContext context) {
    final fichas = [
      for (final id in tecnica.sirvePara)
        if (entradaPorId(id) != null) entradaPorId(id)!,
    ];

    return Scaffold(
      backgroundColor: cFondo,
      appBar: AppBar(
        backgroundColor: _verdeOscuro,
        foregroundColor: Colors.white,
        title: Text(tecnica.titulo),
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Text(tecnica.emoji, style: TextStyle(fontSize: 48)),
              SizedBox(width: 16),
              Expanded(
                child: Text(tecnica.titulo,
                    style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(tecnica.resumen, style: TextStyle(fontSize: 16)),

          // Materiales
          if (tecnica.materiales.isNotEmpty)
            _bloque(
              icono: Icons.inventory_2_outlined,
              titulo: 'Materiales',
              hijos: [
                for (final m in tecnica.materiales) _vineta(m),
              ],
            ),

          // Pasos numerados
          _bloque(
            icono: Icons.format_list_numbered,
            titulo: 'Pasos',
            hijos: [
              for (var i = 0; i < tecnica.pasos.length; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: _verde,
                        child: Text('${i + 1}',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Text(tecnica.pasos[i]),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Consejos
          if (tecnica.consejos.isNotEmpty)
            _bloque(
              icono: Icons.lightbulb_outline,
              titulo: 'Consejos',
              hijos: [
                for (final c in tecnica.consejos) _vineta(c),
              ],
            ),

          // Fichas relacionadas
          if (fichas.isNotEmpty) ...[
            SizedBox(height: 16),
            Text('Sirve para',
                style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in fichas)
                  ActionChip(
                    avatar: Text(e.emoji),
                    label: Text(e.nombre),
                    onPressed: () => _abrirFicha(context, e),
                  ),
              ],
            ),
          ],
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _bloque({
    required IconData icono,
    required String titulo,
    required List<Widget> hijos,
  }) {
    return Card(
      margin: EdgeInsets.only(top: 16),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, color: _verde),
                SizedBox(width: 8),
                Text(titulo,
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            SizedBox(height: 10),
            ...hijos,
          ],
        ),
      ),
    );
  }

  Widget _vineta(String texto) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  '),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}
