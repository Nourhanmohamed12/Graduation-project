import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:triplense_project/splash/splash_screen.dart';
import 'package:triplense_project/authentication/login.dart';
import 'package:triplense_project/provider/ui_provider.dart';
import 'package:triplense_project/Home/home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final uiProvider = UiProvider();
  await uiProvider.init();

  runApp(
    ChangeNotifierProvider(create: (_) => uiProvider, child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<UiProvider>(context);

    return MaterialApp(
      title: 'Triplens',
      debugShowCheckedModeBanner: false,
      darkTheme: themeProvider.darkTheme,
      themeMode: themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LogIn(),
        '/home': (context) => const Home(),
      },
    );
  }
}
