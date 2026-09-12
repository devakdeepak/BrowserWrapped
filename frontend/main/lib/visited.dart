import 'package:flutter/material.dart';
import 'race.dart';
import 'animations/ripple.dart';
import 'animations/ripple_nav.dart';
import 'services/backend_service.dart';

// Spotify-derived palette, green -> cyan
const kInk = Color(0xFF121212);        // base background (Level 0)
const kSurface = Color(0xFF181818);    // cards, elevated surfaces (Level 1)
const kSurfaceAlt = Color(0xFF1F1F1F); // buttons, interactive surfaces
const kWhite = Color(0xFFFFFFFF);
const kSilver = Color(0xFFB3B3B3);     // secondary text, muted labels
const kCyan = Color(0xFF22D3EE);       // functional accent only
const kBorder = Color(0xFF4D4D4D);

const kCardShadow = [
  BoxShadow(
    color: Color(0x4D000000), // rgba(0,0,0,0.3)
    blurRadius: 8,
    offset: Offset(0, 8),
  ),
];

const kHeavyShadow = [
  BoxShadow(
    color: Color(0x80000000), // rgba(0,0,0,0.5)
    blurRadius: 24,
    offset: Offset(0, 8),
  ),
];

class FrontPage extends StatefulWidget {
  const FrontPage({super.key});

  @override
  State<FrontPage> createState() => _FrontPageState();
}

class _FrontPageState extends State<FrontPage>
    with TickerProviderStateMixin, RippleNavMixin {
  late AnimationController _progressController;
  late AnimationController _statsController;

  bool _reviewComplete = false;
  bool _showRipple = false;
  bool _showStats = false;

  // ------------------------------------------------------------
  // BACKEND DATA
  // Populated from `python -m backend collect` followed by
  // `python -m backend wrapped --json`, both in _loadStats().
  //
  // NOTE: this page currently shows total pages visited and the
  // busiest day. The remaining stats (unique sites, active days,
  // streak, active time) will move to their own dedicated pages.
  // ------------------------------------------------------------

  final BrowserWrappedService _backend = BrowserWrappedService(
    // TODO: point this at your BrowserWrapped/ folder. For a shipped app
    // this needs to be resolved relative to the bundled backend instead
    // of hardcoded — see the note in backend_service.dart.
    backendDir: '/home/debuku/BrowserWrapped',
  );

  int totalPagesVisited = 0;
  String busiestDay = 'Loading...';

  String? _loadError;

  @override
  void initState() {
    super.initState();

    // ------------------------------------------------------------
    // LOADING ANIMATION
    // ------------------------------------------------------------

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    // ------------------------------------------------------------
    // STATISTICS ANIMATION
    // ------------------------------------------------------------

    _statsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _startReview();
  }

  // ============================================================
  // START REVIEW
  // ============================================================

  Future<void> _startReview() async {
    // ------------------------------------------------------------
    // 1. Run the loading bar and fetch real stats at the same time,
    //    so the bar isn't just cosmetic. Whichever takes longer
    //    (usually the animation, since `wrapped` is fast) decides
    //    when we move on.
    // ------------------------------------------------------------

    await Future.wait([
      _progressController.forward(),
      _loadStats(),
    ]);

    if (!mounted) return;

    // ------------------------------------------------------------
    // 2. Loading is now 100%.
    //
    // Instead of showing the old "Review Complete" screen,
    // immediately start the ripple transition.
    // ------------------------------------------------------------

    setState(() {
      _reviewComplete = true;
      _showRipple = true;
    });
  }

  // ============================================================
  // LOAD STATS FROM PYTHON BACKEND
  // ============================================================

  Future<void> _loadStats() async {
    try {
      // Scan installed browsers and update the local history db first,
      // so the stats below reflect what's actually happened since the
      // last review, not just whatever was already stored.
      await _backend.collect();

      final data = await _backend.getWrapped();

      if (!mounted) return;
      setState(() {
        totalPagesVisited = data['total_visits'] as int;

        // busiest_single_day is a [dateString, count] pair, or null if
        // there's no history at all.
        final busiestSingleDay = data['busiest_single_day'] as List<dynamic>?;
        busiestDay = busiestSingleDay != null
            ? '${busiestSingleDay[0]} (${busiestSingleDay[1]} visits)'
            : 'No data yet';
      });
    } catch (e) {
      // Keep placeholders on screen rather than crashing the
      // transition; surface the error so it's visible while debugging.
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
      });
    }
  }

  // ============================================================
  // RIPPLE FINISHED
  // ============================================================

  void _onRippleComplete() {
    if (!mounted) return;

    setState(() {
      _showRipple = false;
      _showStats = true;
    });

    // Start the statistics cards appearing.
    _statsController.forward(from: 0);
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _progressController.dispose();
    _statsController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kInk,

      body: SafeArea(
        child: Stack(
          children: [
            // ====================================================
            // MAIN PAGE
            // ====================================================

            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 520,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                  ),

                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 700),

                    child: _showStats
                        ? _buildStatistics()
                        : _buildReviewProgress(),
                  ),
                ),
              ),
            ),

            // ====================================================
            // RIPPLE TRANSITION
            //
            // This sits ABOVE the entire page.
            //
            // Loading:
            //     BAR
            //      ↓
            //     BALL
            //      ↓
            //   BALL SHRINKS
            //      ↓
            //    RIPPLE
            //      ↓
            //   STATISTICS
            // ====================================================

            if (_showRipple)
              RippleTransition(
                onComplete: _onRippleComplete,
              ),

            // ====================================================
            // NEXT-PAGE RIPPLE (left -> right wave on "NEXT")
            // ====================================================

            buildRippleOverlay(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // REVIEW / LOADING SCREEN
  // ============================================================

  Widget _buildReviewProgress() {
    return Column(
      key: const ValueKey('review'),

      mainAxisSize: MainAxisSize.min,

      children: [
        // --------------------------------------------------------
        // LOADING STATE
        // --------------------------------------------------------

        if (!_reviewComplete) ...[
          const Text(
            'Reviewing your browsing',
            textAlign: TextAlign.center,

            style: TextStyle(
              color: kWhite,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'Analyzing your browsing history...',
            textAlign: TextAlign.center,

            style: TextStyle(
              color: kSilver,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 48),

          AnimatedBuilder(
            animation: _progressController,

            builder: (context, child) {
              final progress = _progressController.value;

              return Column(
                children: [
                  // ------------------------------------------------
                  // LOADING BAR
                  // ------------------------------------------------

                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),

                    child: LinearProgressIndicator(
                      value: progress,

                      minHeight: 12,

                      backgroundColor:
                          kBorder.withValues(alpha: 0.4),

                      valueColor:
                          const AlwaysStoppedAnimation<Color>(
                        kCyan,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ------------------------------------------------
                  // PERCENTAGE
                  // ------------------------------------------------

                  Text(
                    '${(progress * 100).round()}%',

                    style: const TextStyle(
                      color: kCyan,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            },
          ),
        ],

        // --------------------------------------------------------
        // Once loading reaches 100%, we intentionally leave this
        // area empty.
        //
        // RippleTransition is now covering the screen.
        // --------------------------------------------------------
      ],
    );
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  Widget _buildStatistics() {
    return SingleChildScrollView(
      key: const ValueKey('statistics'),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Text(
            'Your Browser Wrapped',

            style: TextStyle(
              color: kWhite,
              fontSize: 34,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Here is what we discovered about your browsing.',

            style: TextStyle(
              color: kSilver,
              fontSize: 15,
            ),
          ),

          const SizedBox(height: 36),

          // ------------------------------------------------------
          // BACKEND ERROR (only shown if the Python call failed)
          // ------------------------------------------------------

          if (_loadError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent, width: 1),
              ),
              child: Text(
                'Could not load stats: $_loadError',
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ------------------------------------------------------
          // STAT: TOTAL PAGES VISITED
          // ------------------------------------------------------

          _buildAnimatedStat(
            index: 0,
            icon: Icons.language_rounded,
            title: 'Total Pages Visited',
            value: totalPagesVisited.toString(),
          ),

          // ------------------------------------------------------
          // STAT: BUSIEST DAY
          //
          // The single day with the most browsing activity.
          // ------------------------------------------------------

          _buildAnimatedStat(
            index: 1,
            icon: Icons.calendar_today_rounded,
            title: 'Busiest Day',
            value: busiestDay.toString(),
          ),

          const SizedBox(height: 24),

          // ------------------------------------------------------
          // NEXT BUTTON
          // ------------------------------------------------------

          Align(
            alignment: Alignment.centerRight,

            child: _buildNextButton(),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ============================================================
  // NEXT BUTTON
  // ============================================================

  Widget _buildNextButton() {
    return GestureDetector(
      onTap: () {
        rippleForward(
          action: () => Navigator.push(
            context,
            instantRoute(const RacePage()),
          ),
        );
      },

      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 14,
        ),

        decoration: BoxDecoration(
          color: kCyan,

          borderRadius: BorderRadius.circular(9999),

          boxShadow: kHeavyShadow,
        ),

        child: const Row(
          mainAxisSize: MainAxisSize.min,

          children: [
            Text(
              'NEXT',

              style: TextStyle(
                color: kInk,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),

            SizedBox(width: 8),

            Icon(
              Icons.arrow_forward_rounded,
              color: kInk,
              size: 19,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ANIMATED STAT CARD
  // ============================================================

  Widget _buildAnimatedStat({
    required int index,
    required IconData icon,
    required String title,
    required String value,
  }) {
    final start = index * 0.15;

    final end = (start + 0.4).clamp(
      0.0,
      1.0,
    );

    final animation = CurvedAnimation(
      parent: _statsController,

      curve: Interval(
        start,
        end,
        curve: Curves.easeOutCubic,
      ),
    );

    return AnimatedBuilder(
      animation: animation,

      builder: (context, child) {
        return Opacity(
          opacity: animation.value,

          child: Transform.translate(
            offset: Offset(
              0,
              30 * (1 - animation.value),
            ),

            child: child,
          ),
        );
      },

      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(
          bottom: 20,
        ),

        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),

        decoration: BoxDecoration(
          color: kSurface,

          borderRadius: BorderRadius.circular(20),

          border: Border.all(
            color: kBorder,
            width: 1,
          ),

          boxShadow: kCardShadow,
        ),

        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ----------------------------------------------------
            // ICON
            // ----------------------------------------------------

            Container(
              width: 68,
              height: 68,

              decoration: BoxDecoration(
                color: kSurfaceAlt,

                borderRadius: BorderRadius.circular(18),
              ),

              child: Icon(
                icon,
                color: kCyan,
                size: 34,
              ),
            ),

            const SizedBox(height: 20),

            // ----------------------------------------------------
            // TEXT
            // ----------------------------------------------------

            Text(
              title,
              textAlign: TextAlign.center,

              style: const TextStyle(
                color: kSilver,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              value,
              textAlign: TextAlign.center,

              style: const TextStyle(
                color: kWhite,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}