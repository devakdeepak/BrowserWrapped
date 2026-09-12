import 'package:flutter/material.dart';
import 'visited.dart';
import 'services/backend_service.dart';
import 'animations/ripple_nav.dart';

// Spotify-derived palette, green -> cyan (same tokens used elsewhere)
const kInk = Color(0xFF121212);        // base background (Level 0)
const kSurface = Color(0xFF181818);    // cards, elevated surfaces (Level 1)
const kSurfaceAlt = Color(0xFF1F1F1F); // buttons, interactive surfaces
const kWhite = Color(0xFFFFFFFF);
const kSilver = Color(0xFFB3B3B3);     // secondary text, muted labels
const kCyan = Color(0xFF22D3EE);       // functional accent only
const kGold = Color(0xFFFFD54A);       // winner highlight, matches race.dart
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

/// The last stop in the Browser Wrapped flow: a single-screen recap of
/// the three headline stats from earlier pages — top site (unique.dart
/// / race.dart), active time (estimate.dart), and AI personality
/// (personality.dart) — condensed into one shareable-feeling card.
class FinalePage extends StatefulWidget {
  const FinalePage({super.key});

  @override
  State<FinalePage> createState() => _FinalePageState();
}

class _FinalePageState extends State<FinalePage>
    with SingleTickerProviderStateMixin, RippleNavMixin {
  late final AnimationController _revealController;

  final BrowserWrappedService _backend = BrowserWrappedService(
    // TODO: same as the other pages — resolve this relative to the
    // bundled backend instead of hardcoding for a shipped app.
    backendDir: '/home/debuku/BrowserWrapped',
  );

  bool _isLoading = true;
  String? _loadError;

  String topSite = '';
  int topSiteVisits = 0;
  String activeBrowsingTime = '0h 0m';
  String archetype = '';
  String tagline = '';

  @override
  void initState() {
    super.initState();

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _loadSummary();
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD SUMMARY FROM PYTHON BACKEND
  //
  // Pulls the same two backend calls the earlier pages already use
  // (`wrapped` for site/time stats, `personality` for the archetype)
  // and runs them side by side rather than re-fetching sequentially.
  // ============================================================

  Future<void> _loadSummary() async {
    try {
      final results = await Future.wait([
        _backend.getWrapped(top: 1),
        _backend.getPersonality(),
      ]);

      final wrapped = results[0];
      final personality = results[1];

      // top_domains is a list of [domain, count] pairs.
      final rawTop = wrapped['top_domains'] as List<dynamic>;
      final double estimatedHours =
          (wrapped['estimated_active_hours'] as num).toDouble();
      final int hours = estimatedHours.floor();
      final int minutes = ((estimatedHours - hours) * 60).round();

      if (!mounted) return;
      setState(() {
        if (rawTop.isNotEmpty) {
          final pair = rawTop.first as List<dynamic>;
          topSite = pair[0] as String;
          topSiteVisits = pair[1] as int;
        }
        activeBrowsingTime = '${hours}h ${minutes}m';
        archetype = personality['archetype'] as String? ?? 'Unknown Browser';
        tagline = personality['tagline'] as String? ?? '';
        _isLoading = false;
      });

      _revealController.forward(from: 0);
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
        child: Stack(
          children: [
            Center(
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

            // BACK = right -> left wave, RESTART = left -> right wave.
            buildRippleOverlay(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Wrapped',
          style: TextStyle(
            color: kWhite,
            fontSize: 34,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isLoading
              ? 'Putting the highlights together.'
              : 'The short version of everything above.',
          style: const TextStyle(color: kSilver, fontSize: 15),
        ),
        const SizedBox(height: 16),
        Container(height: 1, color: kBorder),
      ],
    );
  }

  // ============================================================
  // BODY
  // ============================================================

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
            'Could not load your summary: $_loadError',
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildRevealCard(
            index: 0,
            icon: Icons.emoji_events_rounded,
            iconColor: kGold,
            title: 'MOST VISITED SITE',
            value: topSite.isNotEmpty ? topSite : 'No data yet',
            subtitle:
                topSite.isNotEmpty ? '$topSiteVisits visits' : null,
          ),
          const SizedBox(height: 20),
          _buildRevealCard(
            index: 1,
            icon: Icons.schedule_rounded,
            iconColor: kCyan,
            title: 'ACTIVE BROWSING TIME',
            value: activeBrowsingTime,
          ),
          const SizedBox(height: 20),
          _buildRevealCard(
            index: 2,
            icon: Icons.auto_awesome_rounded,
            iconColor: kCyan,
            title: 'YOUR BROWSING PERSONALITY',
            value: archetype,
            subtitle: tagline.isNotEmpty ? tagline : null,
            subtitleItalic: true,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REVEAL CARD — big, centered, icon-on-top layout: a bigger,
  // more "hero stat" feel than the compact left-aligned row cards
  // used on the earlier per-topic pages.
  // ============================================================

  Widget _buildRevealCard({
    required int index,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    String? subtitle,
    bool subtitleItalic = false,
  }) {
    final start = index * 0.2;
    final end = (start + 0.5).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
      parent: _revealController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBorder, width: 1),
          boxShadow: kCardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: kSurfaceAlt,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: iconColor, size: 34),
            ),
            const SizedBox(height: 20),
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
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kSilver,
                  fontSize: 14,
                  fontStyle:
                      subtitleItalic ? FontStyle.italic : FontStyle.normal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // NAV ROW (back + restart, same pill styling used across pages)
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
          onTap: () => rippleBackward(
            action: () => Navigator.pop(context),
          ),
        ),
        _buildPillButton(
          label: 'RESTART',
          icon: Icons.replay_rounded,
          iconFirst: false,
          background: kCyan,
          foreground: kInk,
          // Clears the whole stack back to the very first page rather
          // than pushing yet another copy on top.
          onTap: () => rippleForward(
            action: () => Navigator.pushAndRemoveUntil(
              context,
              instantRoute(const FrontPage()),
              (route) => false,
            ),
          ),
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