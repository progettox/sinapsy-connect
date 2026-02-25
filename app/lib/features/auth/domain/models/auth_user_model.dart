import 'package:supabase_flutter/supabase_flutter.dart';

class AuthUserModel {
  const AuthUserModel({
    required this.id,
    this.email,
  });

  final String id;
  final String? email;

  factory AuthUserModel.fromSupabase(User user) {
    return AuthUserModel(
      id: user.id,
      email: user.email,
    );
  }
}
