import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:qwirkle_net/qwirkle_net.dart';

/// [MessageTransport]-Implementierung auf Basis eines WebRTC-DataChannels.
/// Wird von [WebRtcConnection] erzeugt, sobald der DataChannel geöffnet ist,
/// und kann danach direkt an `HostSession.acceptTransport()` bzw.
/// `ClientSession.connectVia()` übergeben werden - die Sync-Protokolllogik
/// bleibt dadurch identisch zur LAN-Variante (`TcpTransport`).
class WebRtcTransport implements MessageTransport {
  final RTCDataChannel _channel;
  late final StreamSubscription<RTCDataChannelMessage> _messageSub;
  final _linesController = StreamController<String>.broadcast();

  WebRtcTransport(this._channel) {
    _messageSub = _channel.messageStream.listen((message) {
      if (!message.isBinary) _linesController.add(message.text);
    });
  }

  @override
  Stream<String> get lines => _linesController.stream;

  @override
  void send(String line) {
    unawaited(_channel.send(RTCDataChannelMessage(line)));
  }

  @override
  Future<void> close() async {
    await _messageSub.cancel();
    await _channel.close();
    await _linesController.close();
  }
}

/// Öffentliche STUN-Server für die ICE-Kandidatensuche. Es wird bewusst
/// kein TURN-Relay-Server konfiguriert - das reicht für die meisten
/// Heimnetzwerke, funktioniert aber NICHT zuverlässig hinter symmetrischem
/// NAT oder restriktiven Firewalls (dafür bräuchte man einen zusätzlichen,
/// selbst betriebenen oder kommerziellen TURN-Server).
const _defaultIceServers = {
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
  ],
};

/// Baut eine einzelne WebRTC-Peer-Verbindung zu genau einem entfernten Peer
/// auf, unter Verwendung eines [SignalingClient] für den SDP-/ICE-Austausch.
///
/// Der Host (Ersteller des Datenkanals) ruft [connectAsOfferer] auf, der
/// beitretende Gast [connectAsAnswerer] - passend zur Host-autoritativen
/// Architektur, bei der jeder Gast eine eigene direkte Verbindung zum Host
/// aufbaut (Stern-Topologie, kein Mesh).
///
/// ACHTUNG (Grenzen der Verifizierbarkeit): Dieser Code ist statisch
/// analysiert und die einzelnen WebRTC-API-Aufrufe folgen der offiziellen
/// `flutter_webrtc`-Schnittstelle, aber eine ECHTE Verbindung über das
/// offene Internet (insbesondere NAT-Traversal ohne eigenen TURN-Server)
/// muss manuell mit zwei echten Geräten/Netzwerken getestet werden - das
/// ist in dieser Entwicklungsumgebung nicht automatisiert überprüfbar.
class WebRtcConnection {
  final SignalingClient signaling;
  final String remotePeerId;

  /// ICE-Server-Konfiguration für den Verbindungsaufbau. Standard ist
  /// STUN-only ([_defaultIceServers]); ein TURN-Server (nötig für
  /// zuverlässige Verbindungen hinter symmetrischem NAT) kann hier
  /// übergeben werden, sobald einer verfügbar ist - ohne Änderungen an der
  /// restlichen Verbindungslogik.
  final Map<String, dynamic> iceServers;

  RTCPeerConnection? _peerConnection;
  StreamSubscription? _iceSub;

  WebRtcConnection({
    required this.signaling,
    required this.remotePeerId,
    this.iceServers = _defaultIceServers,
  });

  /// Host-Seite: erstellt den DataChannel aktiv, sendet das Offer und
  /// wartet auf Answer + Öffnen des Kanals.
  Future<WebRtcTransport> connectAsOfferer() async {
    final pc = await createPeerConnection(iceServers);
    _peerConnection = pc;
    _wireIceCandidates(pc);

    final channel = await pc.createDataChannel(
      'qwirkle',
      RTCDataChannelInit()..ordered = true,
    );

    final answerSub = signaling.answers
        .where((a) => a.fromPeerId == remotePeerId)
        .listen((answer) {
          pc.setRemoteDescription(RTCSessionDescription(answer.sdp, 'answer'));
        });

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    signaling.sendOffer(remotePeerId, offer.sdp!);

    await _waitForOpen(channel);
    await answerSub.cancel();
    return WebRtcTransport(channel);
  }

  /// Gast-Seite: wartet auf das eingehende Offer des Hosts, beantwortet es
  /// und wartet auf den vom Host erstellten DataChannel.
  Future<WebRtcTransport> connectAsAnswerer() async {
    final pc = await createPeerConnection(iceServers);
    _peerConnection = pc;
    _wireIceCandidates(pc);

    final channelCompleter = Completer<RTCDataChannel>();
    pc.onDataChannel = (channel) {
      if (!channelCompleter.isCompleted) channelCompleter.complete(channel);
    };

    final offer = await signaling.offers
        .where((o) => o.fromPeerId == remotePeerId)
        .first;
    await pc.setRemoteDescription(RTCSessionDescription(offer.sdp, 'offer'));
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    signaling.sendAnswer(remotePeerId, answer.sdp!);

    final channel = await channelCompleter.future;
    await _waitForOpen(channel);
    return WebRtcTransport(channel);
  }

  void _wireIceCandidates(RTCPeerConnection pc) {
    pc.onIceCandidate = (candidate) {
      final value = candidate.candidate;
      if (value == null) return;
      signaling.sendIceCandidate(
        remotePeerId,
        value,
        candidate.sdpMid ?? '',
        candidate.sdpMLineIndex ?? 0,
      );
    };
    _iceSub = signaling.iceCandidates
        .where((c) => c.fromPeerId == remotePeerId)
        .listen((c) {
          pc.addCandidate(
            RTCIceCandidate(c.candidate, c.sdpMid, c.sdpMLineIndex),
          );
        });
  }

  Future<void> _waitForOpen(RTCDataChannel channel) async {
    if (channel.state == RTCDataChannelState.RTCDataChannelOpen) return;
    final completer = Completer<void>();
    channel.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen &&
          !completer.isCompleted) {
        completer.complete();
      }
    };
    await completer.future;
  }

  Future<void> close() async {
    await _iceSub?.cancel();
    await _peerConnection?.close();
  }
}
