import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class LocalPhoto extends StatefulWidget {
  const LocalPhoto({super.key, required this.file, this.fit = BoxFit.cover, this.placeholder});

  final XFile file;
  final BoxFit fit;
  final Widget? placeholder;

  @override
  State<LocalPhoto> createState() => _LocalPhotoState();
}

class _LocalPhotoState extends State<LocalPhoto> {
  late Future<Uint8List> _bytes = widget.file.readAsBytes();

  @override
  void didUpdateWidget(LocalPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) _bytes = widget.file.readAsBytes();
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = widget.placeholder ?? const SizedBox.shrink();
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) => switch (snapshot.data) {
        final bytes? => Image.memory(
            bytes,
            fit: widget.fit,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => placeholder,
          ),
        null => placeholder,
      },
    );
  }
}
