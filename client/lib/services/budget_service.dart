import 'package:sambo/models/budget.dart';
import 'package:sambo/services/api_client.dart';

/// All budget endpoints live under `/api/budget` — household scope is taken
/// from the JWT principal server-side, never sent in the URL.
class BudgetService {
  BudgetService._();
  static final BudgetService instance = BudgetService._();

  /* ---- monthly overview ---------------------------------------------- */

  Future<MonthlyOverview> getOverview(String yearMonth) async {
    final json = await ApiClient.instance.getJson('/api/budget/$yearMonth');
    return MonthlyOverview.fromJson(json);
  }

  /* ---- categories ---------------------------------------------------- */

  Future<List<BudgetCategory>> listCategories() async {
    final res = await ApiClient.instance.getJsonList('/api/budget/categories');
    return res
        .map((e) => BudgetCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BudgetCategory> createCategory(String name) async {
    final json = await ApiClient.instance.postJson(
      '/api/budget/categories',
      body: {'name': name},
    );
    return BudgetCategory.fromJson(json);
  }

  Future<void> deleteCategory(String id) async {
    await ApiClient.instance.deleteJson('/api/budget/categories/$id');
  }

  /* ---- allocations --------------------------------------------------- */

  /// Sets the budget for [categoryId] in [yearMonth] to [amount] (kr).
  /// Idempotent: call again to update.
  Future<void> setAllocation({
    required String yearMonth,
    required String categoryId,
    required double amount,
  }) async {
    await ApiClient.instance.putJson(
      '/api/budget/$yearMonth/categories/$categoryId',
      body: {'amount': amount},
    );
  }

  /* ---- transactions -------------------------------------------------- */

  Future<List<BudgetTransaction>> listTransactions({
    required String yearMonth,
    String? categoryId,
  }) async {
    final qp = StringBuffer('?yearMonth=$yearMonth');
    if (categoryId != null) qp.write('&categoryId=$categoryId');
    final res = await ApiClient.instance
        .getJsonList('/api/budget/transactions$qp');
    return res
        .map((e) => BudgetTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BudgetTransaction> createTransaction({
    required String categoryId,
    required double amount,
    required String description,
    required DateTime bookedDate,
  }) async {
    final json = await ApiClient.instance.postJson(
      '/api/budget/transactions',
      body: {
        'categoryId': categoryId,
        'amount': amount,
        'description': description,
        'bookedDate':
            '${bookedDate.year.toString().padLeft(4, '0')}-${bookedDate.month.toString().padLeft(2, '0')}-${bookedDate.day.toString().padLeft(2, '0')}',
      },
    );
    return BudgetTransaction.fromJson(json);
  }

  Future<void> deleteTransaction(String id) async {
    await ApiClient.instance.deleteJson('/api/budget/transactions/$id');
  }
}
