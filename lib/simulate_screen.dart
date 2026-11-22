import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'sim_store.dart';

/// The simulator: create a fake *incoming* message that is stored locally
/// only and shown in the inbox + conversation exactly like a real received
/// message. Nothing is ever sent anywhere.
class SimulateScreen extends StatefulWidget {
  const SimulateScreen({
    super.key,
    this.initialAddress,
    this.initialDisplayName,
  });

  final String? initialAddress;
  final String? initialDisplayName;

  @override
  State<SimulateScreen> createState() => _SimulateScreenState();
}

class _SimulateScreenState extends State<SimulateScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _address;
  late final TextEditingController _name;
  late final TextEditingController _body;
  DateTime _when = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _address = TextEditingController(text: widget.initialAddress ?? '');
    _name = TextEditingController(text: widget.initialDisplayName ?? '');
    _body = TextEditingController();
  }

  @override
  void dispose() {
    _address.dispose();
    _name.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (time == null || !mounted) return;
    setState(() {
      _when = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    await SimStore.instance.insert(
      address: _address.text,
      displayName: _name.text,
      body: _body.text.trim(),
      timestamp: _when,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Simulated message from ${_address.text.trim()} added — local only, nothing was sent.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulate incoming message'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Card(
              color: Color(0xFFEADDFF),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'This message is stored ONLY on this phone and shown as if '
                  'it arrived from the sender below. It is never sent to '
                  'anyone, and it never appears in your real messaging app.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(
                labelText: 'Sender number / short code *',
                hintText: 'e.g. 9221, 9771, 03001234567',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter the sender number or short code'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Sender name (optional)',
                hintText: 'Shown instead of the number, e.g. MyTelenor',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _body,
              decoration: const InputDecoration(
                labelText: 'Message text *',
                hintText: 'Type the message as it should appear…',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              keyboardType: TextInputType.multiline,
              minLines: 4,
              maxLines: 10,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter the message text'
                  : null,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: const Text('Received time'),
              subtitle: Text(
                DateFormat('EEEE, MMM d, yyyy • h:mm a').format(_when),
              ),
              trailing: TextButton(
                onPressed: _pickDateTime,
                child: const Text('Change'),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: const Text('Add simulated message'),
            ),
          ],
        ),
      ),
    );
  }
}
