import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_tts/flutter_tts.dart';
void main() async {
// Ensure that plugin services are initialized
WidgetsFlutterBinding.ensureInitialized();

// Obtain a list of the available cameras on the device
final cameras = await availableCameras();

// Get the first camera from the list of available cameras
final firstCamera = cameras.first;

runApp(MyApp(camera: firstCamera));
}

class MyApp extends StatelessWidget {
final CameraDescription camera;

const MyApp({Key? key, required this.camera}) : super(key: key);

@override
Widget build(BuildContext context) {
return MaterialApp(
debugShowCheckedModeBanner: false,
title: 'curdet',
home: CameraScreen(camera: camera),
);
}
}

class CameraScreen extends StatefulWidget {
final CameraDescription camera;

const CameraScreen({Key? key, required this.camera}) : super(key: key);

@override
_CameraScreenState createState() => _CameraScreenState();

}

class _CameraScreenState extends State<CameraScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts flutterTts = FlutterTts();
  double speechRate = 0.8;


  CameraController? _controller;
Future<void>? _initializeControllerFuture;
  String val = "";
  String val_auth = "";
@override
void initState() {
  super.initState();
  // Create a CameraController instance
  _controller = CameraController(
    widget.camera,
    ResolutionPreset.medium,
  );
  _initializeCameraController();
  Vibration.vibrate();
}

  void _initializeCameraController() {
    // Create a CameraController instance
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
    );



// Initialize the controller asynchronously
_initializeControllerFuture = _controller!.initialize();
}

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed
    _controller!.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      // Ensure that the controller is initialized before taking a picture
      await _initializeControllerFuture;

      // Play the shutter sound
      _audioPlayer.play(AssetSource('shutter.mp3'));

      // Get a photo from the camera
      final image = await _controller!.takePicture();
      List<int> imageBytes = await File(image.path).readAsBytes();
      // Encode the image data as a base64 string
      String base64Image = base64Encode(imageBytes);

      // Send a POST request to the server with the image data
      var response = await http.post(
        Uri.parse('http://192.168.15.254:5000/api/currency-classification'),
        headers:{'Content-Type':'application/x-www-form-urlencoded'},
        body: {'image': base64Image},
      );

      // Get the prediction result from the response
// Get the prediction result from the response
      String resultAuth="";
      String result = response.body;
      Map<String, dynamic> jsonMap = json.decode(result);
      String val= jsonMap['currency_class'];
      debugPrint(val);
      await flutterTts.speak('The note value is $val');
      if ((val == '500' || val == '2000')){
        var responseAuth = await http.post(
          Uri.parse('http://192.168.15.254:80/api/currency-authentication'),
          headers:{'Content-Type':'application/x-www-form-urlencoded'},
          body: {'image': base64Image},
        );
        resultAuth = responseAuth.body;
        Map<String, dynamic> jsonMap = json.decode(resultAuth);
        String val_auth = jsonMap['currency_auth'];
        debugPrint(val_auth);
        await flutterTts.setSpeechRate(speechRate);
        await Future.delayed(const Duration(seconds: 5));
        await flutterTts.speak('The note is $val_auth');
      }






      // Display the prediction result on the screen
      // Display the photo on the screen
      // ignore: use_build_context_synchronously
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DisplayPictureScreen(imagePath:
          image.path,val: val,
              val_auth: val_auth,

          ),
        ),
      );
    } catch (e) {
      // If an error occurs, print the error to the console
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
        title: Text('Welcome to curDet'),
        backgroundColor: Colors.amber,
        leading: Container(
          padding: EdgeInsets.all(5),
          child: Image.asset('assets/logo.png'),
        ),  
    ),
      body: GestureDetector(
       onTap: _takePicture,
    child: FutureBuilder<void>(
    future: _initializeControllerFuture,
    builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.done) {
    if (_controller != null) {
      return Container(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      child: AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
        child: CameraPreview(_controller!),

    ),
    );

    }
    else {
      // Display an error message if _controller is null
      return const Center(child: Text('Failed to initialize camera'));
    }
    } else {
      // Display a loading indicator while the controller is being initialized
      return Center(child: CircularProgressIndicator());
    }
    },
    ),
    ),
    );
  }}

class DisplayPictureScreen extends StatelessWidget {
final String imagePath;
final String val;
final String val_auth;


const DisplayPictureScreen({Key? key, required this.imagePath,
  required this.val,
  required this.val_auth,})
    : super(key: key);

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: Text('Note value $val'),backgroundColor: Colors.amber,),
    body: Column(
      children: [
        Expanded(child: Image.file(File(imagePath))),
        const SizedBox(height: 16),
        Text(
          'Authenticity: $val_auth',
          style: const TextStyle(fontSize: 18,fontWeight: FontWeight.bold),
        ),
        Text(
          'Note value: $val',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}
}





