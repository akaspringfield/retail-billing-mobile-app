import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/errors/api_error.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../printing/data/latest_invoice_store.dart';
import '../data/pos_repository.dart';
import '../domain/pos_models.dart';

class PosState {
  const PosState({
    this.loading = false,
    this.checkingOut = false,
    this.stores = const [],
    this.customers = const [],
    this.paymentMethods = const [],
    this.cart = const [],
    this.selectedStore,
    this.selectedCustomer,
    this.selectedPaymentMethod,
    this.latestCheckout,
    this.errorMessage,
  });

  final bool loading;
  final bool checkingOut;
  final List<StoreInfo> stores;
  final List<CustomerInfo> customers;
  final List<PaymentMethodInfo> paymentMethods;
  final List<CartLine> cart;
  final StoreInfo? selectedStore;
  final CustomerInfo? selectedCustomer;
  final PaymentMethodInfo? selectedPaymentMethod;
  final CheckoutResult? latestCheckout;
  final String? errorMessage;

  double get subtotal => cart.fold(0, (sum, line) => sum + line.subtotal);
  double get discount => cart.fold(0, (sum, line) => sum + line.discountAmount);
  double get tax => cart.fold(0, (sum, line) => sum + line.taxAmount);
  double get grandTotal => cart.fold(0, (sum, line) => sum + line.total);

  PosState copyWith({
    bool? loading,
    bool? checkingOut,
    List<StoreInfo>? stores,
    List<CustomerInfo>? customers,
    List<PaymentMethodInfo>? paymentMethods,
    List<CartLine>? cart,
    StoreInfo? selectedStore,
    CustomerInfo? selectedCustomer,
    PaymentMethodInfo? selectedPaymentMethod,
    CheckoutResult? latestCheckout,
    String? errorMessage,
    bool clearCustomer = false,
    bool clearCheckout = false,
    bool clearError = false,
  }) {
    return PosState(
      loading: loading ?? this.loading,
      checkingOut: checkingOut ?? this.checkingOut,
      stores: stores ?? this.stores,
      customers: customers ?? this.customers,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      cart: cart ?? this.cart,
      selectedStore: selectedStore ?? this.selectedStore,
      selectedCustomer:
          clearCustomer ? null : selectedCustomer ?? this.selectedCustomer,
      selectedPaymentMethod:
          selectedPaymentMethod ?? this.selectedPaymentMethod,
      latestCheckout:
          clearCheckout ? null : latestCheckout ?? this.latestCheckout,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class PosController extends StateNotifier<PosState> {
  PosController(this.repository, this.ref) : super(const PosState()) {
    load();
  }

  final PosRepository repository;
  final Ref ref;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final auth = ref.read(authControllerProvider);
      final stores = await repository.loadStores(
        organizationUuid: auth.user?.organizationUuid,
      );
      final customers = await repository.loadCustomers();
      final paymentMethods = await repository.loadPaymentMethods();
      state = state.copyWith(
        loading: false,
        stores: stores,
        customers: customers,
        paymentMethods: paymentMethods,
        selectedStore: stores.isNotEmpty ? stores.first : null,
        selectedPaymentMethod:
            paymentMethods.isNotEmpty ? paymentMethods.first : null,
      );
    } on ApiError catch (error) {
      state = state.copyWith(loading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'Unable to load POS data.',
      );
    }
  }

  void selectStore(StoreInfo store) {
    state = state.copyWith(selectedStore: store);
  }

  void selectCustomer(CustomerInfo? customer) {
    state = state.copyWith(
      selectedCustomer: customer,
      clearCustomer: customer == null,
    );
  }

  void selectPaymentMethod(PaymentMethodInfo method) {
    state = state.copyWith(selectedPaymentMethod: method);
  }

  Future<void> lookupAndAdd(String query) async {
    final store = state.selectedStore;
    if (store == null) {
      state = state.copyWith(errorMessage: 'Select a store first.');
      return;
    }
    if (query.trim().isEmpty) return;

    state =
        state.copyWith(loading: true, clearError: true, clearCheckout: true);
    try {
      final product = await repository.lookupProduct(
        storeId: store.id,
        query: query.trim(),
      );
      final next = [...state.cart];
      final index = next.indexWhere(
        (line) => line.product.productId == product.productId,
      );
      if (index >= 0) {
        next[index].quantity += 1;
      } else {
        next.add(CartLine(product: product));
      }
      state = state.copyWith(loading: false, cart: next);
    } on ApiError catch (error) {
      state = state.copyWith(loading: false, errorMessage: error.message);
    } catch (_) {
      state =
          state.copyWith(loading: false, errorMessage: 'Product not found.');
    }
  }

  void changeQuantity(CartLine line, double quantity) {
    if (quantity <= 0) {
      removeLine(line);
      return;
    }
    final next = [...state.cart];
    final index = next.indexOf(line);
    if (index >= 0) {
      next[index].quantity = quantity;
      state = state.copyWith(cart: next);
    }
  }

  void removeLine(CartLine line) {
    state =
        state.copyWith(cart: state.cart.where((item) => item != line).toList());
  }

  Future<CheckoutResult?> checkout({required String referenceNumber}) async {
    final store = state.selectedStore;
    final paymentMethod = state.selectedPaymentMethod;
    if (store == null || paymentMethod == null || state.cart.isEmpty) {
      state = state.copyWith(errorMessage: 'Add items and select payment.');
      return null;
    }

    state = state.copyWith(checkingOut: true, clearError: true);
    try {
      final result = await repository.checkout(
        storeId: store.id,
        customer: state.selectedCustomer,
        items: state.cart,
        paymentMethod: paymentMethod,
        paymentAmount: state.grandTotal,
        referenceNumber: referenceNumber,
      );
      await ref.read(latestInvoiceStoreProvider).save(result.invoiceNumber);
      state = state.copyWith(
        checkingOut: false,
        cart: const [],
        latestCheckout: result,
      );
      return result;
    } on ApiError catch (error) {
      state = state.copyWith(checkingOut: false, errorMessage: error.message);
      return null;
    }
  }

  void newSale() {
    state = state
        .copyWith(cart: const [], clearCustomer: true, clearCheckout: true);
  }
}

final posRepositoryProvider = Provider<PosRepository>((ref) {
  return PosRepository(ref.watch(apiClientProvider));
});

final posControllerProvider = StateNotifierProvider<PosController, PosState>(
  (ref) => PosController(ref.watch(posRepositoryProvider), ref),
);
