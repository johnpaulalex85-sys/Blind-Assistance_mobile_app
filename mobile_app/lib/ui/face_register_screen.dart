import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class FaceRegisterScreen extends StatefulWidget {
  const FaceRegisterScreen({super.key});

  @override
  State<FaceRegisterScreen> createState() => _FaceRegisterScreenState();
}

class _FaceRegisterScreenState extends State<FaceRegisterScreen> {
  final _name = TextEditingController();
  bool _busy = false;
  String _msg = '';
  List<String> _faces = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final api = context.read<AppState>().api;
    if (api == null) return;
    try {
      final f = await api.listFaces();
      if (mounted) setState(() => _faces = f);
    } catch (_) {}
  }

  Future<void> _register() async {
    final s = context.read<AppState>();
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _msg = 'Please enter a name first.');
      return;
    }
    setState(() {
      _busy = true;
      _msg = 'Point the camera at the face. Capturing…';
    });
    await s.speech.say('Point the camera at the face. Capturing now.', force: true);
    final res = await s.registerFace(name, onProgress: (i) => setState(() => _msg = 'Captured $i of 5'));
    await s.speech.say(res, force: true);
    if (mounted) {
      setState(() {
        _busy = false;
        _msg = res;
      });
    }
    _refresh();
  }

  Future<void> _delete(String name) async {
    final s = context.read<AppState>();
    final ok = await s.api?.deleteFace(name) ?? false;
    await s.speech.say(ok ? 'Deleted $name.' : 'Could not delete $name.', force: true);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Faces')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Stand so the person is in front of the camera, then press Register. Five frames are captured.'),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Person\'s name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: _busy ? null : _register,
              child: Text(_busy ? 'Capturing…' : 'Register face', style: const TextStyle(fontSize: 18)),
            ),
          ),
          if (_msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_msg)),
          const Divider(height: 32),
          Text('Registered (${_faces.length})', style: Theme.of(context).textTheme.titleMedium),
          for (final f in _faces)
            ListTile(
              title: Text(f),
              trailing: IconButton(
                tooltip: 'Delete $f',
                icon: const Icon(Icons.delete),
                onPressed: () => _delete(f),
              ),
            ),
          const SizedBox(height: 8),
          const Text('Face data is stored on your server. Only register people who have agreed.',
              style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}
