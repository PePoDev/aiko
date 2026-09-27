import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/storage/local_file_cache.dart';

/// Device-local avatar with a cloud fallback for other devices.
class CachedAvatar extends StatelessWidget {
  const CachedAvatar({
    this.localPath,
    this.cloudUrl,
    required this.fallback,
    super.key,
  });

  final String? localPath;
  final String? cloudUrl;
  final Widget fallback;

  Widget _remote() => cloudUrl == null || cloudUrl!.isEmpty
      ? fallback
      : Image.network(
          cloudUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        );

  @override
  Widget build(BuildContext context) {
    if (localPath == null || localPath!.isEmpty) return _remote();
    return FutureBuilder<Uint8List>(
      future: LocalFileCache.read(localPath!),
      builder: (context, snapshot) => snapshot.hasData
          ? Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _remote(),
            )
          : _remote(),
    );
  }
}
