import 'package:flutter/material.dart';

/// Overlay-based top notifications (toasts) that don't push down app content.
///
/// Usage: call `showTopError(context, '...')` or `showTopSuccess(context, '...')`.
/// The notification slides down from the top, shows an icon and message, and
/// auto-dismisses after [duration]. Multiple calls replace the current one.

OverlayEntry? _currentEntry;

void _removeCurrentEntry() {
  try {
    _currentEntry?.remove();
  } catch (_) {}
  _currentEntry = null;
}

void _showOverlay(BuildContext context, {required String message, required Color backgroundColor, required IconData icon, Duration duration = const Duration(seconds: 4)}) {
  _removeCurrentEntry();

  final entry = OverlayEntry(builder: (ctx) => _TopToast(entryContext: ctx, message: message, backgroundColor: backgroundColor, icon: icon, duration: duration));

  _currentEntry = entry;
  Overlay.of(context).insert(entry);
}

void showTopError(BuildContext context, String message) {
  final color = Colors.red.shade700;
  _showOverlay(context, message: message, backgroundColor: color, icon: Icons.error_outline);
}

void showTopSuccess(BuildContext context, String message) {
  final color = Colors.green.shade700;
  _showOverlay(context, message: message, backgroundColor: color, icon: Icons.check_circle_outline);
}

void showTopInfo(BuildContext context, String message) {
  final color = Colors.blue.shade700;
  _showOverlay(context, message: message, backgroundColor: color, icon: Icons.info_outline);
}

class _TopToast extends StatefulWidget {
  const _TopToast({required this.entryContext, required this.message, required this.backgroundColor, required this.icon, required this.duration});

  final BuildContext entryContext;
  final String message;
  final Color backgroundColor;
  final IconData icon;
  final Duration duration;

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  late final Animation<Offset> _offset = Tween(begin: const Offset(0, -1), end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
    Future.delayed(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _dismiss() async {
    try {
      await _ctrl.reverse();
    } catch (_) {}
    if (mounted) {
      _removeCurrentEntry();
    }
  }

  @override
  Widget build(BuildContext context) {
  // MediaQuery from the entry context is available if needed for adaptive layout

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 8.0, left: 16.0, right: 16.0),
          child: SlideTransition(
            position: _offset,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              color: Colors.transparent,
              shadowColor: Colors.black45,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                      spreadRadius: 2,
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(widget.icon, color: Colors.white, size: 22),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _dismiss,
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.close, color: Colors.white, size: 20),
                      ),
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
