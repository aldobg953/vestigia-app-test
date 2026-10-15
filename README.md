# Vestigia — prototipo de puzzles (Android)

App Flutter con el menú de puzzles de Vestigia. Incluye cuatro puzzles jugables: **Radio**, **Fotografía**, **Mirador del faro** y **Observatorio**. Nombre de paquete provisional: `radio_coordenadas`.

La referencia narrativa del proyecto está en [`docs/BRUJULA_PROYECTO.md`](docs/BRUJULA_PROYECTO.md). El estado técnico detallado está en [`CLAUDE.md`](CLAUDE.md).

## Abrir en IntelliJ IDEA

1. Selecciona **File > Open** y abre esta carpeta completa, la que contiene `pubspec.yaml`. No abras solamente `android`.
2. Deja que IntelliJ termine de cargar el proyecto y sus dependencias.
3. Si solicita el SDK de Flutter, usa `C:\Users\aldob\AppData\Local\Flutter\flutter`.

Se necesitan los plugins Flutter y Dart. Entorno comprobado: Flutter 3.44.4, Dart 3.12.2.

## Ejecutar

```powershell
flutter emulators --launch Medium_Phone_API_35
flutter devices
flutter run -d ID_DEL_DISPOSITIVO
```

Para el sonido y la vibración conviene un teléfono físico: el emulador no vibra y su audio puede tener retraso.

## Cómo se juega la radio

1. En el menú, toca **Radio**.
2. Gira la perilla con el dedo alrededor de su centro. La aguja roja recorre la escala.
3. La señal no se ve en la ventana: búscala de oído. Al acercarte, la estática baja, aparece un tono y las ondas se ordenan.
4. Al encontrarla vibra con un doble clic. Mantén la aguja ahí sin salir: en el centro exacto bastan dos segundos; cuanto más lejos del centro, más lento avanza la captura. Al completarse se capta un dígito y la señal se mueve.
5. Tras tres dígitos se muestra el mensaje `137`, sin revelar todavía su significado. Puedes **Repetir** (posiciones nuevas) o **Volver al menú**.

Los registros provisionales de ambos puzzles y la posición del objeto celeste se comparten en `lib/core/celestial_target.dart`.

## Cómo se juega la fotografía

1. En el menú, toca **Fotografía**. Aparecen tres pedazos rasgados de una misma foto sobre la mesa.
2. Arrastra cada pedazo con el dedo; no hace falta girarlos.
3. Acerca un pedazo al lugar que le corresponde respecto a otro y suéltalo: si sus bordes coinciden, encajan solos. Si solo se tocan o se enciman, no encajan.
4. Dos pedazos unidos se mueven juntos. Al unir el tercero, el teléfono vibra y la foto se voltea para mostrar la inscripción `+042`, conservando el signo sin explicar todavía su significado.
5. **Nueva partida** (icono ↻) separa los pedazos y oculta el reverso.

La imagen provisional está en `assets/photos/foto_provisional.jpg` y se puede reemplazar por otra con proporción 4:5. El valor del reverso se configura en `lib/puzzles/photo/photo_config.dart`.

## Cómo se juega el mirador del faro

1. En el menú, toca **Mirador del faro**. El lente está cubierto de suciedad.
2. Frota el lente con uno o varios dedos. Solo se limpia por donde pasas; repasar la misma zona no avanza. Debajo se ve el porcentaje limpio.
3. Al llegar al 85 % (provisional), el teléfono vibra, la suciedad restante se desvanece y aparecen dos perillas.
4. La perilla **Horizontal · X** mueve la vista a los lados y **Vertical · Y** arriba y abajo. Bajo el lente se ven los valores X e Y (depuración).
5. Busca el observatorio de papel sobre la colina y céntralo en la retícula. La tolerancia es amplia (±14 por eje). Al alinearlo vibra y las perillas se bloquean.
6. El encuadre se abre: aparece primero un resplandor entre las nubes; después el faro y el Observatorio pulsan al mismo tiempo. La secuencia dura cuatro segundos y solo al terminar se marca como resuelto. Si la app pasa al fondo, la secuencia se pausa.
7. **Nueva partida** (↻) vuelve a ensuciar el lente y regresa los ejes a 0.

El panorama está en `assets/photos/mirador_provisional.jpg`. El umbral, los rangos, el objetivo, la tolerancia y la opción de ocultar X/Y se configuran en `lib/puzzles/lookout/lookout_config.dart`.

## Cómo se juega el Observatorio

1. En el menú, toca **Observatorio**. Introduce los registros en **AR (°)** (`137`) y **DEC (°)** (`+042`, con signo), y prepara el telescopio.
2. Sostén el teléfono vertical, como una cámara, apuntando hacia la pantalla de la PC, y pulsa **Calibrar**. Esa dirección horizontal será el norte del juego; no necesitas buscar el norte real.
3. Mueve el teléfono para explorar el cielo. La cámara posterior define hacia dónde apunta el instrumento. Los valores AZ/ALT son de depuración.
4. Apunta al objeto rosado y mantenlo dentro de la retícula dos segundos (tolerancia provisional de 6°). El teléfono vibra y revela el magnetar.
5. **Recalibrar** cambia la referencia sin volver a introducir los códigos. Pasar al fondo detiene el sensor, descarta la espera parcial y exige recalibrar al volver. Salir libera el sensor inmediatamente.

Usa un Android físico con `TYPE_GAME_ROTATION_VECTOR`. Si el sensor no está disponible, la app lo informa y permite reintentar; no usa el magnetómetro como reemplazo. La configuración de tolerancia/espera está en `lib/puzzles/observatory/observatory_game.dart`.

El cielo es ficticio y está congelado: se usa el caso geométrico latitud 20° N, AR 137°, DEC +42°, hora sideral local 137°, que sitúa el objetivo a 68° de altitud y 0° de azimut. No consulta ubicación ni hora del teléfono. El resplandor del mirador anticipa esa misma dirección. No es todavía la conexión con Unity/PC ni un catálogo astronómico real.

## Verificación

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

La APK de desarrollo se genera en `build/app/outputs/flutter-apk/app-debug.apk`.

## Configuración

- Interfaz y lógica: Dart (`lib/`).
- Audio, vibración y orientación nativos: Kotlin (`android/app/src/main/kotlin/...`), mediante los canales `vestigia/radio_audio`, `vestigia/haptics` y `vestigia/game_orientation`. Sin dependencias externas.
- Permiso Android: `VIBRATE`.
- Identificador provisional: `com.example.radio_coordenadas`.
