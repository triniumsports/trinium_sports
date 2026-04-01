import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VerificationService {
  final SupabaseClient _client = Supabase.instance.client;

  static const String bucket = 'professional-verification';

  Future<void> pickAndUpload({required String docType}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      throw Exception('Nenhum arquivo selecionado.');
    }

    final file = result.files.single;
    final Uint8List? bytes = file.bytes;
    final String name = file.name;

    if (bytes == null || bytes.isEmpty) {
      throw Exception('Falha ao ler o arquivo no navegador.');
    }

    final ext = name.split('.').last.toLowerCase();
    final contentType = _guessContentType(ext);

    final objectPath =
        '${user.id}/${docType}_${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _client.storage.from(bucket).uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    final payload = {
      'type': docType,
      'bucket': bucket,
      'path': objectPath,
      'filename': name,
      'uploaded_at': DateTime.now().toIso8601String(),
    };

    final coach = await _client
        .from('coaches')
        .select('verification_documents')
        .eq('id', user.id)
        .maybeSingle();

    final current = coach?['verification_documents'];
    final List<dynamic> docs =
        current is List ? List<dynamic>.from(current) : <dynamic>[];

    docs.add(payload);

    final types = docs
        .map((e) => (e is Map ? (e['type'] ?? '').toString() : ''))
        .toSet();

    final hasAll = types.contains('identity') &&
        types.contains('council') &&
        types.contains('lookup_print');

    final update = <String, dynamic>{
      'verification_documents': docs,
      'verification_status': hasAll ? 'approved' : 'pending',
    };

    if (hasAll) {
      update['verification_submitted_at'] = DateTime.now().toIso8601String();
      update['verification_mode'] = 'auto';
    }

    await _client.from('coaches').update(update).eq('id', user.id);
  }

  String _guessContentType(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }
}
