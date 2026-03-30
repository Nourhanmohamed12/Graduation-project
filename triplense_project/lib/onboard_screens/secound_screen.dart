import 'package:flutter/material.dart';

class SecondScreen extends StatelessWidget {
  const SecondScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset("images/scan_place.jpg"),
        Column(
          children: [
            const SizedBox(height: 50),
            const Text(
              "Scan For Better \nDiscover",
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
                "Scan landmarks to uncover their history, facts, and details innsantly",
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
