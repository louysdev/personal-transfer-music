import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'providers/transfer_provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MusicTransferApp());
}

class MusicTransferApp extends StatelessWidget {
  const MusicTransferApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TransferProvider()..loadSettings()),
      ],
      child: MaterialApp(
        title: 'Music Transfer',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const HomeScreen(),
      ),
    );
  }
}
