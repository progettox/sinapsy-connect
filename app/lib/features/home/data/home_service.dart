import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import 'home_user_model.dart';

final homeServiceProvider = Provider<HomeService>((ref) {
  return HomeService(ref.watch(authRepositoryProvider));
});

class HomeService {
  HomeService(this._authRepository);

  final AuthRepository _authRepository;

  HomeUserModel? get currentUser {
    final user = _authRepository.currentUser;
    if (user == null) return null;
    return HomeUserModel.fromAuthUser(user);
  }

  Future<void> signOut() {
    return _authRepository.signOut();
  }
}
