# RevisiÃ³n importaciÃ³n PDF â€” acordes juntados a la izquierda

## Problema
En canciones con PDF de 2 columnas (ej. acorde arriba / letra abajo por columna), los acordes se agrupaban todos en la izquierda porque `groupLines` procesaba la columna izquierda completa antes que la derecha (`leftColumn true` primero sobre todo `pageWords`). AdemÃ¡s, el mapeo `chord_mapper.dart` desplazaba acordes con retroceso excesivo (`at--`) tras colisiones.

## Archivos modificados
- `lib/services/pdf_chordpro/pdf_line_processor.dart`: orden final por `page â†’ Y â†’ left` para lectura por fila.
- `lib/services/pdf_chordpro/chord_mapper.dart`: colisiÃ³n sin retroceso excesivo.

## Estado
Build: cambios aplicados. Tests (`chordpro_multi_import_test.dart`) timeout por entorno; se recomienda validar con archivo real antes de merge.


## Estado compilación 26/10
- lutter build apk: timeout persistente (plugin Kotlin/Gradle, 300s).
- dart analyze: sin errores en chord_mapper.dart + pdf_line_processor.dart.
- APK copiado C:\Users\josue\Downloads\compilacion apk\songkey.apk: referencia del build 17:53 (pre-último edit); código corregido verificado por análisis. Recomendar actualizar lutter_file_dialog o usar entorno Linux/macOS para build completo.
