import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
  String ip_address = '172.20.10.4';
  bool _isLoading = false;
  final TextEditingController _controller = TextEditingController();
  File? _image;
  FlutterTts flutterTts = FlutterTts();
  stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;
  String _spokenText = "";
  File? _capturedImage;
  late List<CameraDescription> cameras;
  CameraController? _cameraController;
  List<String> _conversation = []; // Conversation transcript
  bool _isSpeaking = false; // Flag to prevent overlapping TTS

  @override
  void initState() {
    super.initState();
    _initializeTTS();
    _initializeSpeechToText();
    initCamera();
  }

  Future<void> initCamera() async {
    cameras = await availableCameras();
    _cameraController = CameraController(cameras[0], ResolutionPreset.high);
    await _cameraController!.initialize();
    setState(() {});
  }

  Future<void> _initializeTTS() async {
    try {
      await flutterTts.setLanguage("en-US");
      await flutterTts.setSpeechRate(0.5);
      await flutterTts.setVolume(1.0);
      await flutterTts.setPitch(1.0);
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
    if (!_isSpeaking) {
      _isSpeaking = true;
      try {
        var result = await flutterTts.speak(text);
        if (result == 1) {
          print("TTS started successfully.");
        }
      } catch (e) {
        print("Error speaking text: $e");
      } finally {
        await Future.delayed(Duration(seconds: 2));  // Adding a slight delay
        _isSpeaking = false;
      }
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
  void _stopSpeaking() async {
    try {
      await flutterTts.stop();
      print("TTS stopped.");
      setState(() {
        _isSpeaking = false; // Reset the speaking flag
      });
    } catch (e) {
      print("Error stopping TTS: $e");
    }
  }

  void _startListening() async {
    if (!_isListening) {
      bool available = await _speechToText.listen(onResult: (result) async {
        if (result.finalResult) {
          String recognizedText = result.recognizedWords;

          // Ensure we process the text regardless of whether it's a repeat
          if (_spokenText != recognizedText || _spokenText == "analyse") {
            setState(() {
              _spokenText = recognizedText;
              _controller.text = _spokenText;
            });

            // Process the recognized text
            if (_spokenText.toLowerCase().contains('analyse') || _spokenText.toLowerCase().contains('what is this')) {
              await _captureAndSendImage();
            } else {
              await _handleResponse(_spokenText);
            }

            // Stop listening after processing
            _stopListening();

            // Reset _spokenText to allow repeated commands like 'analyse'
            _spokenText = "";
          }
        }
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





  void _stopListening() async {
    if (_isListening) {
      await _speechToText.stop();
      setState(() {
        _isListening = false;
      });
    }
  }


  Future<void> _handleResponse(String userInput) async {
    setState(() {
      _isLoading = true;
    });

    String llmResponse = await _sendToLLM(userInput);  // For non-'analyse' queries
    _updateConversation("User: $userInput");
    _updateConversation("Assistant: $llmResponse");
    await _speak(llmResponse);  // Speak only after response is received

    setState(() {
      _controller.clear(); // Clear the text field
      _spokenText = "";    // Reset the recognized text
      _isLoading = false;
    });
  }


  Future<String> _sendToLLM(String userInput) async {
    final response = await http.post(
      Uri.parse('http://$ip_address:8000/query/invoke'),
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

  Future<void> _captureAndSendImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print('Initializing camera...');
      await initCamera();
    }

    try {
      print('Capturing image...');
      final XFile picture = await _cameraController!.takePicture();
      File imageFile = File(picture.path);

      setState(() {
        _image = imageFile;
        _capturedImage = imageFile;
        _isLoading = true;
      });

      print('Converting image to base64...');
      List<int> imageBytes = _image!.readAsBytesSync();
      String base64Image = base64Encode(imageBytes);

      String apiUrl = 'http://$ip_address:5000/process_image';
      print('Sending image to server...');
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"image": base64Image}),
      );

      if (response.statusCode == 200) {
        String sceneDescription = response.body;

        print('Sending scene description to LLM...');
        String llmResponse = await _describeSceneWithLLM(sceneDescription);

        setState(() {
          _response = llmResponse;
          _updateConversation("User: analyse");
          _updateConversation("Assistant: $llmResponse");
          _isLoading = false;
        });

        await _speak(_response);
      } else {
        setState(() {
          _response = "Failed to communicate with server: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _response = "Error: $e";
        _isLoading = false;
      });
    }
  }

  Future<String> _describeSceneWithLLM(String sceneDescription) async {
    final response = await http.post(
      Uri.parse('http://$ip_address:8000/describe/invoke'), // LLM API URL
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "input": {
          "query": "you are now an assistant for a blind person, describe the object name, texts, positioning and relative depth detection scene with confidence greater than 0.5. The objects, texts, their horizontal displacement from center in captured image and depth is given as follows: $sceneDescription. converse like a human and don't tell the depth units rather describe the distance as far, near etc.. your response should be in this format eg. a {object} is {depth} and to the {horizontal position}. dont use words that tell the posture of a person like standing or sitting. dont forget to include the text found in the image if there is any."
        }
      }),
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['output']['content'];
    } else {
      return "Failed to communicate with server: ${response.statusCode}";
    }
  }

  void _updateConversation(String message) {
    setState(() {
      _conversation.add(message);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'BlindViz-Visual Assistance',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.deepPurple.shade900,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView( // Wrap the content in SingleChildScrollView
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Input Field for Queries
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: 'Enter your query',
                  labelStyle: TextStyle(color: Colors.deepPurple.shade900),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.deepOrange, width: 2.0),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon: Icon(Icons.search, color: Colors.deepPurpleAccent),
                ),
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 16.0),

              // Mic and Stop Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  ElevatedButton(
                    onPressed: _startListening,
                    style: ElevatedButton.styleFrom(
                      shape: CircleBorder(),
                      padding: EdgeInsets.all(16.0),
                      backgroundColor: Colors.deepOrange.shade900,
                    ),
                    child: Icon(Icons.mic, size: 50, color: Colors.white),
                  ),
                  SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: _stopSpeaking,
                    style: ElevatedButton.styleFrom(
                      shape: CircleBorder(),
                      padding: EdgeInsets.all(16.0),
                      backgroundColor: Colors.red.shade900,
                    ),
                    child: Icon(Icons.stop, size: 50, color: Colors.white),
                  ),
                ],
              ),
              SizedBox(height: 20.0),

              // Camera Preview (if available)
              if (_cameraController != null && _cameraController!.value.isInitialized)
                Container(
                  height: 400,
                  margin: EdgeInsets.only(bottom: 16.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25.0),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25.0),
                    child: CameraPreview(_cameraController!),
                  ),
                ),

              // Loader (if loading)
              if (_isLoading)
                Center(
                  child: CircularProgressIndicator(),
                ),
              SizedBox(height: 16.0),

              // Display Assistant Response
              if (_response.isNotEmpty)
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25.0),
                  ),
                  color: Colors.white,
                  margin: EdgeInsets.symmetric(vertical: 8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _response,
                      style: TextStyle(fontSize: 18, color: Colors.black87),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ),

              // Conversation History (in a scrollable view)
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.4, // Set height for conversation history
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25.0),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ListView(
                      children: _conversation
                          .map(
                            (message) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            message,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      )
                          .toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

