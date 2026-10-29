import 'package:flutter/material.dart';

import 'app.dart';
import 'controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = SosController();
  await controller.load();
  runApp(SosApp(controller: controller));
}
