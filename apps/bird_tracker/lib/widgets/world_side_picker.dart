import 'dart:math';

import 'package:bird_tracker/model/species.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WorldSidePicker extends StatefulWidget {
  const WorldSidePicker(
      {super.key,
      this.selectedSide,
      this.onChanged,
      this.color,
      this.radius,
      this.label});

  final Direction? selectedSide;
  final Function(dynamic)? onChanged;
  final Color? color;
  final double? radius;
  final String? label;

  @override
  State<WorldSidePicker> createState() => _WorldSidePickerState();
}

class _WorldSidePickerState extends State<WorldSidePicker>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _entryRotationAnimation;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeIn,
    );

    _entryRotationAnimation = Tween<double>(begin: -0.25, end: 0.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Curves.easeOutBack,
      ),
    );

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  double _getRotationAngle(Direction? side) {
    if (side == null) return 0;
    // Each index represents 22.5 degrees (360/16)
    // We need to rotate the compass so the "N" points to the selected direction?
    // Or just rotate the needle? The SVG is a full compass.
    // Let's rotate the compass background.
    return Direction.values.indexOf(side) * (2 * pi / 16);
  }

  @override
  Widget build(BuildContext context) {
    double radius = widget.radius ?? 80.0;
    double size = (radius + 20) * 2 + 50;
    double rotationAngle = _getRotationAngle(widget.selectedSide);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Background Compass Image
          Positioned(
            top: size / 4,
            left: size / 4,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: RotationTransition(
                turns: _entryRotationAnimation,
                child: AnimatedRotation(
                  turns: -rotationAngle / (2 * pi), // Reverse rotation to align
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOutBack,
                  child: SvgPicture.asset(
                    'assets/icons/compass.svg',
                    width: size / 2,
                    height: size / 2,
                  ),
                ),
              ),
            ),
          ),
          // Circle Background
          Positioned.fill(
            child: CustomPaint(
              painter: CirclePainter(
                  color: widget.color, radius: radius),
            ),
          ),
          // Direction Points
          for (int i = 0; i < 16; i++)
            _buildDirectionPoint(i, size, radius),

          // Label
          Positioned(
            left: 20,
            top: 3,
            child: Container(
              padding: const EdgeInsets.only(left: 5, right: 5),
              color: Colors.white,
              child: Text(
                  widget.label ??
                      Direction.values.first.toString().split('.').first,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      )),
            ),
          ),
          // Clear Button
          Positioned(
            right: 2,
            top: 3,
            child: Container(
              color: Colors.white,
              child: SizedBox(
                height: 20,
                width: 20,
                child: IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: Colors.red),
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all<EdgeInsetsGeometry>(
                      const EdgeInsets.all(0),
                    ),
                    backgroundColor: WidgetStateProperty.all<Color>(
                      Colors.grey.shade300,
                    ),
                  ),
                  onPressed: () {
                    if (widget.onChanged != null) {
                      widget.onChanged!(null);
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionPoint(int i, double size, double radius) {
    final direction = Direction.values[i];
    final isSelected = widget.selectedSide == direction;

    // Delayed staggered animation for each point
    final start = (i / 16) * 0.5;
    final end = start + 0.5;
    final curve = CurvedAnimation(
      parent: _entryController,
      curve: Interval(start, end, curve: Curves.elasticOut),
    );

    return Positioned(
      top: (size / 2) + (radius + 20) * sin(2 * pi * (i - 4) / 16) - 15,
      left: (size / 2) + (radius + 20) * cos(2 * pi * (i - 4) / 16) - 15,
      child: ScaleTransition(
        scale: curve,
        child: GestureDetector(
          onTap: () {
            if (widget.onChanged != null) {
              widget.onChanged!(direction);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isSelected ? 35 : 30,
            height: isSelected ? 35 : 30,
            decoration: BoxDecoration(
              color: isSelected ? widget.color ?? const Color(0xFF0F9D58) : null,
              borderRadius: BorderRadius.circular(isSelected ? 10 : 0),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: (widget.color ?? const Color(0xFF0F9D58))
                            .withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  fontSize: direction.isSub() ? (isSelected ? 11 : 10) : (isSelected ? 13 : 12),
                  fontWeight: direction.isSub() ? FontWeight.normal : FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.black,
                ),
                child: Text(
                  direction.isSub() ? direction.toShortString().toLowerCase() : direction.toShortString(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CirclePainter extends CustomPainter {
  const CirclePainter({this.color, this.radius = 80.0});
  final Color? color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color ?? const Color(0xFF0F9D58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(Offset(size.width / 2, size.height / 2), radius, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
