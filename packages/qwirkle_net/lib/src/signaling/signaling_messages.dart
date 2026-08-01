import 'dart:convert';

/// Nachrichten des minimalen WebRTC-Signaling-Protokolls: dient nur dem
/// Verbindungsaufbau (Raum-Beitritt + SDP-/ICE-Austausch). Nach erfolgreichem
/// WebRTC-Verbindungsaufbau laufen die eigentlichen Spielzüge direkt P2P über
/// einen DataChannel (siehe `WebRtcTransport`, implementiert
/// `MessageTransport` aus `transport.dart`) - der Signaling-Server sieht
/// niemals Spieldaten.
abstract class SignalingMessage {
  String get type;

  Map<String, dynamic> toJson();

  String encode() => jsonEncode({'type': type, ...toJson()});
}

/// Client -> Server: erstellt einen neuen Raum (der Ersteller wird "Host").
class CreateRoomMessage extends SignalingMessage {
  CreateRoomMessage();

  @override
  String get type => 'createRoom';

  @override
  Map<String, dynamic> toJson() => {};

  factory CreateRoomMessage.fromJson(Map<String, dynamic> json) =>
      CreateRoomMessage();
}

/// Server -> Client: Raum erstellt, liefert Einladungscode + eigene Peer-Id.
class RoomCreatedMessage extends SignalingMessage {
  final String roomCode;
  final String peerId;

  RoomCreatedMessage(this.roomCode, this.peerId);

  @override
  String get type => 'roomCreated';

  @override
  Map<String, dynamic> toJson() => {'roomCode': roomCode, 'peerId': peerId};

  factory RoomCreatedMessage.fromJson(Map<String, dynamic> json) =>
      RoomCreatedMessage(json['roomCode'] as String, json['peerId'] as String);
}

/// Client -> Server: Beitritt zu einem bestehenden Raum per Einladungscode.
class JoinRoomMessage extends SignalingMessage {
  final String roomCode;

  JoinRoomMessage(this.roomCode);

  @override
  String get type => 'joinRoom';

  @override
  Map<String, dynamic> toJson() => {'roomCode': roomCode};

  factory JoinRoomMessage.fromJson(Map<String, dynamic> json) =>
      JoinRoomMessage(json['roomCode'] as String);
}

/// Server -> Client: Beitritt bestätigt; liefert eigene Peer-Id sowie die
/// IDs der bereits im Raum befindlichen Peers (i. d. R. der Host).
class RoomJoinedMessage extends SignalingMessage {
  final String peerId;
  final List<String> existingPeerIds;

  RoomJoinedMessage(this.peerId, this.existingPeerIds);

  @override
  String get type => 'roomJoined';

  @override
  Map<String, dynamic> toJson() => {
    'peerId': peerId,
    'existingPeerIds': existingPeerIds,
  };

  factory RoomJoinedMessage.fromJson(Map<String, dynamic> json) =>
      RoomJoinedMessage(
        json['peerId'] as String,
        (json['existingPeerIds'] as List<dynamic>).cast<String>(),
      );
}

/// Server -> vorhandene Peers: ein neuer Peer ist dem Raum beigetreten.
class PeerJoinedMessage extends SignalingMessage {
  final String peerId;

  PeerJoinedMessage(this.peerId);

  @override
  String get type => 'peerJoined';

  @override
  Map<String, dynamic> toJson() => {'peerId': peerId};

  factory PeerJoinedMessage.fromJson(Map<String, dynamic> json) =>
      PeerJoinedMessage(json['peerId'] as String);
}

/// Server -> verbleibende Peers: ein Peer hat den Raum verlassen.
class PeerLeftMessage extends SignalingMessage {
  final String peerId;

  PeerLeftMessage(this.peerId);

  @override
  String get type => 'peerLeft';

  @override
  Map<String, dynamic> toJson() => {'peerId': peerId};

  factory PeerLeftMessage.fromJson(Map<String, dynamic> json) =>
      PeerLeftMessage(json['peerId'] as String);
}

/// Peer -> Peer (via Server geroutet an [targetPeerId]): SDP-Offer.
class SdpOfferMessage extends SignalingMessage {
  final String targetPeerId;
  final String fromPeerId;
  final String sdp;

  SdpOfferMessage({
    required this.targetPeerId,
    required this.fromPeerId,
    required this.sdp,
  });

  @override
  String get type => 'sdpOffer';

  @override
  Map<String, dynamic> toJson() => {
    'targetPeerId': targetPeerId,
    'fromPeerId': fromPeerId,
    'sdp': sdp,
  };

  factory SdpOfferMessage.fromJson(Map<String, dynamic> json) =>
      SdpOfferMessage(
        targetPeerId: json['targetPeerId'] as String,
        fromPeerId: json['fromPeerId'] as String,
        sdp: json['sdp'] as String,
      );
}

/// Peer -> Peer (via Server geroutet an [targetPeerId]): SDP-Answer.
class SdpAnswerMessage extends SignalingMessage {
  final String targetPeerId;
  final String fromPeerId;
  final String sdp;

  SdpAnswerMessage({
    required this.targetPeerId,
    required this.fromPeerId,
    required this.sdp,
  });

  @override
  String get type => 'sdpAnswer';

  @override
  Map<String, dynamic> toJson() => {
    'targetPeerId': targetPeerId,
    'fromPeerId': fromPeerId,
    'sdp': sdp,
  };

  factory SdpAnswerMessage.fromJson(Map<String, dynamic> json) =>
      SdpAnswerMessage(
        targetPeerId: json['targetPeerId'] as String,
        fromPeerId: json['fromPeerId'] as String,
        sdp: json['sdp'] as String,
      );
}

/// Peer -> Peer (via Server geroutet an [targetPeerId]): ICE-Kandidat.
class IceCandidateMessage extends SignalingMessage {
  final String targetPeerId;
  final String fromPeerId;
  final String candidate;
  final String sdpMid;
  final int sdpMLineIndex;

  IceCandidateMessage({
    required this.targetPeerId,
    required this.fromPeerId,
    required this.candidate,
    required this.sdpMid,
    required this.sdpMLineIndex,
  });

  @override
  String get type => 'iceCandidate';

  @override
  Map<String, dynamic> toJson() => {
    'targetPeerId': targetPeerId,
    'fromPeerId': fromPeerId,
    'candidate': candidate,
    'sdpMid': sdpMid,
    'sdpMLineIndex': sdpMLineIndex,
  };

  factory IceCandidateMessage.fromJson(Map<String, dynamic> json) =>
      IceCandidateMessage(
        targetPeerId: json['targetPeerId'] as String,
        fromPeerId: json['fromPeerId'] as String,
        candidate: json['candidate'] as String,
        sdpMid: json['sdpMid'] as String,
        sdpMLineIndex: json['sdpMLineIndex'] as int,
      );
}

/// Server -> Client: die zuletzt gesendete Anfrage konnte nicht bearbeitet
/// werden (z. B. unbekannter Raum-Code).
class RoomErrorMessage extends SignalingMessage {
  final String message;

  RoomErrorMessage(this.message);

  @override
  String get type => 'error';

  @override
  Map<String, dynamic> toJson() => {'message': message};

  factory RoomErrorMessage.fromJson(Map<String, dynamic> json) =>
      RoomErrorMessage(json['message'] as String);
}

/// Dekodiert eine empfangene Signaling-Nachricht.
SignalingMessage decodeSignalingMessage(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final type = json['type'] as String;
  switch (type) {
    case 'createRoom':
      return CreateRoomMessage.fromJson(json);
    case 'roomCreated':
      return RoomCreatedMessage.fromJson(json);
    case 'joinRoom':
      return JoinRoomMessage.fromJson(json);
    case 'roomJoined':
      return RoomJoinedMessage.fromJson(json);
    case 'peerJoined':
      return PeerJoinedMessage.fromJson(json);
    case 'peerLeft':
      return PeerLeftMessage.fromJson(json);
    case 'sdpOffer':
      return SdpOfferMessage.fromJson(json);
    case 'sdpAnswer':
      return SdpAnswerMessage.fromJson(json);
    case 'iceCandidate':
      return IceCandidateMessage.fromJson(json);
    case 'error':
      return RoomErrorMessage.fromJson(json);
    default:
      throw FormatException('Unbekannter Signaling-Nachrichtentyp: $type');
  }
}
