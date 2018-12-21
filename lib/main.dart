import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:device_info/device_info.dart';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:convert/convert.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

List<CameraDescription> cameras;
Dio dio;
List refPics;
String imagePath;
final double padding = 15.0;
String deviceId;

final String upyunDomain = 'http://v0.api.upyun.com';
final String upyunBucket = 'challenget-image';
final String upyunDir = 'face';
final String upyunImage = '$upyunDomain/$upyunBucket/$upyunDir';
final List<String> upyunOperator = ['challenget', 'tt199223'];

Future<void> main() async {
  // Fetch the available cameras before initializing the app.
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    logCameraError(e.code, e.description);
  }
  dio = getHttpClient();
  refPics = getRefPics();
  setDeviceId();
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

Future<void> setDeviceId() async {
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  if (Platform.isAndroid) {
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    deviceId = androidInfo.androidId;
  } else if (Platform.isIOS) {
    IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
    deviceId = iosInfo.identifierForVendor;
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
              MaterialPageRoute(builder: (context) => FaceCamera()),
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

    _handleCameraSwitch();
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
              color: Colors.black,
              icon: Icon(Icons.switch_camera),
              onPressed: () {
                _handleCameraSwitch();
              })));

      // 拍照按钮
      toggles.add(
        SizedBox(
            width: 90.0,
            child: IconButton(
              iconSize: 30.0,
              color: Colors.black,
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

  void _handleCameraSwitch() {
    onNewCameraSelected(cameras[descriptionIndex]);
    descriptionIndex++;
    if (descriptionIndex == cameras.length) {
      descriptionIndex = 0;
    }
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
      imagePath = filePath;

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
    var dirPath = await getDirPath();
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
    logCameraError(e.code, e.description);
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
  String iter;
  final String lastIter = 'g2gCZAAEbmV4dGQAA2VvZg';
  bool loadAllPics = false;

  // 当前图片列表
  List files = [];
  double confidence;

  // 当前下载图片
  List<int> curPic;

  // 用于展示
  String curPicPath;

  // 最大获取图片列表次数
  final int maxGetPicList = 1;
  int curGetPicList = 0;

  // 最终结果，找到还是没找到
  bool found;

  BuildContext _context;

  @override
  void initState() {
    super.initState();
    _init();
  }

  /// @param type - 路线类型
  /// 1 获取图片列表 -> 下载图片 -> 面部比对
  /// 2 下载图片 -> 面部比对
  Future<void> _init([int type = 1]) async {
    if (type == 1) {
      await _getPicList();
    }
    curPic = await _downloadPic();
    if (curPic != null) {
      var result = await _compare(curPic);
      _handleResult(result);
    }
  }

  // 又拍云获取图片列表
  // 每次默认取100个，支持调用多次
  Future<void> _getPicList() async {
    if (loadAllPics) {
      return;
    }

    var headers = getYpyunImageHeader(uri: upyunImage);

    headers['Accept'] = 'application/json';
    if (iter != null) {
      headers['x-list-iter'] = iter;
    }

    try {
      var response =
          await dio.get(upyunImage, options: new Options(headers: headers));

      var data = response?.data;
      iter = data['iter'];
      files = data['files'];
      curGetPicList++;

      if (iter == lastIter) {
        loadAllPics = true;
      }
    } on DioError catch (e) {
      logDioError(e);
    }
  }

  Future<dynamic> _downloadPic() async {
    String picPath = _findFirstPic();

    if (picPath != null) {
      var headers = getYpyunImageHeader(uri: picPath);

      try {
        var response = await dio.get(picPath,
            options: new Options(
                headers: headers, responseType: ResponseType.STREAM));

        var data = response?.data;
        List<int> contents = [];

        await for (List<int> content in data) {
          contents.addAll(content);
        }

        return contents;
      } on DioError catch (e) {
        logDioError(e);
      }
    } else {
      _handleFail();
    }
  }

  // 找第一张要下载的图片 1 去除已下载 2 去除用户自己的
  /// @param mark - 标记download
  String _findFirstPic([bool mark = true]) {
    String picPath;

    if (files.isNotEmpty) {
      for (var file in files) {
        String name = file['name'];

        if (file['download'] == null && !name.startsWith(deviceId)) {
          picPath = '$upyunImage/$name';
          if (mark) {
            file['download'] = true;
          }
          break;
        }
      }
    }

    return picPath;
  }

  Future<dynamic> _compare(List<int> targetPic) async {
    final apiKey = '4OBMLbwJjOGx6zdRSfE64sCyXUtPOYYn';
    final apiSecret = 'TbZUyEmYbYX0lFV8LQ9AAnMDXM6wX0dl';
    final pic1 = UploadFileInfo(File(imagePath), 'myFace');
    final pic2 = UploadFileInfo.fromBytes(targetPic, 'refFace');
    final String url = 'https://api-cn.faceplusplus.com/facepp/v3/compare';

    FormData formData = FormData.from({
      'api_key': apiKey,
      'api_secret': apiSecret,
      'image_file1': pic1,
      'image_file2': pic2
    });

    try {
      var response = await dio.post(url, data: formData);
      return response.data;
    } on DioError catch (e) {
      logDioError(e);
    }
  }

  Future<void> _handleResult(result) async {
    confidence = result['confidence'];
    var thresholds = result['thresholds'];

    if (confidence != null && thresholds != null) {
      bool isMax = true;
      thresholds.forEach((key, val) {
        if (confidence < val) {
          isMax = false;
        }
      });

      if (isMax) {
        // 图片二进制显示
        var dirPath = await getDirPath();
        curPicPath = '$dirPath/${timestamp()}.jpg';
        File file = File(curPicPath);
        await file.writeAsBytes(curPic);

        setState(() {
          found = true;
        });

        // 上传当前人脸图像
        _uploadCurFace();
      } else {
        _handleFail();
      }
    } else {
      _handleFail();
    }
  }

  void _handleFail() {
    String picPath = _findFirstPic(false);

    if (picPath != null) {
      _init(2);
    } else {
      if (curGetPicList == maxGetPicList || loadAllPics) {
        setState(() {
          found = false;
        });
        _uploadCurFace();
      } else {
        _init();
      }
    }
  }

  Future<void> _uploadCurFace() async {
    String name = '$deviceId-${timestamp()}.jpg';
    String picPath = '$upyunImage/$name';

    var date = DateTime.now();
    String gmtDate = getGMTTime(date);
    int utcDate =
        date.add(Duration(minutes: 30)).toUtc().millisecondsSinceEpoch;
    String policy = getYpyunImagePolicy(upyunBucket, '$upyunDir/$name', utcDate,
        date: gmtDate);
    var headers = getYpyunImageHeader(
        method: 'POST', uri: picPath, policy: policy, date: gmtDate);

    FormData formData = FormData.from({
      'file': UploadFileInfo(File(imagePath), 'myFace'),
      'policy': policy,
      'authorization': headers['Authorization']
    });

    try {
      await dio.post(picPath, data: formData);
    } on DioError catch (e) {
      logDioError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    _context = context;
    Widget widget;

    if (found == null) {
      // loading
      widget = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(bottom: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  '面部识别中，请耐心等待...',
                  style: TextStyle(fontSize: 16.0),
                )
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              loadingWidget(),
            ],
          )
        ],
      );
    } else if (found == true) {
      widget = Column(
        children: <Widget>[
          _titleWidget('哇，还有和你这么像的人！'),
          _imgWidget(imagePath),
          _middleWidget(confidence),
          _imgWidget(curPicPath),
        ],
      );
    } else {
      widget = Column(
        children: <Widget>[
          _titleWidget('没有找到和你相似的人，独一无二的你！'),
          _imgWidget(imagePath),
        ],
      );
    }

    return Scaffold(appBar: appBar(), body: widget);
  }

  Widget _titleWidget(String title) {
    return Row(
      children: <Widget>[
        Padding(
            padding: EdgeInsets.only(top: 10.0, left: padding, right: padding),
            child: Text(
              title,
              style: TextStyle(fontSize: 16.0),
            ))
      ],
    );
  }

  Widget _imgWidget(imgPath) {
    return Expanded(
        child: Container(
//        decoration: BoxDecoration(color: Colors.grey),
      padding: EdgeInsets.symmetric(vertical: 10.0),
      child: Image.asset(imgPath, fit: BoxFit.contain),
    ));
  }

  Widget _middleWidget([double confidence = 0]) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _dividerWidget(),
        Text('相似率${percent(confidence / 100)}'),
        _dividerWidget(),
      ],
    );
  }

  Widget _dividerWidget() {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: padding),
        decoration: BoxDecoration(
            border: Border(
                top: BorderSide(
                    width: 1.0, color: Theme.of(_context).dividerColor))),
      ),
    );
  }
}

void logCameraError(String code, String message) =>
    print('Error: $code\nError Message: $message');

void logDioError(e) {
  if (e.response) {
    print(e.response.data);
    print(e.response.headers);
    print(e.response.request);
  } else {
    // Something happened in setting up or sending the request that triggered an Error
    print(e.request);
    print(e.message);
  }
}

Map<String, dynamic> extend(
    Map<String, dynamic> obj, Map<String, dynamic> target) {
  target.forEach((key, val) {
    obj[key] = val;
  });
  return obj;
}

Future<String> getDirPath() async {
  final Directory extDir = await getApplicationDocumentsDirectory();
  final String dirPath = '${extDir.path}/Pictures/face';
  await Directory(dirPath).create(recursive: true);
  return dirPath;
}

String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

Map<String, dynamic> getYpyunImageHeader(
    {String method = 'GET', String uri, String policy, String date}) {
  if (date == null) {
    date = getGMTTime();
  }
  String key = upyunOperator[0];
  String password = upyunOperator[1];

  String secret = hex.encode(md5.convert(utf8.encode(password)).bytes);
  uri = Uri.parse(uri).path;

  List temArr = [method, uri, date];
  if (policy != null) {
    temArr.add(policy);
  }
  String value = temArr.join('&');

  String auth = hmacsha1(secret, value);

  return {'Authorization': 'UPYUN $key:$auth', 'Date': date};
}

String getGMTTime([DateTime date]) {
  if (date == null) {
    date = DateTime.now();
  }
  return DateFormat("E, dd MMM y HH:mm:ss 'GMT'")
      .format(date.add(Duration(hours: -8)));
}

String getYpyunImagePolicy(bucket, saveKey, expiration, {String date}) {
  var obj = {'bucket': bucket, 'save-key': saveKey, 'expiration': expiration};
  if (date != null) {
    obj['date'] = date;
  }
  var str = json.encode(obj);
  return base64.encode(utf8.encode(str));
}

String hmacsha1(String secret, String value) {
  var secretBytes = utf8.encode(secret);
  var valueBytes = utf8.encode(value);
  var hmaSha1 = Hmac(sha1, secretBytes);
  var digest = hmaSha1.convert(valueBytes);
  return base64.encode(digest.bytes);
}

String percent(num obj) => '${obj * 100}%';

Widget loadingWidget(
    {Color color = Colors.blue, num size = 30.0, num lineWidth = 4.0}) {
  return SpinKitRing(
    color: color,
    size: size,
    lineWidth: lineWidth,
  );
}
