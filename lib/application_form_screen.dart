import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_service.dart';
import '../job_offer.dart';
import '../validators.dart';

class ApplicationFormScreen extends StatefulWidget {
  final JobOffer offer;
  const ApplicationFormScreen({super.key, required this.offer});

  @override
  State<ApplicationFormScreen> createState() => _ApplicationFormScreenState();
}

class _ApplicationFormScreenState extends State<ApplicationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();

  bool _sending = false;
  String? _fileName;
  Uint8List? _fileBytes;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (result != null && result.files.single.bytes != null) {
      if (result.files.single.size > 5 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plik jest za duży (max 5 MB)')),
        );
        return;
      }
      setState(() {
        _fileName = result.files.single.name;
        _fileBytes = result.files.single.bytes;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      await context.read<ApiService>().applyToJob(
            widget.offer.id,
            name: _nameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            message: _msgCtrl.text.trim().isEmpty ? null : _msgCtrl.text.trim(),
            fileBytes: _fileBytes,
            fileName: _fileName,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aplikacja została wysłana')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.offer;
    return Scaffold(
      appBar: AppBar(title: Text('Aplikuj: ${o.title}', overflow: TextOverflow.ellipsis)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.work, color: Colors.blue),
                title: Text(o.company, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(o.location),
              ),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Imię i nazwisko', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Pole wymagane' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()),
                    validator: validateEmail,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Telefon', border: OutlineInputBorder()),
                    validator: validatePhone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _msgCtrl,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'List motywacyjny (opcjonalny)',
                      hintText: 'Możesz opisać, dlaczego pasujesz do tej roli...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.attach_file),
                          label: Text(_fileName ?? 'Dołącz plik (PDF/DOC)'),
                          onPressed: _pickFile,
                        ),
                      ),
                      if (_fileName != null)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() {
                            _fileName = null;
                            _fileBytes = null;
                          }),
                        ),
                    ],
                  ),
                  if (_fileName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('Wybrano: $_fileName', style: const TextStyle(fontSize: 12)),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.send),
                      label: _sending
                          ? const SizedBox(
                              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Wyślij aplikację'),
                      onPressed: _sending ? null : _submit,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
