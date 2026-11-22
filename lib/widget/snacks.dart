import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:one_context/one_context.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/helpers.dart";
import "package:inventree/l10.dart";

OverlayEntry? _currentSnackOverlay;

/*
 * Display a configurable 'snackbar' at the top of the screen
 *
 * If both [icon] and [onAction] are provided, tapping the icon runs the action
 * (and the text action button is only shown if [actionText] is provided)
 */
void showSnackIcon(
  String text, {
  IconData? icon,
  Function()? onAction,
  bool? success,
  String? actionText,
}) {
  debug("showSnackIcon: '${text}'");

  // Escape quickly if we do not have context
  if (!hasContext()) {
    return;
  }

  BuildContext? context = OneContext().context;
  if (context == null) return;

  // Dismiss any currently visible snack immediately
  _currentSnackOverlay?.remove();
  _currentSnackOverlay = null;

  Color backgroundColor = COLOR_DANGER;

  if (success != null && success == true) {
    backgroundColor = COLOR_SUCCESS;

    if (icon == null && onAction == null) {
      icon = TablerIcons.circle_check;
    }
  } else if (success != null && success == false) {
    backgroundColor = COLOR_DANGER;

    if (icon == null && onAction == null) {
      icon = TablerIcons.exclamation_circle;
    }
  }

  // An action icon replaces the default text action button
  final bool iconAction = onAction != null && icon != null;
  final String? actionLabel = (iconAction && actionText == null)
      ? null
      : actionText ?? L10().details;
  final Duration duration = Duration(seconds: onAction == null ? 5 : 10);

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => TopSnackBar(
      text: text,
      icon: icon,
      backgroundColor: backgroundColor,
      onAction: onAction,
      actionText: actionLabel,
      iconAction: iconAction,
      duration: duration,
      onDismiss: () {
        entry.remove();
        if (_currentSnackOverlay == entry) {
          _currentSnackOverlay = null;
        }
      },
    ),
  );

  _currentSnackOverlay = entry;
  Overlay.of(context).insert(entry);
}

/*
 * Snackbar widget displayed by showSnackIcon()
 * (public for testing, as snackbars are not displayed in tests)
 */
class TopSnackBar extends StatefulWidget {
  const TopSnackBar({
    required this.text,
    required this.backgroundColor,
    required this.duration,
    required this.onDismiss,
    this.icon,
    this.onAction,
    this.actionText,
    this.iconAction = false,
  });

  final String text;
  final IconData? icon;
  final Color backgroundColor;
  final Function()? onAction;
  final String? actionText;

  // Tapping the icon runs the action
  final bool iconAction;

  final Duration duration;
  final VoidCallback onDismiss;

  @override
  _TopSnackBarState createState() => _TopSnackBarState();
}

class _TopSnackBarState extends State<TopSnackBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  Timer? _timer;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _runAction() {
    _dismiss();
    widget.onAction?.call();
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _timer?.cancel();
    _timer = null;
    _controller.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          color: Colors.transparent,
          child: ColoredBox(
            color: widget.backgroundColor,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _dismiss,
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.text,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            if (widget.icon != null && !widget.iconAction)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Icon(widget.icon, color: Colors.white),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.iconAction)
                      IconButton(
                        icon: Icon(widget.icon, color: Colors.white),
                        tooltip: widget.actionText ?? L10().details,
                        onPressed: _runAction,
                      ),
                    if (widget.onAction != null && widget.actionText != null)
                      TextButton(
                        onPressed: _runAction,
                        child: Text(
                          widget.actionText ?? "",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: _dismiss,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
