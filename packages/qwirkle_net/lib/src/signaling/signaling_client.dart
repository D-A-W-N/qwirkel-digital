import 'dart:async';
import 'dart:io';

import 'signaling_messages.dart';

/// Client für den [SignalingServer]: erstellt/betritt Räume per
/// Einladungscode und tauscht SDP-/ICE-Nachrichten mit anderen Peers im
/// selben Raum aus.
///
/// Kapselt ausschließlich den Verbindungsaufbau - die eigentliche WebRTC-
/// `RTCPeerConnection` (z. B. via `flutter_webrtc`) wird von der
/// aufrufenden Schicht erstellt und mit den hier empfangenen
/// Offer-/Answer-/ICE-Daten gefüttert bzw. deren Ergebnisse über
/// [sendOffer]/[sendAnswer]/[sendIceCandidate] verschickt.
class SignalingClient {
  WebSocket? _socket;
  StreamSubscription? _subscription;
  String? _peerId;

  final _roomCreatedController =
      StreamController<RoomCreatedMessage>.broadcast();
  final _roomJoinedController = StreamController<RoomJoinedMessage>.broadcast();
  final _peerJoinedController = StreamController<PeerJoinedMessage>.broadcast();
  final _peerLeftController = StreamController<PeerLeftMessage>.broadcast();
  final _offerController = StreamController<SdpOfferMessage>.broadcast();
  final _answerController = StreamController<SdpAnswerMessage>.broadcast();
  final _iceController = StreamController<IceCandidateMessage>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  /// Eigene Peer-Id, gesetzt nach [createRoom]/[joinRoom].
  String? get peerId => _peerId;

  Stream<PeerJoinedMessage> get peerJoined => _peerJoinedController.stream;
  Stream<PeerLeftMessage> get peerLeft => _peerLeftController.stream;
  Stream<SdpOfferMessage> get offers => _offerController.stream;
  Stream<SdpAnswerMessage> get answers => _answerController.stream;
  Stream<IceCandidateMessage> get iceCandidates => _iceController.stream;
  Stream<String> get errors => _errorController.stream;

  /// Verbindet sich mit dem Signaling-Server unter [url] (z. B.
  /// `ws://192.168.1.10:8090`).
  Future<void> connect(String url) async {
    final socket = await WebSocket.connect(url);
    _socket = socket;
    _subscription = socket.listen((data) => _handleMessage(data as String));
  }

  /// Erstellt einen neuen Raum und liefert den Einladungscode.
  Future<String> createRoom() async {
    final future = _roomCreatedController.stream.first;
    _socket!.add(CreateRoomMessage().encode());
    final message = await future;
    _peerId = message.peerId;
    return message.roomCode;
  }

  /// Betritt einen bestehenden Raum per Einladungscode und liefert die IDs
  /// der bereits anwesenden Peers (i. d. R. der Host).
  Future<List<String>> joinRoom(String roomCode) async {
    final future = _roomJoinedController.stream.first;
    _socket!.add(JoinRoomMessage(roomCode).encode());
    final message = await future;
    _peerId = message.peerId;
    return message.existingPeerIds;
  }

  void sendOffer(String targetPeerId, String sdp) {
    _socket!.add(
      SdpOfferMessage(
        targetPeerId: targetPeerId,
        fromPeerId: _peerId!,
        sdp: sdp,
      ).encode(),
    );
  }

  void sendAnswer(String targetPeerId, String sdp) {
    _socket!.add(
      SdpAnswerMessage(
        targetPeerId: targetPeerId,
        fromPeerId: _peerId!,
        sdp: sdp,
      ).encode(),
    );
  }

  void sendIceCandidate(
    String targetPeerId,
    String candidate,
    String sdpMid,
    int sdpMLineIndex,
  ) {
    _socket!.add(
      IceCandidateMessage(
        targetPeerId: targetPeerId,
        fromPeerId: _peerId!,
        candidate: candidate,
        sdpMid: sdpMid,
        sdpMLineIndex: sdpMLineIndex,
      ).encode(),
    );
  }

  void _handleMessage(String raw) {
    final message = decodeSignalingMessage(raw);
    if (message is RoomCreatedMessage) {
      _roomCreatedController.add(message);
    } else if (message is RoomJoinedMessage) {
      _roomJoinedController.add(message);
    } else if (message is PeerJoinedMessage) {
      _peerJoinedController.add(message);
    } else if (message is PeerLeftMessage) {
      _peerLeftController.add(message);
    } else if (message is SdpOfferMessage) {
      _offerController.add(message);
    } else if (message is SdpAnswerMessage) {
      _answerController.add(message);
    } else if (message is IceCandidateMessage) {
      _iceController.add(message);
    } else if (message is RoomErrorMessage) {
      _errorController.add(message.message);
    }
  }

  Future<void> close() async {
    await _subscription?.cancel();
    await _socket?.close();
    await _roomCreatedController.close();
    await _roomJoinedController.close();
    await _peerJoinedController.close();
    await _peerLeftController.close();
    await _offerController.close();
    await _answerController.close();
    await _iceController.close();
    await _errorController.close();
  }
}
