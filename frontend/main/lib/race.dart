import 'package:flutter/material.dart';
import 'unique.dart';
import 'services/backend_service.dart';
import 'animations/race_track.dart';

// Spotify-derived palette, green -> cyan (same tokens used elsewhere)
const kInk = Color(0xFF121212);        // base background (Level 0)
const kSurface = Color(0xFF181818);    // cards, elevated surfaces (Level 1)
const kSurfaceAlt = Color(0xFF1F1F1F); // buttons, interactive surfaces
const kWhite = Color(0xFFFFFFFF);
const kSilver = Color(0xFFB3B3B3);     // secondary text, muted labels
const kCyan = Color(0xFF22D3EE);       // functional accent only
const kGold = Color(0xFFFFD54A);       // winner highlight
const kBorder = Color(0xFF4D4D4D);

const kCardShadow = [
  BoxShadow(
    color: Color(0x4D000000),
    blurRadius: 8,
    offset: Offset(0, 8),
  ),
];

const kHeavyShadow = [
  BoxShadow(
    color: Color(0x80000000),
    blurRadius: 24,
    offset: Offset(0, 8),
  ),
];

class RacePage extends StatefulWidget {
  const RacePage({super.key});

  @override
  State<RacePage> createState() => _RacePageState();
}

class _RacePageState extends State<RacePage>
    with SingleTickerProviderStateMixin, RaceTrackMixin {

  final BrowserWrappedService _backend = BrowserWrappedService(
    // TODO: same as unique.dart / visited.dart — resolve this relative
    // to the bundled backend instead of hardcoding for a shipped app.
    backendDir: '/home/debuku/BrowserWrapped',
  );

  bool _isLoading = true;
  String? _loadError;
  bool _raceFinished = false;
  bool _hasAdvanced = false;

  // Top 3 by visit count, index 0 = the winner. Each entry:
  // {'domain': String, 'visits': int}.
  List<Map<String, dynamic>> _topThree = [];

  static const double _carSize = 40;
  static const double _laneHeight = 76;

  @override
  void initState() {
    super.initState();
    initRaceTrack(this);
    onRaceComplete = _handleRaceComplete;
    _loadTopThree();
  }

  @override
  void dispose() {
    disposeRaceTrack();
    super.dispose();
  }

  void _handleRaceComplete() {
    if (!mounted) return;
    setState(() => _raceFinished = true);

    // Let the winner reveal sit on screen for a moment, then flow
    // straight into UniquePage — no button tap required. The table
    // slides up from the bottom, so the race feels like it hands off
    // directly into the list rather than being a separate stop.
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      _advanceToUnique();
    });
  }

  void _advanceToUnique() {
    if (_hasAdvanced) return;
    _hasAdvanced = true;
    Navigator.push(context, _slideUpRoute(const UniquePage()));
  }

  /// UniquePage slides up from the bottom of the screen over the
  /// finished race, rather than the default platform transition.
  Route<T> _slideUpRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 600),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ));
        return SlideTransition(position: offsetAnimation, child: child);
      },
    );
  }

  // ============================================================
  // LOAD TOP 3 SITES FROM PYTHON BACKEND
  // ============================================================

  Future<void> _loadTopThree() async {
    try {
      final data = await _backend.getWrapped(top: 10);

      // top_domains is a list of [domain, count] pairs.
      final rawList = data['top_domains'] as List<dynamic>;

      final sites = rawList
          .map((entry) {
            final pair = entry as List<dynamic>;
            return {
              'domain': pair[0] as String,
              'visits': pair[1] as int,
            };
          })
          .toList()
        ..sort((a, b) => (b['visits'] as int).compareTo(a['visits'] as int));

      if (!mounted) return;
      setState(() {
        _topThree = sites.take(3).toList();
        _isLoading = false;
      });

      // Give the page a beat to render the starting positions before
      // the cars take off.
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      startRace();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kInk,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 28,
              ),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 30),
                  Expanded(child: _buildBody()),
                  const SizedBox(height: 20),
                  _buildNavRow(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final winner = _topThree.isNotEmpty ? _topThree.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'The Race',
          style: TextStyle(
            color: kWhite,
            fontSize: 34,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isLoading
              ? 'Lining up your top 3 sites.'
              : _raceFinished
                  ? '${winner?['domain'] ?? 'Your top site'} takes the win.'
                  : 'Your top 3 most-visited sites, head to head.',
          style: const TextStyle(color: kSilver, fontSize: 15),
        ),
        const SizedBox(height: 16),
        Container(height: 1, color: kBorder),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: kCyan),
      );
    }

    if (_loadError != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.redAccent, width: 1),
          ),
          child: Text(
            'Could not load the race: $_loadError',
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_topThree.isEmpty) {
      return const Center(
        child: Text(
          'Not enough sites to race.',
          style: TextStyle(color: kSilver, fontSize: 14),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTrack(),
          const SizedBox(height: 24),
          if (_raceFinished) _buildWinnerReveal(),
        ],
      ),
    );
  }

  // ============================================================
  // TRACK — 3 lanes, only lane 0 reaches the finish line
  // ============================================================

  Widget _buildTrack() {
    return Column(
      children: List.generate(_topThree.length, (index) {
        final isWinner = index == 0;

        // Once the race is finished, fade the non-winning lanes out
        // so the page is left showing only the winner at the line.
        final laneOpacity = (!_raceFinished || isWinner) ? 1.0 : 0.25;

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: laneOpacity,
          child: _buildLane(index: index, isWinner: isWinner),
        );
      }),
    );
  }

  Widget _buildLane({required int index, required bool isWinner}) {
    final site = _topThree[index];
    final laneColor = isWinner ? kGold : kSilver;

    return Container(
      height: _laneHeight,
      margin: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          // Domain label / rank, fixed width so all 3 lanes line up.
          SizedBox(
            width: 110,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  site['domain'] as String,
                  style: TextStyle(
                    color: isWinner ? kGold : kWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${site['visits']} visits',
                  style: const TextStyle(color: kSilver, fontSize: 11),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // The actual track for this lane.
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackWidth = constraints.maxWidth - _carSize;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Track line.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: _laneHeight / 2 - 1,
                      child: Container(height: 2, color: kBorder),
                    ),

                    // Finish line.
                    Positioned(
                      right: _carSize / 2 - 1,
                      top: 4,
                      bottom: 4,
                      child: Container(width: 3, color: kCyan),
                    ),

                    // The racer itself, animated along the lane.
                    AnimatedBuilder(
                      animation: laneProgress(index),
                      builder: (context, child) {
                        final x = laneProgress(index).value * trackWidth;
                        return Positioned(
                          left: x,
                          top: (_laneHeight - _carSize) / 2,
                          child: child!,
                        );
                      },
                      child: Container(
                        width: _carSize,
                        height: _carSize,
                        decoration: BoxDecoration(
                          color: kSurfaceAlt,
                          shape: BoxShape.circle,
                          border: Border.all(color: laneColor, width: 2),
                          boxShadow: kCardShadow,
                        ),
                        child: Icon(
                          Icons.language_rounded,
                          color: laneColor,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WINNER REVEAL
  // ============================================================

  Widget _buildWinnerReveal() {
    final winner = _topThree.first;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (context, t, child) {
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.9 + (0.1 * t), child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kGold, width: 1.5),
          boxShadow: kCardShadow,
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_events_rounded, color: kGold, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    winner['domain'] as String,
                    style: const TextStyle(
                      color: kWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Crosses the line with ${winner['visits']} visits.',
                    style: const TextStyle(color: kSilver, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // NAV ROW
  // ============================================================

  Widget _buildNavRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildPillButton(
          label: 'BACK',
          icon: Icons.arrow_back_rounded,
          iconFirst: true,
          background: kSurfaceAlt,
          foreground: kWhite,
          onTap: () => Navigator.pop(context),
        ),
        // No manual NEXT — once the race finishes, _handleRaceComplete
        // auto-advances into UniquePage. SKIP just lets an impatient
        // user trigger that same transition immediately, once the
        // winner reveal is actually showing.
        if (_raceFinished)
          _buildPillButton(
            label: 'SKIP',
            icon: Icons.arrow_forward_rounded,
            iconFirst: false,
            background: kCyan,
            foreground: kInk,
            onTap: _advanceToUnique,
          ),
      ],
    );
  }

  Widget _buildPillButton({
    required String label,
    required IconData icon,
    required bool iconFirst,
    required Color background,
    required Color foreground,
    required VoidCallback onTap,
  }) {
    final labelWidget = Text(
      label,
      style: TextStyle(
        color: foreground,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
      ),
    );

    final iconWidget = Icon(icon, color: foreground, size: 19);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(9999),
          boxShadow: kHeavyShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: iconFirst
              ? [iconWidget, const SizedBox(width: 8), labelWidget]
              : [labelWidget, const SizedBox(width: 8), iconWidget],
        ),
      ),
    );
  }
}