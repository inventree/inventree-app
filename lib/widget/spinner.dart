import "package:flutter/material.dart";
import "package:flutter/cupertino.dart";

import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/app_colors.dart";

class Spinner extends StatefulWidget {
  final IconData? icon;
  final Duration duration;
  final Color color;

  const Spinner({
    this.color = COLOR_GRAY_LIGHT,
    Key? key,
    @required this.icon,
    this.duration = const Duration(milliseconds: 1800),
  }) : super(key: key);

  @override
  _SpinnerState createState() => _SpinnerState();
}

class _SpinnerState extends State<Spinner> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Widget? _child;

  @override
  void initState() {
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000),
    )
      ..repeat();
    _child = FaIcon(
      widget.icon,
      color: widget.color
    );

    super.initState();
  }

  @override
  void dispose() {
    _controller!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller!,
      child: _child,
    );
  }
}