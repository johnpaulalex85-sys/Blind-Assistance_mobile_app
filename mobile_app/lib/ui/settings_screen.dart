import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'face_register_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _url, _key;
  late double _rate;
  late int _interval;
  late bool _haptics, _skipDup;
  String _status = '';

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _url = TextEditingController(text: s.serverUrl);
    _key = TextEditingController(text: s.apiKey);
    _rate = s.speechRate;
    _interval = s.analysisIntervalSec;
    _haptics = s.hapticsEnabled;
    _skipDup = s.skipDuplicates;
  }

  Future<void> _save({bool test = false}) async {
    final s = context.read<AppState>();
    await s.saveSettings(
      url: _url.text,
      key: _key.text,
      rate: _rate,
      interval: _interval,
      haptic: _haptics,
      skipDup: _skipDup,
    );
    if (test) {
      setState(() => _status = 'Testing…');
      final msg = await s.testConnection();
      setState(() => _status = msg);
      await s.speech.say(msg, force: true);
      return;
    }
    if (!s.running) await s.start();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Server address',
              hintText: 'https://xxxx.ngrok-free.app or http://192.168.1.20:8000',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _key,
            obscureText: true,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'API key (leave empty if server has none)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton(onPressed: () => _save(test: true), child: const Text('Test connection')),
            ),
          ]),
          if (_status.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_status)),
          const Divider(height: 32),
          Text('Speech rate: ${_rate.toStringAsFixed(2)}'),
          Slider(
            value: _rate,
            min: 0.2,
            max: 0.9,
            divisions: 14,
            label: _rate.toStringAsFixed(2),
            semanticFormatterCallback: (v) => 'Speech rate ${v.toStringAsFixed(2)}',
            onChanged: (v) => setState(() => _rate = v),
          ),
          Text('Automatic analysis every $_interval seconds'),
          Slider(
            value: _interval.toDouble(),
            min: 4,
            max: 30,
            divisions: 26,
            label: '$_interval s',
            onChanged: (v) => setState(() => _interval = v.round()),
          ),
          SwitchListTile(
            title: const Text('Vibration alerts'),
            subtitle: const Text('Left: 2 pulses · Right: 3 pulses · Urgent: 3 long'),
            value: _haptics,
            onChanged: (v) => setState(() => _haptics = v),
          ),
          SwitchListTile(
            title: const Text('Skip repeated alerts'),
            value: _skipDup,
            onChanged: (v) => setState(() => _skipDup = v),
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.face),
            title: const Text('Faces'),
            subtitle: const Text('Register or delete people'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FaceRegisterScreen())),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: FilledButton(onPressed: () => _save(), child: const Text('Save', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(height: 12),
          const Text(
            'This app is an aid and does not replace a cane, guide dog or your own judgement.',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
