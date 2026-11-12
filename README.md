# U Farm

Aplicación de la granja urbana U Farm. Equipo 2, Grupo 211.

## Contenido

| Carpeta | Qué hay |
|---|---|
| `lib/` | Código de la app (Flutter) |
| `hardware/` | Programas de Arduino para las placas ESP32: collar del ganado, receptor, riego y vidrios |
| `herramientas/` | Script que prepara la parte de Android |
| `.github/workflows/` | Compilación automática del APK en GitHub |

## Personalizar la app

Desde el engrane de la pantalla de inicio (**Ajustes**) se puede cambiar, sin tocar el código:

- el tema (claro u oscuro) y el color de los botones,
- qué tarjetas aparecen en el inicio, en qué orden y con qué nombre,
- los tiempos de los botones de "Regar ahora" y los botones rápidos del vidrio.

En la **Enciclopedia** se pueden agregar, editar y borrar fichas y sinergias. Todo esto se guarda en cada teléfono (`lib/ajustes.dart`); la enciclopedia original está en `lib/enciclopedia_datos.dart` y se puede restaurar desde Ajustes.

Para agregar otro color a la lista, copien una línea de `opcionesColor` en `lib/ajustes.dart`.

## Antes de compilar: configurar

1. **`lib/ganado.dart`**: `urlFirebase` es la URL de su Realtime Database de Firebase, sin "/" al final. La usan el ganado, el riego y los vidrios.
2. **`lib/clima.dart`**: cambien las coordenadas de `UbicacionGranja` por las del prototipo.

Pongan la misma URL de Firebase en los cuatro programas de la carpeta `hardware/`.

## Opción A: compilar en GitHub (sin instalar nada)

1. Creen una cuenta en [github.com](https://github.com) y un repositorio nuevo (puede ser privado).
2. Suban **todo el contenido** de esta carpeta, incluida la carpeta `.github`.
   - Desde la página: "Add file" → "Upload files" y arrastren las carpetas.
   - En Mac, la carpeta `.github` está oculta en Finder (Cmd + Shift + punto para verla). Si no se sube, créenla desde la página con "Add file" → "Create new file", escribiendo como nombre `.github/workflows/construir_apk.yml`, y peguen el contenido del archivo.
3. Entren a la pestaña **Actions**. La compilación arranca sola al subir los archivos; si no, elijan "Construir APK" → "Run workflow".
4. Cuando termine (unos 5-10 minutos, palomita verde), entren a la ejecución y descarguen **U-Farm-APK** en la sección "Artifacts". Viene dentro de un .zip.

Cada vez que cambien algo en el código y lo suban, se genera un APK nuevo.

## Opción B: compilar en su computadora

Necesitan [Flutter](https://docs.flutter.dev/get-started/install) y Android Studio instalados (`flutter doctor` debe salir sin errores en Android).

```
flutter pub get
dart run herramientas/preparar_android.dart
flutter build apk --release
```

El APK queda en `build/app/outputs/flutter-apk/app-release.apk`.

Para probar con un teléfono conectado por cable: `flutter run`.

## Instalar en el teléfono

1. Pasen el archivo `app-release.apk` al teléfono Android.
2. Ábranlo. Android pedirá permiso para "instalar apps de origen desconocido": acéptenlo para esa app (el explorador de archivos o el navegador).
3. Si Play Protect avisa que la app es desconocida, elijan "Instalar de todos modos". Es normal en apps que no vienen de la Play Store.

Este APK está firmado con una clave de prueba: sirve para instalarlo y presentarlo, pero no para publicarlo en la Play Store.

## Hardware

Cada programa de `hardware/` se abre con Arduino IDE (cada `.ino` debe quedar dentro de una carpeta con su mismo nombre, como ya están). Al inicio de cada archivo vienen el material, las conexiones y las librerías necesarias.

| Programa | Función |
|---|---|
| `prueba_bomba` | Prueba sin internet: enciende cada bomba 5 s y muestra las lecturas de los sensores de humedad (para calibrarlos) |
| `controlador_riego` | Riego de la maqueta: 2 zonas con minibombas, riegos de algunos segundos |
| `prueba_servo` | Prueba sin internet: deja el servo en 0° para montar el engrane, lo mueve por ángulos y muestra el sensor de lluvia |
| `controlador_vidrios` | Vidrio corredizo con servo MG90S, engrane y cremallera (x = r·θ y x(t) = v·t) |
| `collar_conejo` | Mide temperatura y pulso del animal y los envía por LoRa |
| `receptor_granja` | Recibe los collares y sube los datos a Firebase |

Antes de cargar los controladores, escriban el nombre y la clave de su WiFi al inicio de cada archivo. La URL de Firebase ya está puesta.

Cada vez que cambia algo en `hardware/`, GitHub revisa que todos los programas compilen para la ESP32 (pestaña Actions, "Revisar programas de Arduino").

La app funciona aunque todavía no tengan el hardware: el clima y la enciclopedia funcionan solos, y las demás pantallas muestran un aviso mientras no haya Firebase o controladores conectados.
