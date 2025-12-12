import 'dart:async';
import 'package:flutter/material.dart';

class AnimatedSplashPage extends StatefulWidget {
  final Widget next;
  final Duration minDuration;
  

  const AnimatedSplashPage({
    super.key,
    required this.next,
    this.minDuration = const Duration(milliseconds: 900),
  });

  @override
  State<AnimatedSplashPage> createState() => _AnimatedSplashPageState();
}

  final _scrollCtrl = ScrollController();
  bool _glitch = false;


class _AnimatedSplashPageState extends State<AnimatedSplashPage> {
  static const _lines = <String>[
    r"[+] BLE Pentest Lab booting...",
    r"[+] Loading company identifiers...",
    r"[+] Init BLE stack...",
    r"[+] Preparing logger...",
    r"[+] Ready.",
  ];

  final StringBuffer _buffer = StringBuffer();
  int _lineIndex = 0;
  int _charIndex = 0;

  Timer? _typeTimer;
  Timer? _blinkTimer;
  bool _cursorOn = true;

  late final DateTime _start;

  @override
  void initState() {
    super.initState();
    _start = DateTime.now();

    Timer.periodic(const Duration(milliseconds: 120), (t) {
      if (!mounted) return;
      if (_lineIndex >= 2) { 
        t.cancel();
        return;
      }
      setState(() => _glitch = !_glitch);
    });

    _blinkTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (!mounted) return;
      setState(() => _cursorOn = !_cursorOn);
      WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      });
    });

    _typeTimer = Timer.periodic(const Duration(milliseconds: 18), (_) {
      if (!mounted) return;

      if (_lineIndex >= _lines.length) {
        _finish();
        return;
      }

      final line = _lines[_lineIndex];

      // type current line char by char
      if (_charIndex < line.length) {
        _buffer.write(line[_charIndex]);
        _charIndex++;
        setState(() {});
        return;
      }

      // line completed -> newline + pause-like effect
      _buffer.write("\n");
      _lineIndex++;
      _charIndex = 0;
      setState(() {});
    });
  }

  void _finish() async {
    _typeTimer?.cancel();

    // ensure it doesn't feel too fast
    final elapsed = DateTime.now().difference(_start);
    final remaining = widget.minDuration - elapsed;
    if (remaining.inMilliseconds > 0) {
      await Future.delayed(remaining);
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => widget.next,
        transitionsBuilder: (_, anim, __, child) {
          final fade = CurvedAnimation(parent: anim, curve: Curves.easeOut);
          return FadeTransition(opacity: fade, child: child);
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _blinkTimer?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _buffer.toString() + (_cursorOn ? "█" : " ");

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.terminal, color: Color(0xFFB6F09C)),
                  const SizedBox(width: 8),
                  Text(
                    _glitch ? "B00T" : "BOOT",
                    style: const TextStyle(
                      color: Color(0xFFB6F09C),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF070A12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF1E2A3B)),
                  ),
                  child: SingleChildScrollView(
                    controller: _scrollCtrl,
                    child: Text(
                      text,
                      style: const TextStyle(
                        color: Color(0xFFB6F09C),
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: Color(0xFF1E2A3B),
                valueColor: AlwaysStoppedAnimation(Color(0xFFB6F09C)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
