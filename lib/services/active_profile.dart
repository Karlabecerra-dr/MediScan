import 'package:flutter/foundation.dart';
import 'profile_service.dart';

/// Estado global simple para el perfil activo.
/// - Guarda el id en memoria (ValueNotifier)
/// - Persiste en SharedPreferences mediante ProfileService
class ActiveProfile {
  static final ValueNotifier<String?> activeProfileId = ValueNotifier<String?>(
    null,
  );

  /// Llamar al iniciar la app (después de login, o al cargar Home).
  static Future<void> initAndEnsure() async {
    final service = ProfileService();

    // Asegura que exista un perfil (crea "Mi perfil" si no hay)
    await service.ensureDefaultProfileExists();

    // Carga el activo desde prefs
    final id = await service.getActiveProfileId();
    activeProfileId.value = id;
  }

  /// Cambia el perfil activo (y lo persiste).
  static Future<void> set(String profileId) async {
    final service = ProfileService();
    await service.setActiveProfileId(profileId);
    activeProfileId.value = profileId;
  }
}
