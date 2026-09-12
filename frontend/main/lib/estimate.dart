import 'package:flutter/material.dart';
import 'personality.dart';
import 'activity.dart';
import 'services/backend_service.dart';
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

class EstimatePage extends StatefulWidget {
  const EstimatePage({super.key});

  @override
  State<EstimatePage> createState() => _EstimatePageState();
}

class _EstimatePageState extends State<EstimatePage>
    with SingleTickerProviderStateMixin, RippleNavMixin {
  late AnimationController _statsController;

  final BrowserWrappedService _backend = BrowserWrappedService(
    // TODO: same as the other pages — resolve this relative to the
    // bundled backend instead of hardcoding for a shipped app.
    backendDir: '/home/debuku/BrowserWrapped',
  );

  bool _isLoading = true;
  String? _loadError;

  String activeBrowsingTime = '0h 0m';

  @override
  void initState() {
    super.initState();

    _statsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _loadStats();
  }

  @override
  void dispose() {
    _statsController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD STATS FROM PYTHON BACKEND
  // ============================================================

  Future<void> _loadStats() async {
    try {
      final data = await _backend.getWrapped();

      final double estimatedHours =
          (data['estimated_active_hours'] as num).toDouble();
      final int hours = estimatedHours.floor();
      final int minutes = ((estimatedHours - hours) * 60).round();

      if (!mounted) return;
      setState(() {
        activeBrowsingTime = '${hours}h ${minutes}m';
        _isLoading = false;
      });

      _statsController.forward(from: 0);
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
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      const SizedBox(height: 28),
                      _buildHeader(),
                      const SizedBox(height: 36),
                      Expanded(
                        child: SingleChildScrollView(
                          child: _buildBody(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildNavRow(context),
                      const SizedBox(height: 20),
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
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Active Time',
          style: TextStyle(
            color: kWhite,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Roughly how long you spent actually browsing.',
          style: TextStyle(
            color: kSilver,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(
          child: CircularProgressIndicator(color: kCyan),
        ),
      );
    }

    if (_loadError != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.redAccent, width: 1),
        ),
        child: Text(
          'Could not load active time: $_loadError',
          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
        ),
      );
    }

    return _buildAnimatedStat(
      index: 0,
      icon: Icons.schedule_rounded,
      title: 'Estimated Active Browsing Time',
      value: activeBrowsingTime,
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
    final end = (start + 0.4).clamp(0.0, 1.0);

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
            offset: Offset(0, 30 * (1 - animation.value)),
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

  // ============================================================
  // NAV ROW (back + next, same pill styling as unique.dart)
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
          onTap: () {
            rippleBackward(
              action: () => Navigator.push(
                context,
                instantRoute(const ActivityPage()),
              ),
            );
          },
        ),
        _buildPillButton(
          label: 'NEXT',
          icon: Icons.arrow_forward_rounded,
          iconFirst: false,
          background: kCyan,
          foreground: kInk,
          onTap: () {
            rippleForward(
              action: () => Navigator.push(
                context,
                instantRoute(const PersonalityPage()),
              ),
            );
          },
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