import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class ChurchShareService {
  static const _churchName = 'ADTC VILA UNIÃO';
  static const _location = 'SOBRAL • CEARÁ';
  static const _navy = Color(0xFF063B57);
  static const _gold = Color(0xFFF0CF78);
  static const _paper = Color(0xFFFFFCF4);

  static Future<void> chooseShareMode(
    BuildContext context, {
    required String title,
    required String text,
  }) async {
    final mode = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Compartilhar como imagem'),
              subtitle: const Text('Arte com a logo da igreja'),
              onTap: () => Navigator.pop(sheetContext, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.text_fields_rounded),
              title: const Text('Compartilhar como texto'),
              onTap: () => Navigator.pop(sheetContext, 'text'),
            ),
          ],
        ),
      ),
    );
    if (mode == null || !context.mounted) return;

    try {
      if (mode == 'image') {
        final bytes = await createImage(title: title, text: text);
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                bytes,
                mimeType: 'image/png',
                name: 'adtc-vila-uniao.png',
              ),
            ],
            fileNameOverrides: const ['adtc-vila-uniao.png'],
          ),
        );
      } else {
        await SharePlus.instance.share(
          ShareParams(
            text: '$title\n\n$text\n\n$_churchName - $_location',
            subject: title,
          ),
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível compartilhar: $error')),
      );
    }
  }

  static Future<Uint8List> createImage({
    required String title,
    required String text,
  }) async {
    final logoBytes = await rootBundle.load('assets/church_logo.png');
    final codec = await ui.instantiateImageCodec(
      logoBytes.buffer.asUint8List(),
    );
    final logoFrame = await codec.getNextFrame();
    final logo = logoFrame.image;
    codec.dispose();

    final contentWidth = 900.0;
    final titleParagraph = _paragraph(
      title,
      width: contentWidth,
      fontSize: 58,
      color: _navy,
      weight: FontWeight.w700,
    );
    final bodyParagraph = _paragraph(
      text,
      width: contentWidth,
      fontSize: 43,
      color: const Color(0xFF334155),
      height: 1.3,
    );

    const topHeight = 340.0;
    const contentTop = 410.0;
    const footerHeight = 190.0;
    const gap = 42.0;
    final contentHeight =
        titleParagraph.height + gap + bodyParagraph.height + 100;
    final imageHeight = (contentTop + contentHeight + footerHeight).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, 1080, imageHeight.toDouble()),
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, 1080, imageHeight.toDouble()),
      Paint()..color = _paper,
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1080, topHeight),
      Paint()
        ..shader = const LinearGradient(
          colors: [_navy, Color(0xFF0B526F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(const Rect.fromLTWH(0, 0, 1080, topHeight)),
    );

    final logoRect = Rect.fromLTWH(465, 25, 150, 150);
    canvas.drawImageRect(
      logo,
      Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
      logoRect,
      Paint()..filterQuality = FilterQuality.high,
    );
    logo.dispose();

    _drawCentered(
      canvas,
      _paragraph(
        _churchName,
        width: 960,
        fontSize: 39,
        color: Colors.white,
        weight: FontWeight.w700,
        align: TextAlign.center,
        letterSpacing: 2,
      ),
      190,
    );
    _drawCentered(
      canvas,
      _paragraph(
        _location,
        width: 960,
        fontSize: 25,
        color: _gold,
        weight: FontWeight.w600,
        align: TextAlign.center,
        letterSpacing: 3,
      ),
      250,
    );

    var y = contentTop;
    _drawParagraph(canvas, titleParagraph, 90, y);
    y += titleParagraph.height + gap;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(90, y - 22, 8, bodyParagraph.height + 44),
        const Radius.circular(4),
      ),
      Paint()..color = _gold,
    );
    _drawParagraph(canvas, bodyParagraph, 116, y);

    canvas.drawRect(
      Rect.fromLTWH(0, imageHeight - footerHeight, 1080, footerHeight),
      Paint()..color = _navy,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, imageHeight - footerHeight, 1080, 7),
      Paint()..color = _gold,
    );
    _drawCentered(
      canvas,
      _paragraph(
        'Uma mensagem da nossa igreja para você',
        width: 960,
        fontSize: 29,
        color: Colors.white,
        align: TextAlign.center,
      ),
      imageHeight - 112,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(1080, imageHeight);
    picture.dispose();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (png == null) {
      throw StateError('Não foi possível gerar a imagem para compartilhar.');
    }
    return png.buffer.asUint8List();
  }

  static ui.Paragraph _paragraph(
    String text, {
    required double width,
    required double fontSize,
    required Color color,
    FontWeight weight = FontWeight.w400,
    TextAlign align = TextAlign.left,
    double height = 1.15,
    double letterSpacing = 0,
  }) {
    final builder =
        ui.ParagraphBuilder(
          ui.ParagraphStyle(
            textAlign: align,
            fontSize: fontSize,
            height: height,
            maxLines: null,
          ),
        )..pushStyle(
          ui.TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: weight,
            letterSpacing: letterSpacing,
          ),
        );
    builder.addText(text);
    final paragraph = builder.build();
    paragraph.layout(ui.ParagraphConstraints(width: width));
    return paragraph;
  }

  static void _drawCentered(Canvas canvas, ui.Paragraph paragraph, double top) {
    _drawParagraph(canvas, paragraph, (1080 - paragraph.width) / 2, top);
  }

  static void _drawParagraph(
    Canvas canvas,
    ui.Paragraph paragraph,
    double left,
    double top,
  ) {
    canvas.drawParagraph(paragraph, Offset(left, top));
  }
}
