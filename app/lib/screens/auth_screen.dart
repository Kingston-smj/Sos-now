import 'package:flutter/material.dart';

import '../api.dart';
import '../format.dart';
import '../scope.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  TextEditingController? _server;
  bool _creating = false;
  bool _hidePassword = true;
  bool _pinging = false;
  String? _pingMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _server ??= TextEditingController(text: SosScope.of(context).apiBase);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    _server?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sos = SosScope.of(context);
    final server = _server!;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 12),
            const CircleAvatar(
              radius: 28,
              backgroundColor: Color(0xFF0E4D3A),
              child: Icon(Icons.campaign, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text('SOS Now', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Report an accident, fight, riot, or other incident so people nearby can see it.'),
            const SizedBox(height: 20),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Log in')),
                ButtonSegment(value: true, label: Text('Create account')),
              ],
              selected: {_creating},
              onSelectionChanged: (value) {
                if (sos.busy) return;
                setState(() => _creating = value.first);
              },
            ),
            const SizedBox(height: 20),
            Form(
              key: _form,
              child: Column(
                children: [
                  if (_creating) ...[
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (value) => (value == null || value.trim().length < 2) ? 'Enter your name' : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone number', hintText: '0803 123 4567'),
                    validator: (value) => (value == null || value.trim().length < 10) ? 'Enter your Nigerian phone number' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: _hidePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        tooltip: _hidePassword ? 'Show password' : 'Hide password',
                        onPressed: () => setState(() => _hidePassword = !_hidePassword),
                        icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                    validator: (value) => (value == null || value.length < 6) ? 'Use at least 6 characters' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              title: const Text('Server address'),
              children: [
                TextField(
                  controller: server,
                  decoration: const InputDecoration(
                    labelText: 'Server',
                    helperText: 'Emulator: http://10.0.2.2:8000. A phone on the same Wi-Fi uses this computer\'s address, such as http://192.168.1.20:8000.',
                    helperMaxLines: 3,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _pinging ? null : () => _ping(server.text),
                    child: Text(_pinging ? 'Checking...' : 'Test server'),
                  ),
                ),
                if (_pingMessage != null)
                  Align(alignment: Alignment.centerLeft, child: Text(_pingMessage!)),
              ],
            ),
            if (sos.error != null) ...[
              const SizedBox(height: 8),
              Text(sos.error!, style: const TextStyle(color: Color(0xFFB42318))),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: sos.busy ? null : () => _submit(server.text),
              child: Text(sos.busy ? 'Please wait...' : _creating ? 'Create account' : 'Log in'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ping(String base) async {
    setState(() {
      _pinging = true;
      _pingMessage = null;
    });
    try {
      await SosApi(base: normalizeBase(base)).ping();
      if (mounted) setState(() => _pingMessage = 'Server is reachable.');
    } on ApiException catch (err) {
      if (mounted) setState(() => _pingMessage = err.message);
    } finally {
      if (mounted) setState(() => _pinging = false);
    }
  }

  Future<void> _submit(String base) async {
    if (!_form.currentState!.validate()) return;
    final sos = SosScope.of(context);
    if (_creating) {
      await sos.register(
        base: base,
        personName: _name.text,
        phoneNumber: _phone.text,
        password: _password.text,
      );
    } else {
      await sos.login(base: base, phoneNumber: _phone.text, password: _password.text);
    }
  }
}
