import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/errors/api_error.dart';
import '../../pos/presentation/pos_controller.dart';
import '../data/items_repository.dart';
import '../domain/item_models.dart';

class ItemsState {
  const ItemsState({
    this.loading = false,
    this.saving = false,
    this.products = const [],
    this.stocks = const [],
    this.search = '',
    this.lowStockOnly = false,
    this.errorMessage,
    this.successMessage,
  });

  final bool loading;
  final bool saving;
  final List<ProductSummary> products;
  final List<StockBalance> stocks;
  final String search;
  final bool lowStockOnly;
  final String? errorMessage;
  final String? successMessage;

  ItemsState copyWith({
    bool? loading,
    bool? saving,
    List<ProductSummary>? products,
    List<StockBalance>? stocks,
    String? search,
    bool? lowStockOnly,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return ItemsState(
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
      products: products ?? this.products,
      stocks: stocks ?? this.stocks,
      search: search ?? this.search,
      lowStockOnly: lowStockOnly ?? this.lowStockOnly,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      successMessage:
          clearSuccess ? null : successMessage ?? this.successMessage,
    );
  }
}

class ItemsController extends StateNotifier<ItemsState> {
  ItemsController(this.repository, this.ref) : super(const ItemsState()) {
    load();
  }

  final ItemsRepository repository;
  final Ref ref;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true, clearSuccess: true);
    try {
      final store = ref.read(posControllerProvider).selectedStore;
      final products = await repository.loadProducts(storeId: store?.id);
      final stocks = await repository.loadStocks(
        storeId: store?.id,
        search: state.search,
        lowStock: state.lowStockOnly,
      );
      state = state.copyWith(
        loading: false,
        products: products,
        stocks: stocks,
      );
    } on ApiError catch (error) {
      state = state.copyWith(loading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'Unable to load items.',
      );
    }
  }

  Future<void> setSearch(String value) async {
    state = state.copyWith(search: value);
    await load();
  }

  Future<void> toggleLowStock(bool value) async {
    state = state.copyWith(lowStockOnly: value);
    await load();
  }

  Future<bool> addStock({
    required ProductSummary product,
    required String direction,
    required double quantity,
    required double unitCost,
    required String referenceNumber,
    required String remarks,
  }) async {
    final store = ref.read(posControllerProvider).selectedStore;
    if (store == null) {
      state =
          state.copyWith(errorMessage: 'Select a store before adding stock.');
      return false;
    }
    state = state.copyWith(saving: true, clearError: true, clearSuccess: true);
    try {
      final message = await repository.adjustStock(
        store: store,
        product: product,
        direction: direction,
        quantity: quantity,
        unitCost: unitCost,
        referenceNumber: referenceNumber,
        remarks: remarks,
      );
      state = state.copyWith(saving: false, successMessage: message);
      await load();
      return true;
    } on ApiError catch (error) {
      state = state.copyWith(saving: false, errorMessage: error.message);
      return false;
    }
  }
}

final itemsRepositoryProvider = Provider<ItemsRepository>((ref) {
  return ItemsRepository(ref.watch(apiClientProvider));
});

final itemsControllerProvider =
    StateNotifierProvider<ItemsController, ItemsState>((ref) {
  return ItemsController(ref.watch(itemsRepositoryProvider), ref);
});
