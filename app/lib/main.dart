import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/net/internet_room_screen.dart';
import 'src/net/room_connection_manager.dart';
import 'src/settings/app_settings.dart';
import 'src/setup/setup_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: QwirkleApp()));
}

/// App-weite Keys, damit der [RoomConnectionManager] (lebt oberhalb jeder
/// einzelnen Route) auch dann eine Zug-Benachrichtigung anzeigen und dorthin
/// navigieren kann, wenn gerade ein anderer Raum oder gar kein Netzwerk-
/// Screen sichtbar ist - siehe [_QwirkleAppState._listenForTurnNotifications].
final navigatorKey = GlobalKey<NavigatorState>();
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class QwirkleApp extends ConsumerStatefulWidget {
  const QwirkleApp({super.key});

  @override
  ConsumerState<QwirkleApp> createState() => _QwirkleAppState();
}

class _QwirkleAppState extends ConsumerState<QwirkleApp> {
  StreamSubscription<String>? _turnNotificationSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await initializeAppSettings(ref);
    });
    _listenForTurnNotifications();
  }

  /// Zeigt eine app-weite SnackBar, sobald diese Person in einem NICHT
  /// gerade sichtbaren Internet-Raum am Zug ist (siehe
  /// `RoomConnectionManager.turnNotifications`) - Nutzer-Feedback: man soll
  /// mehrere Räume parallel offen halten können, ohne den eigenen Zug in
  /// einem Hintergrund-Raum zu verpassen.
  void _listenForTurnNotifications() {
    final manager = ref.read(roomConnectionManagerProvider);
    _turnNotificationSubscription = manager.turnNotifications.listen((
      roomCode,
    ) {
      final entry = manager.entryFor(roomCode);
      final roomName = entry?.roomName ?? roomCode;
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Du bist am Zug in "$roomName"'),
          action: SnackBarAction(
            label: 'Öffnen',
            onPressed: () => navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => InternetRoomScreen.existingRoom(roomCode: roomCode),
              ),
            ),
          ),
          duration: const Duration(seconds: 8),
        ),
      );
    });
  }

  @override
  void dispose() {
    _turnNotificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qwirkle Digital',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const SetupScreen(),
    );
  }
}
