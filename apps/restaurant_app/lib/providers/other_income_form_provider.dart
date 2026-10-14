import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/finance_attachment.dart';
import '../models/order.dart';
import '../models/other_income.dart';
import '../constants/app_strings.dart';
import 'other_incomes_provider.dart';

@immutable
class OtherIncomeFormState {
  const OtherIncomeFormState({required this.isEdit, required this.date, required this.categoryId, required this.description, required this.amount, required this.paymentType, this.source = '', this.note = '', this.receipt});
  factory OtherIncomeFormState.blank() => OtherIncomeFormState(isEdit: false, date: DateTime.now(), categoryId: '', description: '', amount: '', paymentType: PaymentType.cash);
  factory OtherIncomeFormState.from(OtherIncome i) => OtherIncomeFormState(isEdit: true, date: i.date, categoryId: i.categoryId, description: i.description, amount: i.amount.toStringAsFixed(2), paymentType: i.paymentType, source: i.source, note: i.note, receipt: i.receipt);
  final bool isEdit;
  final DateTime date;
  final String categoryId;
  final String description;
  final String amount;
  final PaymentType paymentType;
  final String source;
  final String note;
  final FinanceAttachment? receipt;
  Uint8List? get receiptBytes => receipt?.bytes;
  static String? validateDescription(String? v) =>
      (v ?? '').trim().isEmpty ? AppStrings.describeIncome : null;
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
  OtherIncomeFormState copyWith({String? categoryId, String? description, String? amount, PaymentType? paymentType, String? source, String? note, FinanceAttachment? receipt, bool clearReceipt = false}) {
    return OtherIncomeFormState(isEdit: isEdit, date: date, categoryId: categoryId ?? this.categoryId, description: description ?? this.description, amount: amount ?? this.amount, paymentType: paymentType ?? this.paymentType, source: source ?? this.source, note: note ?? this.note, receipt: clearReceipt ? null : (receipt ?? this.receipt));
  }
  OtherIncomeFormState copyWithDate(DateTime d) => OtherIncomeFormState(isEdit: isEdit, date: d, categoryId: categoryId, description: description, amount: amount, paymentType: paymentType, source: source, note: note, receipt: receipt);
}

class OtherIncomeFormNotifier extends AutoDisposeFamilyNotifier<OtherIncomeFormState, String?> {
  @override
  OtherIncomeFormState build(String? id) {
    if (id == null) return OtherIncomeFormState.blank();
    for (final i in ref.read(otherIncomesListProvider)) { if (i.id == id) return OtherIncomeFormState.from(i); }
    return OtherIncomeFormState.blank();
  }
  void setDate(DateTime v) => state = state.copyWithDate(v);
  void setCategory(String v) => state = state.copyWith(categoryId: v);
  void setDescription(String v) => state = state.copyWith(description: v);
  void setAmount(String v) => state = state.copyWith(amount: v);
  void setPaymentType(PaymentType v) => state = state.copyWith(paymentType: v);
  void setSource(String v) => state = state.copyWith(source: v);
  void setNote(String v) => state = state.copyWith(note: v);
  void setReceipt(String n, Uint8List b) => state = state.copyWith(receipt: FinanceAttachment(name: n, bytes: b));
  void clearReceipt() => state = state.copyWith(clearReceipt: true);

  Future<OtherIncome> save() async {
    final notifier = ref.read(otherIncomesProvider.notifier);
    OtherIncome? existing;
    if (arg != null) { for (final i in ref.read(otherIncomesListProvider)) { if (i.id == arg) existing = i; } }
    final amount = double.tryParse(state.amount.trim()) ?? 0;

    if (existing != null) {
      return notifier.edit(
        existing,
        date: state.date,
        categoryId: state.categoryId,
        description: state.description.trim(),
        amount: amount,
        paymentType: state.paymentType,
        source: state.source.trim(),
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
      source: state.source.trim(),
      note: state.note.trim(),
      receipt: state.receipt,
    );
  }
}

final otherIncomeFormProvider = NotifierProvider.autoDispose.family<OtherIncomeFormNotifier, OtherIncomeFormState, String?>(OtherIncomeFormNotifier.new);
