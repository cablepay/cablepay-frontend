import 'package:flutter/material.dart';


class Label extends StatelessWidget {
  final String text;
  const Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Text(text, style: TextStyle(fontWeight: FontWeight.w600)),
  );
}