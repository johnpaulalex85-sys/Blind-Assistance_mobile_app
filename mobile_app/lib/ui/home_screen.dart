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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _StatusBar(s),
            Expanded(
              child: Center(
                child: (s.running && cam != null && cam.value.isInitialized)
                    ? AspectRatio(
                        aspectRatio: 1 / cam.value.aspectRatio,
                        child: ExcludeSemantics(
                          child: Stack(fit: StackFit.expand, children: [
                            CameraPreview(cam),
                            CustomPaint(painter: OverlayPainter(s.last, s.frameSize)),
                          ]),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(s.error ?? 'Starting camera…', textAlign: TextAlign.center),
                      ),
              ),
            ),
            _Controls(s, onSettings: _openSettings),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar(this.s);
  final AppState s;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (s.link) {
      LinkState.connected => ('Connected', Colors.greenAccent),
      LinkState.connecting => ('Connecting…', Colors.amber),
      LinkState.disconnected => (s.running ? 'Reconnecting…' : 'Stopped', Colors.redAccent),
    };
    final r = s.last;
    final alert = r?.hazardAlert ?? '';
    return Semantics(
      liveRegion: false,
      label: 'Status: $label',
      child: Container(
        width: double.infinity,
        color: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Icon(Icons.circle, size: 12, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              alert.isNotEmpty ? alert : (r == null ? '' : '${r.detections.length} objects · ${r.inferenceMs.round()} ms'),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: (r?.isUrgent ?? false) ? Colors.redAccent : Colors.white70),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls(this.s, {required this.onSettings});
  final AppState s;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(
            child: _BigButton(
              icon: Icons.visibility,
              label: 'Describe',
              hint: 'Describe what the camera sees',
              onTap: s.describe,
            ),
          ),
          Expanded(
            child: _BigButton(
              icon: s.voiceOn ? Icons.mic : Icons.mic_none,
              label: s.voiceOn ? 'Listening' : 'Voice',
              hint: 'Toggle voice commands',
              active: s.voiceOn,
              onTap: s.toggleVoice,
            ),
          ),
        ]),
        Row(children: [
          Expanded(
            child: _BigButton(
              icon: s.continuous ? Icons.pause_circle : Icons.play_circle,
              label: s.continuous ? 'Auto: on' : 'Auto: off',
              hint: 'Toggle continuous scene analysis',
              active: s.continuous,
              onTap: () => s.setContinuous(!s.continuous),
            ),
          ),
          Expanded(
            child: _BigButton(
              icon: Icons.settings,
              label: 'Settings',
              hint: 'Open settings and face registration',
              onTap: onSettings,
            ),
          ),
        ]),
      ]),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label, hint;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Semantics(
        button: true,
        label: label,
        hint: hint,
        excludeSemantics: true,
        onTap: onTap,
        child: SizedBox(
          height: 88,
          child: FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: active ? Colors.amber : null,
              foregroundColor: active ? Colors.black : null,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: onTap,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 34),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      ),
    );
  }
}
