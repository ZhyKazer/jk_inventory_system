import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jk_inventory_system/services/product_image_cache_service.dart';

class ProductImageView extends StatefulWidget {
  const ProductImageView({
    super.key,
    required this.imagePath,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.inventory_2_outlined,
    this.errorIcon = Icons.broken_image_outlined,
    this.placeholderColor,
    this.iconSize = 24,
  });

  final String? imagePath;
  final BoxFit fit;
  final IconData placeholderIcon;
  final IconData errorIcon;
  final Color? placeholderColor;
  final double iconSize;

  @override
  State<ProductImageView> createState() => _ProductImageViewState();
}

class _ProductImageViewState extends State<ProductImageView> {
  final ProductImageCacheService _cacheService = ProductImageCacheService();
  Future<String?>? _resolvedPathFuture;

  @override
  void initState() {
    super.initState();
    _resolvedPathFuture = _cacheService.resolveImagePath(widget.imagePath);
  }

  @override
  void didUpdateWidget(covariant ProductImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _resolvedPathFuture = _cacheService.resolveImagePath(widget.imagePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPath = (widget.imagePath ?? '').trim().isNotEmpty;
    if (!hasPath) {
      return _placeholder(context, widget.placeholderIcon);
    }

    return FutureBuilder<String?>(
      future: _resolvedPathFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }

        final resolvedPath = snapshot.data;
        if (snapshot.hasError) {
          debugPrint(
            'ProductImageView failed to resolve image path: ${snapshot.error}',
          );
          return _placeholder(context, widget.errorIcon);
        }

        if (resolvedPath == null || resolvedPath.isEmpty) {
          return _placeholder(context, widget.errorIcon);
        }

        try {
          return Image.file(
            File(resolvedPath),
            fit: widget.fit,
            errorBuilder: (_, _, _) => _placeholder(context, widget.errorIcon),
          );
        } catch (error) {
          debugPrint('ProductImageView failed to render image file: $error');
          return _placeholder(context, widget.errorIcon);
        }
      },
    );
  }

  Widget _placeholder(BuildContext context, IconData icon) {
    return ColoredBox(
      color:
          widget.placeholderColor ??
          Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(child: Icon(icon, size: widget.iconSize)),
    );
  }
}
