import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:triplense_project/Home/home.dart';

class EditProfile extends StatefulWidget {
  const EditProfile({super.key});

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  final TextEditingController _nameController = TextEditingController();
  File? _pickedImage;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameController.text = user?.displayName ?? '';
    _imageUrl = user?.photoURL;
  }

  // اختيار صورة من المعرض
  Future<void> pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null && mounted) {
        setState(() {
          _pickedImage = File(picked.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to pick image: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Update profile
  Future<void> updateProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String? newImageUrl = _imageUrl;

    try {
      // Upload image if selected
      if (_pickedImage != null) {
        final ref = FirebaseStorage.instance.ref().child(
          'user_images/${user.uid}.jpg',
        );
        await ref.putFile(_pickedImage!);
        newImageUrl = await ref.getDownloadURL();
      }

      // Update name and photo
      await user.updateDisplayName(_nameController.text.trim());
      await user.updatePhotoURL(newImageUrl);

      if (!mounted) return;

      // Display a success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Profile updated successfully"),
          backgroundColor: Colors.green,
        ),
      );

      // Go to the Home page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Home()),
      );
    } catch (e) {
      // Display an error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Failed to update profile: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const mainColor = Color.fromARGB(255, 192, 141, 64);

    return Scaffold(
      body: Stack(
        children: [
          // background image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("images/chat1.jpg"),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Color.fromARGB(255, 192, 141, 64),
                  BlendMode.dstATop,
                ),
              ),
            ),
          ),

          // content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        color: Colors.black,
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                      // IconButton(
                      //   icon: const Icon(Icons.image, size: 28),
                      //   color: Colors.black,
                      //   onPressed: pickImage,
                      // ),
                    ],
                  ),
                  const SizedBox(height: 50),

                  // Profile picture
                  GestureDetector(
                    onTap: pickImage,
                    child: CircleAvatar(
                      radius: 70,
                      backgroundColor: const Color.fromARGB(255, 254, 250, 224),
                      backgroundImage:
                          _pickedImage != null
                              ? FileImage(_pickedImage!)
                              : (_imageUrl != null
                                  ? NetworkImage(_imageUrl!)
                                  : null),
                      child:
                          (_pickedImage == null && _imageUrl == null)
                              ? const Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.black54,
                              )
                              : null,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // حقل إدخال الاسم
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: "Name",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Save changes button with full width display
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: const Color.fromARGB(
                          255,
                          192,
                          145,
                          76,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: updateProfile,
                      child: const Text(
                        "Save Changes",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
