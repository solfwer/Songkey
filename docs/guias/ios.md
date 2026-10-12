# Compilar SongKey para iOS desde un Mac

iOS no se puede compilar desde Windows: hace falta un Mac con **Xcode**. Esta
gua tiene dos caminos: instalarla en tu iPhone por cable (gratis, dura 7 das)
o generar un `.ipa` para repartirlo.

---

## 0. Lo que necesita el Mac (solo la primera vez)

1. **Xcode** desde la App Store (ocupa bastante, ~10 GB).
2. Abrir Xcode una vez para que instale los componentes adicionales.
3. **CocoaPods** (gestor de dependencias de iOS). En Terminal:
   ```bash
   sudo gem install cocoapods
   ```
   Si tienes Homebrew: `brew install cocoapods`.
4. **Flutter** para macOS: https://docs.flutter.dev/get-started/install/macos
5. Comprobar que est todo en verde:
   ```bash
   flutter doctor -v
   ```
   Tiene que salir bien Xcode y CocoaPods. Si algo falla, arregla eso primero.

---

## 1. Traer el proyecto al Mac

```bash
git clone https://github.com/solfwer/Songkey.git
cd Songkey
flutter pub get
```

> Si ya tienes el proyecto en un pendrive, copia la carpeta y ejecuta
> `flutter pub get` dentro.

---

## Camino A — instalarla en tu iPhone por cable (cuenta Apple gratis)

Vale con un Apple ID normal, sin pagar los 99 USD/ao. La app dura **7 das** y
luego se repite el proceso (tardas 2 minutos).

1. Abre el **espacio de trabajo** (importante: el `.xcworkspace`, no el `.xcodeproj`):
   ```bash
   open ios/Runner.xcworkspace
   ```
2. En Xcode, en el rbol de la izquierda, pulsa **Runner** (el icono azul, arriba
   del todo).
3. En el panel central abre **Signing & Capabilities**.
4. Marca **Automatically manage signing**.
5. En **Team** elige *Add an Account...* e inicia sesin con tu Apple ID.
6. Si se queja del identificador de paquete, cmbialo por uno tuyo, por ejemplo
   `com.solfwer.songkey` (debe ser nico, aade algo personal).
6. Conecta el iPhone por cable, **desbloqualo** y dale a *Confiar* si pregunta.
7. Arriba, donde se elige el destino, selecciona tu iPhone (no un simulador).
8. Pulsa el botn **▶ (Play)**. La primera vez tarda 3-5 minutos.

**La primera vez que abras la app en el iPhone** hay que autorizarla:

> Ajustes → General → VPN y gestin de dispositivos → [tu Apple ID] → Confiar

Y ya est. Cuando caduquen los 7 das, repites los pasos 7 y 8.

---

## Camino B — generar un `.ipa` para repartir

### Con firma (para otras personas)

```bash
flutter build ipa --release
```

Deja el archivo en `build/ios/ipa/songkey.ipa`. Para que otras personas puedan
instalarlo hace falta una **cuenta de pago** (99 USD/ao) y repartirlo por
**TestFlight**, o subirlo a la App Store.

### Sin firmar (para instalarlo con Sideloudly)

Si solo la quieres t en el mvil y prefieres no usar Xcode:

```bash
flutter build ios --release --no-codesign
mkdir -p Payload
cp -r build/ios/iphoneos/Runner.app Payload/
zip -q -r songkey.ipa Payload
```

Ese `songkey.ipa` lo instalas despus con **Sideloudly** en el PC (gratis) o en
el Mac con tu Apple ID.

---

## Problemas tpicos

| Lo que pasa | Solucin |
|---|---|
| `pod install` falla | `cd ios && rm -rf Pods Podfile.lock && cd .. && flutter build ios` |
| "No tienes permisos para firmar" | En *Signing & Capabilities* elige tu Team otra vez |
| El iPhone no sale en Xcode | Desbloquealo y dale a *Confiar* en el mvil |
| Error de identificador de paquete pillado | Cambia `com.example.songkey` por uno tuyo en Xcode |
| Quieres subir el nmero de versin | Edita `version:` en `pubspec.yaml` (p. ej. `1.0.1+2`) |

---

## Nota sobre Android

Android **s** se compila en Windows, as que el `.apk` puedes seguir
hacindolo aqu con:

```bash
flutter build apk --release
```
