class UserModel {
  final int    id;
  final String token;

  const UserModel({required this.id, required this.token});

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id:    json['user_id'] ?? 0,
    token: json['access_token'],
  );
}