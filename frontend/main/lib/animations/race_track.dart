import 'package:flutter/material.dart';

/// Drives a fixed 3-lane "race" among the top visited sites.
///
/// Lane 0 is always the site with the most visits. It is the only
/// lane whose target progress reaches the finish line (1.0) — lanes
/// 1 and 2 are given lower targets so they visibly fall short when
/// the race finishes. This guarantees, deterministically, that only
/// the #1 site ever crosses the line, regardless of how close the
/// actual visit counts are.
///
/// Mix this into any State that already has a TickerProvider
/// (SingleTickerProviderStateMixin or TickerProviderStateMixin).
mixin RaceTrackMixin<T extends StatefulWidget> on State<T> {
  late final AnimationController _controller;

  /// How far (as a fraction of the track, 0..1) each lane travels by
  /// the time the race finishes. Index 0 = winner's lane.
  static const List<double> _laneTargets = [1.0, 0.82, 0.66];

  /// Slightly different curves per lane so they don't move in
  /// lockstep — gives the impression of different paces even though
  /// every lane starts and stops at the same animation time.
  static const List<Curve> _laneCurves = [
    Curves.easeOutCubic,
    Curves.easeOutQuart,
    Curves.easeOut,
  ];

  /// Total time the race takes to run once, start to finish.
  Duration get raceDuration => const Duration(milliseconds: 2600);

  /// Fires once, right when the race animation finishes, so the page
  /// can reveal the winner and dismiss the other lanes.
  VoidCallback? onRaceComplete;

  /// Call once in initState (data doesn't need to be loaded yet —
  /// call startRace() separately once it is).
  void initRaceTrack(TickerProvider vsync) {
    _controller = AnimationController(vsync: vsync, duration: raceDuration);
    _controller.addStatusListener(_handleStatus);
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      onRaceComplete?.call();
    }
  }

  /// Starts (or restarts) the race from the beginning.
  void startRace() {
    _controller.forward(from: 0);
  }

  void disposeRaceTrack() {
    _controller.removeStatusListener(_handleStatus);
    _controller.dispose();
  }

  /// Progress (0..1 of track width) for a given lane. Lane 0 is the
  /// winner and is the only one that reaches exactly 1.0.
  Animation<double> laneProgress(int lane) {
    final target = _laneTargets[lane.clamp(0, _laneTargets.length - 1)];
    final curve = _laneCurves[lane.clamp(0, _laneCurves.length - 1)];
    return Tween<double>(begin: 0, end: target).animate(
      CurvedAnimation(parent: _controller, curve: curve),
    );
  }

  bool get isRaceRunning => _controller.status == AnimationStatus.forward;

  bool get isRaceFinished => _controller.status == AnimationStatus.completed;
}