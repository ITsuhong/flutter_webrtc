import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_webrtc/flutter_webrtc.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text("这是视频电话"),
        ),
        body: const MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  IO.Socket? socket;
  int roomId = 1;

  final _localVideoRenderer = RTCVideoRenderer();
  late RTCPeerConnection localConnection;
  dynamic localstream = null;

  final _remoteVideoRenderer = RTCVideoRenderer();
  late RTCPeerConnection remoteConnection;
  late MediaStream remotestream;
  bool caller = false;
  bool called = false;

  final Map<String, dynamic> localmediaConstraints = {
    'audio': true,
    'video': {
      "width": {"ideal": 8000},
      "heigth": {"ideal": 6000},
      'facingMode': 'user', //'facingMode': 'user','facingMode': 'environment',
      "frameRate": {
        "ideal": 60,
      },
    }
  };

  final Map<String, dynamic> remotemediaConstraints = {
    'audio': true,
    'video': {
      "width": {"ideal": 8000},
      "heigth": {"ideal": 6000},
      'facingMode': 'environment', //'facingMode': 'user',
      "frameRate": {
        "ideal": 60,
      },
    }
  };
  Map<String, dynamic> configuration = {
    "iceServers": [
      {"url": "stun:stun.l.google.com:19302"},
    ]
  };
  final Map<String, dynamic> sdpConstraints = {
    "mandatory": {
      "OfferToReceiveAudio": true,
      "OfferToReceiveVideo": false,
    },
    "optional": [],
  };

  final Map<String, dynamic> pcConstraints = {
    "mandatory": {},
    "optional": [],
  };

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    initISocket();
    initRenderers();
    // _getlocalUserMedia();
  }

  initISocket() async {
    socket = IO.io('http://172.21.192.1:3000', <String, dynamic>{
      'autoConnect': true,
      'transports': ['websocket'],
    });
    socket!.connect();
    socket!.onConnect((_) {
      print('Connection established');
    });
    socket!.onDisconnect((_) => print('Connection Disconnection'));
    socket!.onConnectError((err) => print(err));
    socket!.onError((err) => print(err));
    socket!.on('connectionSuccess', (newMessage) {
      print("连接成功");
    });
    // Map data = {'roomId': roomId};
    socket!.emit('joinRoom', roomId);
    socket!.on('acceptCall', (data) async {
      if (caller) {
        //生成offer
        RTCSessionDescription offer =
            await localConnection.createOffer(sdpConstraints);
        localConnection.setLocalDescription(offer);
        remoteConnection.setRemoteDescription(offer);

        remoteConnection =
            await createPeerConnection(configuration, pcConstraints);
        remoteConnection.onIceCandidate = (candidate) {
          localConnection.addCandidate(candidate);
        };
        Map data = {'roomId': roomId, "offer": offer.sdp};
        socket!.emit('sendOffer', data);
      }
      // setState(() {
      //   caller = false;
      //   called = true;
      // });
    });
    socket!.on('sendAnswer', (data) {
      print("收到回复");
      print(data);
    });
  }

  void initRenderers() async {
    await _localVideoRenderer.initialize();
    await _remoteVideoRenderer.initialize();
  }

  _getlocalUserMedia() async {
    localstream =
        await navigator.mediaDevices.getUserMedia(localmediaConstraints);
    _localVideoRenderer.srcObject = localstream;
    localConnection = await createPeerConnection(configuration, pcConstraints);
    remoteConnection = await createPeerConnection(configuration, pcConstraints);
    localConnection.onIceCandidate = (candidate) {
      remoteConnection.addCandidate(candidate);
    };
    localConnection.onConnectionState = (state) {
      print(state);
    };

    for (MediaStreamTrack track in localstream.getTracks()) {
      localConnection.addTrack(track, localstream);
    }
    // 确保对视频轨道调用 setTorch
    final videoTracks = localstream.getVideoTracks();
    if (videoTracks.isNotEmpty) {
      videoTracks[0].setTorch(true);
    } else {
      print("No video tracks available1");
    }
    setState(() {});
  }

  //拨打电话

  CallUser() {
    caller = true;
    if (localstream == null) {
      _getlocalUserMedia();
    }
    socket!.emit("call", roomId);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      // child: _localRenderer.srcObject != null
      //     ? RTCVideoView(_localRenderer)
      //     : CircularProgressIndicator(),
      child: Column(
        children: [
          Container(
            key: const Key('local'),
            margin: const EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
            decoration: const BoxDecoration(color: Colors.black),
            child: Container(
              height: 300,
              width: 200,
              child: localstream != null
                  ? RTCVideoView(_localVideoRenderer)
                  : Text(
                      "等待连接",
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                  onPressed: () {
                    CallUser();
                  },
                  child: Text("拨打视频")),
              ElevatedButton(onPressed: () {}, child: Text("接听"))
            ],
          )
        ],
      ),
    );
  }
}
