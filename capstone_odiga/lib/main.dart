import 'package:flutter/material.dart';

import 'screens/app_screens.dart';
import 'state/app_state.dart';
import 'widgets/odiga_widgets.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final app = AppState();
  @override
  void dispose() {
    app.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '오디가',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Noto Sans KR',
      colorScheme: ColorScheme.fromSeed(seedColor: OdigaTokens.brand),
      scaffoldBackgroundColor: OdigaTokens.background,
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: OdigaTokens.ink,
        displayColor: OdigaTokens.ink,
        fontFamily: 'Noto Sans KR',
      ),
    ),
    home: AppShell(app: app),
  );
}
