import 'models.dart';

AppState seedState() {
  return AppState(
    groups: [
      Group(id: 'g1', name: 'Alabanza Dominical', color: GroupColor.primary),
      Group(id: 'g2', name: 'Coro juvenil', color: GroupColor.accent),
      Group(id: 'g3', name: 'Acústico noche', color: GroupColor.warm),
    ],
    songs: [
      Song(id: 's1', title: 'Luz de la mañana', key: 'G', bpm: 72, groupId: 'g1', body: _s1),
      Song(id: 's2', title: 'Río en calma', key: 'D', bpm: 64, groupId: 'g3', body: _s2),
      Song(id: 's3', title: 'Somos uno', key: 'A', bpm: 118, groupId: 'g2', body: _s3),
      Song(id: 's4', title: 'Cielo nuevo', key: 'E', bpm: 76, groupId: 'g1', body: _s4),
      Song(id: 's5', title: 'Puertas abiertas', key: 'F', bpm: 96, groupId: 'g2', body: _s5),
      Song(id: 's6', title: 'En tu presencia', key: 'Bm', bpm: 58, groupId: 'g3', body: _s6),
      Song(id: 's7', title: 'Aleluya eterno', key: 'D', bpm: 110, groupId: 'g1', body: _s7),
      Song(id: 's8', title: 'Camino seguro', key: 'C', bpm: 80, groupId: 'g3', body: _s8),
      Song(id: 's9', title: 'Viento fresco', key: 'G', bpm: 104, groupId: 'g2', body: _s9),
      // Himnos tradicionales de dominio público (letras y traducciones antiguas,
      // derechos de autor expirados) para que haya repertorio inicial legal.
      Song(id: 's10', title: 'Sublime gracia', key: 'G', bpm: 66, groupId: 'g1', body: _pd1),
      Song(id: 's11', title: 'Santo, santo, santo', key: 'C', bpm: 78, groupId: 'g1', body: _pd2),
      Song(id: 's12', title: 'Oh qué amigo nos es Cristo', key: 'C', bpm: 84, groupId: 'g2', body: _pd3),
      Song(id: 's13', title: 'Noche de paz', key: 'G', bpm: 72, groupId: 'g3', body: _pd4),
      Song(id: 's14', title: 'Cristo me ama', key: 'C', bpm: 88, groupId: 'g2', body: _pd5),
      Song(id: 's15', title: 'Venid fieles todos', key: 'G', bpm: 100, groupId: 'g1', body: _pd6),
    ],
    setlists: [
      Setlist(
        id: 'l1',
        name: 'Domingo',
        date: DateTime.now().toIso8601String().substring(0, 10),
        groupId: 'g1',
        songIds: ['s1', 's7', 's3', 's2', 's4'],
        members: [
          Member(id: 'm1', name: 'María', role: 'voz', status: 'confirmado'),
          Member(id: 'm2', name: 'Jorge', role: 'guitarra', status: 'pendiente'),
        ],
      ),
      Setlist(
        id: 'l2',
        name: 'Viernes acústico',
        date: DateTime.now().toIso8601String().substring(0, 10),
        groupId: 'g3',
        songIds: ['s6', 's2', 's8'],
        members: [
          Member(id: 'm3', name: 'Lucía', role: 'voz', status: 'confirmado'),
        ],
      ),
      Setlist(
        id: 'l3',
        name: 'Juventud',
        date: DateTime.now().toIso8601String().substring(0, 10),
        groupId: 'g2',
        songIds: ['s9', 's5', 's3'],
        members: [],
      ),
    ],
  );
}

const _s1 = 'Verso 1\n'
    '[G]Cuando sale el [D]sol sobre el [Em]valle\n'
    '[C]todo vuelve a [G]comenzar\n'
    '[G]Mis pasos [D]lentos se [Em]levantan\n'
    '[C]tu voz me ense[D]na a caminar\n'
    '\n'
    'Coro\n'
    '[C]Luz de la ma[G]nana\n'
    '[D]llena mi ca[Em]sa\n'
    '[C]canto otra [G]vez\n'
    '[D]tu bondad no se a[G]caba\n';

const _s2 = 'Verso 1\n'
    'D          A          Bm\n'
    'Hay un río que corre en calma\n'
    'G               D\n'
    'lleva el agua a mi interior\n'
    '\n'
    'Coro\n'
    'G          D\n'
    'Río en calma, río en calma\n'
    'A                Bm\n'
    'llévame más cerca de ti\n'
    'G          D          A\n'
    'río en calma, en tu corriente\n'
    'quiero vivir\n'
    '\n'
    'Verso 2\n'
    'D          A          Bm\n'
    'Las piedras del camino ceden\n'
    'G               A\n'
    'el cansancio se queda atrás';

const _s3 = 'Intro\n'
    'A  E  F#m  D\n'
    '\n'
    'Verso 1\n'
    '[A]Mil voces [E]juntas a cantar\n'
    '[F#m]una can[D]ción sin final\n'
    '\n'
    'Pre-coro\n'
    '[D]Y no hay dis[E]tancia que nos pueda separar\n'
    '\n'
    'Coro\n'
    '[A]Somos uno, [E]somos uno\n'
    '[F#m]una familia, [D]un corazón\n'
    '[A]Somos uno, [E]somos uno\n'
    '[D]levantando [E]una misma [A]voz';

const _s4 = 'Verso 1\n'
    '[E]Baja el cielo, [B]abre el mar\n'
    '[C#m]todo lo viejo [A]se va\n'
    '[E]Una promesa [B]de verdad\n'
    '[A]renueva mi [E]alma\n'
    '\n'
    'Coro\n'
    '[E]Cielo nuevo, [B]tierra nueva\n'
    '[C#m]tu luz nos [A]guiará\n'
    '[E]Cielo nuevo, [B]tierra nueva\n'
    '[A]en ti vivire[E]mos\n';

const _s5 = 'Intro\n'
    'F  C  Dm  Bb\n'
    '\n'
    'Verso 1\n'
    '[F]Empujé la [C]puerta y entré\n'
    '[Dm]hoy no hay llaves que [Bb]me detengan\n'
    '[F]Tus brazos [C]amplios me reciben\n'
    '[Dm]y el miedo se [C]queda fuera\n'
    '\n'
    'Coro\n'
    '[F]Puertas abiertas, [C]cielo abierto\n'
    '[Dm]nada me puede [Bb]separar\n'
    '[F]Puertas abiertas, [C]camino cierto\n'
    '[Dm]tu gracia me [C]alcanzará\n';

const _s6 = 'Verso 1\n'
    '[Bm]En quietud [G]me postro ante ti\n'
    '[D]no hay prisa [A]en tu presencia aquí\n'
    '[Bm]Sólo tu [G]voz me basta ya\n'
    '[D]quiero es[A]cuchar tu voz\n'
    '\n'
    'Coro\n'
    '[Bm]En tu presencia [G]quiero quedarme\n'
    '[D]en tu presencia [A]quiero orar\n'
    '[Bm]En tu presencia [G]quiero cantar\n'
    '[D]tu nombre [A]exaltar\n';

const _s7 = 'Coro\n'
    '[D]Aleluya, aleluya eterno\n'
    '[A]aleluya al Rey de reyes\n'
    '[Bm]Aleluya, [G]aleluya eterno\n'
    '[D]cantamos hoy [A]a ú\n'
    '\n'
    'Verso 1\n'
    '[D]De generación [A]en generación\n'
    '[Bm]tu fidelidad [G]crece en mí\n'
    '[D]Y toda la [A]tierra cantará\n'
    '[G]tu grandeza, [D]Señor\n';

const _s8 = 'Verso 1\n'
    '[C]Cuando el camino se [G]tuerce\n'
    '[Am]y no sé bien a do[F]nde ir\n'
    '[C]Tus pasos me con[G]ducen\n'
    '[F]tu mano va con[G]migo\n'
    '\n'
    'Coro\n'
    '[F]Camino seguro [C]eres tú\n'
    '[G]roca firme de [Am]mi fe\n'
    '[F]Camino seguro [C]eres tú\n'
    '[Dm] en ti descansaré\n';

const _s9 = 'Intro\n'
    'G  D  Em  C\n'
    '\n'
    'Verso 1\n'
    '[G]Sopla un viento [D]que renueva\n'
    '[Em]seca el llanto y [C]trae vida\n'
    '[G]Sopla un viento [D]que transforma\n'
    '[Em]mi desierto en [C]primavera\n'
    '\n'
    'Coro\n'
    '[G]Viento fresco, [D]sopla en mí\n'
    '[Em]lléname de tu [C]poder\n'
    '[G]Viento fresco, [D]sopla en mí\n'
    '[Em]sé tú mi [C]todo ser\n';

// --- Himnos tradicionales de dominio público ---------------------------------
// Letras y traducciones antiguas (s. XVIII-XIX) con derechos de autor expirados.
// Los acordes son arreglos simples de referencia (progresiones funcionales).

const _pd1 = 'Verso 1\n'
    '[G]Sublime [C]gracia del [G]Señor\n'
    'que a un [D]infeliz sal[G]vó\n'
    '[G]fui ciego, [C]mas hoy veo [G]yo\n'
    'per[Em]dido y Él me [D]ha[G]lló\n'
    '\n'
    'Verso 2\n'
    '[G]La gracia [C]enseñó a mi [G]corazón\n'
    'a [D]temer la mal[G]dad\n'
    '[G]la gracia [C]mis temores [G]disipó\n'
    'y [D]cuán precioso [G]es su amor\n'
    '\n'
    'Verso 3\n'
    '[G]En los [C]peligros, aflicción y do[G]lor\n'
    'la [D]gracia me sostend[G]rá\n'
    '[G]y al dejar [C]este mundo mor[G]tal\n'
    'en el [Em]cielo he de [D]mo[G]rar\n';

const _pd2 = 'Coro\n'
    '[C]Santo, santo, [F]santo\n'
    '[C]Señor omni[G]potente\n'
    'siempre el [F]labio [C]mío [Am]loores te dar[G]á\n'
    '[C]Santo, santo, [F]santo\n'
    '[C]misericor[G]dioso y po[C]deroso\n'
    '[F]Dios en tres [C]personas, ben[G]dita [C]Trinidad\n'
    '\n'
    'Verso 1\n'
    '[C]Santo, santo, [F]santo\n'
    '[C]a los que te a[G]doran\n'
    'en tu [F]santo [C]templo con [Em]gozo los ver[G]ás\n'
    '[C]Santo, santo, [F]santo\n'
    '[C]misericor[G]dioso y po[C]deroso\n'
    '[F]Dios en tres [C]personas, ben[G]dita [C]Trinidad\n';

const _pd3 = 'Verso 1\n'
    '[C]Oh qué a[G7]migo nos es [C]Cristo\n'
    '[D7]él tomó mi [G7]culpa y do[D7]lor\n'
    '[C]es mi [F]amigo más sin[C]cero\n'
    '[G7]cuánta [F]paz me [C]da su [G7]amor\n'
    '\n'
    'Coro\n'
    '[C]¿Vives [F]débil y car[G7]gado?\n'
    '[C]no hay [F]amigo [G7]como [C]Él\n'
    '[C]no hay a[F]migo tan be[C]nigno\n'
    '[G7]no hay a[F]mor tan [C]dulce [G7]y [C]fiel\n';

const _pd4 = 'Verso 1\n'
    '[G]Noche de [D]paz, no[G]che de [C]amor\n'
    '[D]todo duer[G]me al re[D]dedor\n'
    '[C]entre los [G]astros que es[Em]parcen su [C]luz\n'
    '[G]bella anun[D]ciando al ni[G]ñito Je[Em]sús\n'
    '[C]brilla la [G]estrella de [D]paz\n'
    '[C]brilla la [G]estrella de [D]paz\n';

const _pd5 = 'Coro\n'
    '[C]Cristo me [G]ama, bien lo [C]sé\n'
    'su pa[F]labra me lo [G]hace ver\n'
    '[C]los pe[F]queños son de a[C]quel\n'
    '[G]Cristo me [C]ama, [G]él es [C]fiel\n'
    '\n'
    'Verso 1\n'
    '[C]Cristo me [G]ama, sí me [C]ama\n'
    '[F]Cristo me [G]ama, bien lo [C]sé\n'
    '[C]Cristo me [F]ama, sí me [C]ama\n'
    '[G]Cristo me [C]ama, [G]él es [C]fiel\n';

const _pd6 = 'Verso 1\n'
    '[G]Venid fieles [D]todos con [G]júbilo can[C]tad\n'
    '[G]venid, ven[D]id a [G]Belén\n'
    '[C]ved al Redentor, [Am]ved al Sal[D]vador\n'
    '\n'
    'Coro\n'
    '[G]Venid, ado[Em]remos, cada [C]fiel ado[G]remos\n'
    '[Em]venid, adoremos a [D]Cristo el Se[C]ñor\n'
    '[G]Venid, ado[Em]remos, cada [C]fiel ado[G]remos\n'
    '[Em]venid, adoremos a [D]Cristo el Se[G]ñor\n';

