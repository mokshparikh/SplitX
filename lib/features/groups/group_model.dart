import '../expenses/expense_model.dart';

class Group {
  final String id;
  final String name;
  final List<String> members;
  final List<Expense> expenses;

  Group({
    required this.id,
    required this.name,
    required this.members,
    required this.expenses,
  });
}
