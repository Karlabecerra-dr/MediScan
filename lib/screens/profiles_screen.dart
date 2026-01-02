import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../services/profile_service.dart';
import '../services/active_profile.dart';

class ProfilesScreen extends StatefulWidget {
  static const routeName = '/profiles';

  const ProfilesScreen({super.key});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  final _service = ProfileService();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Asegura que exista al menos 1 perfil y que haya un activo
    await ActiveProfile.initAndEnsure();

    // Sincroniza el activo desde SharedPreferences al ValueNotifier
    final active = await _service.getActiveProfileId();
    ActiveProfile.activeProfileId.value = active;
  }

  Future<void> _createProfile() async {
    final name = await _askNameDialog(title: 'Nuevo perfil', hint: 'Ej: Mamá');
    if (name == null || name.trim().isEmpty) return;

    final id = await _service.createProfile(name: name.trim());
    await ActiveProfile.set(id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perfil creado y seleccionado ✅')),
    );
  }

  Future<void> _editProfile(Profile profile) async {
    final name = await _askNameDialog(
      title: 'Editar perfil',
      hint: 'Nombre',
      initialValue: profile.name,
    );
    if (name == null || name.trim().isEmpty) return;

    if (profile.id == null) return;
    await _service.updateProfile(profile.id!, name: name.trim());

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Perfil actualizado ✅')));
  }

  Future<void> _deleteProfile(
    Profile profile,
    List<Profile> allProfiles,
  ) async {
    // Regla segura: no permitir borrar si es el último perfil
    if (allProfiles.length <= 1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes mantener al menos 1 perfil.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar perfil'),
        content: Text(
          '¿Eliminar "${profile.name}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (profile.id == null) return;

    await _service.deleteProfile(profile.id!);

    // Si se borró el activo, asignamos otro automáticamente
    await _service.ensureDefaultProfileExists();
    final active = await _service.getActiveProfileId();
    ActiveProfile.activeProfileId.value = active;

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Perfil eliminado ✅')));
  }

  Future<String?> _askNameDialog({
    required String title,
    required String hint,
    String? initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue ?? '');

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfiles')),
      floatingActionButton: FloatingActionButton(
        onPressed: _createProfile,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Profile>>(
        stream: _service.streamProfiles(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final profiles = snap.data ?? [];

          if (profiles.isEmpty) {
            return const Center(
              child: Text('No hay perfiles.\nCrea uno con el botón +'),
            );
          }

          return ValueListenableBuilder<String?>(
            valueListenable: ActiveProfile.activeProfileId,
            builder: (context, activeId, _) {
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: profiles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final p = profiles[i];
                  final isActive = p.id != null && p.id == activeId;

                  return Material(
                    color: Theme.of(context).colorScheme.surface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          (p.name.isNotEmpty ? p.name[0].toUpperCase() : '?'),
                        ),
                      ),
                      title: Text(
                        p.name,
                        style: TextStyle(
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                      subtitle: isActive ? const Text('Perfil activo') : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Editar',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _editProfile(p),
                          ),
                          IconButton(
                            tooltip: 'Eliminar',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteProfile(p, profiles),
                          ),
                        ],
                      ),
                      onTap: () async {
                        if (p.id == null) return;

                        await ActiveProfile.set(p.id!);
                        ActiveProfile.activeProfileId.value =
                            p.id!; // ✅ asegura UI

                        if (!mounted) return;
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
