//import 'package:flutter/material.dart';
//
//void main() {
//  runApp(App());
//}
//
//class App extends StatelessWidget {
//  @override
//  Widget build(BuildContext context) {
//    return MaterialApp(title: 'Face', home: Home());
//  }
//}
//
//class Home extends StatelessWidget {
//  @override
//  Widget build(BuildContext context) {
//    return Scaffold(
//        appBar: AppBar(
//          title: Text('Face'),
//        ),
//        body: Center(
//          child: Column(
//            mainAxisAlignment: MainAxisAlignment.center,
//            children: <Widget>[
//              Text(
//                '这是一个头像识别游戏',
//                style: TextStyle(fontSize: 18.0),
//              ),
//              HomeButton()
//            ],
//          ),
//        ));
//  }
//}
//
//class HomeButton extends StatelessWidget {
//  @override
//  Widget build(BuildContext context) {
//    return GestureDetector(
//      onTap: () {
//        print('MyButton was tapped!');
//      },
//      child: Container(
//        height: 46.0,
//        padding: const EdgeInsets.all(8.0),
//        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
//        decoration: BoxDecoration(
//          borderRadius: BorderRadius.circular(5.0),
//          color: Colors.blue,
//        ),
//        child: Center(
//          child: Text(
//            '玩玩看',
//            style: TextStyle(fontSize: 16.0, color: Colors.white),
//          ),
//        ),
//      ),
//    );
//  }
//}

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;

class CameraExampleHome extends StatefulWidget {
  @override
  _CameraExampleHomeState createState() {
    return _CameraExampleHomeState();
  }
}

/// Returns a suitable camera icon for [direction].
IconData getCameraLensIcon(CameraLensDirection direction) {
  switch (direction) {
    case CameraLensDirection.back:
      return Icons.camera_rear;
    case CameraLensDirection.front:
      return Icons.camera_front;
    case CameraLensDirection.external:
      return Icons.camera;
  }
  throw ArgumentError('Unknown lens direction');
}

void logError(String code, String message) =>
    print('Error: $code\nError Message: $message');

class _CameraExampleHomeState extends State<CameraExampleHome> {
  CameraController controller;
  String videoPath;
  VideoPlayerController videoController;
  VoidCallback videoPlayerListener;
  int contentShow = 1;
  var homeContext;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    homeContext = context;

    return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text('Face'),
        ),
        body: _bodyWidget());
  }

  Widget _bodyWidget() {
    if (contentShow == 1) {
      return AlertDialog(
        title: Text('提示'),
        content: Text('这是一个头像识别游戏，你可以点击下面的按钮来一张自拍体验一下'),
        actions: <Widget>[
          FlatButton(
            child: Text('好的'),
            onPressed: () {
              setState(() {
                contentShow = 2;
              });
            },
          ),
          FlatButton(
            child: Text('不要'),
            onPressed: () {
              setState(() {
                contentShow = 3;
              });
            },
          )
        ],
      );
    } else if (contentShow == 2) {
      return Column(children: <Widget>[
        Expanded(
          child: Container(
            child: Padding(
              padding: const EdgeInsets.all(1.0),
              child: Center(
                child: _cameraPreviewWidget(),
              ),
            ),
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(
                color: controller != null && controller.value.isRecordingVideo
                    ? Colors.redAccent
                    : Colors.grey,
                width: 3.0,
              ),
            ),
          ),
        ),
//          _captureControlRowWidget(),
        Padding(
            padding: const EdgeInsets.all(5.0),
            child: _cameraTogglesRowWidget()),
      ]);
    } else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Center(
            child: Text('确定不要试一试吗？', style: TextStyle(fontSize: 16.0)),
          ),
          Row(
            children: <Widget>[
              Expanded(
                  child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: RaisedButton(
                  child: Text('试一试'),
                  onPressed: () {
                    setState(() {
                      contentShow = 2;
                    });
                  },
                ),
              ))
            ],
          )
        ],
      );
    }
  }

  /// Display the preview from the camera (or a message if the preview is not available).
  Widget _cameraPreviewWidget() {
    if (controller == null || !controller.value.isInitialized) {
      return const Text(
        'Tap a camera',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {
      return AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: CameraPreview(controller),
      );
    }
  }

  /// Display the thumbnail of the captured image or video.
//  Widget _thumbnailWidget() {
//    return Expanded(
//      child: Align(
//        alignment: Alignment.centerRight,
//        child: videoController == null && imagePath == null
//            ? null
//            : SizedBox(
//                child: (videoController == null)
//                    ? Image.file(File(imagePath))
//                    : Container(
//                        child: Center(
//                          child: AspectRatio(
//                              aspectRatio: videoController.value.size != null
//                                  ? videoController.value.aspectRatio
//                                  : 1.0,
//                              child: VideoPlayer(videoController)),
//                        ),
//                        decoration: BoxDecoration(
//                            border: Border.all(color: Colors.pink)),
//                      ),
//                width: 64.0,
//                height: 64.0,
//              ),
//      ),
//    );
//  }

  /// Display the control bar with buttons to take pictures and record videos.
//  Widget _captureControlRowWidget() {
//    return IconButton(
//      icon: const Icon(Icons.camera_alt),
//      color: Colors.blue,
//      onPressed: controller != null &&
//              controller.value.isInitialized &&
//              !controller.value.isRecordingVideo
//          ? onTakePictureButtonPressed
//          : null,
//    );
//  }

  /// Display a row of toggle to select the camera (or a message if no camera is available).
  Widget _cameraTogglesRowWidget() {
    final List<Widget> toggles = <Widget>[];

    if (cameras.isEmpty) {
      toggles.add(Text('No camera found'));
    } else {
      for (CameraDescription cameraDescription in cameras) {
        toggles.add(SizedBox(
          width: 90.0,
          child: RadioListTile<CameraDescription>(
            title: Icon(getCameraLensIcon(cameraDescription.lensDirection)),
            groupValue: controller?.description,
            value: cameraDescription,
            onChanged: controller != null && controller.value.isRecordingVideo
                ? null
                : onNewCameraSelected,
          ),
        ));
      }

      toggles.add(
        SizedBox(
            width: 90.0,
            child: IconButton(
              icon: const Icon(Icons.camera_alt),
              color: Colors.blue,
              onPressed: controller != null &&
                      controller.value.isInitialized &&
                      !controller.value.isRecordingVideo
                  ? onTakePictureButtonPressed
                  : null,
            )),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: toggles,
    );
  }

  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  void showInSnackBar(String message) {
    _scaffoldKey.currentState.showSnackBar(SnackBar(content: Text(message)));
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    if (controller != null) {
      await controller.dispose();
    }
    controller = CameraController(cameraDescription, ResolutionPreset.high);

    // If the controller is updated then update the UI.
    controller.addListener(() {
      if (mounted) setState(() {});
      if (controller.value.hasError) {
        showInSnackBar('Camera error ${controller.value.errorDescription}');
      }
    });

    try {
      await controller.initialize();
    } on CameraException catch (e) {
      _showCameraException(e);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void onTakePictureButtonPressed() {
    takePicture().then((String filePath) {
      if (mounted) {
        setState(() {
          imagePath = filePath;
          videoController?.dispose();
          videoController = null;
        });
        if (filePath != null) showInSnackBar('Picture saved to $filePath');
        Navigator.push(
          homeContext,
          MaterialPageRoute(builder: (context) => FaceInfo()),
        );
      }
    });
  }

  void onVideoRecordButtonPressed() {
    startVideoRecording().then((String filePath) {
      if (mounted) setState(() {});
      if (filePath != null) showInSnackBar('Saving video to $filePath');
    });
  }

  void onStopButtonPressed() {
    stopVideoRecording().then((_) {
      if (mounted) setState(() {});
      showInSnackBar('Video recorded to: $videoPath');
    });
  }

  Future<String> startVideoRecording() async {
    if (!controller.value.isInitialized) {
      showInSnackBar('Error: select a camera first.');
      return null;
    }

    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/Movies/flutter_test';
    await Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${timestamp()}.mp4';

    if (controller.value.isRecordingVideo) {
      // A recording is already started, do nothing.
      return null;
    }

    try {
      videoPath = filePath;
      await controller.startVideoRecording(filePath);
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
    return filePath;
  }

  Future<void> stopVideoRecording() async {
    if (!controller.value.isRecordingVideo) {
      return null;
    }

    try {
      await controller.stopVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }

    await _startVideoPlayer();
  }

  Future<void> _startVideoPlayer() async {
    final VideoPlayerController vcontroller =
        VideoPlayerController.file(File(videoPath));
    videoPlayerListener = () {
      if (videoController != null && videoController.value.size != null) {
        // Refreshing the state to update video player with the correct ratio.
        if (mounted) setState(() {});
        videoController.removeListener(videoPlayerListener);
      }
    };
    vcontroller.addListener(videoPlayerListener);
    await vcontroller.setLooping(true);
    await vcontroller.initialize();
    await videoController?.dispose();
    if (mounted) {
      setState(() {
        imagePath = null;
        videoController = vcontroller;
      });
    }
    await vcontroller.play();
  }

  Future<String> takePicture() async {
    if (!controller.value.isInitialized) {
      showInSnackBar('Error: select a camera first.');
      return null;
    }
    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/Pictures/flutter_test';
    await Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${timestamp()}.jpg';

    if (controller.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }

    try {
      await controller.takePicture(filePath);
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
    return filePath;
  }

  void _showCameraException(CameraException e) {
    logError(e.code, e.description);
    showInSnackBar('Error: ${e.code}\n${e.description}');
  }
}

class CameraApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CameraExampleHome(),
    );
  }
}

List<CameraDescription> cameras;
var dio;
var refPics;
String imagePath;

getHttpClient() {
  var dio = new Dio();

  return dio;
}

List getRefPics() {
  List refPics = ['images/me.jpeg'];

  return refPics;
}

class FaceInfo extends StatefulWidget {
  @override
  _FaceInfoState createState() {
    _compare();
    return _FaceInfoState();
  }

  Future _compare() async {
    final apiKey = '4OBMLbwJjOGx6zdRSfE64sCyXUtPOYYn';
    final apiSecret = 'TbZUyEmYbYX0lFV8LQ9AAnMDXM6wX0dl';
    var pic = await rootBundle.load(refPics[0]);
    final pic1 = UploadFileInfo.fromBytes(pic.buffer.asInt8List(), 'refPic');
    final pic2 = UploadFileInfo(File(imagePath), 'uploadPic');
    final String url = 'https://api-cn.faceplusplus.com/facepp/v3/compare';

    FormData formData = FormData.from({
      'api_key': apiKey,
      'api_secret': apiSecret,
      'image_file1': pic1,
      'image_file2': pic2
    });

    var response = await dio.post(url, data: formData);
    print(response);
  }
}

class _FaceInfoState extends State<FaceInfo> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Face Info'),
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Navigator.pop(context);
              },
            );
          },
        ),
      ),
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 200.0,
            child: Image.asset(refPics[0]),
          ),
          Expanded(
            child: Image.file(File(imagePath)),
          )
        ],
      ),
    );
  }
}

Future<void> main() async {
  // Fetch the available cameras before initializing the app.
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    logError(e.code, e.description);
  }
  dio = getHttpClient();
  refPics = getRefPics();
  runApp(CameraApp());
}
