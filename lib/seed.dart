import 'cancionero_data.dart';
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
      ...cancioneroSongs(),
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

