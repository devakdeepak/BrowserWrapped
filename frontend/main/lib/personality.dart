import 'package:flutter/material.dart';
import 'services/backend_service.dart';
import 'estimate.dart';
import 'finale.dart';
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

class PersonalityPage extends StatefulWidget {
  const PersonalityPage({super.key});

  @override
  State<PersonalityPage> createState() => _PersonalityPageState();
}

class _PersonalityPageState extends State<PersonalityPage>
    with SingleTickerProviderStateMixin, RippleNavMixin {
  late AnimationController _animationController;

  final BrowserWrappedService _backend = BrowserWrappedService(
    // TODO: same as the other pages — resolve this relative to the
    // bundled backend instead of hardcoding for a shipped app.
    backendDir: '/home/debuku/BrowserWrapped',
  );

  bool _isLoading = true;
  String? _loadError;

  String archetype = '';
  String tagline = '';
  String description = '';
  List<String> traits = [];

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _loadPersonality();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD PERSONALITY FROM PYTHON BACKEND
  // (calls `python -m backend personality --json`, which itself
  // calls Gemini, falling back to OpenRouter if that fails)
  // ============================================================

  Future<void> _loadPersonality() async {
    try {
      final data = await _backend.getPersonality();

      if (!mounted) return;
      setState(() {
        archetype = data['archetype'] as String? ?? 'Unknown Browser';
        tagline = data['tagline'] as String? ?? '';
        description = data['description'] as String? ?? '';
        traits = (data['traits'] as List<dynamic>? ?? [])
            .map((t) => t as String)
            .toList();
        _isLoading = false;
      });

      _animationController.forward();
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
                      const SizedBox(height: 12),
                      Expanded(child: _buildBody()),
                      _buildNavRow(),
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

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Your Browsing Personality',
          style: TextStyle(
            color: kWhite,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'An AI take on what your browsing history says about you.',
          style: TextStyle(
            color: kSilver,
            fontSize: 15,
          ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: kCyan),
            SizedBox(height: 16),
            Text(
              'Thinking about who you are online...',
              style: TextStyle(color: kSilver, fontSize: 13),
            ),
          ],
        ),
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
            'Could not load personality: $_loadError',
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return FadeTransition(
      opacity: _animationController,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOutCubic,
        )),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ------------------------------------------------
              // ARCHETYPE CARD
              // ------------------------------------------------
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 32,
                ),
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
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: kCyan,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      archetype,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: kCyan,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    if (tagline.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        tagline,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: kWhite,
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ------------------------------------------------
              // DESCRIPTION
              // ------------------------------------------------
              if (description.isNotEmpty)
                Text(
                  description,
                  style: const TextStyle(
                    color: kSilver,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),

              if (traits.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'TRAITS',
                  style: TextStyle(
                    color: kSilver,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: traits.map(_buildTraitChip).toList(),
                ),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTraitChip(String trait) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: kSurfaceAlt,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: kBorder, width: 1),
      ),
      child: Text(
        trait,
        style: const TextStyle(
          color: kCyan,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ============================================================
  // BACK / NEXT NAV ROW
  // ============================================================

  Widget _buildNavRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildBackButton(),
          _buildNextButton(),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () {
        rippleBackward(
          action: () => Navigator.push(
            context,
            instantRoute(const EstimatePage()),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: kSurfaceAlt,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: kBorder, width: 1),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back_rounded, color: kWhite, size: 18),
            SizedBox(width: 8),
            Text(
              'BACK',
              style: TextStyle(
                color: kWhite,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    return GestureDetector(
      onTap: () {
        rippleForward(
          action: () => Navigator.push(
            context,
            instantRoute(const FinalePage()),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
            Icon(Icons.arrow_forward_rounded, color: kInk, size: 19),
          ],
        ),
      ),
    );
  }
}