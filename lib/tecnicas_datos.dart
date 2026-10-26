// U Farm - Técnicas de plantación
//
// 1. Datos de siembra de cada cultivo (método, profundidad, distancia,
//    germinación y trasplante). Se muestran en la ficha del cultivo.
// 2. Guías paso a paso de técnicas generales. Se muestran en la pestaña
//    "Técnicas" de la enciclopedia.
//
// Los "id" deben coincidir con los de enciclopedia_datos.dart.

// ---------------------------------------------------------------------------
// DATOS DE SIEMBRA POR CULTIVO
// ---------------------------------------------------------------------------

class DatosSiembra {
  final String metodo;
  final String profundidad;
  final String distancia;
  final String germinacion;
  final String? trasplante; // null si se siembra directo
  final String consejo;

  const DatosSiembra({
    required this.metodo,
    required this.profundidad,
    required this.distancia,
    required this.germinacion,
    this.trasplante,
    required this.consejo,
  });
}

const Map<String, DatosSiembra> datosSiembra = {
  'tomate': DatosSiembra(
    metodo: 'Almácigo y trasplante',
    profundidad: '0.5 cm',
    distancia: '40 a 60 cm',
    germinacion: '5 a 10 días',
    trasplante: 'A las 4-6 semanas, con 4 a 6 hojas verdaderas',
    consejo: 'Al trasplantar, entierra parte del tallo: echa raíces nuevas y la planta queda más firme.',
  ),
  'lechuga': DatosSiembra(
    metodo: 'Almácigo o directa',
    profundidad: '0.3 a 0.5 cm (apenas cubierta)',
    distancia: '20 a 30 cm',
    germinacion: '4 a 7 días',
    trasplante: 'A las 3-4 semanas',
    consejo: 'Germina mal con más de 27 °C. En días calurosos, siembra en un lugar fresco y sombreado.',
  ),
  'zanahoria': DatosSiembra(
    metodo: 'Siembra directa (no aguanta el trasplante)',
    profundidad: '0.5 a 1 cm',
    distancia: 'Aclarar a 5 cm',
    germinacion: '10 a 21 días',
    consejo: 'Mezcla la semilla con arena para repartirla mejor. Cubre con un costal húmedo hasta que germine.',
  ),
  'papa': DatosSiembra(
    metodo: 'Directa, con papa-semilla',
    profundidad: '10 cm',
    distancia: '30 cm',
    germinacion: 'Brota en 2 a 4 semanas',
    consejo: 'Usa papa-semilla certificada; las del súper pueden traer inhibidores de brotación. '
        'Si cortas trozos, que tengan 2 o 3 "ojos" y déjalos secar 1 o 2 días antes de sembrar.',
  ),
  'chile': DatosSiembra(
    metodo: 'Almácigo y trasplante',
    profundidad: '0.5 cm',
    distancia: '40 a 50 cm',
    germinacion: '7 a 14 días (necesita calor)',
    trasplante: 'A las 6-8 semanas',
    consejo: 'Germina lento y necesita más de 24 °C. Pon el almácigo en el lugar más cálido del invernadero.',
  ),
  'calabacita': DatosSiembra(
    metodo: 'Siembra directa',
    profundidad: '2 a 3 cm',
    distancia: 'Alrededor de 1 m',
    germinacion: '5 a 10 días',
    consejo: 'Pon 2 o 3 semillas por hoyo y deja solo la plántula más fuerte. '
        'Si usas almácigo, siembra en vasos biodegradables: su raíz se daña fácil.',
  ),
  'frijol': DatosSiembra(
    metodo: 'Siembra directa',
    profundidad: '3 a 4 cm',
    distancia: '10 a 15 cm',
    germinacion: '5 a 10 días',
    consejo: 'No lo siembres en tierra fría o encharcada: la semilla se pudre.',
  ),
  'maiz': DatosSiembra(
    metodo: 'Siembra directa',
    profundidad: '3 a 5 cm',
    distancia: '25 a 30 cm entre plantas, 60 a 75 cm entre filas',
    germinacion: '5 a 10 días',
    consejo: 'Siembra en bloque de varias filas cortas para que se polinice bien.',
  ),
  'cebolla': DatosSiembra(
    metodo: 'Almácigo y trasplante',
    profundidad: '0.5 a 1 cm',
    distancia: '10 cm',
    germinacion: '7 a 14 días',
    trasplante: 'A las 8-10 semanas, cuando tenga el grosor de un lápiz',
    consejo: 'También puedes plantar cebollín o bulbos pequeños directo: es más rápido.',
  ),
  'rabano': DatosSiembra(
    metodo: 'Siembra directa',
    profundidad: '1 cm',
    distancia: '5 cm',
    germinacion: '3 a 7 días',
    consejo: 'Perfecto para enseñar a sembrar: en menos de una semana ya se ven las plántulas.',
  ),
  'espinaca': DatosSiembra(
    metodo: 'Siembra directa',
    profundidad: '1 a 1.5 cm',
    distancia: '10 a 15 cm',
    germinacion: '7 a 14 días',
    consejo: 'Germina mal con más de 25 °C; espera a que refresque.',
  ),
  'cilantro': DatosSiembra(
    metodo: 'Siembra directa (no le gusta el trasplante)',
    profundidad: '1 cm',
    distancia: '5 a 10 cm',
    germinacion: '7 a 14 días',
    consejo: 'Cada "semilla" es un fruto con dos semillas dentro. Presiónala suavemente para partirla y germinará mejor.',
  ),
  'albahaca': DatosSiembra(
    metodo: 'Almácigo, directa o esquejes',
    profundidad: '0.3 a 0.5 cm',
    distancia: '25 a 30 cm',
    germinacion: '5 a 10 días',
    trasplante: 'A las 4-6 semanas',
    consejo: 'También se reproduce fácil con esquejes en un vaso con agua.',
  ),
  'calendula': DatosSiembra(
    metodo: 'Siembra directa o almácigo',
    profundidad: '0.5 a 1 cm',
    distancia: '25 cm',
    germinacion: '7 a 14 días',
    trasplante: 'A las 4-5 semanas',
    consejo: 'Si dejas algunas flores secarse en la planta, se resiembra sola.',
  ),
  'capuchina': DatosSiembra(
    metodo: 'Siembra directa',
    profundidad: '2 cm',
    distancia: '25 a 30 cm',
    germinacion: '7 a 14 días',
    consejo: 'Remoja la semilla de 12 a 24 horas antes de sembrar para que germine más rápido.',
  ),
  'alfalfa': DatosSiembra(
    metodo: 'Siembra directa al voleo',
    profundidad: '0.5 a 1 cm',
    distancia: 'Esparcida, sin distancia fija',
    germinacion: '3 a 7 días',
    consejo: 'Esparce la semilla, pasa un rastrillo ligero para cubrirla y apisona con una tabla.',
  ),
};

// ---------------------------------------------------------------------------
// GUÍAS DE TÉCNICAS
// ---------------------------------------------------------------------------

class Tecnica {
  final String id;
  final String titulo;
  final String emoji;
  final String resumen;
  final List<String> materiales;
  final List<String> pasos;
  final List<String> consejos;
  final List<String> sirvePara; // ids de fichas

  const Tecnica({
    required this.id,
    required this.titulo,
    required this.emoji,
    required this.resumen,
    this.materiales = const [],
    required this.pasos,
    this.consejos = const [],
    this.sirvePara = const [],
  });
}

const List<Tecnica> tecnicas = [
  Tecnica(
    id: 'almacigo',
    titulo: 'Hacer un almácigo',
    emoji: '🌱',
    resumen: 'Germinar semillas en un semillero protegido antes de llevarlas a su lugar definitivo.',
    materiales: [
      'Charola de germinación o vasos con agujeros abajo',
      'Sustrato ligero: fibra de coco o turba, composta cernida y perlita o vermiculita',
      'Atomizador',
      'Plástico transparente o tapa',
    ],
    pasos: [
      'Llena las celdas con sustrato húmedo, sin apretarlo.',
      'Pon 2 o 3 semillas por celda, a una profundidad de 2 o 3 veces su tamaño (revisa la ficha del cultivo).',
      'Cubre con un poco de sustrato y humedece con el atomizador.',
      'Tapa con plástico para conservar la humedad y deja en un lugar cálido.',
      'En cuanto germinen, quita el plástico y dales luz. Sin luz se estiran y se debilitan.',
      'Cuando tengan 2 hojas verdaderas, deja solo la plántula más fuerte de cada celda (corta las demás con tijera).',
      'Riega desde abajo o con atomizador para no tumbarlas.',
    ],
    consejos: [
      'Etiqueta cada charola con el cultivo y la fecha.',
      'Las primeras dos hojas (cotiledones) no cuentan como hojas verdaderas.',
    ],
    sirvePara: ['tomate', 'chile', 'lechuga', 'cebolla', 'albahaca', 'calendula'],
  ),
  Tecnica(
    id: 'trasplante',
    titulo: 'Trasplantar una plántula',
    emoji: '🪴',
    resumen: 'Pasar la plántula del almácigo a la tierra sin estresarla.',
    pasos: [
      'Endurecimiento: de 7 a 10 días antes, saca el almácigo al sol y al aire 1 o 2 horas al día, aumentando el tiempo poco a poco.',
      'Trasplanta por la tarde o en un día nublado.',
      'Riega el almácigo una hora antes para que el cepellón (la tierra con raíz) salga entero.',
      'Haz un hoyo un poco más grande que el cepellón.',
      'Saca la plántula empujando desde abajo. Si tienes que sujetarla, tómala de las hojas, nunca del tallo.',
      'Colócala, rellena con tierra y presiona suavemente alrededor.',
      'Riega bien y dale media sombra durante 2 o 3 días.',
    ],
    consejos: [
      'El tomate se puede enterrar más profundo que como estaba; casi ninguna otra planta lo aguanta.',
      'Es normal que se vea un poco decaída el primer día.',
    ],
    sirvePara: ['tomate', 'chile', 'lechuga', 'cebolla', 'albahaca', 'calendula'],
  ),
  Tecnica(
    id: 'directa',
    titulo: 'Siembra directa y aclareo',
    emoji: '🫳',
    resumen: 'Sembrar la semilla en su lugar definitivo y después dejar solo las mejores plantas.',
    pasos: [
      'Afloja la tierra y quita piedras y terrones hasta que quede fina.',
      'Haz un surco con la profundidad que indica la ficha del cultivo.',
      'Siembra las semillas a lo largo del surco, un poco más juntas de lo necesario.',
      'Cubre, presiona ligeramente con la mano y riega con una regadera de chorro fino.',
      'Mantén la tierra húmeda hasta que germinen.',
      'Aclareo: cuando tengan 2 hojas verdaderas, deja la distancia indicada en la ficha. Corta las sobrantes con tijera en lugar de arrancarlas, para no dañar las raíces de las vecinas.',
    ],
    sirvePara: [
      'zanahoria', 'rabano', 'cilantro', 'espinaca', 'frijol', 'maiz',
      'calabacita', 'capuchina', 'alfalfa', 'calendula', 'lechuga',
    ],
  ),
  Tecnica(
    id: 'escalonada',
    titulo: 'Siembra escalonada',
    emoji: '📅',
    resumen: 'Sembrar poco y seguido para cosechar todo el tiempo en lugar de todo de golpe.',
    pasos: [
      'Calcula cuánto consumes por semana (por ejemplo, 3 lechugas).',
      'Siembra solo esa cantidad, más un par de extra por si alguna falla.',
      'Repite la siembra cada 2 o 3 semanas mientras dure la temporada.',
    ],
    consejos: [
      'Anota la fecha de cada siembra para saber cuándo toca la siguiente.',
    ],
    sirvePara: ['lechuga', 'cilantro', 'rabano', 'espinaca'],
  ),
  Tecnica(
    id: 'aporcar',
    titulo: 'Aporcar',
    emoji: '⛰️',
    resumen: 'Arrimar tierra a la base de la planta para darle firmeza y más espacio para producir.',
    pasos: [
      'Cuando la planta mida de 15 a 20 cm, junta tierra alrededor del tallo dejando libres las hojas de arriba.',
      'Repite 2 o 3 veces mientras crece.',
      'Papa en costal: empieza con 15 cm de tierra y ve agregando más conforme crece la planta, hasta llenar el costal.',
    ],
    consejos: [
      'En la papa evita que los tubérculos queden expuestos al sol: se ponen verdes y tóxicos.',
    ],
    sirvePara: ['papa', 'maiz'],
  ),
  Tecnica(
    id: 'tutorar',
    titulo: 'Tutorar y podar',
    emoji: '🪵',
    resumen: 'Dar soporte a las plantas que crecen hacia arriba y guiar su crecimiento.',
    materiales: [
      'Estacas, jaulas de alambre o hilo de rafia colgado del techo',
      'Material suave para amarrar (tiras de tela, rafia)',
    ],
    pasos: [
      'Pon el tutor al momento del trasplante, para no lastimar las raíces después.',
      'Amarra el tallo al tutor en forma de 8, flojo, para no estrangularlo.',
      'Ve amarrando cada 20 o 30 cm conforme crece.',
      'Tomate: quita los chupones (brotes entre el tallo y las ramas) cuando midan menos de 5 cm, con los dedos.',
      'Quita las hojas de abajo que toquen la tierra; por ahí entran enfermedades.',
    ],
    consejos: [
      'Con hilo colgado del techo se aprovecha la altura de la estructura de U Farm.',
    ],
    sirvePara: ['tomate', 'frijol', 'chile'],
  ),
  Tecnica(
    id: 'acolchado',
    titulo: 'Acolchado',
    emoji: '🍂',
    resumen: 'Cubrir la tierra con material seco para conservar la humedad. Muy útil en el verano de Monterrey.',
    materiales: ['Paja, hojas secas, pasto seco o cascarilla'],
    pasos: [
      'Riega bien antes de acolchar.',
      'Extiende una capa de 5 a 8 cm sobre la tierra.',
      'Deja unos centímetros libres alrededor de cada tallo para que no se pudra.',
      'Repón el material conforme se vaya descomponiendo.',
    ],
    consejos: [
      'Reduce el riego, frena la maleza y mantiene la tierra más fresca.',
      'La paja usada de la cama de los conejos sirve como acolchado y abono a la vez.',
    ],
    sirvePara: ['tomate', 'chile', 'calabacita', 'papa'],
  ),
  Tecnica(
    id: 'composta',
    titulo: 'Composta con estiércol',
    emoji: '♻️',
    resumen: 'Convertir el estiércol y los restos del huerto en abono seguro.',
    materiales: [
      'Compostero o un rincón de 1 m × 1 m',
      'Material "verde": estiércol y restos de verdura',
      'Material "café": hojas secas, paja, cartón sin tinta',
    ],
    pasos: [
      'Alterna capas: por cada parte de material verde, pon de 2 a 3 partes de material café.',
      'Humedece hasta que se sienta como una esponja exprimida.',
      'Voltea la pila cada 1 o 2 semanas para que le entre aire.',
      'Está lista en 2 a 3 meses, cuando huele a tierra de bosque y ya no se distinguen los materiales.',
    ],
    consejos: [
      'El estiércol de conejo se puede usar directo, pero en la composta también ayuda a que se caliente y avance más rápido.',
      'El de gallina y codorniz siempre debe compostarse antes de usarlo.',
      'Si huele mal, le falta material café o aire.',
    ],
    sirvePara: ['conejo', 'gallina', 'codorniz'],
  ),
  Tecnica(
    id: 'rotacion',
    titulo: 'Rotación de cultivos',
    emoji: '🔄',
    resumen: 'Cambiar de lugar los cultivos cada temporada para que el suelo no se agote y las plagas no se acumulen.',
    pasos: [
      'Divide el huerto en 4 zonas.',
      'Zona 1, leguminosas: frijol (dejan nitrógeno en la tierra).',
      'Zona 2, hojas: lechuga, espinaca, cilantro (aprovechan ese nitrógeno).',
      'Zona 3, frutos: tomate, chile, calabacita.',
      'Zona 4, raíces y tubérculos: zanahoria, rábano, cebolla, papa.',
      'Cada temporada, mueve cada grupo a la zona siguiente.',
    ],
    consejos: [
      'Nunca sigas tomate con papa o chile en el mismo lugar: son de la misma familia.',
    ],
    sirvePara: ['frijol', 'lechuga', 'tomate', 'chile', 'papa', 'zanahoria'],
  ),
  Tecnica(
    id: 'vertical',
    titulo: 'Cultivo vertical',
    emoji: '🧱',
    resumen: 'Cultivar hacia arriba para aprovechar paredes y poco espacio, como en la ciudad.',
    materiales: [
      'Torres, tubos de PVC con hoyos, bolsas colgantes o tarimas',
      'Riego por goteo (opcional)',
    ],
    pasos: [
      'Elige plantas pequeñas y de raíz poco profunda: lechuga, espinaca, cilantro, albahaca, capuchina.',
      'Orienta la estructura hacia el sur, que es de donde viene el sol en México.',
      'Pon arriba las plantas que necesitan menos agua y abajo las que necesitan más: el agua escurre hacia abajo.',
      'Riega de arriba hacia abajo y revisa que la parte alta no se seque.',
    ],
    consejos: [
      'No sirve para plantas grandes o pesadas como maíz, calabacita o papa.',
    ],
    sirvePara: ['lechuga', 'espinaca', 'cilantro', 'albahaca', 'capuchina'],
  ),
  Tecnica(
    id: 'hidroponia',
    titulo: 'Hidroponía de raíz flotante',
    emoji: '💧',
    resumen: 'Cultivar sin tierra, con las raíces en agua con nutrientes. Fácil de conectar con los sensores de la app.',
    materiales: [
      'Contenedor opaco (la luz hace crecer algas)',
      'Placa de unicel con hoyos',
      'Vasitos con esponja o lana de roca',
      'Solución nutritiva hidropónica (A y B)',
      'Bomba de aire de pecera',
      'Medidor de pH',
    ],
    pasos: [
      'Llena el contenedor con agua y agrega la solución nutritiva según su etiqueta.',
      'Ajusta el pH entre 5.5 y 6.5.',
      'Pon la bomba de aire para oxigenar las raíces.',
      'Coloca las plántulas en los vasitos y los vasitos en los hoyos del unicel, flotando.',
      'Revisa el pH cada semana y cambia la solución cada 2 o 3 semanas.',
    ],
    consejos: [
      'Ideal para lechuga, albahaca y espinaca.',
      'Un sensor de pH o de temperatura del agua conectado a la ESP32 puede avisar en la app.',
    ],
    sirvePara: ['lechuga', 'albahaca', 'espinaca'],
  ),
  Tecnica(
    id: 'esquejes',
    titulo: 'Reproducir con esquejes',
    emoji: '✂️',
    resumen: 'Sacar plantas nuevas de un pedazo de tallo, sin semillas.',
    pasos: [
      'Corta una punta de tallo de 10 a 15 cm, justo debajo de un nudo (donde salen las hojas).',
      'Quita las hojas de la mitad de abajo.',
      'Ponlo en un vaso con agua (cámbiala cada 2 o 3 días) o en sustrato húmedo.',
      'En 1 a 3 semanas salen raíces.',
      'Cuando las raíces midan de 2 a 5 cm, plántalo.',
    ],
    consejos: [
      'Funciona muy bien con albahaca y con otras hierbas como hierbabuena y romero.',
    ],
    sirvePara: ['albahaca'],
  ),
  Tecnica(
    id: 'polinizacion',
    titulo: 'Polinización manual',
    emoji: '🐝',
    resumen: 'Ayudar a las flores a dar fruto cuando dentro de la estructura hay pocos insectos.',
    pasos: [
      'Calabacita: distingue la flor hembra (tiene una calabacita pequeña en la base) de la macho (solo un tallo delgado).',
      'Temprano en la mañana, cuando estén abiertas, pasa polen de la flor macho al centro de la hembra con un pincel.',
      'Tomate y chile: sus flores se polinizan solas, pero necesitan movimiento. Sacude suavemente la planta o el tutor a media mañana.',
    ],
    consejos: [
      'Sembrar caléndula y capuchina cerca atrae polinizadores naturales.',
    ],
    sirvePara: ['calabacita', 'tomate', 'chile'],
  ),
];

// ---------------------------------------------------------------------------
// FUNCIONES DE BÚSQUEDA
// ---------------------------------------------------------------------------

List<Tecnica> tecnicasPara(String id) =>
    tecnicas.where((t) => t.sirvePara.contains(id)).toList();
