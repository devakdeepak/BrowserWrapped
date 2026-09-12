import 'package:flutter/material.dart';

/// A horizontally scrolling, infinitely looping marquee banner,
/// styled to match the app's dark Spotify-derived palette.
class MarqueeBanner extends StatefulWidget {
  final List<String> items;
  final Color backgroundColor;
  final Color textColor;
  final Color accentColor;
  final double height;
  final Duration speed; // time to scroll one full loop of the content
  final TextStyle? textStyle;

  const MarqueeBanner({
    super.key,
    required this.items,
    this.backgroundColor = const Color(0xFF1F1F1F), // kSurfaceAlt
    this.textColor = const Color(0xFFFFFFFF),        // kWhite
    this.accentColor = const Color(0xFF22D3EE),      // kCyan
    this.height = 48,
    this.speed = const Duration(seconds: 12),
    this.textStyle,
  });

  @override
  State<MarqueeBanner> createState() => _MarqueeBannerState();
}

class _MarqueeBannerState extends State<MarqueeBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final ScrollController _scrollController = ScrollController();

  // Key used to measure the width of a single copy of the content.
  final GlobalKey _contentKey = GlobalKey();
  double _contentWidth = 0;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: widget.speed)
      ..addListener(_onTick)
      ..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    final box = _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      setState(() => _contentWidth = box.size.width);
    }
  }

  void _onTick() {
    if (_contentWidth == 0 || !_scrollController.hasClients) return;

    // Move forward by a fraction of the content width each frame,
    // wrapping around seamlessly once we've scrolled past one copy.
    final offset = _controller.value * _contentWidth;
    _scrollController.jumpTo(offset % _contentWidth);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildContentRow() {
    final style = widget.textStyle ??
        TextStyle(
          color: widget.textColor,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        );

    final children = <Widget>[];
    for (final item in widget.items) {
      children.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(item, style: style),
      ));
      children.add(Icon(Icons.auto_awesome, size: 14, color: widget.accentColor));
    }

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: double.infinity,
      color: widget.backgroundColor,
      child: ClipRect(
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // First copy: measured via _contentKey to know the loop width.
              KeyedSubtree(
                key: _contentKey,
                child: _buildContentRow(),
              ),
              // Duplicate copies so the strip never runs out of content
              // while scrolling and wrapping around.
              _buildContentRow(),
              _buildContentRow(),
            ],
          ),
        ),
      ),
    );
  }
}