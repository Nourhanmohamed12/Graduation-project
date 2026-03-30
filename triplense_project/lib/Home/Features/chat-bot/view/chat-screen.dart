import "dart:convert";
import "dart:io";
import 'package:triplense_project/Home/Features/chat-bot/view/widget/SendRequestToGemini.dart';
import "package:flutter/material.dart";
import 'package:image_picker/image_picker.dart';
import "../data/chat_model.dart";

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  static String id = 'ChatScreen';

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class MyColors {
  static Color color = const Color(0xff283618);
}

class _ChatScreenState extends State<ChatScreen> {
  List<ChatModel> chatList = [];
  final TextEditingController controller = TextEditingController();
  File? image;
  bool _isPicking = false;

  void clearImage() {
    setState(() {
      image = null;
    });
  }

  void clearChat() {
    setState(() {
      chatList.clear();
    });
  }

  Future<void> selectImage() async {
    if (_isPicking) return;
    _isPicking = true;

    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() {
          image = File(picked.path);
        });
      }
    } catch (e) {
      print("Error picking image: $e");
    } finally {
      _isPicking = false;
    }
  }

  Future<void> onSendMessage() async {
    if (controller.text.trim().isEmpty && image == null) return;

    late ChatModel model;

    if (image == null) {
      model = ChatModel(isMe: true, message: controller.text);
    } else {
      final imageBytes = await image!.readAsBytes();
      String base64EncodedImage = base64Encode(imageBytes);
      model = ChatModel(
        isMe: true,
        message: controller.text,
        base64EncodedImage: base64EncodedImage,
      );
    }

    controller.clear();
    setState(() {
      image = null;
      chatList.insert(0, model);
    });

    final geminiModel = await sendRequestToGemini(model);
    setState(() {
      chatList.insert(0, geminiModel);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xffFAF5EB),
        body: Stack(
          children: [
            // Add background image from EditProfile here
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(
                    "images/chat1.jpg",
                  ), // Use your background image path here
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Color.fromARGB(255, 192, 141, 64),
                    BlendMode.dstATop,
                  ),
                ),
              ),
            ),

            // Chat content
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: MyColors.color,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "Triplens Bot",
                        style: TextStyle(
                          fontFamily: 'pacifico',
                          fontSize: 20,
                          color: MyColors.color,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: clearChat,
                        icon: Icon(Icons.update, color: MyColors.color),
                      ),
                    ],
                  ),
                ),

                // Chat List
                Expanded(
                  flex: 10,
                  child: ListView.builder(
                    reverse: true,
                    itemCount: chatList.length,
                    itemBuilder: (context, index) {
                      final chat = chatList[index];
                      final isMe = chat.isMe;
                      final bgColor =
                          isMe
                              ? const Color.fromARGB(
                                255,
                                254,
                                250,
                                224,
                              ).withOpacity(.7)
                              : const Color.fromARGB(255, 246, 244, 241);
                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: 5,
                            horizontal: 10,
                          ),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                            children: [
                              if (chat.base64EncodedImage != null)
                                Image.memory(
                                  base64Decode(chat.base64EncodedImage!),
                                  height: 300,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                ),
                              SelectableText(
                                chat.message,
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Selected Image Preview
                if (image != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 90.0),
                    child: Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: MyColors.color.withOpacity(.6),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(30),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Image.file(image!, fit: BoxFit.contain),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: IconButton(
                              onPressed: clearImage,
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Input Field
                Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Row(
                    children: [
                      Flexible(
                        child: TextField(
                          controller: controller,
                          style: TextStyle(color: MyColors.color),
                          maxLines: null,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xfffefae0).withOpacity(.8),
                            prefixIcon: IconButton(
                              icon: Icon(
                                Icons.upload_file,
                                color: MyColors.color,
                                size: 30,
                              ),
                              onPressed: () {
                                selectImage();
                                controller.clear();
                              },
                            ),
                            hintText: "Message",
                            hintStyle: TextStyle(color: MyColors.color),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: MyColors.color),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: MyColors.color),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          onSendMessage();
                          controller.clearComposing();
                        },
                        icon: Icon(Icons.send, color: MyColors.color, size: 30),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
