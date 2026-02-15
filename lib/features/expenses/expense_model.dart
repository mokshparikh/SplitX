import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final String title;
  final double amount;
  final String paidBy;
  final Map<String, double> split;
  final String? category;
  final String? note;
  final bool? isRecurring;
  final String? recurringFrequency;
  final bool? isSettled; // ← New field
  final DateTime?
      settledAt; // ← New field (optional: settlement date track karne ke liye)

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.paidBy,
    required this.split,
    this.category,
    this.note,
    this.isRecurring,
    this.recurringFrequency,
    this.isSettled, // ← New field
    this.settledAt, // ← New field
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'paidBy': paidBy,
      'split': split,
      'category': category,
      'note': note,
      'isRecurring': isRecurring,
      'recurringFrequency': recurringFrequency,
      'isSettled': isSettled, // ← New field
      'settledAt': settledAt, // ← New field
    };
  }

  factory Expense.fromMap(String id, Map<String, dynamic> map) {
    return Expense(
      id: id,
      title: map['title'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      paidBy: map['paidBy'] ?? '',
      split: Map<String, double>.from(
        (map['split'] as Map).map(
          (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
        ),
      ),
      category: map['category'],
      note: map['note'],
      isRecurring: map['isRecurring'],
      recurringFrequency: map['recurringFrequency'],
      isSettled: map['isSettled'] ?? false, // ← New field (default: false)
      settledAt: map['settledAt'] != null
          ? (map['settledAt'] as Timestamp).toDate() // ← New field
          : null,
    );
  }

  // ← New method: Expense को settled mark karne ke liye
  Expense copyWith({
    String? id,
    String? title,
    double? amount,
    String? paidBy,
    Map<String, double>? split,
    String? category,
    String? note,
    bool? isRecurring,
    String? recurringFrequency,
    bool? isSettled,
    DateTime? settledAt,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      paidBy: paidBy ?? this.paidBy,
      split: split ?? this.split,
      category: category ?? this.category,
      note: note ?? this.note,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringFrequency: recurringFrequency ?? this.recurringFrequency,
      isSettled: isSettled ?? this.isSettled,
      settledAt: settledAt ?? this.settledAt,
    );
  }
}
