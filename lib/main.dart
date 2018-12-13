import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;

List<CameraDescription> cameras;
Dio dio;
List refPics;
String imagePath;
final double padding = 15.0;

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

Dio getHttpClient() {
  var dio = new Dio();

  return dio;
}

List getRefPics() {
  List refPics = ['images/me.jpeg'];

  return refPics;
}

class CameraApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CameraExampleHome(),
    );
  }
}

class CameraExampleHome extends StatefulWidget {
  @override
  _CameraExampleHomeState createState() {
    return _CameraExampleHomeState();
  }
}

class _CameraExampleHomeState extends State<CameraExampleHome> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar(needBack: false),
      body: ListView(
        children: <Widget>[
          Container(
              margin: EdgeInsets.only(top: 30.0, bottom: 10.0),
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text('人脸识别小游戏', style: TextStyle(fontSize: 20.0))
                ],
              )),
          _titleWidget('玩法'),
          _textWidget('点击开始按钮进行自拍，自拍完成后系统与图库进行比对，然后寻找与你最接近的人脸。'),
          _titleWidget('注意'),
          _textWidget('系统会自动存储你的自拍图像，该图像只用于游戏内，不会在任何其他地方使用和展示。')
        ],
      ),
      floatingActionButton: FloatingActionButton(
          child: Text('开始'),
          onPressed: () {
            Navigator.push(
              context,
              // todo
              MaterialPageRoute(builder: (context) => FaceInfo()),
            );
          }),
    );
  }

  Widget _titleWidget(title) {
    return Container(
        margin: EdgeInsets.only(top: 20.0),
        padding: EdgeInsets.symmetric(horizontal: padding),
        child: Text(
          title,
          style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
        ));
  }

  Widget _textWidget(text) {
    return Container(
        margin: EdgeInsets.only(top: 10.0),
        padding: EdgeInsets.symmetric(horizontal: padding),
        child: Text(text, style: TextStyle(fontSize: 16.0), softWrap: true));
  }
}

Widget appBar({String title = 'Face', bool needBack = true}) {
  return AppBar(
    title: Text(title),
    leading: Builder(
      builder: (BuildContext context) {
        if (needBack) {
          return IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () {
              Navigator.pop(context);
            },
          );
        }
        return Container(
          width: 0,
          height: 0,
        );
      },
    ),
  );
}

class FaceCamera extends StatefulWidget {
  @override
  _FaceCameraState createState() {
    return _FaceCameraState();
  }
}

class _FaceCameraState extends State<FaceCamera> {
  CameraController controller;
  String videoPath;
  VideoPlayerController videoController;
  VoidCallback videoPlayerListener;
  BuildContext globalContext;

  // 摄像头前后置index
  int descriptionIndex;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    descriptionIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    globalContext = context;

    return Scaffold(
        key: _scaffoldKey,
        appBar: appBar(),
        body: Column(children: <Widget>[
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
                  color: Colors.grey,
                  width: 3.0,
                ),
              ),
            ),
          ),
          Padding(
              padding: const EdgeInsets.all(5.0),
              child: _cameraTogglesRowWidget()),
        ]));
  }

  /// Display the preview from the camera (or a message if the preview is not available).
  Widget _cameraPreviewWidget() {
    if (controller == null || !controller.value.isInitialized) {
      return const Text(
        '初始化...',
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

  /// Display a row of toggle to select the camera (or a message if no camera is available).
  Widget _cameraTogglesRowWidget() {
    final List<Widget> toggles = <Widget>[];

    if (cameras.isEmpty) {
      toggles.add(Text(
        '没有找到摄像头',
        style: TextStyle(fontSize: 20.0),
      ));
    } else {
      // 切换前后置按钮
      toggles.add(SizedBox(
          width: 90.0,
          child: IconButton(
              iconSize: 30.0,
              color: Colors.grey,
              icon: Icon(Icons.switch_camera),
              onPressed: () {
                if (controller != null) {
                  onNewCameraSelected(cameras[descriptionIndex]);
                  descriptionIndex++;
                  if (descriptionIndex == cameras.length) {
                    descriptionIndex = 0;
                  }
                }
              })));

      // 拍照按钮
      toggles.add(
        SizedBox(
            width: 90.0,
            child: IconButton(
              iconSize: 30.0,
              icon: Icon(Icons.camera_alt),
              onPressed: controller != null && controller.value.isInitialized
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

  void showInSnackBar(String message) {
    _scaffoldKey.currentState.showSnackBar(SnackBar(content: Text(message)));
  }

  void onTakePictureButtonPressed() {
    takePicture().then((String filePath) {
      Navigator.push(
        globalContext,
        MaterialPageRoute(builder: (context) => FaceInfo()),
      );
    });
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

  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  void _showCameraException(CameraException e) {
    logError(e.code, e.description);
    showInSnackBar('Error: ${e.code}\n${e.description}');
  }
}

class FaceInfo extends StatefulWidget {
  @override
  _FaceInfoState createState() {
    return _FaceInfoState();
  }
}

class _FaceInfoState extends State<FaceInfo> {
  var response;

  @override
  void initState() {
    super.initState();
    // todo
    response = {
      "time_used": 473,
      "confidence": 96.46,
      "thresholds": {
        "1e-3": 65.3,
        "1e-5": 76.5,
        "1e-4": 71.8
      },
      "request_id": "1469761507,07174361-027c-46e1-811f-ba0909760b18"
    };
//    _compare();
  }

  Future<void> _compare() async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar(),
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

void logError(String code, String message) =>
    print('Error: $code\nError Message: $message');
