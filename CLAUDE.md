# Contexto del proyecto
@docs/BRUJULA_PROYECTO.md

Prototipo de una APK de puzzles de Vestigia. Se trabaja con Flutter y Dart en IntelliJ IDEA, usando Claude Code. La plataforma inicial es Android; el código nativo (audio, vibración y orientación) está en Kotlin.

Este prototipo móvil explora puzzles por separado. No es todavía la experiencia PC + teléfono descrita en la brújula.

## Estado actual

- La app abre en el **menú principal de Vestigia** con la lista de puzzles. El contador inicial de Flutter se eliminó.
- Hay cuatro puzzles jugables (prototipos), en el orden de la brújula: **Radio** (registro `137`), **Fotografía** (inscripción `+042`), **Mirador del faro** (limpieza, perillas y evento) y **Observatorio** (AR/DEC, calibración y orientación del teléfono).
- Orientación fijada en vertical (`lib/main.dart`).
- Nombre visible de la app: “Vestigia”. El paquete sigue siendo `radio_coordenadas` / `com.example.radio_coordenadas` (provisional).

## Estructura

```
lib/
  main.dart                     arranque y orientación
  app/vestigia_app.dart         MaterialApp; acepta un catálogo alternativo (pruebas)
  app/vestigia_theme.dart       paleta de instrumento antiguo compartida
  app/puzzle_top_bar.dart       barra común de los puzzles (volver al menú, título, nueva partida)
  core/haptics.dart             HapticCue + canal "vestigia/haptics"
  core/celestial_target.dart    registros compartidos y posición del cielo ficticio congelado
  core/dial_feedback.dart       cuándo vibrar al girar una perilla (muescas y topes); radio y mirador
  core/widgets/tuning_knob.dart perilla de latón compartida (radio y mirador)
  menu/puzzle_entry.dart        entrada de menú (título, descripción, icono, builder)
  menu/puzzle_catalog.dart      lista de puzzles del menú
  menu/main_menu_screen.dart    menú; no conoce la lógica de ningún puzzle
  puzzles/radio/
    radio_config.dart           parámetros y dígitos provisionales
    radio_tuning_game.dart      lógica pura (sin Flutter): señales, franja, espera, capturas
    radio_audio.dart            interfaz de audio + canal "vestigia/radio_audio"
    radio_puzzle_screen.dart    une lógica, interfaz, audio, vibración y ciclo de vida
    widgets/                    ventana de sintonía
  puzzles/photo/
    photo_config.dart           parámetros, imagen y coordenada B provisional
    torn_photo.dart             geometría: tres pedazos con bordes rasgados (lógica pura)
    photo_assembly.dart         reglas de unión, arrastre, conjuntos y reparto inicial (lógica pura)
    photo_layout.dart           escala y tolerancia según el tamaño de pantalla
    photo_puzzle_screen.dart    gestos → lógica; presentación y volteo
    widgets/                    vista de un pedazo y reverso de la foto
  puzzles/lookout/
    lookout_config.dart         parámetros provisionales (umbral, ejes, objetivo, tolerancia, depuración)
    lens_cleaning.dart          suciedad y superficie limpiada (rejilla + trazos), lógica pura
    view_orientation.dart       ejes X/Y, límites, encuadre y alineación, lógica pura
    lookout_game.dart           fases (limpieza → orientación → evento → resuelto) y sucesos únicos
    lookout_screen.dart         dedos y perillas → lógica; presentación
    widgets/lens_view.dart      lente: panorama, objetivo, retícula, suciedad y aro de cartón
    widgets/observation_view.dart resplandor celeste y pulsos simultáneos de ambos receptores
  puzzles/observatory/
    observatory_game.dart       códigos, calibración, tolerancia angular y espera con lecturas frescas
    orientation_source.dart    interfaz inyectable + EventChannel "vestigia/game_orientation"
    observatory_screen.dart    formulario, ciclo de vida, orientación y confirmación
    widgets/sky_view.dart       cielo ficticio y proyección celeste compartida con el mirador
assets/photos/foto_provisional.jpg     fotografía provisional (reemplazable)
assets/photos/mirador_provisional.jpg  panorama provisional del mirador (reemplazable)
android/app/src/main/kotlin/com/example/radio_coordenadas/
  MainActivity.kt               registra los tres canales
  RadioNoiseSynth.kt            síntesis en tiempo real (AudioTrack), sin archivos de audio
  VestigiaHaptics.kt            patrones de vibración (permiso VIBRATE en el manifiesto)
  GameOrientationSensor.kt      TYPE_GAME_ROTATION_VECTOR, eje de cámara posterior, sin magnetómetro
```

### Añadir un puzzle

1. Crear `lib/puzzles/<nombre>/` con su pantalla y su lógica separada.
2. Registrar una `PuzzleEntry` en `lib/menu/puzzle_catalog.dart`.
3. Cada apertura construye una pantalla nueva; liberar recursos en `dispose` y al salir (`PopScope`).

## Puzzle de radio: comportamiento implementado

- Una perilla grande; se gira arrastrando el dedo alrededor del centro. 1,5 vueltas recorren toda la escala (530–1610 kHz). Se detiene en los topes sin saltos.
- Ventana con escala, ondas y aguja roja. **La franja de la señal es invisible** (decisión del usuario: el reto es encontrarla); solo la delatan el sonido y las ondas. El texto de estado tampoco da pistas de cercanía (siempre “Gira la perilla y escucha”, salvo en pausa o al completar). Esto sustituye a “en la ventana de canales se ve una franja de sintonía”.
- Una sola medida, `signalStrength` (0–1), alimenta las ondas y el audio. Tiene un pico solo en el centro exacto de la señal y cae de forma continua hasta 0 (a `bandHalfWidth + audibleRange`). **No hay mesetas**: antes la intensidad valía 1 en toda la franja y se aplanaba cerca del borde, lo que se sentía como un imán; se eliminó a petición del usuario.
- Audio: estática con chasquidos que baja al acercarse; aparece un tono pulsante cuya altura baja y se estabiliza al llegar al centro.
- Captura: el tiempo dentro de la franja cuenta según la distancia al centro (`captureRateAt`). En el 20 % central (`centerZone`) avanza a velocidad real (2 s); de ahí baja de forma lineal hasta 0,25× en el borde (`edgeCaptureRate`, unos 8 s). Salir de la franja reinicia la espera. Cada dígito se capta una vez y la señal pasa a otra posición.
- Tres rondas. Al terminar se muestra el mensaje y los botones **Repetir** y **Volver al menú**. No se explica que son coordenadas antes del Observatorio.
- Las tres posiciones se generan juntas al empezar la partida (separadas entre sí, lejos de los extremos y del dial inicial), se conservan durante la partida y se regeneran al repetir o al volver a entrar.
- Vibración con clics cortos y firmes (“crispy”), pensada para motores lineales de eje X: clic al 90 % por cada muesca al girar (`TICK_SCALE`; máx. ~22 por segundo), “clac” doble en los topes, doble clic al entrar en la franja (una sola vez; no se rearma hasta alejarse más de dos medias franjas), tres clics ascendentes al captar y una ráfaga al completar. Orden de preferencia: primitiva `PRIMITIVE_CLICK` (Android 11+, si el motor la soporta) → `EFFECT_CLICK`/`EFFECT_DOUBLE_CLICK` → pulsos de 5–10 ms a intensidad máxima. Al iniciar se registra en Logcat (etiqueta `VestigiaHaptics`) qué soporta el motor.
- Al pasar la app al fondo se pausa el audio y se descarta la espera incompleta. Al salir del puzzle (botón o Atrás de Android) se detiene el audio y el reloj de inmediato.

### Decisiones provisionales de la radio (no son canon)

- Dígitos provisionales: `RadioPuzzleConfig.provisionalDigits` = 1, 3, 7, compartidos desde `PrototypeSky.radioDigits`. Se muestran en pantalla como mensaje.
- El prompt pedía “una sola posición aleatoria por partida” y a la vez “la siguiente señal en otra posición”. Se interpretó como: generar **una vez por partida** el conjunto de tres posiciones.
- Acuerdo de diseño del 10 de octubre implementado: la radio entrega ascensión recta, `137` (137°). Los valores definitivos y la transmisión por voz siguen pendientes (ver brújula, sección 23).

## Puzzle de la fotografía: comportamiento implementado

- Tres pedazos de una misma foto sobre una mesa de trabajo: uno superior y dos inferiores (izquierdo y derecho). Los cortes son fijos (semilla fija en `TornPhoto.threePieces`); lo aleatorio es dónde aparecen.
- Se arrastran con el dedo, sin rotar. El punto donde el dedo sujetó la pieza se conserva (sin saltos) y los conjuntos no pueden salir de la mesa.
- **Regla de encaje:** cada pieza guarda el *origen* de la foto armada según su posición. Dos piezas vecinas encajan al soltar si sus orígenes distan como mucho la tolerancia. Al encajar, el conjunto que se soltó se alinea exactamente y la pieza quieta no se mueve. Tocarse o superponerse no basta.
- Tolerancia: 0,08 anchos de foto, nunca menos de 20 px. La escala de la foto se calcula con `PhotoLayout.fit` para que las piezas quepan repartidas en dos filas y la foto armada quepa completa.
- Reparto inicial: la pieza más ancha en una fila y las otras dos en la otra, en orden y posición aleatorios, sin encimarse y lejos de encajar (más de 3 veces la tolerancia).
- Dos piezas unidas se arrastran como un solo objeto. Se puede armar en cualquier zona de la mesa; no hay casillas de destino.
- Al unir la tercera: doble clic breve de vibración (`HapticCue.photoSolved`) y la foto completa gira como un solo objeto (eje vertical, en perspectiva) mientras va al centro, hasta mostrar el reverso. Allí está escrita la segunda parte de las coordenadas. La resolución se informa una sola vez por partida (`ReleaseResult.solved`).
- Barra superior con **Volver al menú** y **Nueva partida** (separa las piezas y oculta el reverso). El botón Atrás de Android también vuelve. Cada entrada desde el menú es una partida nueva.
- Estética provisional: imagen sepia generada para el prototipo, bordes rasgados con el alma blanca del papel y sombra. La dirección final (papel y cartón hechos a mano) queda pendiente.

### Decisiones provisionales de la fotografía (no son canon)

- Inscripción implementada: `PhotoPuzzleConfig.provisionalCoordinatePart` = `+042`, compartida desde `PrototypeSky.photoCode`. Corresponde a declinación +42°; conserva el signo y el cero inicial. La interfaz no explica su significado antes del Observatorio.
- La imagen (`assets/photos/foto_provisional.jpg`, 800 × 1000) se puede reemplazar por otra con la misma proporción, 4:5 (`aspect` = 1,25). Muestra un faro con una figura en la costa; el contenido real de la foto sigue pendiente (brújula, sección 23).
- Por ahora solo vibra al completar; unir dos piezas no vibra.

## Acuerdos de diseño del 10 de octubre de 2026

La brújula es la referencia del comportamiento acordado. La adaptación móvil ya está implementada; los parámetros civiles definitivos, el arte final y la integración con PC/Unity siguen pendientes.

- Orden: Radio → Fotografía → Mirador del faro → Observatorio.
- Mirador: conservar limpieza táctil y perillas X/Y. Tras limpiar, centrar el Observatorio en una zona amplia; la búsqueda debe durar pocos segundos.
- Evento del mirador: bloquear ambas perillas, mostrar primero el resplandor entre las nubes y después hacer pulsar el faro y el Observatorio simultáneamente. Marcarlo como resuelto al terminar. Registrar el disparo antes de animar para garantizar una única ejecución por partida.
- El resplandor pertenece a la misma región celeste donde se localizará el magnetar. Abrir el encuadre del evento si hace falta para mostrar el cielo y ambos edificios.
- La radio entrega AR en grados (`137`); el reverso de la fotografía entrega DEC con signo (`+042`). El Observatorio muestra campos `AR (°)` y `DEC (°)` para deducir la correspondencia de las pistas.
- Congelar fecha, hora y ubicación del mundo de Vestigia. Convertir AR/DEC a altitud/azimut; precalcular para un objetivo fijo o compartir conversión en C# si Unity dibuja el cielo completo. Astropy sirve de referencia de validación.
- Caso geométrico de validación: latitud 20° N, AR 137°, DEC +42° y hora sideral local 137° producen altitud 68° y azimut 0° (norte) al culminar. Faltan los parámetros civiles del escenario para un cálculo astronómico definitivo.
- Calibrar apuntando hacia la PC: esa dirección horizontal define el norte del juego. Mantener la altitud referenciada a la gravedad. Permitir recalibrar ante deriva sin perder el progreso.
- Para el prototipo Android, usar `TYPE_GAME_ROTATION_VECTOR` desde Kotlin mediante un canal de eventos a Flutter. No depende del magnetómetro; comprobar disponibilidad y estabilidad en teléfono físico. La API documentada de `sensors_plus` no ofrece directamente este vector fusionado.
- La coordenada del prototipo representa un magnetar ficticio; cualquier correspondencia con un objeto catalogado sigue pendiente.

## Puzzle del mirador del faro: comportamiento implementado

**Fase 1 — Limpiar el lente**
- Ventana redonda con aro de cartón. El cristal está cubierto de suciedad opaca con manchas; detrás se ve el panorama en la orientación inicial.
- Se limpia deslizando uno o varios dedos (multitáctil) sobre el lente. Cada trazo borra solo por donde pasa (pincel de radio 0,075 del diámetro) y lo limpio queda limpio.
- Progreso: rejilla de 72 × 72 celdas; solo cuentan las celdas dentro del círculo del cristal, y cada una cuenta una sola vez, así que frotar el mismo sitio no suma. Cada movimiento limpia todo el segmento desde la posición anterior, de modo que los trazos rápidos no dejan huecos.
- Se muestra “Lente limpio: N %”. Al llegar al umbral (`cleanThreshold`, 85 % provisional) se pasa sola a la fase 2: vibración `capture`, la suciedad restante se desvanece y aparecen las perillas.

**Fase 2 — Orientar el mirador**
- Se conserva la ventana y aparecen dos perillas de latón (la misma perilla de la radio): una solo mueve el eje X (horizontal) y la otra solo el eje Y (vertical; Y positivo mira hacia arriba). Cada eje va de −100 a 100 (provisional), con 1,5 vueltas de perilla para el recorrido completo. Movimiento continuo, con topes y sin saltos; vibra igual que la radio (muescas ligeras y “clac” en los topes).
- La retícula está fija en el centro; lo que se mueve es la vista sobre el panorama, sin salir de él.
- “X: … Y: …” se muestra siempre bajo el lente como dato de depuración; se oculta con `LookoutConfig.showDebugValues = false`.
- Objetivo provisional: un observatorio de papel recortado sobre la colina de la derecha, dibujado por la app encima del panorama en `targetPosition` (0,82; 0,40). Su centro está en X ≈ 88,9 e Y = 37,5. Tolerancia `alignTolerance` = ±14 por eje para una búsqueda breve.
- Al alinear ambos ejes: vibra una vez (`signalFound`), entra en fase `observing` y las perillas se bloquean antes de animar. El encuadre se abre: primero resplandor entre nubes, después tres pulsos compartidos por faro y Observatorio. `observationDuration` = 4 s; solo al terminar pasa a `solved`. La secuencia se pausa en segundo plano y no vuelve a dispararse hasta reiniciar.
- **Nueva partida** restaura la suciedad, los ejes iniciales (0, 0) y la fase 1. Cada entrada desde el menú es una partida nueva.

### Decisiones provisionales del mirador (no son canon)

- Umbral del 85 %, rangos de los ejes, tolerancia numérica, duración del evento, posición del objetivo y panorama: provisionales. El objetivo Observatorio y la secuencia narrativa están implementados (brújula, sección 11.2).
- Los valores X e Y controlan el encuadre del mirador; no son los códigos de AR y DEC de la radio y la fotografía.
- La vibración al limpiar, al alinear y al girar las perillas reutiliza patrones ya existentes; no estaba pedida explícitamente.
- Al terminar la limpieza, la suciedad restante (hasta el 15 %) se desvanece para dejar la vista despejada en la fase 2.
- El observatorio posterior conservará los sensores del teléfono; este puzzle usa perillas.

## Puzzle del Observatorio: comportamiento implementado

- Valida `AR (°)` = `137` y `DEC (°)` = `+042`; el signo es obligatorio. Los mismos valores alimentan radio y foto desde `PrototypeSky`. El teclado de DEC permite introducir `+` incluso en Android sin teclado numérico firmado completo.
- El puente Kotlin entrega la dirección de la cámara posterior (-Z del teléfono) como azimut y altitud. Solo usa `TYPE_GAME_ROTATION_VECTOR`; informa sensor ausente sin reemplazarlo por brújula real.
- Calibrar hacia la PC define el norte horizontal del juego; la altitud sigue referenciada a la gravedad. Se rechaza calibración sin lectura reciente o demasiado cerca del cenit/nadir (>75°). Recalibrar conserva los códigos y descarta la espera parcial.
- Cielo ficticio fijo con estrellas y fuente rosada. Objetivo provisional: azimut 0°, altitud 68°, a partir del caso geométrico anterior. La proyección de esa misma dirección sitúa el resplandor del mirador; no hay efemérides, GPS ni hora real.
- Para resolver: permanecer dos segundos a ≤6° de distancia angular esférica del objetivo. Lecturas con más de 500 ms de edad, salida de la tolerancia o interrupciones largas descartan la espera. Éxito único, vibración `complete`, retícula verde y revelación del magnetar.
- Al pasar al fondo se cancelan suscripción/reloj y se exige recalibrar al volver, sin borrar códigos. Éxito ya completado se conserva. Al salir por botón o Atrás se liberan inmediatamente los recursos; reiniciar borra ambos campos y empieza de nuevo.
- El prototipo es autónomo: apuntar hacia la PC define una referencia, pero no establece ninguna conexión con Unity ni envía eventos a la PC. Arte del cielo, escena final y estabilidad/comodidad física siguen sujetos a validación.

## Verificación

Desde la raíz del proyecto:

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

El SDK local está en `C:\Users\aldob\AppData\Local\Flutter\flutter`. La APK queda en `build/app/outputs/flutter-apk/app-debug.apk`.

Las pruebas usan audio, vibración y orientación falsos, o simulan los canales nativos. Las de la fotografía y el mirador usan gestos reales (arrastrar piezas, frotar el lente, girar perillas). Las del Observatorio cubren códigos/signo, calibración, cruce de 360°, espera, lecturas obsoletas, interrupciones, reinicio y liberación del sensor. El sonido real, la vibración y la comodidad de los gestos/apuntado requieren un teléfono físico.
