import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';

class ProfileService {
  static const _activeProfileKey = 'activeProfileId';

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No hay usuario autenticado.');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> _profilesCol() {
    return _db.collection('users').doc(_uid).collection('profiles');
  }

  Stream<List<Profile>> streamProfiles() {
    return _profilesCol()
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Profile.fromDoc(d)).toList());
  }

  Future<List<Profile>> getProfilesOnce() async {
    final q = await _profilesCol().get();
    return q.docs.map((d) => Profile.fromDoc(d)).toList();
  }

  Future<Profile?> getProfileById(String profileId) async {
    final doc = await _profilesCol().doc(profileId).get();
    if (!doc.exists) return null;
    return Profile.fromDoc(doc);
  }

  // ✅ Alias por compatibilidad (por si alguna pantalla usa otro nombre)
  Future<Profile?> getProfileByIdOnce(String profileId) =>
      getProfileById(profileId);

  Future<String> createProfile({
    required String name,
    String? avatar,
    bool isDefault = false,
  }) async {
    final doc = await _profilesCol().add({
      'name': name.trim(),
      'avatar': avatar,
      'isDefault': isDefault,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> updateProfile(
    String profileId, {
    String? name,
    String? avatar,
    bool clearAvatar = false,
  }) {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name.trim();
    if (clearAvatar) data['avatar'] = null;
    if (!clearAvatar && avatar != null) data['avatar'] = avatar;
    return _profilesCol().doc(profileId).update(data);
  }

  Future<void> deleteProfile(String profileId) async {
    await _profilesCol().doc(profileId).delete();

    final active = await getActiveProfileId();
    if (active == profileId) {
      await setActiveProfileId(null);
    }
  }

  Future<void> setActiveProfileId(String? profileId) async {
    final prefs = await SharedPreferences.getInstance();
    if (profileId == null) {
      await prefs.remove(_activeProfileKey);
    } else {
      await prefs.setString(_activeProfileKey, profileId);
    }
  }

  Future<String?> getActiveProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeProfileKey);
  }

  Future<void> ensureDefaultProfileExists() async {
    final profiles = await getProfilesOnce();

    if (profiles.isEmpty) {
      final newId = await createProfile(name: 'Mi perfil', isDefault: true);
      await setActiveProfileId(newId);
      return;
    }

    final active = await getActiveProfileId();
    if (active != null) {
      final exists = profiles.any((p) => p.id == active);
      if (exists) return;
    }

    final defaultOne = profiles.where((p) => p.isDefault).toList();
    final pickId = (defaultOne.isNotEmpty
        ? defaultOne.first.id
        : profiles.first.id);

    if (pickId != null) {
      await setActiveProfileId(pickId);
    }
  }
}
