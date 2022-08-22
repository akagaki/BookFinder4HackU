import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.first;

  // runApp(
  //   MaterialApp(
  //     theme: ThemeData.dark(),
  //     home: TakePictureScreen(
  //       camera: firstCamera,
  //     ),
  //   ),
  // );
  runApp(MyApp(camera: firstCamera));
}

class MyApp extends StatelessWidget {
  MyApp({super.key, required this.camera});
  CameraDescription camera;
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Page Route',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(camera: camera),
    );
  }
}

class MyHomePage extends StatelessWidget {
  MyHomePage({Key? key, required this.camera}) : super(key: key);
  CameraDescription camera;

  String search_word = "";
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("First Page"),
      ),
      body: Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ignore: prefer_const_constructors
          SizedBox(
            width: 300,
            child: TextField(
            maxLines: 1,
            decoration: const InputDecoration(hintText: '検索ワード：ネットワーク，プログラミング'),
            onChanged: (text){
              search_word = text;
            }
          ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                CupertinoPageRoute(builder: (context){
                return TakePictureScreen(search_word: search_word, camera: camera);
              })
            );
            },
            child: const Text("Take Picture"),
          ),
        ],
      ),)
    );
  }
}

// A screen that allows users to take a picture using a given camera.
class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen({
    super.key,
    required this.camera,
    required this.search_word
  });

  final CameraDescription camera;
  final String search_word;

  @override
  // ignore: no_logic_in_create_state
  TakePictureScreenState createState() => TakePictureScreenState(search_word);
}

class TakePictureScreenState extends State<TakePictureScreen> {
  TakePictureScreenState(this.search_word);
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final String search_word;

  @override
  void initState() {
    super.initState();
    // To display the current output from the Camera,
    // create a CameraController.
    _controller = CameraController(
      // Get a specific camera from the list of available cameras.
      widget.camera,
      // Define the resolution to use.
      ResolutionPreset.medium,
    );

    // Next, initialize the controller. This returns a Future.
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Take a picture')),
      // You must wait until the controller is initialized before displaying the
      // camera preview. Use a FutureBuilder to display a loading spinner until the
      // controller has finished initializing.
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // If the Future is complete, display the preview.
            return CameraPreview(_controller);
          } else {
            // Otherwise, display a loading indicator.
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        // Provide an onPressed callback.
        onPressed: () async {
          // Take the Picture in a try / catch block. If anything goes wrong,
          // catch the error.
          try {
            // Ensure that the camera is initialized.
            await _initializeControllerFuture;

            // Attempt to take a picture and get the file `image`
            // where it was saved.
            final image = await _controller.takePicture();

            if (!mounted) return;

            // If the picture was taken, display it on a new screen.
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => DisplayPictureScreen(
                  // Pass the automatically generated path to
                  // the DisplayPictureScreen widget.
                  imagePath: image.path,
                  search_word: search_word,
                ),
              ),
            );
          } catch (e) {
            // If an error occurs, log the error to the console.
            print(e);
          }
        },
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}

// A widget that displays the picture taken by the user.
class DisplayPictureScreen extends StatelessWidget {
  final String imagePath;
  final String search_word;

  const DisplayPictureScreen({super.key, required this.imagePath, required this.search_word});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Display the Picture')),
      // The image is stored as a file on the device. Use the `Image.file`
      // constructor with the given path to display the image.
      body: Column(
        children: [
          Image.file(File(imagePath)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                child: const Text('送信'),
                style: ElevatedButton.styleFrom(
                  primary: Colors.tealAccent,
                  onPrimary: Colors.black,
                  shape: const StadiumBorder(),
                ),
                onPressed: () async {
                  /// file -> base64
                  //画像ファイルをバイトのリストとして読み込む
                  List<int> imageBytes = File(imagePath).readAsBytesSync();

                  //base64にエンコード
                  String base64Image = base64Encode(imageBytes);

                  //サーバー側で設定してあるURLを選択
                  Uri url = Uri.parse('http://192.168.2.162:5000');

                  String body = json.encode({
                    'post_img': base64Image,
                    'post_text': search_word,
                  });

                  /// send to backend
                  // サーバーにデータをPOST,予測画像をbase64に変換したものを格納したJSONで返ってくる
                  Response response = await http.post(url, body: body);

                  /// base64 -> file
                  final data = json.decode(response.body);
                  String imageBase64 = data['result'];
                  //バイトのリストに変換
                  Uint8List bytes = base64Decode(imageBase64);

                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ResultScreen(
                        // Pass the automatically generated path to
                        // the DisplayPictureScreen widget.
                        result: bytes,
                      ),
                    ),
                  );
                },
              ),
            ],
        )],
      )
    );
  }
}


class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.result,
  });
  final Uint8List result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Result')),
        // The image is stored as a file on the device. Use the `Image.file`
        // constructor with the given path to display the image.
        body: Center(
          child: RotatedBox(
            quarterTurns: 45,
            child: Image.memory(result),
          )
        )
    );
  }
}