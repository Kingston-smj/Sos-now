import 'package:flutter/material.dart';

import 'controller.dart';
import 'scope.dart';
import 'screens/auth_screen.dart';
import 'screens/shell.dart';
import 'theme.dart';

class SosApp extends StatelessWidget {
  const SosApp({super.key, required this.controller});

  final SosController controller;

  @override
  Widget build(BuildContext context) {
    return SosScope(
      controller: controller,
      child: Builder(
        builder: (context) {
          final sos = SosScope.of(context);
          return MaterialApp(
            title: 'SOS Now',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            home: !sos.ready
                ? const Scaffold(body: Center(child: CircularProgressIndicator()))
                : sos.token == null
                    ? const AuthScreen()
                    : const HomeShell(),
          );
        },
      ),
    );
  }
}
