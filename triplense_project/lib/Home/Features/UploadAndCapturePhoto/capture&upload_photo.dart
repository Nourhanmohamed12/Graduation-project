import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:triplense_project/Home/Features/UploadAndCapturePhoto/custom-button-model.dart';
//import 'package:triplense_project/Home/Features/UploadAndCapturePhoto/ruslt-page.dart';
import 'package:triplense_project/Home/pages/PlaceScreen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class UploadAndCapturePhoto extends StatefulWidget {
  const UploadAndCapturePhoto({super.key});

  @override
  State<UploadAndCapturePhoto> createState() => _UploadAndCapturePhotoState();
}

class _UploadAndCapturePhotoState extends State<UploadAndCapturePhoto> {
  late ImagePicker imagePicker;
  File? _image;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    imagePicker = ImagePicker();
  }

  Future<void> _imgFromCamera() async {
    final pickedFile = await imagePicker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _imgFromGallery() async {
    final pickedFile = await imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                  'assets/White Photocentric Egypt Travel Package Promotion Flyer.png',
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 200),
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _imgFromGallery,
                        child: const Text(
                          'Choose',
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.cyan,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                      const Text(
                        ' Photo To Upload',
                        style: TextStyle(
                          fontSize: 22,
                          color: Colors.white,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Or',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  GestureDetector(
                    onTap: _imgFromCamera,
                    child: const Text(
                      'CapturePhoto',
                      style: TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 22,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 120),
              if (_image != null)
                Stack(
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: FileImage(_image!),
                          fit: BoxFit.cover,
                        ),
                        border: Border.all(color: Colors.white, width: 2.0),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 36),
                        color: Colors.red,
                        onPressed: () {
                          setState(() => _image = null);
                        },
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              CustomButtonModel(
                text: 'Upload Photo',
                onPressed: () async {
                  if (_image != null && !_isProcessing) {
                    setState(() => _isProcessing = true);

                    final request = http.MultipartRequest(
                      'POST',
                      Uri.parse(
                        'http://192.168.1.10:4000/predict',
                      ), // Replace with your backend URL
                    );
                    request.files.add(
                      await http.MultipartFile.fromPath('image', _image!.path),
                    );

                    try {
                      final streamedResponse = await request.send();
                      final response = await http.Response.fromStream(
                        streamedResponse,
                      );

                      if (response.statusCode == 200) {
                        final jsonData = json.decode(response.body);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PlaceScreen(place: jsonData),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to recognize image'),
                          ),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }

                    setState(() => _isProcessing = false);
                  }
                },
                isProcessing: _isProcessing,
              ),
              const SizedBox(height: 103),
            ],
          ),
        ],
      ),
    );
  }
}
