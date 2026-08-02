import 'package:flutter/material.dart';
import 'widgets/themes.dart';
import 'pages/rect/homepage.dart';
import 'pages/radial/homepage.dart';
import 'package:rive/rive.dart' as rive;

Future<void> main() async {
  await rive.RiveNative.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return MaterialApp(
      title: 'Flutter Demo',
      theme: AppTheme.darkTheme,
      // home: size.width == size.height ? const RadialHomePage() : const HomePage(),
      home: const RadialHomePage(),
    );
  }
}
