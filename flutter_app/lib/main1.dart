// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:image_picker/image_picker.dart';
// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter_tts/flutter_tts.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt;
//
// void main() {
//   runApp(MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//         visualDensity: VisualDensity.adaptivePlatformDensity,
//       ),
//       home: HomeScreen(),
//     );
//   }
// }
//
// class HomeScreen extends StatefulWidget {
//   @override
//   _HomeScreenState createState() => _HomeScreenState();
// }
//
// class _HomeScreenState extends State<HomeScreen> {
//   Color _buttonColor = Colors.amberAccent;
//   String _response = "";
//   String ip_address='192.168.45.17';
//   bool _isLoading = false;
//   final TextEditingController _controller = TextEditingController();
//   File? _image;
//   final picker = ImagePicker();
//   FlutterTts flutterTts = FlutterTts();
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeTTS();
//   }
//   Future<void> _initializeTTS() async {
//     try {
//       await flutterTts.setLanguage("en-US");
//       await flutterTts.setSpeechRate(0.5);
//       await flutterTts.setVolume(1.0);
//       await flutterTts.setPitch(1.0);
//
//       print("TTS initialized with language en-US.");
//
//       flutterTts.setStartHandler(() {
//         print("TTS started speaking.");
//       });
//
//       flutterTts.setCompletionHandler(() {
//         print("TTS finished speaking.");
//       });
//
//       flutterTts.setErrorHandler((msg) {
//         print("TTS Error: $msg");
//       });
//     } catch (e) {
//       print("Error initializing TTS: $e");
//     }
//   }
//
//   Future<void> _speak(String text) async {
//     try {
//       var result = await flutterTts.speak(text);
//       if (result == 1) {
//         print("TTS started successfully.");
//       }
//     } catch (e) {
//       print("Error speaking text: $e");
//     }
//   }
//
//
//   void _changeColorTemporarily() async {
//     setState(() {
//       _buttonColor = Colors.orange;
//       _isLoading = true;
//     });
//
//     String userInput = _controller.text;
//     String llmResponse = await _sendToLLM(userInput);
//
//     setState(() {
//       _response = llmResponse;
//       _buttonColor = Colors.amberAccent;
//       _isLoading = false;
//     });
//
//     _showResponseDialog(llmResponse);
//   }
//
//   Future<String> _sendToLLM(String userInput) async {
//     final response = await http.post(
//       Uri.parse('http://$ip_address:8000/response/invoke'),
//       headers: {"Content-Type": "application/json"},
//       body: jsonEncode({"input": {"query": userInput}}),
//     );
//
//     if (response.statusCode == 200) {
//       final jsonResponse = jsonDecode(response.body);
//       return jsonResponse['output']['content'];
//     } else {
//       return "Failed to communicate with server: ${response.statusCode}";
//     }
//   }
//
//   void _showResponseDialog(String response) {
//     _speak(response);
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Response'),
//           content: Text(response),
//           actions: <Widget>[
//             TextButton(
//               child: Text('Close'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   Future<String> _describeSceneWithLLM(String sceneDescription) async {
//     final response = await http.post(
//       Uri.parse('http://$ip_address:8000/response/invoke'), // LLM API URL
//       headers: {"Content-Type": "application/json"},
//       body: jsonEncode({"input": {"query": "you are now an assistant for a blind person, describe the object name, positioning and relative depth detection scene. The objects, their horizontal displacement from center in captured image and depth is given as follows: $sceneDescription. converse like a human and don't tell the depth units rather describe the distance as far, near etc.. your response should be in this format eg. a {object} is {depth} and to the {horizontal position}."}}),
//     );
//
//     if (response.statusCode == 200) {
//       final jsonResponse = jsonDecode(response.body);
//       return jsonResponse['output']['content'];
//     } else {
//       return "Failed to communicate with server: ${response.statusCode}";
//     }
//   }
//
//
//   Future<void> _captureAndSendImage() async {
//     final pickedFile = await picker.pickImage(source: ImageSource.camera);
//
//     if (pickedFile != null) {
//       setState(() {
//         _image = File(pickedFile.path);
//         _isLoading = true;
//       });
//
//       List<int> imageBytes = _image!.readAsBytesSync();
//       String base64Image = base64Encode(imageBytes);
//
//       String apiUrl = 'http://$ip_address:5000/process_image';
//       final response = await http.post(
//         Uri.parse(apiUrl),
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode({"image": base64Image}),
//       );
//
//       if (response.statusCode == 200) {
//         // Process the response from object detection API
//         String sceneDescription = response.body; // Customize based on actual response
//
//         // Send the scene description to LLM
//         String llmResponse = await _describeSceneWithLLM(sceneDescription);
//
//         setState(() {
//           _response = llmResponse;
//           _isLoading = false;
//         });
//
//         _showResponseDialog(_response);
//       } else {
//         setState(() {
//           _response = "Failed to communicate with server: ${response.statusCode}";
//           _isLoading = false;
//         });
//       }
//     }
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Home'),
//         foregroundColor: Colors.white70,
//         backgroundColor: Colors.deepPurple,
//         elevation: 6,
//         actions: [
//           IconButton(
//             icon: Icon(Icons.info_outline),
//             onPressed: () {
//               // Action for the info button
//             },
//           ),
//         ],
//       ),
//       body: Column(
//         children: <Widget>[
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: TextField(
//               controller: _controller,
//               decoration: InputDecoration(
//                 labelText: 'Enter your query',
//                 border: OutlineInputBorder(),
//               ),
//             ),
//           ),
//           Expanded(
//             child: GridView.count(
//               crossAxisCount: 2,
//               childAspectRatio: 1.0,
//               padding: EdgeInsets.all(16.0),
//               crossAxisSpacing: 16.0,
//               mainAxisSpacing: 16.0,
//               children: <Widget>[
//                 _buildButton(Colors.red, 'Capture & Send Image', _captureAndSendImage),
//                 _buildButton(Colors.green, 'Object Detection', () {}),
//                 _buildButton(Colors.blue, 'GPS Navigation', () {}),
//                 _buildButton(Colors.orange, 'Analyze Surroundings', () {}),
//               ],
//             ),
//           ),
//           Container(
//             width: double.infinity,
//             padding: EdgeInsets.all(16.0),
//             child: ElevatedButton(
//               onPressed: _changeColorTemporarily,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: _buttonColor,
//                 minimumSize: Size(double.infinity, 90),
//                 padding: EdgeInsets.symmetric(vertical: 16.0),
//               ),
//               child: _isLoading
//                   ? CircularProgressIndicator(
//                 valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//               )
//                   : Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(Icons.mic, size: 24.0),
//                   SizedBox(width: 8.0),
//                   Text('AI Button'),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildButton(Color color, String text, VoidCallback onPressed) {
//     return ElevatedButton(
//       onPressed: onPressed,
//       style: ElevatedButton.styleFrom(
//         backgroundColor: color,
//         minimumSize: Size(100, 100),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12.0),
//         ),
//         elevation: 5,
//       ),
//       child: Text(
//         text,
//         style: TextStyle(color: Colors.white, fontSize: 16),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:camera/camera.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Color _buttonColor = Colors.amberAccent;
  String _response = "";
  String ip_address = '192.168.1.9';
  bool _isLoading = false;
  final TextEditingController _controller = TextEditingController();
  File? _image;
  final picker = ImagePicker();
  FlutterTts flutterTts = FlutterTts();
  stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;
  String _spokenText = "";

  @override
  void initState() {
    super.initState();
    _initializeTTS();
    _initializeSpeechToText();
  }

  File? _capturedImage;
  late List<CameraDescription> cameras;
  CameraController? _cameraController;
  Future<void> initCamera() async {
    cameras = await availableCameras();
    _cameraController = CameraController(cameras[0], ResolutionPreset.high);
    await _cameraController!.initialize();
  }


  Future<void> _initializeTTS() async {
    try {
      await flutterTts.setLanguage("en-US");
      await flutterTts.setSpeechRate(0.5);
      await flutterTts.setVolume(1.0);
      await flutterTts.setPitch(1.0);

      print("TTS initialized with language en-US.");

      flutterTts.setStartHandler(() {
        print("TTS started speaking.");
      });

      flutterTts.setCompletionHandler(() {
        print("TTS finished speaking.");
      });

      flutterTts.setErrorHandler((msg) {
        print("TTS Error: $msg");
      });
    } catch (e) {
      print("Error initializing TTS: $e");
    }
  }

  Future<void> _speak(String text) async {
    try {
      var result = await flutterTts.speak(text);
      if (result == 1) {
        print("TTS started successfully.");
      }
    } catch (e) {
      print("Error speaking text: $e");
    }
  }

  void _initializeSpeechToText() async {
    bool available = await _speechToText.initialize();
    if (available) {
      print("Speech-to-Text initialized.");
    } else {
      print("Speech-to-Text not available.");
    }
  }

  void _startListening() async {
    if (!_isListening) {
      bool available = await _speechToText.listen(onResult: (result) {
        setState(() {
          _spokenText = result.recognizedWords;
          _controller.text = _spokenText;

          // Check if the spoken query contains the word "analyze"
          if (_spokenText.toLowerCase().contains('analyse')) {
            _captureAndSendImage(); // Trigger image capture and send
          }
        });
      });

      if (available) {
        setState(() {
          _isListening = true;
        });
      } else {
        print("Speech-to-Text listen not available or failed.");
      }
    }
  }

  void _stopListening() {
    if (_isListening) {
      _speechToText.stop();
      setState(() {
        _isListening = false;
      });
    }
  }

  void _changeColorTemporarily() async {
    setState(() {
      _buttonColor = Colors.orange;
      _isLoading = true;
    });

    String userInput = _controller.text;
    String llmResponse = await _sendToLLM(userInput);

    setState(() {
      _response = llmResponse;
      _buttonColor = Colors.amberAccent;
      _isLoading = false;
    });

    _showResponseDialog(llmResponse);
  }

  Future<String> _sendToLLM(String userInput) async {
    final response = await http.post(
      Uri.parse('http://$ip_address:8000/response/invoke'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"input": {"query": userInput}}),
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['output']['content'];
    } else {
      return "Failed to communicate with server: ${response.statusCode}";
    }
  }

  void _showResponseDialog(String response) {
    _speak(response);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Response'),
          content: Text(response),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<String> _describeSceneWithLLM(String sceneDescription) async {
    final response = await http.post(
      Uri.parse('http://$ip_address:8000/response/invoke'), // LLM API URL
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"input": {"query": "you are now an assistant for a blind person, describe the object name, positioning and relative depth detection scene. The objects, their horizontal displacement from center in captured image and depth is given as follows: $sceneDescription. converse like a human and don't tell the depth units rather describe the distance as far, near etc.. your response should be in this format eg. a {object} is {depth} and to the {horizontal position}."}}),
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['output']['content'];
    } else {
      return "Failed to communicate with server: ${response.statusCode}";
    }
  }

  // Future<void> _captureAndSendImage() async {
  //   final pickedFile = await picker.pickImage(source: ImageSource.camera);
  //
  //   if (pickedFile != null) {
  //     setState(() {
  //       _image = File(pickedFile.path);
  //       _isLoading = true;
  //     });
  //
  //     List<int> imageBytes = _image!.readAsBytesSync();
  //     String base64Image = base64Encode(imageBytes);
  //
  //     String apiUrl = 'http://$ip_address:5000/process_image';
  //     final response = await http.post(
  //       Uri.parse(apiUrl),
  //       headers: {"Content-Type": "application/json"},
  //       body: jsonEncode({"image": base64Image}),
  //     );
  //
  //     if (response.statusCode == 200) {
  //       // Process the response from object detection API
  //       String sceneDescription = response.body; // Customize based on actual response
  //
  //       // Send the scene description to LLM
  //       String llmResponse = await _describeSceneWithLLM(sceneDescription);
  //
  //       setState(() {
  //         _response = llmResponse;
  //         _isLoading = false;
  //       });
  //
  //       _showResponseDialog(_response);
  //     } else {
  //       setState(() {
  //         _response = "Failed to communicate with server: ${response.statusCode}";
  //         _isLoading = false;
  //       });
  //     }
  //   }
  // }
  // Future<void> _captureAndSendImage() async {
  //   if (_cameraController == null || !_cameraController!.value.isInitialized) {
  //     print('Initializing camera...');
  //     await initCamera();
  //   }
  //
  //   try {
  //     print('Capturing image...');
  //     // Capture image
  //     final XFile picture = await _cameraController!.takePicture();
  //     print('Image captured: ${picture.path}');
  //
  //     // Convert image to File
  //     File imageFile = File(picture.path);
  //
  //     setState(() {
  //       _image = imageFile;
  //       _isLoading = true;
  //     });
  //
  //     print('Converting image to base64...');
  //     // Convert image to base64
  //     List<int> imageBytes = _image!.readAsBytesSync();
  //     String base64Image = base64Encode(imageBytes);
  //
  //     // Send image to server
  //     String apiUrl = 'http://$ip_address:5000/process_image';
  //     print('Sending image to server...');
  //     final response = await http.post(
  //       Uri.parse(apiUrl),
  //       headers: {"Content-Type": "application/json"},
  //       body: jsonEncode({"image": base64Image}),
  //     );
  //
  //     if (response.statusCode == 200) {
  //       print('Image processed successfully.');
  //       // Process the response from object detection API
  //       String sceneDescription = response.body; // Customize based on actual response
  //
  //       // Send the scene description to LLM
  //       print('Sending scene description to LLM...');
  //       String llmResponse = await _describeSceneWithLLM(sceneDescription);
  //
  //       setState(() {
  //         _response = llmResponse;
  //         _isLoading = false;
  //       });
  //
  //       print('LLM response received: $_response');
  //       _showResponseDialog(_response);
  //     } else {
  //       print('Failed to communicate with server: ${response.statusCode}');
  //       setState(() {
  //         _response = "Failed to communicate with server: ${response.statusCode}";
  //         _isLoading = false;
  //       });
  //     }
  //   } catch (e) {
  //     print('Error occurred: $e');
  //     setState(() {
  //       _response = "Error: $e";
  //       _isLoading = false;
  //     });
  //   }
  // }
  //
  // @override
  // void dispose() {
  //   _cameraController?.dispose();
  //   super.dispose();
  // }
  //
  //
  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     appBar: AppBar(
  //       title: Text('Home'),
  //       foregroundColor: Colors.white70,
  //       backgroundColor: Colors.deepPurple,
  //       elevation: 6,
  //       actions: [
  //         IconButton(
  //           icon: Icon(Icons.info_outline),
  //           onPressed: () {
  //             // Action for the info button
  //           },
  //         ),
  //       ],
  //     ),
  //     body: Column(
  //       children: <Widget>[
  //         Padding(
  //           padding: const EdgeInsets.all(16.0),
  //           child: TextField(
  //             controller: _controller,
  //             decoration: InputDecoration(
  //               labelText: 'Enter your query',
  //               border: OutlineInputBorder(),
  //             ),
  //           ),
  //         ),
  //         Row(
  //           mainAxisAlignment: MainAxisAlignment.center,
  //           children: <Widget>[
  //             IconButton(
  //               icon: Icon(Icons.mic),
  //               style: ElevatedButton.styleFrom(
  //                 backgroundColor: Colors.deepOrange,
  //                 padding: EdgeInsets.symmetric(vertical: 16.0),
  //               ),
  //               onPressed: _isListening ? _stopListening : _startListening,
  //             ),
  //             SizedBox(width: 10),
  //             Text(_isListening ? 'Listening...' : 'Tap to Speak'),
  //           ],
  //         ),
  //         // Commented out the grid of buttons
  //         /*
  //         Expanded(
  //           child: GridView.count(
  //             crossAxisCount: 2,
  //             childAspectRatio: 1.0,
  //             padding: EdgeInsets.all(16.0),
  //             crossAxisSpacing: 16.0,
  //             mainAxisSpacing: 16.0,
  //             children: <Widget>[
  //               _buildButton(Colors.red, 'Capture & Send Image', _captureAndSendImage),
  //               _buildButton(Colors.green, 'Object Detection', () {}),
  //               _buildButton(Colors.blue, 'GPS Navigation', () {}),
  //               _buildButton(Colors.orange, 'Analyze Surroundings', () {}),
  //             ],
  //           ),
  //         ),
  //         */
  //         Container(
  //           width: double.infinity,
  //           padding: EdgeInsets.all(16.0),
  //           child: ElevatedButton(
  //             onPressed: _changeColorTemporarily,
  //             style: ElevatedButton.styleFrom(
  //               backgroundColor: _buttonColor,
  //               minimumSize: Size(double.infinity, 90),
  //               padding: EdgeInsets.symmetric(vertical: 16.0),
  //             ),
  //             child: _isLoading
  //                 ? CircularProgressIndicator(
  //               valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
  //             )
  //                 : Row(
  //               mainAxisAlignment: MainAxisAlignment.center,
  //               children: [
  //                 Icon(Icons.mic, size: 24.0),
  //                 SizedBox(width: 8.0),
  //                 Text('AI Button'),
  //               ],
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
  Future<void> _captureAndSendImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print('Initializing camera...');
      await initCamera();
    }

    try {
      print('Capturing image...');
      // Capture image
      final XFile picture = await _cameraController!.takePicture();
      print('Image captured: ${picture.path}');

      // Convert image to File
      File imageFile = File(picture.path);

      setState(() {
        _image = imageFile;
        _capturedImage = imageFile;  // Set the captured image
        _isLoading = true;
      });

      print('Converting image to base64...');
      // Convert image to base64
      List<int> imageBytes = _image!.readAsBytesSync();
      String base64Image = base64Encode(imageBytes);

      // Send image to server
      String apiUrl = 'http://$ip_address:5000/process_image';
      print('Sending image to server...');
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"image": base64Image}),
      );

      if (response.statusCode == 200) {
        print('Image processed successfully.');
        // Process the response from object detection API
        String sceneDescription = response.body; // Customize based on actual response

        // Send the scene description to LLM
        print('Sending scene description to LLM...');
        String llmResponse = await _describeSceneWithLLM(sceneDescription);

        setState(() {
          _response = llmResponse;
          _isLoading = false;
        });

        print('LLM response received: $_response');
        _showResponseDialog(_response);
      } else {
        print('Failed to communicate with server: ${response.statusCode}');
        setState(() {
          _response = "Failed to communicate with server: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error occurred: $e');
      setState(() {
        _response = "Error: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
        foregroundColor: Colors.white70,
        backgroundColor: Colors.deepPurple,
        elevation: 6,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () {
              // Action for the info button
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Enter your query',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              IconButton(
                icon: Icon(Icons.mic),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                ),
                onPressed: _isListening ? _stopListening : _startListening,
              ),
              SizedBox(width: 10),
              Text(_isListening ? 'Listening...' : 'Tap to Speak'),
            ],
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _changeColorTemporarily,
              style: ElevatedButton.styleFrom(
                backgroundColor: _buttonColor,
                minimumSize: Size(double.infinity, 90),
                padding: EdgeInsets.symmetric(vertical: 16.0),
              ),
              child: _isLoading
                  ? CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic, size: 24.0),
                  SizedBox(width: 8.0),
                  Text('AI Button'),
                ],
              ),
            ),
          ),
          // Display the captured image
          if (_capturedImage != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Image.file(
                _capturedImage!,
                height: 300,  // Adjust the height as needed
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
        ],
      ),
    );
  }
  Widget _buildButton(Color color, String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        minimumSize: Size(100, 100),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        elevation: 5,
      ),
      child: Text(
        text,
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }
}
