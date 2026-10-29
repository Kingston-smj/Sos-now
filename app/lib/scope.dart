import 'package:flutter/material.dart';

import '../controller.dart';

class SosScope extends InheritedNotifier<SosController> {
  const SosScope({super.key, required SosController controller, required super.child}) : super(notifier: controller);

  static SosController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SosScope>();
    assert(scope != null, 'SosScope is missing above this widget');
    return scope!.notifier!;
  }
}
