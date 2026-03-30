import 'package:flutter/material.dart';

class FirstScreen extends StatelessWidget {
  const FirstScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset("images/explore.jpg"),
        Column(
          children: [
            const SizedBox(height: 50),
            const Text(
              "Explore a World of\nWonders",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'Times New Roman',
                color: Colors.black,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 40),
              child: Text(
                "Our categories help you navigate the beauty and history of Egypt effortlessly",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Times New Roman',
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        )
      ],
    );
  }
}


