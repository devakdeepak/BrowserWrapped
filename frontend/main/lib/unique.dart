import 'package:flutter/material.dart';
import 'activity.dart';
import 'services/backend_service.dart';
import 'animations/table.dart';
import 'animations/ripple_nav.dart';

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

class UniquePage extends StatefulWidget {
  const UniquePage({super.key});

  @override
  State<UniquePage> createState() => _UniquePageState();
}

class _UniquePageState extends State<UniquePage>
    with SingleTickerProviderStateMixin, SplitTableMixin, RippleNavMixin {

  @override
  int get rowCount => uniqueSites.length;

  final BrowserWrappedService _backend = BrowserWrappedService(
    // TODO: same as visited.dart — resolve this relative to the
    // bundled backend instead of hardcoding for a shipped app.
    backendDir: '/home/debuku/BrowserWrapped',
  );

  bool _isLoading = true;
  String? _loadError;

  // Each entry: {'domain': String, 'visits': int}
  List<Map<String, dynamic>> uniqueSites = [];

  @override
  void initState() {
    super.initState();
    // rowCount is 0 at this point since uniqueSites hasn't loaded yet —
    // that's fine, SplitTableMixin says to call restartSplitEntrance()
    // once the real data (and therefore real rowCount) is in.
    initSplitTable(this);
    _loadSites();
  }

  @override
  void dispose() {
    disposeSplitTable();
    super.dispose();
  }

  // ============================================================
  // LOAD UNIQUE SITES FROM PYTHON BACKEND
  // ============================================================

  Future<void> _loadSites() async {
    try {
      // Top 10 domains by visit count.
      final data = await _backend.getWrapped(top: 10);

      // top_domains is a list of [domain, count] pairs — NOT a list of
      // {'domain': ..., 'visits': ...} objects. Each entry decodes from
      // JSON as a 2-element List<dynamic>.
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
        uniqueSites = sites;
        _isLoading = false;
      });

      // rowCount only became meaningful once uniqueSites was populated
      // above, so (re)play the staggered entrance now.
      restartSplitEntrance();
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

            // NEXT = left -> right wave, BACK = right -> left wave.
            buildRippleOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Unique Sites',
          style: TextStyle(
            color: kWhite,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isLoading
              ? 'Counting distinct websites you visited.'
              : 'Your top ${uniqueSites.length} most-visited sites.',
          style: const TextStyle(
            color: kSilver,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 1,
          color: kBorder,
        ),
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
            'Could not load unique sites: $_loadError',
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (uniqueSites.isEmpty) {
      return const Center(
        child: Text(
          'No sites found.',
          style: TextStyle(color: kSilver, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: uniqueSites.length,
      itemBuilder: (context, index) {
        return SplitRevealRow(
          // Per-row stagger driven by SplitTableMixin's own controller —
          // no separate AnimationController needed in this file at all.
          animation: rowAnimation(index),
          child: _buildSiteCard(
            site: uniqueSites[index],
            index: index,
          ),
        );
      },
    );
  }

  Widget _buildSiteCard({
    required Map<String, dynamic> site,
    required int index,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: kBorder,
          width: 1,
        ),
        boxShadow: kCardShadow,
      ),
      child: Row(
        children: [
          // Ranking number
          SizedBox(
            width: 38,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: index < 3 ? kCyan : kSilver,
                fontSize: index < 3 ? 20 : 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          // Site icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: kSurfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.language_rounded,
              color: kCyan,
              size: 22,
            ),
          ),

          const SizedBox(width: 14),

          // Domain
          Expanded(
            child: Text(
              site['domain'] as String,
              style: const TextStyle(
                color: kWhite,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Visits
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${site['visits'] as int}',
                style: const TextStyle(
                  color: kWhite,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'visits',
                style: TextStyle(
                  color: kSilver,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NAV ROW (back + next, same pill styling used across pages)
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
          // Right-to-left crescent wave, then pop.
          onTap: () => rippleBackward(
            action: () => Navigator.pop(context),
          ),
        ),
        _buildPillButton(
          label: 'NEXT',
          icon: Icons.arrow_forward_rounded,
          iconFirst: false,
          background: kCyan,
          foreground: kInk,
          // Left-to-right crescent wave, then push.
          onTap: () => rippleForward(
            action: () => Navigator.push(
              context,
              instantRoute(const ActivityPage()),
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

    final iconWidget = Icon(
      icon,
      color: foreground,
      size: 19,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 14,
        ),
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