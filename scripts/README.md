# Scripts de desarrollo / herramientas one-off

Estos scripts **no forman parte de la app** (no están en `lib/` ni se compilan en el APK).
Son utilidades de línea de comandos para trabajar con el cancionero ChordPro.

## Scripts disponibles

### `verificar_cancionero.dart`
Verifica todos los archivos `.cho` de una carpeta contra el formato canónico de SongKey.

**Uso:**
```bash
dart run scripts/verificar_cancionero.dart [carpeta]
```

**Qué revisa:**
- Idempotencia: `texto → modelo → texto` debe dar igual
- Problemas de parseo (directivas desconocidas, corchetes sin cerrar, etc.)
- Secciones vacías (sin letra ni acordes)
- Canciones sin título detectado
- Acordes que el parser no reconoce
- Estadísticas: secciones, líneas, acordes totales

**Ejemplo:**
```bash
dart run scripts/verificar_cancionero.dart C:\Users\josue\Downloads\cancionero_chordpro\word_revisado
```

---

### `import_cancionero.dart`
Convierte un cancionero de archivos `.cho` en un **JSON importable** por Songkey (Ajustes → Biblioteca → Importar biblioteca).

**Uso:**
```bash
dart run scripts/import_cancionero.dart [--literal] [carpeta] [salida.json] [salida_reporte.txt]
```

**Modos:**
- **Normal (por defecto):** Extrae `{title:}`, `{key:}`, convierte `{start_of_X:}`/{`end_of_X`} a cabeceras limpias, elimina directivas no reconocidas, conserva letra y acordes.
- **Literal (`--literal`):** Cuerpo = texto CRUDO del `.cho` (menos `{title:}`/{`key:`}). La app mostrará las directivas como texto visible y **no detectará secciones** (chips/mapa).

**Qué hace:**
- Descarta copias con letra idéntica (por hash de letra pura)
- Marca títulos iguales con letra distinta (se conservan todas)
- Detecta títulos parecidos (Levenshtein ≤ 2 o contención)
- Avisa si ya existen en la biblioteca de ejemplo (`lib/data/seed.dart`)

**Ejemplos:**
```bash
# Modo normal
dart run scripts/import_cancionero.dart ^
  C:\Users\josue\Downloads\cancionero_chordpro\word_revisado ^
  C:\Users\josue\Downloads\Songkey_cancionero_nuevas.json ^
  C:\Users\josue\Downloads\cancionero_revisado.txt

# Modo literal
dart run scripts/import_cancionero.dart --literal ^
  C:\Users\josue\Downloads\cancionero_chordpro\word_revisado ^
  C:\Users\josue\Downloads\Songkey_cancionero_literal.json ^
  C:\Users\josue\Downloads\cancionero_revisado_literal.txt
```

**Salida:**
- `salida.json` → JSON listo para importar en Songkey
- `salida_reporte.txt` → Informe legible con resumen, descartadas, duplicados, similares, ya en seed

---

### `generar_pdf_ejemplo.dart`
Genera `docs/ejemplo_pdf_valido.pdf`, un PDF de muestra con el formato que espera el importador PDF → ChordPro de la app.

**Uso:**
```bash
dart run scripts/generar_pdf_ejemplo.dart
```

**El PDF incluye:**
- Texto real (no escaneado), fuentes Helvetica/Helvetica-Bold
- Acordes **justo encima de la letra**, alineados por X sobre la sílaba
- Encabezados de sección reconocidos: `INTRODUCCIÓN:`, `VERSO 1`, `PRECORO`, `CORO`, `PUENTE`, `FINAL`
- Una progresión sola con barras (`|`) que el importador convierte a acordes
- Un número de página (solo dígitos) que el importador debe filtrar

**Salida:** `docs/ejemplo_pdf_valido.pdf`

**Nota:** Este PDF se usa en `test/pdf_chordpro/ejemplo_pdf_test.dart`. Si se borra, regenerarlo con este script antes de ejecutar tests.

---

## Requisitos
- Solo usan `dart:core`, `dart:io`, `dart:convert`, `dart:typed_data` (sin Flutter).
- Ejecutables con `dart run scripts/<script>.dart`.

## Rutas por defecto
Los scripts usan rutas del usuario actual (`C:\Users\josue\Downloads\...`) como fallback si no se pasan argumentos. Ajusta según tu entorno.