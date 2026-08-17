import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/bootstrap.dart';
import 'app/prayan_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only. A trading journal is a one-handed, vertical-list product;
  // supporting landscape would mean maintaining a second layout for every
  // screen without a use case asking for it.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final overrides = await Bootstrap.initialise();

  runApp(ProviderScope(overrides: overrides, child: const PrayanApp()));
}
