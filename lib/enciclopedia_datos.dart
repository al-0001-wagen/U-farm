// U Farm - Contenido de la enciclopedia
//
// Aquí está toda la información de cultivos, ganado y sinergias.
// Para agregar una ficha nueva, copien una entrada existente y cambien
// sus datos. Para agregar una sinergia, agreguen una línea a la lista
// "sinergias" usando los "id" de las dos fichas.
//
// Las fechas de siembra son aproximadas para el clima cálido y semiárido
// de Nuevo León (veranos muy calurosos y heladas ocasionales de diciembre
// a febrero). Pueden ajustarlas con el calendario agrícola del INIFAP.

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// MODELOS
// ---------------------------------------------------------------------------

enum TipoEntrada { cultivo, ganado }

enum TipoSinergia { beneficiosa, precaucion, evitar }

class Seccion {
  final String titulo;
  final IconData icono;
  final List<String> puntos;
  const Seccion(this.titulo, this.icono, this.puntos);
}

class Entrada {
  final String id;
  final String nombre;
  final String cientifico;
  final String emoji;
  final TipoEntrada tipo;
  final String resumen;
  final List<int> mesesSiembra; // 1 = enero ... 12 = diciembre
  final List<Seccion> secciones;

  const Entrada({
    required this.id,
    required this.nombre,
    required this.cientifico,
    required this.emoji,
    required this.tipo,
    required this.resumen,
    this.mesesSiembra = const [],
    required this.secciones,
  });
}

class Sinergia {
  final String a;
  final String b;
  final TipoSinergia tipo;
  final String razon;
  const Sinergia(this.a, this.b, this.tipo, this.razon);
}

// Íconos de las secciones
const _clima = Icons.wb_sunny_outlined;
const _riego = Icons.water_drop_outlined;
const _suelo = Icons.grass;
const _plagas = Icons.bug_report_outlined;
const _cosecha = Icons.agriculture;
const _casa = Icons.home_outlined;
const _comida = Icons.restaurant;
const _temp = Icons.thermostat;
const _salud = Icons.medical_services_outlined;
const _produccion = Icons.egg_outlined;
const _abono = Icons.recycling;
const _legal = Icons.gavel;

// ---------------------------------------------------------------------------
// CULTIVOS
// ---------------------------------------------------------------------------

const List<Entrada> entradas = [
  Entrada(
    id: 'tomate',
    nombre: 'Tomate',
    cientifico: 'Solanum lycopersicum',
    emoji: '🍅',
    tipo: TipoEntrada.cultivo,
    resumen: 'Fruto estrella del huerto. Necesita sol, tutores y riego constante.',
    mesesSiembra: [2, 3, 7, 8],
    secciones: [
      Seccion('Clima y temporada', _clima, [
        'Sol directo de 6 a 8 horas al día.',
        'Temperatura ideal de 20 a 30 °C. Con más de 35 °C las flores se caen y no da fruto.',
        'En Nuevo León se trasplanta en febrero-marzo y en julio-agosto para cosechar en otoño.',
        'Protégelo de las heladas cerrando los vidrios del techo.',
      ]),
      Seccion('Riego', _riego, [
        'Riego profundo y regular, al pie de la planta y sin mojar las hojas.',
        'El riego irregular agrieta los frutos y causa pudrición en la punta.',
        'Una capa de paja sobre la tierra conserva la humedad.',
      ]),
      Seccion('Suelo y espacio', _suelo, [
        '40 a 60 cm entre plantas. En maceta, mínimo 20 litros.',
        'Necesita tutor, estaca o jaula.',
        'Tierra con composta y buen drenaje.',
      ]),
      Seccion('Cuidados y plagas', _plagas, [
        'Quita los brotes que salen entre el tallo y las ramas (chupones).',
        'Plagas comunes: mosca blanca, pulgón y gusano del fruto.',
        'No lo siembres donde el año anterior hubo tomate, papa o chile.',
      ]),
      Seccion('Cosecha', _cosecha, [
        'De 70 a 90 días después del trasplante.',
        'Cosecha cuando empiece a cambiar de color y deja que termine de madurar adentro.',
      ]),
    ],
  ),
  Entrada(
    id: 'lechuga',
    nombre: 'Lechuga',
    cientifico: 'Lactuca sativa',
    emoji: '🥬',
    tipo: TipoEntrada.cultivo,
    resumen: 'Hoja de ciclo corto, ideal para la temporada fresca y el cultivo vertical.',
    mesesSiembra: [10, 11, 12, 1, 2],
    secciones: [
      Seccion('Clima y temporada', _clima, [
        'Prefiere de 10 a 24 °C. Con calor florece y se vuelve amarga.',
        'Siembra de octubre a febrero. Tolera media sombra.',
      ]),
      Seccion('Riego', _riego, [
        'Riegos frecuentes y ligeros: su raíz es poco profunda.',
      ]),
      Seccion('Suelo y espacio', _suelo, [
        '20 a 30 cm entre plantas. Macetas desde 15 cm de profundidad.',
        'Muy buena para torres verticales e hidroponía.',
      ]),
      Seccion('Cuidados y plagas', _plagas, [
        'Plagas comunes: babosas y pulgón.',
        'Siembra un poco cada 2 o 3 semanas para cosechar todo el tiempo.',
      ]),
      Seccion('Cosecha', _cosecha, [
        'De 45 a 65 días. Puedes cortar solo las hojas de afuera y dejar que siga creciendo.',
      ]),
    ],
  ),
  Entrada(
    id: 'zanahoria',
    nombre: 'Zanahoria',
    cientifico: 'Daucus carota',
    emoji: '🥕',
    tipo: TipoEntrada.cultivo,
    resumen: 'Raíz de temporada fresca. Necesita tierra suelta y paciencia al germinar.',
    mesesSiembra: [9, 10, 11, 12, 1, 2],
    secciones: [
      Seccion('Clima y temporada', _clima, [
        'Siembra de septiembre a febrero. Temperatura ideal de 15 a 21 °C.',
      ]),
      Seccion('Riego', _riego, [
        'Mantén la tierra húmeda hasta que germine (puede tardar de 1 a 3 semanas).',
        'Después, riego regular.',
      ]),
      Seccion('Suelo y espacio', _suelo, [
        'Tierra suelta y sin piedras. El estiércol fresco hace que la raíz se deforme.',
        'Contenedor de al menos 30 cm de profundidad.',
        'Siembra directa y deja 5 cm entre plantas al aclarar.',
      ]),
      Seccion('Cuidados y plagas', _plagas, [
        'Plaga principal: mosca de la zanahoria.',
      ]),
      Seccion('Cosecha', _cosecha, [
        'De 70 a 80 días.',
        'Las hojas son buen alimento para los conejos.',
      ]),
    ],
  ),
  Entrada(
    id: 'papa',
    nombre: 'Papa',
    cientifico: 'Solanum tuberosum',
    emoji: '🥔',
    tipo: TipoEntrada.cultivo,
    resumen: 'Tubérculo muy productivo que se puede cultivar en costales o contenedores.',
    mesesSiembra: [1, 2],
    secciones: [
      Seccion('Clima y temporada', _clima, [
        'Prefiere de 15 a 20 °C. Siembra en enero-febrero, después de las heladas fuertes.',
      ]),
      Seccion('Riego', _riego, [
        'Riego constante mientras se forman las papas. Sin encharcar.',
      ]),
      Seccion('Suelo y espacio', _suelo, [
        'Costales o contenedores de unos 40 litros.',
        'Aporca: cubre el tallo con más tierra conforme crece. Así da más papas y no se ponen verdes.',
      ]),
      Seccion('Cuidados y plagas', _plagas, [
        'Plagas y enfermedades comunes: tizón y palomilla.',
        'No la siembres después de tomate o chile.',
      ]),
      Seccion('Cosecha', _cosecha, [
        'De 90 a 120 días, cuando las hojas se secan.',
        'Las papas verdes son tóxicas. Las hojas y tallos son tóxicos para los animales.',
      ]),
    ],
  ),
  Entrada(
    id: 'chile',
    nombre: 'Chile',
    cientifico: 'Capsicum annuum',
    emoji: '🌶️',
    tipo: TipoEntrada.cultivo,
    resumen: 'Base de la cocina mexicana. Aguanta mejor el calor que el tomate.',
    mesesSiembra: [2, 3, 4],
    secciones: [
      Seccion('Clima y temporada', _clima, [
        'Temperatura ideal de 20 a 32 °C. Trasplante de febrero a abril.',
      ]),
      Seccion('Riego', _riego, [
        'Regular. La falta de agua baja la producción y el exceso pudre la raíz.',
      ]),
      Seccion('Suelo y espacio', _suelo, [
        '40 a 50 cm entre plantas. Maceta de 10 a 15 litros.',
      ]),
      Seccion('Cuidados y plagas', _plagas, [
        'Plagas comunes: pulgón, mosca blanca y picudo del chile.',
      ]),
      Seccion('Cosecha', _cosecha, [
        'De 70 a 90 días después del trasplante.',
        'Cosechar seguido hace que la planta produzca más.',
      ]),
    ],
  ),
  Entrada(
    id: 'calabacita',
    nombre: 'Calabacita',
    cientifico: 'Cucurbita pepo',
    emoji: '🥒',
    tipo: TipoEntrada.cultivo,
    resumen: 'Rápida y muy productiva, pero ocupa bastante espacio.',
    mesesSiembra: [2, 3, 4, 8, 9],
    secciones: [
      Seccion('Clima y temporada', _clima, [
        'Temperatura ideal de 18 a 30 °C. Siembra en febrero-abril y agosto-septiembre.',
      ]),
      Seccion('Riego', _riego, [
        'Profundo y al pie. Las hojas mojadas favorecen un hongo blanco (cenicilla).',
      ]),
      Seccion('Suelo y espacio', _suelo, [
        'Alrededor de 1 m² por planta.',
      ]),
      Seccion('Cuidados y plagas', _plagas, [
        'Plagas comunes: chinche de la calabaza y cenicilla.',
        'Si hay pocos insectos en el invernadero, poliniza a mano: pasa polen de la flor macho a la hembra con un pincel.',
      ]),
      Seccion('Cosecha', _cosecha, [
        'De 45 a 55 días. Cosecha cuando midan de 15 a 20 cm.',
        'La flor de calabaza también se come.',
      ]),
    ],
  ),
  Entrada(
    id: 'frijol',
    nombre: 'Frijol',
    cientifico: 'Phaseolus vulgaris',
    emoji: '🫘',
    tipo: TipoEntrada.cultivo,
    resumen: 'Leguminosa que enriquece el suelo con nitrógeno.',
    mesesSiembra: [2, 3, 8, 9],
    secciones: [
      Seccion('Clima y temporada', _clima, [
        'Temperatura ideal de 18 a 30 °C. No tolera heladas.',
        'Siembra en febrero-marzo y agosto-septiembre.',
      ]),
      Seccion('Riego', _riego, [
        'Moderado. El momento más importante es la floración.',
      ]),
      Seccion('Suelo y espacio', _suelo, [
        'Frijol de mata: 10 a 15 cm entre plantas. Frijol de guía: necesita tutor o maíz.',
        'Casi no necesita fertilizante con nitrógeno: lo toma del aire.',
      ]),
      Seccion('Cuidados y plagas', _plagas, [
        'Plagas comunes: conchuela y pulgón.',
      ]),
      Seccion('Cosecha', _cosecha, [
        'Ejote: de 50 a 60 días. Grano seco: de 80 a 100 días.',
        'El frijol crudo es tóxico para las aves: dáselos solo cocido.',
      ]),
    ],
  ),
  Entrada(
    id: 'maiz',
    nombre: 'Maíz',
    cientifico: 'Zea mays',
    emoji: '🌽',
    tipo: TipoEntrada.cultivo,
    resumen: 'Pilar de la milpa, junto con el frijol y la calabaza.',
    mesesSiembra: [2, 3, 7],
    secciones: [
      Seccion('Clima y temporada', _clima, [
        'Necesita calor y sol pleno. Siembra en febrero-marzo y en julio.',
      ]),
      Seccion('Riego', _riego, [
        'Abundante, sobre todo cuando salen la espiga y los jilotes.',
      ]),
      Seccion('Suelo y espacio', _suelo, [
        'Siémbralo en bloque (varias filas juntas), no en una sola fila: se poliniza con el viento.',
        'Ocupa mucho espacio. En azoteas conviene usar variedades bajas.',
      ]),
      Seccion('Cuidados y plagas', _plagas, [
        'Plagas comunes: gusano cogollero y gusano elotero.',
      ]),
      Seccion('Cosecha', _cosecha, [
        'Elote: de 80 a 100 días.',
        'El grano y el rastrojo sirven de alimento para las gallinas.',
      ]),
    ],
  ),
  Entrada(
    id: 'cebolla',
    nombre: 'Cebolla',
    cientifico: 'Allium cepa',
    emoji: '🧅',
    tipo: TipoEntrada.cultivo,
    resumen: 'Ciclo largo, pero ocupa muy poco espacio.',
    mesesSiembra: [10, 11, 12],
    secciones: [
      Seccion('Clima y temporada', _clima, [
        'Siembra de octubre a diciembre.',
        'En el norte de México usa variedades de "día corto".',
      ]),
      Seccion('Riego', _riego, [
        'Regular. Deja de regar cuando el cuello de la planta se doble.',
      ]),
      Seccion('Suelo y espacio', _suelo, [
        '10 cm entre plantas.',
      ]),
      Seccion('Cuidados y plagas', _plagas, [
        'Plaga principal: trips.',
      ]),
      Seccion('Cosecha', _cosecha, [
        'De 100 a 150 días. Déjala secar al sol unos días antes de guardarla.',
      ]),
    ],
  ),
  Entrada(
    id: 'rabano',
    nombre: 'Rábano',
    cientifico: 'Raphanus sativus',
    emoji: '🌱',
    tipo: TipoEntrada.cultivo,
    resumen: 'El cultivo más rápido del huerto. Ideal para empezar.',
    mesesSiembra: [9, 10, 11, 12, 1, 2, 3],
    secciones: [
      Seccion('Clima y temporada', _clima, [
        'Temporada fresca: de septiembre a marzo.',
      ]),
      Seccion('Riego', _riego, [
        'Constante. Si el riego es irregular, salen huecos y muy picantes.',
      ]),
      Seccion('Suelo y espacio', _suelo, [
        '5 cm entre plantas. Macetas desde 15 cm de profundidad.',
      ]),
      Seccion('Cuidados y plagas', _plagas, [
        'Plaga principal: pulguilla (hace agujeritos en las hojas).',
      ]),
      Seccion('Cosecha', _cosecha, [
        'De 25 a 30 días. Las hojas también se comen.',
      ]),
    ],
  ),
  Entrada(
    id: 'espinaca',
    nombre: 'Espinaca',
    cientifico: 'Spinacia oleracea',
    emoji: '🍃',
    tipo: TipoEntrada.cultivo,
    resumen: 'Hoja nutritiva para el invierno.',
    mesesSiembra: [10, 11, 12, 1],
    secciones: [
      Seccion('Clima y temporada', _clima, [
        'Siembra de octubre a enero. Con calor y días largos florece y deja de producir.',
      ]),
      Seccion('Riego', _riego, [
        'Regular, sin encharcar.',
      ]),
      Seccion('Suelo y espacio', _suelo, [
        '10 a 15 cm entre plantas.',
      ]),
      Seccion('Cosecha', _cosecha, [
        'De 40 a 50 días. Corta las hojas de afuera.',
      ]),
    ],
  ),
  Entrada(
    id: 'cilantro',
    nombre: 'Cilantro',
    cientifico: 'Coriandrum sativum',
    emoji: '🌿',
    tipo: TipoEntrada.cultivo,
    resumen: 'Hierba de ciclo corto que florece rápido con el calor.',
    mesesSiembra: [10, 11, 12, 1, 2],
    secciones: [
      Seccion('Clima y temporada', _clima, [
        'Siembra de octubre a febrero. Con calor florece en pocas semanas.',
      ]),
      Seccion('Riego', _riego, [
        'Regular.',
      ]),
      Seccion('Suelo y espacio', _suelo, [
        'Maceta de 20 cm. Siembra directa cada 3 semanas para tener siempre.',
      ]),
      Seccion('Cuidados y plagas', _plagas, [
        'Deja florecer algunas plantas: sus flores atraen insectos que se comen a los pulgones.',
      ]),
      Seccion('Cosecha', _cosecha, [
        'De 40 a 50 días. Las semillas secas son el coriandro.',
      ]),
    ],
  ),
  Entrada(
    id: 'albahaca',
    nombre: 'Albahaca',
    cientifico: 'Ocimum basilicum',
    emoji: '🌿',
    tipo: TipoEntrada.cultivo,
    resumen: 'Aromática de clima cálido y compañera clásica del tomate.',
    mesesSiembra: [3, 4, 5, 6],
    secciones: [
      Seccion('Clima y temporada', _clima, [
        'Necesita más de 18 °C. Es sensible al frío. Siembra de marzo a junio.',
      ]),
      Seccion('Riego', _riego, [
        'Regular, sin encharcar.',
      ]),
      Seccion('Suelo y espacio', _suelo, [
        '25 a 30 cm entre plantas. Maceta de 3 a 5 litros.',
      ]),
      Seccion('Cuidados y plagas', _plagas, [
        'Corta las puntas y quita las flores para que dé más hojas.',
      ]),
      Seccion('Cosecha', _cosecha, [
        'Desde los 60 días, cortando las hojas de arriba.',
      ]),
    ],
  ),
  Entrada(
    id: 'calendula',
    nombre: 'Caléndula',
    cientifico: 'Calendula officinalis',
    emoji: '🌼',
    tipo: TipoEntrada.cultivo,
    resumen: 'Flor comestible que atrae polinizadores e insectos benéficos.',
    mesesSiembra: [10, 11, 12, 1, 2],
    secciones: [
      Seccion('Clima y temporada', _clima, [
        'Temporada fresca. Aguanta frío ligero. Siembra de octubre a febrero.',
      ]),
      Seccion('Riego', _riego, [
        'Moderado.',
      ]),
      Seccion('Suelo y espacio', _suelo, [
        '25 cm entre plantas.',
      ]),
      Seccion('Cuidados y plagas', _plagas, [
        'Quita las flores secas para que siga floreciendo.',
      ]),
      Seccion('Cosecha', _cosecha, [
        'Los pétalos se usan en ensaladas.',
      ]),
    ],
  ),
  Entrada(
    id: 'capuchina',
    nombre: 'Capuchina',
    cientifico: 'Tropaeolum majus',
    emoji: '🌺',
    tipo: TipoEntrada.cultivo,
    resumen: 'Flor y hoja comestibles. Atrae a los pulgones lejos de otros cultivos.',
    mesesSiembra: [10, 11, 12, 1, 2],
    secciones: [
      Seccion('Clima y temporada', _clima, [
        'Temporada fresca. Sufre con el calor fuerte del verano.',
      ]),
      Seccion('Riego', _riego, [
        'Moderado. En tierra poco fertilizada da más flores.',
      ]),
      Seccion('Cuidados y plagas', _plagas, [
        'Funciona como "cultivo trampa": los pulgones la prefieren.',
        'Revísala seguido y quita las hojas con pulgón antes de que se pasen a otras plantas.',
      ]),
      Seccion('Cosecha', _cosecha, [
        'Flores, hojas y semillas son comestibles, con sabor picante.',
      ]),
    ],
  ),
  Entrada(
    id: 'alfalfa',
    nombre: 'Alfalfa',
    cientifico: 'Medicago sativa',
    emoji: '🌾',
    tipo: TipoEntrada.cultivo,
    resumen: 'Forraje que dura varios años y fija nitrógeno. Alimento para conejos y gallinas.',
    mesesSiembra: [10, 11],
    secciones: [
      Seccion('Clima y temporada', _clima, [
        'Siembra en octubre-noviembre. Es perenne: rebrota varios años.',
      ]),
      Seccion('Riego', _riego, [
        'Profundo. Una vez establecida aguanta bien la sequía.',
      ]),
      Seccion('Suelo y espacio', _suelo, [
        'Siembra al voleo (esparciendo la semilla).',
      ]),
      Seccion('Cosecha', _cosecha, [
        'Corta cada 4 a 6 semanas y vuelve a crecer.',
        'Rica en proteína y calcio: ideal para conejos jóvenes y hembras lactando. En adultos, con moderación.',
      ]),
    ],
  ),

  // -------------------------------------------------------------------------
  // GANADO PEQUEÑO
  // -------------------------------------------------------------------------

  Entrada(
    id: 'conejo',
    nombre: 'Conejo',
    cientifico: 'Oryctolagus cuniculus',
    emoji: '🐇',
    tipo: TipoEntrada.ganado,
    resumen: 'Ganado ideal para la ciudad: silencioso, eficiente y con un estiércol excelente para el huerto.',
    secciones: [
      Seccion('Alojamiento', _casa, [
        'Al menos medio metro cuadrado por conejo adulto.',
        'Un adulto por jaula: los machos pelean.',
        'Protégelos del sol directo, la lluvia y los depredadores.',
        'Deja una zona de piso sólido para descansar; la malla sola lastima las patas.',
      ]),
      Seccion('Alimentación', _comida, [
        'Base: heno o forraje siempre disponible. Además de nutrir, desgasta sus dientes.',
        'Complementa con alimento balanceado (pellets) según su etapa.',
        'Verduras de hoja: lechuga romana, cilantro, albahaca, hojas de zanahoria.',
        'Agua limpia siempre.',
        'Nunca: hojas o tallos de tomate y papa, aguacate, cebolla, ajo ni chocolate.',
        'Haz los cambios de dieta poco a poco.',
      ]),
      Seccion('Clima', _temp, [
        'Ideal de 15 a 25 °C. Aguantan mejor el frío que el calor.',
        'Con más de 30 °C hay riesgo de golpe de calor: sombra, ventilación y botellas de agua congelada en la jaula.',
      ]),
      Seccion('Salud', _salud, [
        'Urgencia: si deja de comer o de hacer popó por más de 12 horas.',
        'Otras señales de alerta: diarrea, estornudos, cabeza ladeada.',
        'Existe vacuna contra la enfermedad hemorrágica viral (EHVC). Consulta a un veterinario.',
        'Limpia seguido para evitar la coccidiosis.',
      ]),
      Seccion('Producción', _produccion, [
        'Gestación de unos 31 días. Camadas de 6 a 10 crías.',
        'Destete a las 4-6 semanas.',
        'Razas de carne (Nueva Zelanda, California): 2 a 2.5 kg a las 10-12 semanas.',
      ]),
      Seccion('Estiércol', _abono, [
        'Es un abono "frío": se puede poner directo en el huerto sin quemar las plantas.',
        'Rico en nitrógeno y fósforo.',
      ]),
      Seccion('Normas y bienestar', _legal, [
        'Revisa el reglamento de tu municipio sobre animales en zona urbana.',
        'El sacrificio debe ser humanitario, según la NOM-033-SAG/ZOO-2014.',
      ]),
    ],
  ),
  Entrada(
    id: 'gallina',
    nombre: 'Gallina',
    cientifico: 'Gallus gallus domesticus',
    emoji: '🐔',
    tipo: TipoEntrada.ganado,
    resumen: 'Huevo fresco diario, control de insectos y abono para composta.',
    secciones: [
      Seccion('Alojamiento', _casa, [
        'Gallinero de 0.3 a 0.4 m² por gallina, más un patio.',
        'Percha de 20 a 25 cm por ave y un nido por cada 4 o 5 gallinas.',
        'Ciérralo de noche (tlacuaches, gatos, ratas).',
        'No hace falta gallo para tener huevo, y hace mucho ruido.',
      ]),
      Seccion('Alimentación', _comida, [
        'Base: alimento de postura (alrededor de 16 % de proteína).',
        'Calcio extra: concha de ostión o cascarón triturado.',
        'Complementos: restos de verduras, calabaza, maíz quebrado, insectos.',
        'Nunca: aguacate, papa cruda o verde, frijol crudo, chocolate, comida salada o con moho.',
      ]),
      Seccion('Clima', _temp, [
        'Sufren con más de 32 °C: jadean y abren las alas. Dales sombra, agua fresca y ventilación.',
        'Ponen menos con días cortos y durante la muda de plumas (otoño).',
      ]),
      Seccion('Salud', _salud, [
        'Vacuna contra Newcastle.',
        'Revisa piojos y ácaros. Un baño de tierra o arena les ayuda a limpiarse.',
        'Lávate las manos después de tocarlas o recoger huevos (salmonela).',
      ]),
      Seccion('Producción', _produccion, [
        'Empiezan a poner entre las 18 y 22 semanas.',
        'Razas ponedoras: unos 250-300 huevos el primer año; luego baja.',
        'Vida productiva de 2 a 3 años.',
      ]),
      Seccion('Estiércol', _abono, [
        'Es un abono "caliente", muy fuerte: quema las raíces si se pone fresco.',
        'Compóstalo al menos 2 o 3 meses antes de usarlo.',
      ]),
      Seccion('En el huerto', _suelo, [
        'Déjalas escarbar en camas ya cosechadas: limpian plagas y hierbas.',
        'Mantenlas lejos de los cultivos que están creciendo.',
      ]),
    ],
  ),
  Entrada(
    id: 'codorniz',
    nombre: 'Codorniz',
    cientifico: 'Coturnix japonica',
    emoji: '🐦',
    tipo: TipoEntrada.ganado,
    resumen: 'La opción más compacta: poco espacio, postura rápida y casi sin ruido.',
    secciones: [
      Seccion('Alojamiento', _casa, [
        'Jaula baja o con techo suave: cuando se asustan saltan hacia arriba y se golpean.',
        'Ocupan mucho menos espacio que una gallina.',
        'Un macho por cada 3 o 4 hembras si quieres huevo fértil; si no, solo hembras.',
      ]),
      Seccion('Alimentación', _comida, [
        'Alimento alto en proteína (20 a 24 %), como el de codorniz o pavo.',
        'Hojas verdes picadas y calcio extra.',
        'Bebederos pequeños: las crías se pueden ahogar en recipientes hondos.',
      ]),
      Seccion('Clima', _temp, [
        'Sensibles a las corrientes de aire y al calor extremo.',
      ]),
      Seccion('Salud', _salud, [
        'Limpia la jaula seguido: el olor a amoníaco las enferma.',
        'Se estresan si se manipulan mucho.',
      ]),
      Seccion('Producción', _produccion, [
        'Empiezan a poner desde las 6-8 semanas.',
        'En su mejor etapa, casi un huevo al día.',
      ]),
      Seccion('Estiércol', _abono, [
        'Como el de gallina: compóstalo antes de usarlo.',
      ]),
    ],
  ),
];

// ---------------------------------------------------------------------------
// SINERGIAS
// beneficiosa = se ayudan; precaucion = sirve con cuidado; evitar = no juntar
// ---------------------------------------------------------------------------

const List<Sinergia> sinergias = [
  // Planta con planta
  Sinergia('maiz', 'frijol', TipoSinergia.beneficiosa,
      'Milpa: el frijol aporta nitrógeno al suelo y el maíz le sirve de tutor.'),
  Sinergia('frijol', 'calabacita', TipoSinergia.beneficiosa,
      'Milpa: la calabaza cubre el suelo, conserva la humedad y frena la maleza.'),
  Sinergia('maiz', 'calabacita', TipoSinergia.beneficiosa,
      'Milpa: aprovechan distintas alturas del mismo espacio.'),
  Sinergia('tomate', 'albahaca', TipoSinergia.beneficiosa,
      'Asociación tradicional: la albahaca atrae polinizadores y aprovecha el espacio entre tomates.'),
  Sinergia('zanahoria', 'rabano', TipoSinergia.beneficiosa,
      'El rábano germina rápido, marca las hileras y afloja la tierra. Se cosecha antes de que estorbe.'),
  Sinergia('zanahoria', 'cebolla', TipoSinergia.beneficiosa,
      'Asociación tradicional: el olor de cada una confunde a las plagas de la otra.'),
  Sinergia('lechuga', 'rabano', TipoSinergia.beneficiosa,
      'Ambas son de ciclo corto y raíz poco profunda: comparten bien la misma cama.'),
  Sinergia('cilantro', 'lechuga', TipoSinergia.beneficiosa,
      'Las flores del cilantro atraen insectos que se comen a los pulgones de la lechuga.'),
  Sinergia('capuchina', 'calabacita', TipoSinergia.beneficiosa,
      'Cultivo trampa: atrae pulgones y chinches lejos de la calabacita.'),
  Sinergia('capuchina', 'tomate', TipoSinergia.beneficiosa,
      'Cultivo trampa: los pulgones prefieren la capuchina.'),
  Sinergia('calendula', 'tomate', TipoSinergia.beneficiosa,
      'Atrae polinizadores e insectos que controlan plagas.'),
  Sinergia('calendula', 'chile', TipoSinergia.beneficiosa,
      'Atrae polinizadores e insectos que controlan plagas.'),
  Sinergia('tomate', 'papa', TipoSinergia.evitar,
      'Son de la misma familia: comparten el tizón y varias plagas.'),
  Sinergia('tomate', 'maiz', TipoSinergia.evitar,
      'Comparten el gusano elotero, que también ataca el fruto del tomate.'),
  Sinergia('frijol', 'cebolla', TipoSinergia.evitar,
      'Tradicionalmente se recomienda separarlos: la cebolla frena el crecimiento del frijol.'),

  // Animal con planta
  Sinergia('conejo', 'alfalfa', TipoSinergia.beneficiosa,
      'Forraje fresco que se puede cultivar en la misma granja. Moderar en conejos adultos.'),
  Sinergia('conejo', 'zanahoria', TipoSinergia.beneficiosa,
      'Las hojas son buen alimento. La raíz solo como premio, porque tiene mucha azúcar.'),
  Sinergia('conejo', 'lechuga', TipoSinergia.beneficiosa,
      'Las hojas de afuera alimentan a los conejos y su estiércol fertiliza la lechuga directo.'),
  Sinergia('conejo', 'cilantro', TipoSinergia.beneficiosa,
      'Les gusta y es seguro para ellos.'),
  Sinergia('conejo', 'espinaca', TipoSinergia.precaucion,
      'Solo en poca cantidad: tiene oxalatos que en exceso les hacen daño.'),
  Sinergia('conejo', 'tomate', TipoSinergia.evitar,
      'Hojas y tallos tóxicos para el conejo. Su estiércol sí es buen abono para el tomate.'),
  Sinergia('conejo', 'papa', TipoSinergia.evitar,
      'Hojas, tallos y papas verdes son tóxicos.'),
  Sinergia('conejo', 'cebolla', TipoSinergia.evitar,
      'La cebolla es tóxica para los conejos.'),
  Sinergia('gallina', 'maiz', TipoSinergia.beneficiosa,
      'El grano y el rastrojo complementan su alimento.'),
  Sinergia('gallina', 'calabacita', TipoSinergia.beneficiosa,
      'Comen las calabazas pasadas y sus semillas.'),
  Sinergia('gallina', 'alfalfa', TipoSinergia.beneficiosa,
      'Hojas frescas ricas en proteína.'),
  Sinergia('gallina', 'tomate', TipoSinergia.precaucion,
      'Su estiércol compostado lo fertiliza, pero picotean los frutos: mantenlas fuera.'),
  Sinergia('gallina', 'papa', TipoSinergia.evitar,
      'La papa cruda y las cáscaras verdes son tóxicas.'),
  Sinergia('gallina', 'frijol', TipoSinergia.evitar,
      'El frijol crudo es tóxico para las aves. Solo cocido.'),
  Sinergia('codorniz', 'lechuga', TipoSinergia.beneficiosa,
      'Hojas picadas como complemento de su alimento.'),
  Sinergia('codorniz', 'espinaca', TipoSinergia.precaucion,
      'Hojas picadas como complemento, en poca cantidad.'),

  // Animal con animal
  Sinergia('conejo', 'gallina', TipoSinergia.precaucion,
      'Pueden compartir la granja, pero no la jaula: las gallinas picotean y pueden contagiarles enfermedades.'),
  Sinergia('gallina', 'codorniz', TipoSinergia.precaucion,
      'Alójalas por separado: las gallinas las dominan y comparten enfermedades.'),
];

// ---------------------------------------------------------------------------
// FUNCIONES DE BÚSQUEDA
// ---------------------------------------------------------------------------

Entrada? entradaPorId(String id) {
  for (final e in entradas) {
    if (e.id == id) return e;
  }
  return null;
}

/// Todas las sinergias de una ficha, junto con la otra ficha relacionada.
List<(Sinergia, Entrada)> sinergiasDe(String id) {
  final resultado = <(Sinergia, Entrada)>[];
  for (final s in sinergias) {
    if (s.a != id && s.b != id) continue;
    final otra = entradaPorId(s.a == id ? s.b : s.a);
    if (otra != null) resultado.add((s, otra));
  }
  return resultado;
}
