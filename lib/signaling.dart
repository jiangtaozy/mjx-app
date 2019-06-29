/*
 * Maintained by jemo from 2019.6.12 to now
 * Created by jemo on 2019.6.12 15:14
 * Signaling
 */

import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter_webrtc/webrtc.dart';

enum SignalingState {
  CallStateNew,
  CallStateRinging,
  CallStateInvite,
  CallStateConnected,
  CallStateBye,
  ConnectionOpen,
  ConnectionClosed,
  ConnectionError,
}

typedef void SignalingStateCallback(SignalingState state);
typedef void StreamStateCallback(MediaStream stream);
typedef void OtherEventCallback(dynamic event);
typedef void DataChannelMessageCallback(RTCDataChannel dc, data);
typedef void DataChannelCallback(RTCDataChannel dc);

String randomNumber() {
  var rand = new Random();
  var selfId = rand.nextInt(100);
  return selfId.toString();
}

class Signaling {
  String selfId = randomNumber();
  var socket;
  var sessionId;
  var host;
  var port = 3001;
  var displayName;
  var peerConnections = new Map<String, RTCPeerConnection>();
  var dataChannels = new Map<String, RTCDataChannel>();
  MediaStream localStream;
  List<MediaStream> remoteStreams;
  SignalingStateCallback onStateChange;
  StreamStateCallback onLocalStream;
  StreamStateCallback onAddRemoteStream;
  StreamStateCallback onRemoveRemoteStream;
  OtherEventCallback onPeersUpdate;
  DataChannelMessageCallback onDataChannelMessage;
  DataChannelCallback onDataChannel;
  Map<String, dynamic> iceServers = {
    'iceServers': [
      {
        'url': 'stun:stun.l.google.com:19302',
      },
    ]
  };
  final Map<String, dynamic> config = {
    'mandatory': {},
    'optional': [
      {
        'DtlsSrtpKeyAgreement': true,
      },
    ],
  };
  final Map<String, dynamic> constraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true,
    },
    'optional': [],
  };
  final Map<String, dynamic> dataChannelConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': false,
      'OfferToReceiveVideo': false,
    },
    'optional': [],
  };
  Signaling(this.host, this.displayName);

  close() {
    if(localStream != null) {
      localStream.dispose();
      localStream = null;
    }
    peerConnections.forEach((key, pc) {
      pc.close();
    });
    if(socket != null) {
      socket.close();
    }
  }

  void switchCamera() {
    if(localStream != null) {
      localStream.getVideoTracks()[0].switchCamera();
    }
  }

  void invite(String peerId, String media, useScreen) {
    this.sessionId = this.selfId + '-' + peerId;
    if(this.onStateChange != null) {
      this.onStateChange(SignalingState.CallStateNew);
    }
    createRTCPeerConnection(peerId, media, useScreen).then((pc) {
      peerConnections[peerId] = pc;
      if(media == 'data') {
        createDataChannel(peerId, pc);
      }
      createOffer(peerId, pc, media);
    });
  }

  void bye() {
    send('bye', {
      'session_id': this.sessionId,
      'from': this.selfId,
    });
  }

  void onMessage(message) async {
    Map<String, dynamic> mapData = message;
    var data = mapData['data'];
    switch(mapData['type']) {
      case 'new':
        {
          List<dynamic> peers = [data];
          if(this.onPeersUpdate != null) {
            Map<String, dynamic> event = new Map<String, dynamic>();
            event['self'] = selfId;
            event['peers'] = peers;
            this.onPeersUpdate(event);
          }
        }
        break;
      case 'peers':
        {
          List<dynamic> peers = data;
          if(this.onPeersUpdate != null) {
            Map<String, dynamic> event = new Map<String, dynamic>();
            event['self'] = selfId;
            event['peers'] = peers;
            this.onPeersUpdate(event);
          }
        }
        break;
      case 'offer':
        {
          var id = data['from'];
          var description = data['description'];
          var media = data['media'];
          var sessionId = data['session_id'];
          this.sessionId = sessionId;
          if(this.onStateChange != null) {
            this.onStateChange(SignalingState.CallStateNew);
          }
          createRTCPeerConnection(id, media, false).then((pc) {
            peerConnections[id] = pc;
            pc.setRemoteDescription(new RTCSessionDescription(
              description['sdp'], description['type']
            ));
            createAnswer(id, pc, media);
          });
        }
        break;
      case 'answer':
        {
          var id = data['from'];
          var description = data['description'];
          var pc = peerConnections[id];
          if(pc != null) {
            pc.setRemoteDescription(new RTCSessionDescription(
              description['sdp'], description['type']
            ));
          }
        }
        break;
      case 'candidate':
        {
          var id = data['from'];
          var candidateMap = data['candidate'];
          var pc = peerConnections[id];
          if(pc != null) {
            RTCIceCandidate candidate = new RTCIceCandidate(
              candidateMap['candidate'],
              candidateMap['sdpMid'],
              candidateMap['sdpMLineIndex']
            );
            pc.addCandidate(candidate);
          }
        }
        break;
      case 'leave':
        {
          var id = data;
          peerConnections.remove(id);
          dataChannels.remove(id);
          if(localStream != null) {
            localStream.dispose();
            localStream = null;
          }
          var pc = peerConnections[id];
          if(pc != null) {
            pc.close();
            peerConnections.remove(id);
          }
          this.sessionId = null;
          if(this.onStateChange != null) {
            this.onStateChange(SignalingState.CallStateBye);
          }
        }
        break;
      case 'bye':
        {
          var from = data['from'];
          var to = data['to'];
          var sessionId = data['session_id'];
          if(localStream != null) {
            localStream.dispose();
            localStream = null;
          }
          var pc = peerConnections[to];
          if(pc != null) {
            pc.close();
            peerConnections.remove(to);
          }
          var dc = dataChannels[to];
          if(dc != null) {
            dc.close();
            dataChannels.remove(to);
          }
          this.sessionId = null;
          if(this.onStateChange != null) {
            this.onStateChange(SignalingState.CallStateBye);
          }
        }
        break;
      case 'keepalive':
        {
        }
        break;
      default:
        break;
    }
  }

  Future<WebSocket> connectForSelfSignedCert(String host, int port) async {
    try {
      Random r = new Random();
      String key = base64.encode(List<int>.generate(8, (_) => r.nextInt(255)));
      SecurityContext securityContext = new SecurityContext();
      HttpClient client = HttpClient(context: securityContext);
      client.badCertificateCallback = (X509Certificate cert, String host, int port) {
        return true;
      };
      HttpClientRequest request = await client.getUrl(
        Uri.parse('https://$host:$port/ws?teacherId=1')
      );
      request.headers.add('Connection', 'Upgrade');
      request.headers.add('Upgrade', 'websocket');
      request.headers.add('Sec-WebSocket-Version', '13');
      request.headers.add('Sec-WebSocket-Key', key.toLowerCase());
      HttpClientResponse response = await request.close();
      Socket socket = await response.detachSocket();
      var webSocket = WebSocket.fromUpgradedSocket(
        socket,
        protocol: 'signaling',
        serverSide: false,
      );
      return webSocket;
    }
    catch(e) {
      throw e;
    }
  }

  void connect() async {
    try {
      /*
      var url = 'ws://$host:$port';
      socket = await WebSocket.connect(url);
      */
      socket = await connectForSelfSignedCert(host, port);
      if(this.onStateChange != null) {
        this.onStateChange(SignalingState.ConnectionOpen);
      }
      socket.listen((data) {
        JsonDecoder decoder = new JsonDecoder();
        this.onMessage(decoder.convert(data));
      }, onDone: () {
        if(this.onStateChange != null) {
          this.onStateChange(SignalingState.ConnectionClosed);
        }
      });
      send('new', {
        'name': displayName,
        'id': selfId,
        'user_agent':
          'flutter-webrtc/' + Platform.operatingSystem + '-plugin 0.0.1',
      });
    }
    catch(e) {
      if(this.onStateChange != null) {
        this.onStateChange(SignalingState.ConnectionError);
      }
    }
  }

  Future<MediaStream> createStream(media, useScreen) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'mandatory': {
          'minWidth': '640',
          'minHeight': '480',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
      }
    };
    MediaStream stream = useScreen
      ? await navigator.getDisplayMedia(mediaConstraints)
      : await navigator.getUserMedia(mediaConstraints);
    if(this.onLocalStream != null) {
      this.onLocalStream(stream);
    }
    return stream;
  }

  createRTCPeerConnection(id, media, useScreen) async {
    if(media != 'data') {
      localStream = await createStream(media, useScreen);
    }
    RTCPeerConnection pc = await createPeerConnection(iceServers, config);
    if(media != 'data') {
      pc.addStream(localStream);
    }
    pc.onIceCandidate = (candidate) {
      send('candidate', {
        'to': id,
        'from': selfId,
        'candidate': {
          'sdpMLineIndex': candidate.sdpMlineIndex,
          'sdpMid': candidate.sdpMid,
          'candidate': candidate.candidate,
        },
        'session_id': this.sessionId,
      });
    };
    pc.onIceConnectionState = (state) {};
    pc.onAddStream = (stream) {
      if(this.onAddRemoteStream != null) {
        this.onAddRemoteStream(stream);
      }
    };
    pc.onRemoveStream = (stream) {
      if(this.onRemoveRemoteStream != null) {
        this.onRemoveRemoteStream(stream);
      }
      remoteStreams.removeWhere((it) {
        return (it.id == stream.id);
      });
    };
    pc.onDataChannel = (channel) {
      addDataChannel(id, channel);
    };
    return pc;
  }

  addDataChannel(id, RTCDataChannel channel) {
    channel.onDataChannelState = (e) {};
    channel.onMessage = (data) {
      if(this.onDataChannelMessage != null) {
        this.onDataChannelMessage(channel, data);
      }
    };
    dataChannels[id] = channel;
    if(this.onDataChannel != null) {
      this.onDataChannel(channel);
    }
  }

  createDataChannel(id, RTCPeerConnection pc, {label: 'fileTransfer'}) async {
    RTCDataChannelInit dataChannelDict = new RTCDataChannelInit();
    RTCDataChannel channel = await pc.createDataChannel(label, dataChannelDict);
    addDataChannel(id, channel);
  }

  createOffer(String id, RTCPeerConnection pc, String media) async {
    try {
      RTCSessionDescription s = await pc.createOffer(
        media == 'data' ? dataChannelConstraints : constraints
      );
      pc.setLocalDescription(s);
      send('offer', {
        'from': selfId,
        'to': id,
        'description': {
          'sdp': s.sdp,
          'type': s.type,
        },
        'session_id': this.sessionId,
        'media': media,
      });
    }
    catch(e) {
      print(e.toString());
    }
  }

  createAnswer(String id, RTCPeerConnection pc, media) async {
    try {
      RTCSessionDescription s = await pc.createAnswer(
        media == 'data' ? dataChannelConstraints : constraints
      );
      pc.setLocalDescription(s);
      send('answer', {
        'to': id,
        'from': selfId,
        'description': {
          'sdp': s.sdp,
          'type': s.type,
        },
        'session_id': this.sessionId,
      });
    }
    catch(e) {
      print(e.toString());
    }
  }

  send(event, data) {
    JsonEncoder encoder = new JsonEncoder();
    if(socket != null) {
      socket.add(encoder.convert({
        'type': event,
        'data': data,
      }));
    }
  }
}
