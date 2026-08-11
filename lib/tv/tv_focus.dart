import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/sabuflix_theme.dart';
import 'tv_metrics.dart';

/// Every key a remote can send for "OK".
///
/// Flutter already binds Enter, Space and the gamepad A button to
/// [ActivateIntent]; `select` is what an Android TV D-pad centre button
/// reports, and TV browsers send plain Enter. Binding all of them means one
/// widget answers the OK button of a Google, Samsung or LG remote, a keyboard,
/// and a gamepad alike.
const Map<ShortcutActivator, Intent> tvActivateShortcuts = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
};

/// A focusable, clickable surface — the single building block of the D-pad
/// interface.
///
/// It does the four things every TV control has to do, which no stock Flutter
/// widget does together:
///
/// 1. takes directional focus from the remote, and answers OK;
/// 2. shows *where the focus is* unmistakably from three metres away — the
///    accent ring plus a small lift, never a subtle tint;
/// 3. scrolls itself into view when focus lands on it, through every enclosing
///    scrollable, so a shelf slides sideways as you arrow through it;
/// 4. still behaves like a normal tap target for mouse and touch, so the phone
///    and desktop builds keep working unchanged.
class TvFocusable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onFocused;
  final ValueChanged<bool>? onFocusChange;
  final bool autofocus;
  final FocusNode? focusNode;
  final BorderRadius? borderRadius;

  /// Draw the focus ring. Off for controls that render their own focused
  /// state (the navigation rail, the segmented control).
  final bool showRing;

  /// Lift the widget slightly while focused.
  final bool scaleOnFocus;

  /// Where the enclosing scrollables should park this widget when it takes
  /// focus. 0.5 centres it, which is what a TV shelf wants.
  final double scrollAlignment;

  /// Optional custom rendering of the focused state.
  final Widget Function(BuildContext context, bool focused, Widget child)? builder;

  final String? semanticLabel;

  const TvFocusable({
    Key? key,
    required this.child,
    this.onPressed,
    this.onFocused,
    this.onFocusChange,
    this.autofocus = false,
    this.focusNode,
    this.borderRadius,
    this.showRing = true,
    this.scaleOnFocus = true,
    this.scrollAlignment = 0.5,
    this.builder,
    this.semanticLabel,
  }) : super(key: key);

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  FocusNode? _internalNode;
  bool _focused = false;
  bool _hovered = false;

  FocusNode get _node => widget.focusNode ?? (_internalNode ??= FocusNode(debugLabel: widget.semanticLabel));

  @override
  void dispose() {
    _internalNode?.dispose();
    super.dispose();
  }

  void _handleFocusChange(bool focused) {
    if (mounted) setState(() => _focused = focused);
    widget.onFocusChange?.call(focused);
    if (!focused) return;

    widget.onFocused?.call();
    // Let the frame that moved focus settle first, otherwise a shelf that is
    // still being built reports the wrong offset.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: widget.scrollAlignment,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final metrics = TvMetrics.of(context);
    final highlighted = _focused || _hovered;
    final radius = widget.borderRadius ?? SabuflixTheme.radiusLg;

    Widget content = widget.child;

    if (widget.builder != null) {
      content = widget.builder!(context, highlighted, content);
    } else {
      if (widget.showRing) {
        content = AnimatedContainer(
          duration: SabuflixTheme.durationFast,
          curve: SabuflixTheme.curveStandard,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: highlighted ? SabuflixTheme.textPrimary : Colors.transparent,
              width: highlighted ? metrics.focusRingWidth : 0,
            ),
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.55),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ]
                : null,
          ),
          child: content,
        );
      }
      if (widget.scaleOnFocus) {
        content = AnimatedScale(
          scale: highlighted ? metrics.focusScale : 1.0,
          duration: SabuflixTheme.durationFast,
          curve: SabuflixTheme.curveStandard,
          child: content,
        );
      }
    }

    return FocusableActionDetector(
      focusNode: _node,
      autofocus: widget.autofocus,
      enabled: true,
      mouseCursor: widget.onPressed == null ? MouseCursor.defer : SystemMouseCursors.click,
      shortcuts: tvActivateShortcuts,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed?.call();
            return null;
          },
        ),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
          onInvoke: (_) {
            widget.onPressed?.call();
            return null;
          },
        ),
      },
      onFocusChange: _handleFocusChange,
      onShowHoverHighlight: (hovered) {
        if (mounted) setState(() => _hovered = hovered);
      },
      child: Semantics(
        label: widget.semanticLabel,
        button: widget.onPressed != null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed == null
              ? null
              : () {
                  // A pointer tap should also move the focus, so a following
                  // D-pad press continues from where the user clicked.
                  _node.requestFocus();
                  widget.onPressed!.call();
                },
          child: content,
        ),
      ),
    );
  }
}

/// Focus ring for widgets that draw their own background (pills, list rows).
///
/// Returns the decoration rather than a widget so callers can merge it into an
/// [AnimatedContainer] they already have.
BoxDecoration tvFocusDecoration({
  required bool focused,
  required BorderRadius borderRadius,
  required double ringWidth,
  Color? fill,
  Gradient? gradient,
}) {
  return BoxDecoration(
    color: gradient == null ? fill : null,
    gradient: gradient,
    borderRadius: borderRadius,
    border: Border.all(
      color: focused ? SabuflixTheme.textPrimary : Colors.transparent,
      width: focused ? ringWidth : 0,
    ),
    boxShadow: focused
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ]
        : null,
  );
}
