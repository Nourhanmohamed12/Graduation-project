import 'dart:convert';
import 'package:triplense_project/Home/Features/chat-bot/api/api_key.dart';
import 'package:triplense_project/Home/Features/chat-bot/data/chat_model.dart';
import 'package:http/http.dart' as http;

Future<ChatModel> sendRequestToGemini(ChatModel model) async {
  final String url =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=AIzaSyAEbtB7aFZn6AVbuMMMicK4VSoBBrasVg0";
  Map<String, dynamic> body;

  if (model.base64EncodedImage == null) {
    // Text-only input

    body = {
      "contents": [
        {
          "parts": [
            {"text": model.message},
          ],
        },
      ],
    };
  } else {
    // Image + Text input (image comes first)

    body = {
      "contents": [
        {
          "parts": [
            {
              "inline_data": {
                "mime_type": "image/jpeg", // Change to image/png if needed

                "data": model.base64EncodedImage,
              },
            },

            {"text": model.message},
          ],
        },
      ],
    };
  }

  try {
    final response = await http.post(
      Uri.parse(url),

      headers: {"Content-Type": "application/json"},

      body: json.encode(body),
    );

    print("Status Code: ${response.statusCode}");

    print("Response: ${response.body}");

    final decoded = json.decode(response.body);

    String message;

    if (decoded != null &&
        decoded["candidates"] != null &&
        decoded["candidates"].isNotEmpty &&
        decoded["candidates"][0]["content"] != null &&
        decoded["candidates"][0]["content"]["parts"] != null &&
        decoded["candidates"][0]["content"]["parts"].isNotEmpty &&
        decoded["candidates"][0]["content"]["parts"][0]["text"] != null) {
      message = decoded["candidates"][0]["content"]["parts"][0]["text"];
    } else {
      message =
          "⚠ Gemini error: ${decoded['error']?['message'] ?? 'Unknown issue'}";
    }

    return ChatModel(isMe: false, message: message);
  } catch (e) {
    print("Exception: $e");

    return ChatModel(isMe: false, message: "⚠ Failed to connect to Gemini.");
  }
}
