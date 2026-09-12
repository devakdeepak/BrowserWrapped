import 'package:flutter/material.dart';
import 'visited.dart';
import 'background/dyna.dart';
import 'widgets/marquee_banner.dart';
import 'widgets/wireframe_3d.dart';
import 'widgets/node_graph.dart';
import 'animations/ripple_crescent_transition.dart';

void main() {
  runApp(const BrowserPersonalityApp());
}

// Spotify-derived palette, green -> cyan
const kInk = Color(0xFF121212);        // base background (Level 0)
const kSurface = Color(0xFF181818);    // cards, elevated surfaces (Level 1)
const kSurfaceAlt = Color(0xFF1F1F1F); // buttons, interactive surfaces
const kWhite = Color(0xFFFFFFFF);
const kSilver = Color(0xFFB3B3B3);     // secondary text, muted labels
const kCyan = Color(0xFF22D3EE);       // functional accent only
const kBorder = Color(0xFF4D4D4D);

const kHeavyShadow = [
  BoxShadow(
    color: Color(0x80000000), // rgba(0,0,0,0.5)
    blurRadius: 24,
    offset: Offset(0, 8),
  ),
];

class BrowserPersonalityApp extends StatelessWidget {
  const BrowserPersonalityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Browser Wrapped',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: kInk,
        colorScheme: const ColorScheme.dark(
          surface: kSurface,
          primary: kCyan,
          secondary: kSilver,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kInk,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: kInk,
      body: Stack(
        children: [
          const DynamicBackground(),

          // --- Ambient 3D wireframe decoration, filling the side gaps ---
          // Only shown when there's actually room beside the centered
          // 420-wide content column (tablets/web/large phones landscape).
          // Up to 10 shapes scattered across both margins.
          if (screenWidth > 560) ...[
            // Big sphere bleeding off the top-left corner.
            Positioned(
              left: -300,
              top: -300,
              child: Opacity(
                opacity: 0.5,
                child: AnimatedWireframeShape(
                  type: WireframeShapeType.sphere,
                  size: 600,
                  color: kCyan,
                  rotationSpeed: const Duration(seconds: 24),
                  tiltX: 0.4,
                ),
              ),
            ),
            // Big sphere bleeding off the bottom-right corner
            // (opposite diagonal).
            Positioned(
              right: -300,
              bottom: -300,
              child: Opacity(
                opacity: 0.5,
                child: AnimatedWireframeShape(
                  type: WireframeShapeType.sphere,
                  size: 600,
                  color: kCyan,
                  rotationSpeed: const Duration(seconds: 24),
                  tiltX: 0.4,
                ),
              ),
            ),
            // Node graph decoration on the left, vertically centered.
            Positioned(
              left: 20,
              top: (screenHeight - 420) / 2,
              child: AnimatedNodeGraph(
                width: 220,
                height: 420,
                nodeCount: 14,
                color: kCyan,
              ),
            ),
          ],

          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Browser Wrapped',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: kWhite,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'A look back at everything you searched, visited, and probably shouldn\'t have.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: kSilver,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 64),
                      const GetStartedButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Marquee banner pinned to the very top of the screen,
          // above the dynamic background and the rest of the content.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: MarqueeBanner(
                items: const [
                  'Internet is Vast',
                  "Careful what you search for!",
                  'Privacy is Key',
                  'Data is Valuable',
                ],
                backgroundColor: kSurfaceAlt,
                textColor: kWhite,
                accentColor: kCyan,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GetStartedButton extends StatefulWidget {
  const GetStartedButton({super.key});

  @override
  State<GetStartedButton> createState() => _GetStartedButtonState();
}

class _GetStartedButtonState extends State<GetStartedButton> {
  bool _pressed = false;

  void _setPressed(bool value) => setState(() => _pressed = value);

  void _playTransitionThenNavigate(BuildContext context) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => RippleCrescentTransition(
        onComplete: () {
          entry.remove();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const FrontPage(),
            ),
          );
        },
      ),
    );

    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: () => _playTransitionThenNavigate(context),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 43),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kCyan,
            borderRadius: BorderRadius.circular(9999),
            boxShadow: kHeavyShadow,
          ),
          child: const Text(
            'START REVIEW',
            style: TextStyle(
              color: kInk,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}