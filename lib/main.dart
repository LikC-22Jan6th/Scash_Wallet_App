import 'package:flutter/material.dart';
import 'package:scash_wallet/utils/I10n.dart';
import 'src/app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocaleController.instance.load();
  runApp(MyApp());
}