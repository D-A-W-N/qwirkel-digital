import 'dart:async';

import 'package:qwirkle_net/qwirkle_net.dart';
import 'package:test/test.dart';

void main() {
  group('SignalingServer/SignalingClient (Loopback)', () {
    late SignalingServer server;

    setUp(() async {
      server = SignalingServer();
      await server.start(address: '127.0.0.1', port: 0);
    });

    tearDown(() async {
      await server.close();
    });

    Future<SignalingClient> connectClient() async {
      final client = SignalingClient();
      await client.connect('ws://127.0.0.1:${server.port}');
      return client;
    }

    test('Host erstellt einen Raum und erhält einen Einladungscode', () async {
      final host = await connectClient();
      final roomCode = await host.createRoom();

      expect(roomCode, isNotEmpty);
      expect(host.peerId, isNotEmpty);

      await host.close();
    });

    test(
      'Gast tritt per Einladungscode bei und Host wird benachrichtigt',
      () async {
        final host = await connectClient();
        final roomCode = await host.createRoom();

        final guest = await connectClient();
        final peerJoinedFuture = host.peerJoined.first;
        final existingPeerIds = await guest.joinRoom(roomCode);

        expect(existingPeerIds, [host.peerId]);

        final peerJoined = await peerJoinedFuture;
        expect(peerJoined.peerId, guest.peerId);

        await host.close();
        await guest.close();
      },
    );

    test('Unbekannter Raum-Code liefert einen Fehler', () async {
      final guest = await connectClient();
      final errorFuture = guest.errors.first;

      final existingPeerIdsFuture = guest.joinRoom('XXXXX');

      final error = await errorFuture;
      expect(error, contains('Unbekannter Raum-Code'));

      // Die join-Anfrage bleibt unbeantwortet (kein roomJoined) - daher hier
      // absichtlich nicht awaiten, nur den ungenutzten Future abfangen, damit
      // kein "unhandled exception" beim Schließen des Streams entsteht.
      unawaited(existingPeerIdsFuture.catchError((_) => <String>[]));

      await guest.close();
    });

    test(
      'SDP-Offer/Answer und ICE-Kandidaten werden an den Ziel-Peer weitergeleitet',
      () async {
        final host = await connectClient();
        final roomCode = await host.createRoom();
        final guest = await connectClient();
        await guest.joinRoom(roomCode);

        final offerFuture = guest.offers.first;
        host.sendOffer(guest.peerId!, 'v=0 fake-offer-sdp');
        final offer = await offerFuture;
        expect(offer.sdp, 'v=0 fake-offer-sdp');
        expect(offer.fromPeerId, host.peerId);

        final answerFuture = host.answers.first;
        guest.sendAnswer(host.peerId!, 'v=0 fake-answer-sdp');
        final answer = await answerFuture;
        expect(answer.sdp, 'v=0 fake-answer-sdp');
        expect(answer.fromPeerId, guest.peerId);

        final iceFuture = guest.iceCandidates.first;
        host.sendIceCandidate(guest.peerId!, 'candidate:1 fake', 'audio', 0);
        final ice = await iceFuture;
        expect(ice.candidate, 'candidate:1 fake');
        expect(ice.sdpMLineIndex, 0);

        await host.close();
        await guest.close();
      },
    );

    test(
      'Verlässt ein Peer den Raum, wird der andere benachrichtigt',
      () async {
        final host = await connectClient();
        final roomCode = await host.createRoom();
        final guest = await connectClient();
        await guest.joinRoom(roomCode);

        final peerLeftFuture = host.peerLeft.first;
        await guest.close();

        final peerLeft = await peerLeftFuture;
        expect(peerLeft.peerId, isNotEmpty);

        await host.close();
      },
    );
  });
}
