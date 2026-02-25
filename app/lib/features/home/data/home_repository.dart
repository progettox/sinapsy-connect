import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_service.dart';
import 'home_user_model.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(ref.watch(homeServiceProvider));
});

class HomeRepository {
  HomeRepository(this._service);

  final HomeService _service;

  HomeUserModel? get currentUser => _service.currentUser;

  Future<void> signOut() => _service.signOut();
}
