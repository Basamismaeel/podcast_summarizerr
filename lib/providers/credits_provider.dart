import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/credits_service.dart';

final creditsServiceProvider = Provider<CreditsService>((ref) {
  return CreditsService();
});

final creditsBalanceProvider =
    StateNotifierProvider<CreditsNotifier, AsyncValue<int>>((ref) {
  return CreditsNotifier(ref.watch(creditsServiceProvider));
});

class CreditsNotifier extends StateNotifier<AsyncValue<int>> {
  CreditsNotifier(this._service) : super(const AsyncValue.data(3));

  final CreditsService _service;

  Future<void> refresh(String userId) async {
    state = const AsyncValue.loading();
    try {
      final balance = await _service.fetchBalance(userId);
      state = AsyncValue.data(balance);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> deduct(String userId) async {
    final success = await _service.deductCredit(userId);
    if (success) await refresh(userId);
    return success;
  }
}
