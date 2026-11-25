import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

@Preview(name: 'Minha Tela Inicial')
Widget previewMinhaTela() {
  return const MaterialApp(
    home: Scaffold(
      body: Center(
        child: Text('Visualizando no VS Code!'),
      ),
    ),
  );
}
