// U Farm - Pantallas de la enciclopedia
//
// - Lista con buscador y filtros (Todo / Cultivos / Ganado)
// - "Para sembrar este mes" según la fecha del teléfono
// - Ficha de cada cultivo o animal, con su calendario y sus sinergias

import 'package:flutter/material.dart';

import 'enciclopedia_datos.dart';
import 'tecnicas_datos.dart';

const _verde = Color(0xFF16A34A);
const _verdeOscuro = Color(0xFF0E3B34);

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
      backgroundColor: const Color(0xFFF1EFE8),
      appBar: AppBar(
        backgroundColor: _verdeOscuro,
        foregroundColor: Colors.white,
        title: const Text('Enciclopedia de la granja'),
        bottom: const TabBar(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Color(0xFF86EFAC),
          tabs: [
            Tab(icon: Icon(Icons.eco), text: 'Fichas'),
            Tab(icon: Icon(Icons.handyman), text: 'Técnicas'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Buscar cultivo o animal',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (texto) => setState(() => _busqueda = texto.trim()),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _filtroChip('Todo', null),
              _filtroChip('Cultivos', TipoEntrada.cultivo),
              _filtroChip('Ganado', TipoEntrada.ganado),
            ],
          ),

          if (mostrarTemporada && paraSembrar.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.calendar_month, color: _verde),
                const SizedBox(width: 8),
                Text('Para sembrar en ${_meses[mes - 1]}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
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

          const SizedBox(height: 20),
          if (resultados.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No se encontró nada con ese nombre.')),
            ),
          for (final e in resultados)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Text(e.emoji, style: const TextStyle(fontSize: 32)),
                title: Text(e.nombre,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(e.resumen),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _abrirFicha(context, e),
              ),
            ),
        ],
      ),
          const _ListaTecnicas(),
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
    final relaciones = sinergiasDe(entrada.id);
    final siembra = datosSiembra[entrada.id];
    final tecnicasUtiles = tecnicasPara(entrada.id);

    return Scaffold(
      backgroundColor: const Color(0xFFF1EFE8),
      appBar: AppBar(
        backgroundColor: _verdeOscuro,
        foregroundColor: Colors.white,
        title: Text(entrada.nombre),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Encabezado
          Row(
            children: [
              Text(entrada.emoji, style: const TextStyle(fontSize: 56)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entrada.nombre,
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800)),
                    Text(entrada.cientifico,
                        style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(entrada.resumen, style: const TextStyle(fontSize: 16)),

          // Calendario de siembra
          if (entrada.mesesSiembra.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Meses de siembra',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _Calendario(meses: entrada.mesesSiembra),
          ],

          // Cómo sembrar
          if (siembra != null) _tarjetaSiembra(siembra),

          // Técnicas relacionadas
          if (tecnicasUtiles.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Técnicas útiles',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
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
          const SizedBox(height: 12),
          for (final s in entrada.secciones) _tarjetaSeccion(s),

          // Sinergias
          if (relaciones.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Sinergias',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            for (final tipo in TipoSinergia.values)
              ..._grupoSinergias(context, tipo, relaciones),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _tarjetaSiembra(DatosSiembra s) {
    Widget fila(IconData icono, String etiqueta, String valor) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 18, color: Colors.black54),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: Text(etiqueta,
                  style: const TextStyle(color: Colors.black54)),
            ),
            Expanded(
              child: Text(valor,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(top: 16),
      color: Color.alphaBlend(_verde.withValues(alpha: 0.08), Colors.white),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.spa, color: _verde),
                SizedBox(width: 8),
                Text('Cómo sembrar',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            fila(Icons.call_split, 'Método', s.metodo),
            fila(Icons.vertical_align_bottom, 'Profundidad', s.profundidad),
            fila(Icons.straighten, 'Distancia', s.distancia),
            fila(Icons.timer_outlined, 'Germinación', s.germinacion),
            if (s.trasplante != null)
              fila(Icons.move_down, 'Trasplante', s.trasplante!),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline,
                    size: 18, color: Colors.amber),
                const SizedBox(width: 8),
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
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(s.icono, color: _verde),
                const SizedBox(width: 8),
                Text(s.titulo,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            for (final p in s.puntos)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
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
      const SizedBox(height: 12),
      Row(
        children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(width: 6),
          Text(titulo,
              style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
      for (final (sinergia, otra) in delTipo)
        Card(
          margin: const EdgeInsets.only(top: 6),
          color: Color.alphaBlend(color.withValues(alpha: 0.06), Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withValues(alpha: 0.4)),
          ),
          child: ListTile(
            leading: Text(otra.emoji, style: const TextStyle(fontSize: 28)),
            title: Text(otra.nombre,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(sinergia.razon),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _abrirFicha(context, otra),
          ),
        ),
    ];
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
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: meses.contains(m) ? _verde : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: m == mesActual ? _verdeOscuro : Colors.black12,
                  width: m == mesActual ? 2 : 1,
                ),
              ),
              child: Text(
                iniciales[m - 1],
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: meses.contains(m) ? Colors.white : Colors.black54,
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
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Guías paso a paso para sembrar, cuidar y abonar tu granja.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 12),
        for (final t in tecnicas)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Text(t.emoji, style: const TextStyle(fontSize: 30)),
              title: Text(t.titulo,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(t.resumen),
              trailing: const Icon(Icons.chevron_right),
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
      backgroundColor: const Color(0xFFF1EFE8),
      appBar: AppBar(
        backgroundColor: _verdeOscuro,
        foregroundColor: Colors.white,
        title: Text(tecnica.titulo),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Text(tecnica.emoji, style: const TextStyle(fontSize: 48)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(tecnica.titulo,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(tecnica.resumen, style: const TextStyle(fontSize: 16)),

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
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: _verde,
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
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
            const SizedBox(height: 16),
            const Text('Sirve para',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
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
          const SizedBox(height: 24),
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
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, color: _verde),
                const SizedBox(width: 8),
                Text(titulo,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),
            ...hijos,
          ],
        ),
      ),
    );
  }

  Widget _vineta(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}
