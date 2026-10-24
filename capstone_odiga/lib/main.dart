import 'package:flutter/material.dart';

import 'screens/app_screens.dart';
import 'state/app_state.dart';
import 'widgets/odiga_widgets.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.loadState});
  final Future<AppState> Function()? loadState;
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<AppState> loading = load();
  AppState? app;
  Future<AppState> load() async {
    final state = await (widget.loadState ?? AppState.load)();
    if (mounted) {
      app = state;
    } else {
      state.dispose();
    }
    return state;
  }

  @override
  void dispose() {
    app?.dispose();
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
    home: FutureBuilder<AppState>(
      future: loading,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('예시 데이터를 불러오지 못했어요.'),
                  TextButton(
                    onPressed: () => setState(() {
                      loading = load();
                    }),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return AppShell(app: snapshot.data!);
      },
    ),
  );
}
