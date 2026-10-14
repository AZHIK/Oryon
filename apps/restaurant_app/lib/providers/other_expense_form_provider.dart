import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/finance_attachment.dart';
import '../models/order.dart';
import '../models/other_expense.dart';
import '../constants/app_strings.dart';
import 'other_expenses_provider.dart';

@immutable
class OtherExpenseFormState {
  const OtherExpenseFormState({required this.isEdit, required this.date, required this.categoryId, required this.description, required this.amount, required this.paymentType, this.payee = '', this.note = '', this.receipt});
  factory OtherExpenseFormState.blank() => OtherExpenseFormState(isEdit: false, date: DateTime.now(), categoryId: '', description: '', amount: '', paymentType: PaymentType.cash);
  factory OtherExpenseFormState.from(OtherExpense e) => OtherExpenseFormState(isEdit: true, date: e.date, categoryId: e.categoryId, description: e.description, amount: e.amount.toStringAsFixed(2), paymentType: e.paymentType, payee: e.payee, note: e.note, receipt: e.receipt);
  final bool isEdit;
  final DateTime date;
  final String categoryId;
  final String description;
  final String amount;
  final PaymentType paymentType;
  final String payee;
  final String note;
  final FinanceAttachment? receipt;
  Uint8List? get receiptBytes => receipt?.bytes;
  static String? validateDescription(String? v) =>
      (v ?? '').trim().isEmpty ? AppStrings.describeExpense : null;
  static String? validateCategory(String? v) =>
      (v ?? '').isEmpty ? AppStrings.pickCategory : null;
  static String? validateAmount(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return AppStrings.enterAmount;
    final p = double.tryParse(t);
    if (p == null) return AppStrings.enterNumberError;
    if (p <= 0) return AppStrings.amountPositiveError;
    return null;
  }
  bool get canSave => validateDescription(description) == null && validateCategory(categoryId) == null && validateAmount(amount) == null;
  OtherExpenseFormState copyWith({String? categoryId, String? description, String? amount, PaymentType? paymentType, String? payee, String? note, FinanceAttachment? receipt, bool clearReceipt = false}) {
    return OtherExpenseFormState(isEdit: isEdit, date: date, categoryId: categoryId ?? this.categoryId, description: description ?? this.description, amount: amount ?? this.amount, paymentType: paymentType ?? this.paymentType, payee: payee ?? this.payee, note: note ?? this.note, receipt: clearReceipt ? null : (receipt ?? this.receipt));
  }
  OtherExpenseFormState copyWithDate(DateTime d) => OtherExpenseFormState(isEdit: isEdit, date: d, categoryId: categoryId, description: description, amount: amount, paymentType: paymentType, payee: payee, note: note, receipt: receipt);
}

class OtherExpenseFormNotifier extends AutoDisposeFamilyNotifier<OtherExpenseFormState, String?> {
  @override
  OtherExpenseFormState build(String? id) {
    if (id == null) return OtherExpenseFormState.blank();
    for (final e in ref.read(otherExpensesListProvider)) { if (e.id == id) return OtherExpenseFormState.from(e); }
    return OtherExpenseFormState.blank();
  }
  void setDate(DateTime v) => state = state.copyWithDate(v);
  void setCategory(String v) => state = state.copyWith(categoryId: v);
  void setDescription(String v) => state = state.copyWith(description: v);
  void setAmount(String v) => state = state.copyWith(amount: v);
  void setPaymentType(PaymentType v) => state = state.copyWith(paymentType: v);
  void setPayee(String v) => state = state.copyWith(payee: v);
  void setNote(String v) => state = state.copyWith(note: v);
  void setReceipt(String n, Uint8List b) => state = state.copyWith(receipt: FinanceAttachment(name: n, bytes: b));
  void clearReceipt() => state = state.copyWith(clearReceipt: true);

  Future<OtherExpense> save() async {
    final notifier = ref.read(otherExpensesProvider.notifier);
    OtherExpense? existing;
    if (arg != null) { for (final e in ref.read(otherExpensesListProvider)) { if (e.id == arg) existing = e; } }
    final amount = double.tryParse(state.amount.trim()) ?? 0;

    if (existing != null) {
      return notifier.edit(
        existing,
        date: state.date,
        categoryId: state.categoryId,
        description: state.description.trim(),
        amount: amount,
        paymentType: state.paymentType,
        payee: state.payee.trim(),
        note: state.note.trim(),
        receipt: state.receipt,
        clearReceipt: state.receipt == null,
      );
    }

    return notifier.create(
      date: state.date,
      categoryId: state.categoryId,
      description: state.description.trim(),
      amount: amount,
      paymentType: state.paymentType,
      payee: state.payee.trim(),
      note: state.note.trim(),
      receipt: state.receipt,
    );
  }
}

final otherExpenseFormProvider = NotifierProvider.autoDispose.family<OtherExpenseFormNotifier, OtherExpenseFormState, String?>(OtherExpenseFormNotifier.new);
