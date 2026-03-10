import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/errors/api_error.dart';
import '../../pos/presentation/pos_controller.dart';
import '../data/reports_repository.dart';
import '../domain/report_models.dart';

class ReportsState {
  const ReportsState({
    this.loading = false,
    this.summary,
    this.errorMessage,
  });

  final bool loading;
  final DashboardSummary? summary;
  final String? errorMessage;

  ReportsState copyWith({
    bool? loading,
    DashboardSummary? summary,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ReportsState(
      loading: loading ?? this.loading,
      summary: summary ?? this.summary,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class ReportsController extends StateNotifier<ReportsState> {
  ReportsController(this.repository, this.ref) : super(const ReportsState()) {
    load();
  }

  final ReportsRepository repository;
  final Ref ref;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      final store = ref.read(posControllerProvider).selectedStore;
      final summary = await repository.loadDashboard(
        storeId: store?.id,
        startDate: today,
        endDate: today,
      );
      state = state.copyWith(loading: false, summary: summary);
    } on ApiError catch (error) {
      state = state.copyWith(loading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'Unable to load reports.',
      );
    }
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(apiClientProvider));
});

final reportsControllerProvider =
    StateNotifierProvider<ReportsController, ReportsState>((ref) {
  return ReportsController(ref.watch(reportsRepositoryProvider), ref);
});
