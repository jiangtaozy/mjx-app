/*
 * Maintained by jemo from 2019.5.29 to now
 * Created by jemo on 2019.5.29 16:38
 * Classroom
 */

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/webrtc.dart';
import 'dart:core';
import 'dart:async';

class Classroom extends StatefulWidget {

  @override
  ClassroomState createState() => ClassroomState();

}

class ClassroomState extends State<Classroom> {

  MediaStream localStream;
  RTCPeerConnection peerConnection;
  final localRenderer = new RTCVideoRenderer();
  final remoteRenderer = new RTCVideoRenderer();
  bool inCalling = false;
  Timer timer;

  @override
  initState() {
    super.initState();
    initRenderers();
  }

  @override
  deactivate() {
    super.deactivate();
    if(inCalling) {
      hangUp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        child: Stack(
          children: [
            Align(
              alignment: const FractionalOffset(0.5, 0.1),
              child: Container(
                width: 320.0,
                height: 240.0,
                child: RTCVideoView(localRenderer),
              ),
            ),
            Align(
              alignment: const FractionalOffset(0.5, 0.9),
              child: Container(
                width: 320.0,
                height: 240.0,
                child: RTCVideoView(remoteRenderer),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: inCalling ? hangUp : makeCall,
        tooltip: inCalling ? '挂断' : '通话',
        child: Icon(inCalling ? Icons.call_end : Icons.phone),
      ),
    );
  }

  initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  makeCall() async {
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
      },
    };
    Map<String, dynamic> configuration = {
      'iceServers': [
        {
          'url': 'stun:stun.l.google.com:19302',
        },
      ],
    };
    final Map<String, dynamic> offerSDPConstraints = {
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': true,
      },
      'optional': [],
    };
    final Map<String, dynamic> loopbackConstraints = {
      'mandatory': {},
      'optional': [
        {
          'DtlsSrtpKeyAgreement': false,
        },
      ],
    };
    if(peerConnection != null) return;
    try {
      localStream = await navigator.getUserMedia(mediaConstraints);
      localRenderer.srcObject = localStream;
      peerConnection =
      await createPeerConnection(configuration, loopbackConstraints);
      peerConnection.onSignalingState = onSignalingState;
      peerConnection.onIceGatheringState = onIceGatheringState;
      peerConnection.onIceConnectionState = onIceConnectionState;
      peerConnection.onAddStream = onAddStream;
      peerConnection.onRemoveStream = onRemoveStream;
      peerConnection.onIceCandidate = onCandidate;
      peerConnection.onRenegotiationNeeded = onRenegotiationNeeded;
      peerConnection.addStream(localStream);
      RTCSessionDescription description =
      await peerConnection.createOffer(offerSDPConstraints);
      print('sdp: ${description.sdp}');
      peerConnection.setLocalDescription(description);
      description.type = 'answer';
      peerConnection.setRemoteDescription(description);
      //timer = new Timer.periodic(Duration(seconds: 1), handleStatsReport);
      setState(() {
        inCalling = true;
      });
    }
    catch(e) {
      print(e.toString());
    }
  }

  hangUp() async {
    try {
      await localStream.dispose();
      await peerConnection.close();
      peerConnection = null;
      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;
    }
    catch(e) {
      print(e.toString());
    }
    setState(() {
      inCalling = false;
    });
  }

  void handleStatsReport(Timer timer) async {
    if(peerConnection != null) {
      List<StatsReport> reports = await peerConnection.getStats(null);
      reports.forEach((report) {
        print('report => { ');
        print('    id: ${report.id},');
        print('    type: ${report.type}');
        print('    timestamp: ${report.timestamp},');
        print('    values => {');
        report.values.forEach((key, value) {
          print('        ${key}: ${value},');
        });
        print('    }');
        print('}');
      });
    }
  }

  onSignalingState(RTCSignalingState state) {
    print(state);
  }

  onIceGatheringState(RTCIceGatheringState state) {
    print(state);
  }

  onIceConnectionState(RTCIceConnectionState state) {
    print(state);
  }

  onAddStream(MediaStream stream) {
    print('addStream.id: ${stream.id}');
    remoteRenderer.srcObject = stream;
  }

  onRemoveStream(MediaStream stream) {
    remoteRenderer.srcObject = null;
  }

  onCandidate(RTCIceCandidate candidate) {
    print('onCandidate: ${candidate.candidate}');
    peerConnection.addCandidate(candidate);
  }

  onRenegotiationNeeded() {
    print('RenegotiationNeeded');
  }
}
