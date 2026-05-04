import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WorkspaceSession {
  WorkspaceSession._();

  static final WorkspaceSession instance = WorkspaceSession._();

  static const _sessionKey = 'workspace_active_profile_id';

  final ValueNotifier<String?> _currentProfileId = ValueNotifier<String?>(null);
  SharedPreferences? _preferences;

  ValueListenable<String?> get currentProfileIdListenable => _currentProfileId;

  String? get currentProfileId => _currentProfileId.value;

  Future<void> initialize() async {
    if (_preferences != null) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    _preferences = preferences;
    _currentProfileId.value = preferences.getString(_sessionKey);
  }

  Future<void> signIn(String profileId) async {
    await initialize();
    final normalizedProfileId = profileId.trim().toLowerCase();
    _currentProfileId.value = normalizedProfileId;
    await _preferences!.setString(_sessionKey, normalizedProfileId);
  }

  Future<void> signOut() async {
    await initialize();
    _currentProfileId.value = null;
    await _preferences!.remove(_sessionKey);
  }
}
