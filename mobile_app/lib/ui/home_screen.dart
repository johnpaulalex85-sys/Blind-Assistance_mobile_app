import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/detect_socket.dart';
import '../state/app_state.dart';
import 'face_register_screen.dart';
import 'overlay_painter.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final s = context.read<AppState>();
    s.onOpenFaceRegister = () {
      if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const FaceRegisterScreen()));
    };
    while (mounted && !s.loaded) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    if (!mounted) return;
    if (!s.configured) {
      await s.speech.say('Welcome. Please enter your server address in settings.', force: true);
      if (mounted) _openSettings();
      return;
    }
    final ok = await s.start();
    if (ok) await s.speech.say('Vision Assistant ready.', force: true);
  }

  void _openSettings() => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final s = context.read<AppState>();
    if (state == AppLifecycleState.paused && s.running) s.stop();
    if (state == AppLifecycleState.resumed && !s.running && s.configured) s.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cam = s.camera.controller;
    final r = s.last;

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. FULLSCREEN CAMERA FEED (matching web client video viewport)
              if (s.running && cam != null && cam.value.isInitialized)
                SizedOverflowBox(
                  size: size,
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: cam.value.previewSize?.height ?? size.width,
                      height: cam.value.previewSize?.width ?? size.height,
                      child: CameraPreview(cam),
                    ),
                  ),
                )
              else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Color(0xFF38BDF8)),
                        const SizedBox(height: 16),
                        Text(
                          s.error ?? 'Starting camera feed…',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),

              // 2. NEON GLOWING BOUNDING BOXES & WALKING CORRIDOR OVERLAY
              if (s.running && cam != null && cam.value.isInitialized)
                CustomPaint(
                  painter: OverlayPainter(s.last, s.frameSize),
                  size: size,
                ),

              // 3. TOP-LEFT GLASS BADGE: Vision Assistant AI
              Positioned(
                top: 12,
                left: 12,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xCC0F172A),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: s.link == LinkState.connected
                                ? const Color(0xFF10B981)
                                : (s.link == LinkState.connecting ? Colors.amber : Colors.redAccent),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: s.link == LinkState.connected
                                    ? const Color(0xFF10B981)
                                    : (s.link == LinkState.connecting ? Colors.amber : Colors.redAccent),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Vision Assistant AI',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              s.link == LinkState.connected
                                  ? 'Live Walking Safety Feed'
                                  : (s.link == LinkState.connecting ? 'Connecting…' : 'Disconnected'),
                              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 4. TOP-RIGHT TELEMETRY HUD BAR (Latency & Detections)
              Positioned(
                top: 12,
                right: 12,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xCC0F172A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.speed, size: 14, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 6),
                        Text(
                          r != null ? '${r.inferenceMs.round()} ms' : '--',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          r != null ? '${r.detections.length} objs' : '--',
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 5. TOP-CENTER HAZARD ALERT BANNER
              if (r != null && r.hazardAlert.isNotEmpty)
                Positioned(
                  top: 72,
                  left: 16,
                  right: 16,
                  child: SafeArea(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: r.isUrgent ? const Color(0xEEEF4444) : const Color(0xEEF59E0B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: (r.isUrgent ? Colors.red : Colors.orange).withOpacity(0.6),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            r.isUrgent ? Icons.warning_amber_rounded : Icons.info_outline,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              r.hazardAlert,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 6. FLOATING BOTTOM FROSTED GLASS CONTROLS
              Positioned(
                bottom: 16,
                left: 12,
                right: 12,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xDD0F172A),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.6),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _GlassButton(
                            icon: Icons.visibility,
                            label: 'Describe',
                            hint: 'Describe scene',
                            onTap: s.describe,
                          ),
                        ),
                        Expanded(
                          child: _GlassButton(
                            icon: s.voiceOn ? Icons.mic : Icons.mic_none,
                            label: s.voiceOn ? 'Listening' : 'Voice',
                            hint: 'Toggle voice commands',
                            active: s.voiceOn,
                            activeColor: const Color(0xFFF59E0B),
                            onTap: s.toggleVoice,
                          ),
                        ),
                        Expanded(
                          child: _GlassButton(
                            icon: s.continuous ? Icons.pause_circle : Icons.play_circle,
                            label: s.continuous ? 'Auto: on' : 'Auto: off',
                            hint: 'Continuous analysis',
                            active: s.continuous,
                            activeColor: const Color(0xFF10B981),
                            onTap: () => s.setContinuous(!s.continuous),
                          ),
                        ),
                        Expanded(
                          child: _GlassButton(
                            icon: Icons.settings,
                            label: 'Settings',
                            hint: 'Open settings',
                            onTap: _openSettings,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
    this.active = false,
    this.activeColor = const Color(0xFF38BDF8),
  });

  final IconData icon;
  final String label, hint;
  final VoidCallback onTap;
  final bool active;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Semantics(
        button: true,
        label: label,
        hint: hint,
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: active ? activeColor.withOpacity(0.25) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: active ? activeColor.withOpacity(0.6) : Colors.white.withOpacity(0.08),
                  width: active ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 24, color: active ? activeColor : Colors.white),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: active ? activeColor : Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
