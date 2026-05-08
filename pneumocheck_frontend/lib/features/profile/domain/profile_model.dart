class ProfileModel {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String speciality;
  final String avatarB64;
  final String createdAt;

  const ProfileModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.speciality,
    required this.avatarB64,
    required this.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) => ProfileModel(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        phone: json['phone'] ?? '',
        speciality: json['speciality'] ?? '',
        avatarB64: json['avatar_b64'] ?? '',
        createdAt: json['created_at']?.toString() ?? '',
      );
}
