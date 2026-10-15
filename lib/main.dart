import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/vestigia_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Los puzzles están diseñados para el teléfono en vertical.
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const VestigiaApp());
}
