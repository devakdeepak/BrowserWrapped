import 'package:flutter/material.dart';
import 'ripple_crescent_transition.dart';
import 'ripple_crescent_transition_rtl.dart';

/// How long the NEXT/BACK crescent wave takes to sweep the screen.
/// Kept shorter than the 1200ms loading-screen ripple in visited.dart
/// since this fires on every single page turn.
const Duration kNavRippleDuration = Duration(milliseconds: 650);

/// Pushes [page] with no built-in Material transition, so the only
/// motion the user sees is the crescent wave — not a slide-in fighting
/// it underneath. Popping a route pushed this way is instant too.
Route<T> instantRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (context, animation, secondaryAnimation) => page,
  );
}

/// Drop this into any page's State to get the "NEXT = wave left-to-
/// right" / "BACK = wave right-to-left" page-turn effect used across
/// the Browser Wrapped flow.
///
/// Usage:
///   1. `class _MyPageState extends State<MyPage> with RippleNavMixin { ... }`
///   2. Wrap the Scaffold's body content in a `Stack` and add
///      `buildRippleOverlay()` as its last child, e.g.:
///
///        body: SafeArea(
///          child: Stack(
///            children: [
///              Center(child: ...), // normal page content
///              buildRippleOverlay(),
///            ],
///          ),
///        ),
///
///   3. On the NEXT button:
///        onTap: () => rippleForward(
///          action: () => Navigator.push(context, instantRoute(const NextPage())),
///        ),
///
///   4. On the BACK button:
///        onTap: () => rippleBackward(
///          action: () => Navigator.pop(context),
///        ),
mixin RippleNavMixin<T extends StatefulWidget> on State<T> {
  bool _rippleActive = false;
  bool _rippleIsForward = true;
  VoidCallback? _pendingAction;

  /// Left-to-right wave. Call on "NEXT".
  void rippleForward({required VoidCallback action}) {
    if (_rippleActive) return;
    _pendingAction = action;
    setState(() {
      _rippleIsForward = true;
      _rippleActive = true;
    });
  }

  /// Right-to-left wave. Call on "BACK".
  void rippleBackward({required VoidCallback action}) {
    if (_rippleActive) return;
    _pendingAction = action;
    setState(() {
      _rippleIsForward = false;
      _rippleActive = true;
    });
  }

  void _onRippleComplete() {
    // Fire the navigation right as the wave fully covers the screen,
    // then drop the overlay — the new/previous page is already
    // underneath it by the time it clears.
    final action = _pendingAction;
    _pendingAction = null;
    action?.call();

    if (mounted) {
      setState(() => _rippleActive = false);
    }
  }

  /// Place this as the LAST child of a Stack so it draws on top of
  /// the rest of the page.
  Widget buildRippleOverlay() {
    if (!_rippleActive) return const SizedBox.shrink();

    return _rippleIsForward
        ? RippleCrescentTransition(
            onComplete: _onRippleComplete,
            duration: kNavRippleDuration,
          )
        : RippleCrescentTransitionRTL(
            onComplete: _onRippleComplete,
            duration: kNavRippleDuration,
          );
  }
}
