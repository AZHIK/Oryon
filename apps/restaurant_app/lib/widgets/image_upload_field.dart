import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/app_limits.dart';
import '../constants/app_strings.dart';
import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';

/// A square image dropzone: dashed outline and an upload prompt when empty,
/// the picked image filling the same square once one is chosen.
///
/// Sized by [size] rather than a hardcoded width, because the same control has
/// to serve an item photo at ~190px, a business logo, and a staff avatar at
/// considerably less.
class ImageUploadField extends StatefulWidget {
  const ImageUploadField({
    super.key,
    required this.image,
    required this.onPicked,
    required this.onRemoved,
    this.size = 190,
    this.label,
    this.hint,
    this.enabled = true,
  });

  /// Bytes of the current image, or null for the empty state.
  final Uint8List? image;

  /// Fires with the chosen file's name and bytes. The widget does the picking
  /// but keeps none of the result — the form owns it.
  final void Function(String name, Uint8List bytes) onPicked;

  final VoidCallback onRemoved;

  /// Edge length of the square.
  final double size;

  final String? label;

  /// File type and size guidance under the label. Empty string hides it, for
  /// sizes too small to fit two lines of text.
  final String? hint;

  final bool enabled;

  @override
  State<ImageUploadField> createState() => _ImageUploadFieldState();
}

class _ImageUploadFieldState extends State<ImageUploadField> {
  final _picker = ImagePicker();
  bool _busy = false;

  Future<void> _pick() async {
    if (_busy || !widget.enabled) return;
    setState(() => _busy = true);

    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        // Downscaled on the way in: a phone camera original is many megabytes
        // of memory for a thumbnail that renders at 190px.
        maxWidth: AppLimits.pickerMaxWidth,
        maxHeight: AppLimits.pickerMaxHeight,
        imageQuality: AppLimits.pickerQuality,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;
      widget.onPicked(file.name, bytes);
    } catch (_) {
      if (!mounted) return;
      // A missing gallery on a desktop CI box, a denied permission on a
      // phone — either way the form stays usable without a photo.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the image picker')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.image;

    return SizedBox(
      width: widget.size,
      child: AspectRatio(
        aspectRatio: 1,
        child: image == null
            ? _buildEmpty(context)
            : _buildFilled(context, image),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final colors = context.colors;
    final enabled = widget.enabled;
    final foreground = enabled
        ? colors.onSurfaceVariant
        : colors.onSurfaceVariant.withValues(alpha: 0.5);

    // Small squares (an avatar picker) have no room for the hint line, and a
    // clipped caption reads worse than no caption.
    final showHint = (widget.hint ?? AppStrings.imageHint).isNotEmpty && widget.size >= 150;
    final showLabel = widget.size >= 96;

    return CustomPaint(
      painter: _DashedBorderPainter(
        color: enabled
            ? colors.outlineVariant
            : colors.outlineVariant.withValues(alpha: 0.5),
        radius: Radii.md,
      ),
      child: Material(
        color: colors.surfaceContainerHigh.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(Radii.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? _pick : null,
          child: Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_busy)
                  SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: colors.primary,
                    ),
                  )
                else
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: widget.size >= 150 ? 30 : 22,
                    color: enabled ? colors.primary : foreground,
                  ),
                if (showLabel) ...[
                  const SizedBox(height: Insets.sm),
                  Text(
                    widget.label ?? AppStrings.uploadImage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: context.text.labelLarge?.copyWith(
                      color: enabled ? colors.onSurface : foreground,
                    ),
                  ),
                ],
                if (showHint) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.hint ?? AppStrings.imageHint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall?.copyWith(color: foreground),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilled(BuildContext context, Uint8List bytes) {
    final colors = context.colors;

    return Stack(
      fit: StackFit.expand,
      children: [
        Material(
          borderRadius: BorderRadius.circular(Radii.md),
          clipBehavior: Clip.antiAlias,
          color: colors.surfaceContainerHigh,
          child: Ink.image(
            image: MemoryImage(bytes),
            fit: BoxFit.cover,
            child: InkWell(
              // The image itself is the replace target; the corner button is
              // the only thing that removes.
              onTap: widget.enabled ? _pick : null,
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Positioned(
          top: Insets.xs,
          right: Insets.xs,
          child: _OverlayButton(
            icon: Icons.close_rounded,
            tooltip: AppStrings.removeImage,
            onPressed: widget.enabled ? widget.onRemoved : null,
          ),
        ),
        if (_busy)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.35),
              child: const Center(
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A small circular control that has to stay legible over arbitrary
/// photography, so it carries its own opaque backing rather than relying on
/// the image behind it.
class _OverlayButton extends StatelessWidget {
  const _OverlayButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.6),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: 28,
            width: 28,
            child: Icon(icon, size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Dashed rounded rectangle. Flutter's [Border] only draws solid lines, and a
/// dashed outline is the convention that reads as "drop something here".
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _dash = 6;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          // Inset by half the stroke so the dashes sit inside the box rather
          // than straddling its edge.
          Rect.fromLTWH(0.7, 0.7, size.width - 1.4, size.height - 1.4),
          Radius.circular(radius),
        ),
      );

    for (final metric in outline.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + _dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
