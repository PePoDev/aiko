import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:pdfrx/pdfrx.dart';

import '../domain/transaction_attachment.dart';

/// Full-screen attachment preview.
///
/// Renders images with [PhotoView] (pinch-to-zoom), PDFs with [PdfViewer],
/// and plain-text-like files (txt/csv/md) as a scrollable monospace block.
/// Anything else falls back to a "preview not available" message with the
/// file path so the user can open it externally.
class AttachmentViewerDialog extends StatelessWidget {
  const AttachmentViewerDialog({required this.attachment, super.key});

  final TransactionAttachment attachment;

  /// Convenience wrapper so callers can `showDialog(... AttachmentViewerDialog)`.
  static Future<void> show(
    BuildContext context, {
    required TransactionAttachment attachment,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => AttachmentViewerDialog(attachment: attachment),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned.fill(child: _body(context, theme)),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        attachment.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, ThemeData theme) {
    final file = File(attachment.storagePath);
    if (attachment.isImagePreviewable) {
      return PhotoView(
        imageProvider: FileImage(file),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (_, _) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        errorBuilder: (_, error, _) => _Fallback(
          message: 'Could not load image.',
          error: error,
        ),
      );
    }
    if (attachment.isPdf) {
      return PdfViewer.file(
        attachment.storagePath,
        params: PdfViewerParams(
          backgroundColor: Colors.black,
        ),
      );
    }
    if (attachment.isTextPreviewable) {
      return _TextPreview(file: file, theme: theme);
    }
    return _UnsupportedPreview(attachment: attachment, theme: theme);
  }
}

class _TextPreview extends StatelessWidget {
  const _TextPreview({required this.file, required this.theme});

  final File file;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 24),
      child: FutureBuilder<String>(
        future: file.readAsString(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _Fallback(
              message: 'Could not read file.',
              error: snapshot.error,
            );
          }
          final content = snapshot.data ?? '';
          return SingleChildScrollView(
            child: SelectableText(
              content,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.4,
                color: theme.colorScheme.onSurface,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _UnsupportedPreview extends StatelessWidget {
  const _UnsupportedPreview({required this.attachment, required this.theme});

  final TransactionAttachment attachment;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Preview not available',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aiko can preview images, PDFs, and plain-text files (txt, csv, '
            'md). Open "${attachment.fileName}" in another app to view it.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.message, this.error});

  final String message;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.white70,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '$error',
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
