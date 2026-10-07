import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class TrackArtwork extends StatelessWidget {
  final String? artworkUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const TrackArtwork({
    super.key,
    required this.artworkUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    if (artworkUrl == null || artworkUrl!.isEmpty) {
      imageWidget = Image.asset(
        'assets/images/logo_prism.jpg',
        width: width,
        height: height,
        fit: fit,
      );
    } else if (artworkUrl!.startsWith('http://') || artworkUrl!.startsWith('https://')) {
      imageWidget = Image.network(
        artworkUrl!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => Image.asset(
          'assets/images/logo_prism.jpg',
          width: width,
          height: height,
          fit: fit,
        ),
      );
    } else if (kIsWeb) {
      // In web mode, ensure spaces and symbols are properly URI encoded
      final encodedUrl = Uri.encodeFull(artworkUrl!);
      imageWidget = Image.network(
        encodedUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => Image.asset(
          'assets/images/logo_prism.jpg',
          width: width,
          height: height,
          fit: fit,
        ),
      );
    } else {
      final file = File(artworkUrl!);
      if (file.existsSync()) {
        imageWidget = Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => Image.asset(
            'assets/images/logo_prism.jpg',
            width: width,
            height: height,
            fit: fit,
          ),
        );
      } else {
        imageWidget = Image.asset(
          'assets/images/logo_prism.jpg',
          width: width,
          height: height,
          fit: fit,
        );
      }
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}
