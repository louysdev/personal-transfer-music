import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'single_playlist_screen.dart';
import 'transfer_all_screen.dart';
import 'delete_all_screen.dart';
import 'settings_screen.dart';
import '../providers/transfer_all_provider.dart';
import '../providers/delete_all_provider.dart';
import '../providers/transfer_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const SinglePlaylistScreen(),
          ChangeNotifierProvider(
            create: (_) => TransferAllProvider(
              baseUrl: context.read<TransferProvider>().baseUrl,
            ),
            child: const TransferAllScreen(),
          ),
          ChangeNotifierProvider(
            create: (_) => DeleteAllProvider(
              baseUrl: context.read<TransferProvider>().baseUrl,
            ),
            child: const DeleteAllScreen(),
          ),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.queue_music_outlined),
            selectedIcon: Icon(Icons.queue_music),
            label: 'Single',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music),
            label: 'All',
          ),
          NavigationDestination(
            icon: Icon(Icons.delete_outline),
            selectedIcon: Icon(Icons.delete),
            label: 'Delete',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

