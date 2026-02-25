import '../../auth/domain/models/auth_user_model.dart';

class HomeUserModel {
  const HomeUserModel({
    required this.id,
    this.email,
  });

  final String id;
  final String? email;

  factory HomeUserModel.fromAuthUser(AuthUserModel user) {
    return HomeUserModel(
      id: user.id,
      email: user.email,
    );
  }
}
