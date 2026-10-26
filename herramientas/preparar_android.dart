// Prepara la parte de Android del proyecto U Farm.
//
// Uso (desde la carpeta del proyecto, después de "flutter pub get"):
//     dart run herramientas/preparar_android.dart
//
// Qué hace:
//   1. Crea la carpeta "android" con "flutter create" (si no existe),
//      sin tocar el código de la app.
//   2. Agrega el permiso de INTERNET (sin él, el APK no puede consultar
//      el clima ni Firebase).
//   3. Pone "U Farm" como nombre de la app en el teléfono.
//
// Funciona igual en Windows, Mac y Linux.

import 'dart:io';

Future<void> main() async {
  // Trabajar siempre desde la carpeta del proyecto
  Directory.current = File(Platform.script.toFilePath()).parent.parent;

  // Respaldo por seguridad: flutter create no debe tocar estos archivos
  final respaldo = <String, String>{
    for (final ruta in ['pubspec.yaml', 'lib/main.dart'])
      ruta: File(ruta).readAsStringSync(),
  };

  if (!Directory('android').existsSync()) {
    print('Creando la parte de Android...');
    final r = await Process.run(
      'flutter',
      [
        'create',
        '--platforms=android',
        '--project-name',
        'u_farm',
        '--org',
        'mx.uanl.ufarm',
        '.',
      ],
      runInShell: true,
    );
    stdout.write(r.stdout);
    stderr.write(r.stderr);
    if (r.exitCode != 0) exit(r.exitCode);
  }

  respaldo.forEach((ruta, contenido) => File(ruta).writeAsStringSync(contenido));

  // La prueba de ejemplo que genera Flutter no aplica a esta app
  final prueba = File('test/widget_test.dart');
  if (prueba.existsSync()) prueba.deleteSync();

  final manifiesto = File('android/app/src/main/AndroidManifest.xml');
  var xml = manifiesto.readAsStringSync();
  if (!xml.contains('android.permission.INTERNET')) {
    xml = xml.replaceFirst(
      '<application',
      '<uses-permission android:name="android.permission.INTERNET"/>\n    <application',
    );
  }
  xml = xml.replaceAll(RegExp(r'android:label="[^"]*"'), 'android:label="U Farm"');
  manifiesto.writeAsStringSync(xml);

  print('Android listo: permiso de internet agregado y nombre "U Farm".');
}
