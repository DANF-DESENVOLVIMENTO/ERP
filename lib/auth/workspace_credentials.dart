import 'dart:convert';

import 'package:crypto/crypto.dart';

String hashWorkspaceAccessCode(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return '';
  }

  return sha256.convert(utf8.encode(normalized)).toString();
}
