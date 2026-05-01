import 'package:flutter/material.dart';
import 'package:sambo/app/app.dart';
import 'package:sambo/app/app_init_service.dart';

Future<void> main() async {
  await AppInitService.instance.run();
  runApp(const SamboApp());
}
