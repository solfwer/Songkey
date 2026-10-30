// Área legal de Songkey: aviso legal y política de privacidad.
//
// IMPORTANTE: antes de publicar en la Play Store, reemplaza [legalContact]
// por un correo real que uses para consultas y solicitudes de retiro de
// contenido, y revisa los textos con quien necesites (los textos son una
// base razonable, no asesoría legal).
import 'package:flutter/material.dart';

import '../../theme.dart';

/// Correo de contacto para asuntos legales (aviso de retiro de contenido,
/// preguntas de privacidad). CAMBIA ESTE VALOR.
const String legalContact = 'contacto@tudominio.com';

enum LegalTopic { aviso, privacidad }

extension LegalTopicInfo on LegalTopic {
  String get title => switch (this) {
        LegalTopic.aviso => 'Aviso legal',
        LegalTopic.privacidad => 'Política de privacidad',
      };

  List<String> get body => switch (this) {
        LegalTopic.aviso => const [
            'Songkey es una aplicación de apoyo para músicos: permite guardar '
                'canciones con letra y acordes, organizar setlists y exportar '
                'material de ensayo para uso personal.',
            'Derechos sobre las letras y los acordes',
            'Las letras, traducciones, arreglos y acordes incluidos en la '
                'biblioteca de canciones pertenecen a sus respectivos autores, '
                'compositores y editores. Songkey no está afiliado ni patrocinado '
                'por dichos autores, y el material se facilita para uso personal '
                'y de ensayo.',
            'Si eres titular de los derechos de alguna obra incluida y deseas '
                'que se retire o se corrija su atribución, escríbenos a '
                '$legalContact indicando qué contenido corresponde y lo '
                'retiraremos en un plazo razonable.',
            'Marcas',
            'Los nombres de productos, servicios y marcas citados en la app '
                '(por ejemplo, Syncfusion) pertenecen a sus respectivos '
                'titulares.',
            'Licencias de código abierto',
            'Songkey usa componentes de código abierto cuyas licencias se '
                'pueden consultar en Ajustes > Legal > Licencias de código '
                'abierto. El componente de generación de PDF (Syncfusion '
                'Flutter PDF) se utiliza bajo los términos de su propio '
                'acuerdo de licencia.',
            'Detección de tono',
            'La tonalidad sugerida se calcula en tu dispositivo a partir de '
                'los acordes de la canción. Es solo una sugerencia y puedes '
                'cambiarla en cualquier momento.',
            'Responsabilidad',
            'La aplicación se ofrece "tal cual", sin garantías de ningún '
                'tipo. No nos hacemos responsables del uso que se dé al '
                'material exportado o compartido desde la app.',
            'Contacto legal',
            legalContact,
          ],
        LegalTopic.privacidad => const [
            'Última actualización: octubre de 2026',
            'Qué datos tratamos',
            'Songkey no exige cuenta en línea ni conexión a servidores. Los '
                'únicos datos que guarda son los que tú introduces, y se '
                'almacenan exclusivamente en tu dispositivo:',
            '• Canciones, grupos y setlists que creas.\n'
                '• El nombre de perfil y el acceso local (usuario y '
                'contraseña) que configures en la app.',
            'Cómo se almacenan',
            'Los datos se guardan localmente en el almacenamiento de la '
                'aplicación. No se transmiten, sincronizan ni comparten con '
                'terceros en ningún momento.',
            'Compartir y exportar',
            'Al usar las funciones de compartir o exportar (texto o PDF), los '
                'archivos se generan en tu dispositivo y salen de él '
                'únicamente a través del mecanismo de compartir de tu sistema '
                'operativo; el destinatario lo eliges tú.',
            'Supresión de datos',
            'Puedes borrar todos los datos en cualquier momento desde '
                'Ajustes (Restablecer datos de ejemplo o Eliminar cuenta '
                'local), o desinstalando la aplicación.',
            'Contacto',
            'Para preguntas sobre privacidad puedes escribir a '
                '$legalContact.',
          ],
      };
}

/// Pantalla con un documento legal (aviso o privacidad).
class LegalScreen extends StatelessWidget {
  final LegalTopic topic;
  const LegalScreen({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    final body = topic.body;
    return Scaffold(
      appBar: AppBar(title: Text(topic.title), elevation: 0),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: body.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, i) {
          // Los títulos de sección van en negrita/accent; el resto es texto.
          final text = body[i];
          final isHeading =
              i > 0 && !text.contains('\n') && text.length < 60 && !text.endsWith('.');
          return Text(
            text,
            style: isHeading
                ? const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  )
                : const TextStyle(fontSize: 14.5, height: 1.5),
          );
        },
      ),
    );
  }
}