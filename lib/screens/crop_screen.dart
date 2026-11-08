import 'dart:io';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../widgets.dart';

/// Pure-Dart crop screen. Pops with the cropped [File], or null if cancelled.
class CropScreen extends StatefulWidget {
  final File image;
  const CropScreen({super.key, required this.image});

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  final _controller = CropController();
  Uint8List? _bytes;
  bool _cropping = false;

  @override
  void initState() {
    super.initState();
    widget.image.readAsBytes().then((b) {
      if (mounted) setState(() => _bytes = b);
    });
  }

  Future<void> _onCropped(CropResult result) async {
    if (result is CropSuccess) {
      final dir = await getTemporaryDirectory();
      final f = File(
          '${dir.path}/crop_${DateTime.now().microsecondsSinceEpoch}.png');
      await f.writeAsBytes(result.croppedImage);
      if (mounted) Navigator.of(context).pop(f);
    } else {
      if (!mounted) return;
      setState(() => _cropping = false);
      snack(context, 'Could not crop this image');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop to the object'),
        actions: [
          TextButton(
            onPressed: (_bytes == null || _cropping)
                ? null
                : () {
                    setState(() => _cropping = true);
                    _controller.crop();
                  },
            child: const Text('Done'),
          ),
        ],
      ),
      body: _bytes == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Positioned.fill(
                  child: Crop(
                    image: _bytes!,
                    controller: _controller,
                    onCropped: _onCropped,
                    baseColor: Colors.black,
                    maskColor: Colors.black.withValues(alpha: 0.6),
                  ),
                ),
                if (_cropping)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black45,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
    );
  }
}
