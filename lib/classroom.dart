/*
 * Maintained by jemo from 2019.5.29 to now
 * Created by jemo on 2019.5.29 16:38
 * Classroom
 */

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/webrtc.dart';
import 'dart:io';
import 'dart:core';
import 'dart:async';
import 'signaling.dart';

class Classroom extends StatefulWidget {

  @override
  ClassroomState createState() => ClassroomState();

}

class ClassroomState extends State<Classroom> {

  Signaling signaling;
  String displayName =
    Platform.localHostname + '(' + Platform.operatingSystem + ')';
  List<dynamic> peers;
  var selfId;
  RTCVideoRenderer localRenderer = new RTCVideoRenderer();
  RTCVideoRenderer remoteRenderer = new RTCVideoRenderer();
  bool inCalling = false;
  final String serverIP = '192.168.1.112';

  @override
  initState() {
    super.initState();
    initRenderers();
    connect();
  }

  @override
  deactivate() {
    super.deactivate();
    if(signaling != null) {
      signaling.close();
    }
    localRenderer.dispose();
    remoteRenderer.dispose();
  }

  initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  void connect() async {
    if(signaling == null) {
      signaling = new Signaling(serverIP, displayName)
        ..connect();
      signaling.onStateChange = (SignalingState state) {
        switch(state) {
          case SignalingState.CallStateNew:
            this.setState(() {
              inCalling = true;
            });
            break;
          case SignalingState.CallStateBye:
            this.setState(() {
              localRenderer.srcObject = null;
              remoteRenderer.srcObject = null;
              inCalling = false;
            });
            break;
          case SignalingState.CallStateInvite:
          case SignalingState.CallStateConnected:
          case SignalingState.CallStateRinging:
          case SignalingState.ConnectionClosed:
          case SignalingState.ConnectionError:
          case SignalingState.ConnectionOpen:
            break;
        }
      };
      signaling.onPeersUpdate = ((event) {
        this.setState(() {
          selfId = event['self'];
          peers = event['peers'];
        });
      });
      signaling.onLocalStream = ((stream) {
        localRenderer.srcObject = stream;
      });
      signaling.onAddRemoteStream = ((stream) {
        remoteRenderer.srcObject = stream;
      });
      signaling.onRemoveRemoteStream = ((stream) {
        remoteRenderer.srcObject = null;
      });
    }
  }
  invitePeer(context, peerId, useScreen) async {
    if(signaling != null && peerId != selfId) {
      signaling.invite(peerId, 'video', useScreen);
    }
  }
    
  hangUp() {
    if(signaling != null) {
      signaling.bye();
    }
  }

  switchCamera() {
    signaling.switchCamera();
  }

  muteMic() {
  }

  buildRow(context, peer) {
    var self = (peer['id'] == selfId);
    return ListBody(
      children: <Widget>[
        ListTile(
          title: Text(self
            ? peer['name'] + '[Your self]'
            : peer['name'] + '[' + peer['user_agent'] + ']'),
          onTap: null,
          trailing: new SizedBox(
            width: 100.0,
            child: new Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                IconButton(
                  icon: Icon(Icons.videocam),
                  onPressed: () => invitePeer(context, peer['id'], false),
                  tooltip: 'Video calling',
                ),
                IconButton(
                  icon: Icon(Icons.screen_share),
                  onPressed: () => invitePeer(context, peer['id'], true),
                  tooltip: 'Screen sharing',
                ),
              ],
            ),
          ),
          subtitle: Text('id: ' + peer['id']),
        ),
        Divider(),
      ]
    );
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('P2P Call Sample'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: null,
            tooltip: 'setup',
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: inCalling
        ? new SizedBox(
          width: 200.0,
          child: new Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              FloatingActionButton(
                child: const Icon(Icons.switch_camera),
                onPressed: switchCamera,
              ),
              FloatingActionButton(
                child: new Icon(Icons.call_end),
                onPressed: hangUp,
                tooltip: 'Hangup',
                backgroundColor: Colors.pink,
              ),
              FloatingActionButton(
                child: const Icon(Icons.mic_off),
                onPressed: muteMic,
              )
            ],
          ),
        )
        : null,
      body: inCalling
        ? OrientationBuilder(builder: (context, orientation) {
          return new Container(
            child: new Stack(
              children: <Widget>[
                new Positioned(
                  left: 0.0,
                  right: 0.0,
                  top: 0.0,
                  bottom: 0.0,
                  child: new Container(
                    margin: new EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                    child: new RTCVideoView(remoteRenderer),
                    decoration: new BoxDecoration(color: Colors.black54),
                  ),
                ),
                new Positioned(
                  left: 10.0,
                  top: 10.0,
                  child: new Container(
                    width: orientation == Orientation.portrait ? 90.0 : 120.0,
                    height: orientation == Orientation.portrait ? 120.0 : 90.0,
                    child: new RTCVideoView(localRenderer),
                    decoration: new BoxDecoration(color: Colors.black54),
                  ),
                ),
              ],
            ),
          );
        })
        : new ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.all(0.0),
          itemCount: (peers != null ? peers.length : 0),
          itemBuilder: (context, i) {
            return buildRow(context, peers[i]);
          },
        )
    );
  }
}
