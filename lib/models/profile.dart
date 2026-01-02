import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de perfil (persona) dentro de un mismo usuario.
/// Ej: "Karla", "Mamá", "Alanis".
class Profile {
  final String? id; // id del documento en Firestore
  final String name;
  final String? avatar; // opcional: emoji o url
  final bool isDefault;
  final DateTime? createdAt;

  const Profile({
    this.id,
    required this.name,
    this.avatar,
    this.isDefault = false,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'avatar': avatar,
      'isDefault': isDefault,
      'createdAt': createdAt == null ? FieldValue.serverTimestamp() : createdAt,
    };
  }

  factory Profile.fromMap(Map<String, dynamic> map, {String? id}) {
    final ts = map['createdAt'];
    DateTime? created;
    if (ts is Timestamp) created = ts.toDate();

    return Profile(
      id: id,
      name: (map['name'] ?? '').toString(),
      avatar: map['avatar']?.toString(),
      isDefault: map['isDefault'] == true,
      createdAt: created,
    );
  }

  Profile copyWith({
    String? id,
    String? name,
    String? avatar,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return Profile(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Profile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Profile.fromMap(data, id: doc.id);
  }
}
