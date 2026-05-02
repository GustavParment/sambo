import 'package:sambo/core/cache.dart';
import 'package:sambo/models/budget.dart';
import 'package:sambo/services/api_client.dart';
import 'package:sambo/services/auth_service.dart';

/// All budget endpoints live under `/api/budget` — household scope is taken
/// from the JWT principal server-side, never sent in the URL.
class BudgetService {
  BudgetService._();
  static final BudgetService instance = BudgetService._();

  String? _hh() => AuthService.instance.user.value?.householdId;

  /* ---- monthly overview ---------------------------------------------- */

  MonthlyOverview? cachedOverview(String yearMonth) {
    final hh = _hh();
    if (hh == null) return null;
    final raw = Cache.read<Map<String, dynamic>>(
      Cache.householdKey(hh, 'budget:overview:$yearMonth'),
      (j) => j as Map<String, dynamic>,
    );
    if (raw == null) return null;
    return MonthlyOverview.fromJson(raw);
  }

  Future<MonthlyOverview> getOverview(String yearMonth) async {
    final json = await ApiClient.instance.getJson('/api/budget/$yearMonth');
    final hh = _hh();
    if (hh != null) {
      await Cache.write(
        Cache.householdKey(hh, 'budget:overview:$yearMonth'),
        json,
      );
    }
    return MonthlyOverview.fromJson(json);
  }

  /* ---- categories ---------------------------------------------------- */

  List<BudgetCategory>? cachedCategories() {
    final hh = _hh();
    if (hh == null) return null;
    final raw = Cache.read<List<dynamic>>(
      Cache.householdKey(hh, 'budget:categories'),
      (j) => j as List<dynamic>,
    );
    if (raw == null) return null;
    return raw
        .map((e) => BudgetCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<BudgetCategory>> listCategories() async {
    final res = await ApiClient.instance.getJsonList('/api/budget/categories');
    final hh = _hh();
    if (hh != null) {
      await Cache.write(Cache.householdKey(hh, 'budget:categories'), res);
    }
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

  String _txKey(String yearMonth, String? categoryId) =>
      categoryId == null
          ? 'budget:tx:$yearMonth'
          : 'budget:tx:$yearMonth:$categoryId';

  List<BudgetTransaction>? cachedTransactions({
    required String yearMonth,
    String? categoryId,
  }) {
    final hh = _hh();
    if (hh == null) return null;
    final raw = Cache.read<List<dynamic>>(
      Cache.householdKey(hh, _txKey(yearMonth, categoryId)),
      (j) => j as List<dynamic>,
    );
    if (raw == null) return null;
    return raw
        .map((e) => BudgetTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<BudgetTransaction>> listTransactions({
    required String yearMonth,
    String? categoryId,
  }) async {
    final qp = StringBuffer('?yearMonth=$yearMonth');
    if (categoryId != null) qp.write('&categoryId=$categoryId');
    final res =
        await ApiClient.instance.getJsonList('/api/budget/transactions$qp');
    final hh = _hh();
    if (hh != null) {
      await Cache.write(
        Cache.householdKey(hh, _txKey(yearMonth, categoryId)),
        res,
      );
    }
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
