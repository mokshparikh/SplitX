import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../groups/group_model.dart';
import 'expense_model.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExpenseScreen extends StatefulWidget {
  final Group group;

  const ExpenseScreen({super.key, required this.group});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  String selectedCategory = 'All';
  String searchQuery = '';
  DateTimeRange? dateFilter;
  String sortBy = 'date'; // date, amount, category

  // Available expense categories
  final List<String> categories = [
    'All',
    'Food',
    'Transport',
    'Entertainment',
    'Utilities',
    'Rent',
    'Shopping',
    'Health',
    'Education',
    'Travel',
    'Bills',
    'Other'
  ];

  // Category icons
  final Map<String, IconData> categoryIcons = {
    'Food': Icons.restaurant_rounded,
    'Transport': Icons.directions_car_rounded,
    'Entertainment': Icons.movie_rounded,
    'Utilities': Icons.electric_bolt_rounded,
    'Rent': Icons.home_rounded,
    'Shopping': Icons.shopping_bag_rounded,
    'Health': Icons.medical_services_rounded,
    'Education': Icons.school_rounded,
    'Travel': Icons.flight_rounded,
    'Bills': Icons.receipt_long_rounded,
    'Other': Icons.more_horiz_rounded,
  };

  // ============= ROYAL BLUE THEME COLORS =============
  static const Color primaryColor = Color(0xFF1E3A8A);
  static const Color secondaryColor = Color(0xFF3B82F6);
  static const Color accentColor = Color(0xFF60A5FA);
  static const Color backgroundGradientStart = Color(0xFFF8FAFC);
  static const Color backgroundGradientEnd = Color(0xFFE2E8F0);
  static const Color successColor = Color(0xFF10B981);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color warningColor = Color(0xFFF59E0B);

  // ================= GET USER EMAIL FROM UID =================
  Future<String> getUserEmail(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        return userDoc.data()!['email'] ?? userId;
      }
    } catch (e) {
      debugPrint('Error fetching user email: $e');
    }
    return userId;
  }

  // ================= CALCULATE SETTLEMENTS =================
  Future<Map<String, Map<String, double>>> calculateSettlements(
      List<Expense> expenses) async {
    Map<String, double> balances = {};

    for (var expense in expenses) {
      balances[expense.paidBy] =
          (balances[expense.paidBy] ?? 0) + expense.amount;

      expense.split.forEach((userId, amount) {
        balances[userId] = (balances[userId] ?? 0) - amount;
      });
    }

    Map<String, Map<String, double>> settlements = {};

    List<MapEntry<String, double>> creditors = [];
    List<MapEntry<String, double>> debtors = [];

    balances.forEach((userId, balance) {
      if (balance > 0.01) {
        creditors.add(MapEntry(userId, balance));
      } else if (balance < -0.01) {
        debtors.add(MapEntry(userId, -balance));
      }
    });

    creditors.sort((a, b) => b.value.compareTo(a.value));
    debtors.sort((a, b) => b.value.compareTo(a.value));

    int i = 0, j = 0;
    while (i < creditors.length && j < debtors.length) {
      final creditor = creditors[i];
      final debtor = debtors[j];

      final amount =
          creditor.value < debtor.value ? creditor.value : debtor.value;

      settlements.putIfAbsent(debtor.key, () => {});
      settlements[debtor.key]![creditor.key] = amount;

      creditors[i] = MapEntry(creditor.key, creditor.value - amount);
      debtors[j] = MapEntry(debtor.key, debtor.value - amount);

      if (creditors[i].value < 0.01) i++;
      if (debtors[j].value < 0.01) j++;
    }

    return settlements;
  }

// ================= GET CURRENT USER BALANCE =================
  Future<Map<String, dynamic>> getCurrentUserBalance(
      List<Expense> expenses) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return {'owes': 0.0, 'owed': 0.0};

    double youOwe = 0.0;
    double youAreOwed = 0.0;

    // ✅ PEHLE SETTLED EXPENSES FILTER KARO
    final unsettledExpenses =
        expenses.where((e) => !(e.isSettled ?? false)).toList();

    for (var expense in unsettledExpenses) {
      // ✅ YEH CHANGE
      // If current user paid
      if (expense.paidBy == currentUserId) {
        // Calculate total owed to current user
        expense.split.forEach((userId, amount) {
          if (userId != currentUserId) {
            youAreOwed += amount;
          }
        });
      } else {
        // If current user owes
        final userShare = expense.split[currentUserId] ?? 0.0;
        youOwe += userShare;
      }
    }

    return {
      'owes': youOwe,
      'owed': youAreOwed,
      'net': youAreOwed - youOwe,
    };
  }

// ================= SHOW SETTLEMENTS DIALOG =================
  void showSettlementsDialog(
      BuildContext context, List<Expense> expenses) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );

    // Only unsettled expenses ke liye settlement calculate karein
    final unsettledExpenses =
        expenses.where((e) => !(e.isSettled ?? false)).toList();

    final settlements = await calculateSettlements(unsettledExpenses);

    // Track करें ki kon si expenses kis settlement में involved hain
    Map<String, Map<String, List<String>>> settlementExpenses = {};

    for (var expense in unsettledExpenses) {
      final paidBy = expense.paidBy;
      expense.split.forEach((userId, amount) {
        if (userId != paidBy && amount > 0.01) {
          settlementExpenses.putIfAbsent(userId, () => {});
          settlementExpenses[userId]!.putIfAbsent(paidBy, () => []);
          settlementExpenses[userId]![paidBy]!.add(expense.id);
        }
      });
    }

    Map<String, String> memberEmails = {};
    for (var memberId in widget.group.members) {
      memberEmails[memberId] = await getUserEmail(memberId);
    }

    if (!mounted) return;
    Navigator.pop(context);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 700),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [backgroundGradientStart, backgroundGradientEnd],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primaryColor, secondaryColor],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Settlement Summary',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Simplify payments',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // Settlements List
              Flexible(
                child: settlements.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: successColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  size: 64,
                                  color: successColor,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'All Settled Up!',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No pending settlements',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: primaryColor.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(20),
                        shrinkWrap: true,
                        children: settlements.entries.expand((entry) {
                          final debtorId = entry.key;
                          final debtorEmail =
                              memberEmails[debtorId] ?? debtorId;

                          return entry.value.entries.map((payment) {
                            final creditorId = payment.key;
                            final creditorEmail =
                                memberEmails[creditorId] ?? creditorId;
                            final amount = payment.value;

                            // Related expense IDs nikaalein
                            final relatedExpenses =
                                settlementExpenses[debtorId]?[creditorId] ?? [];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withOpacity(0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      // Debtor
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              debtorEmail.length > 15
                                                  ? '${debtorEmail.substring(0, 15)}...'
                                                  : debtorEmail,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: primaryColor,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'owes',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: primaryColor
                                                    .withOpacity(0.6),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      // Arrow with amount
                                      Flexible(
                                        flex: 1,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                primaryColor,
                                                secondaryColor
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.arrow_forward_rounded,
                                                color: Colors.white,
                                                size: 12,
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  '₹${amount.toStringAsFixed(0)}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      // Creditor
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              creditorEmail.length > 15
                                                  ? '${creditorEmail.substring(0, 15)}...'
                                                  : creditorEmail,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: successColor,
                                              ),
                                              textAlign: TextAlign.right,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'receives',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: successColor
                                                    .withOpacity(0.6),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Settle Up Button
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: successColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        // Related expense IDs pass करें
                                        _recordSettlement(debtorId, creditorId,
                                            amount, relatedExpenses);
                                      },
                                      icon: const Icon(
                                          Icons.check_circle_rounded,
                                          size: 14),
                                      label: const Text(
                                        'Mark as Settled',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          });
                        }).toList(),
                      ),
              ),

              // Summary Stats
              if (unsettledExpenses.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: primaryColor.withOpacity(0.1),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        Icons.receipt_long_rounded,
                        'Expenses',
                        unsettledExpenses.length.toString(),
                        primaryColor,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: primaryColor.withOpacity(0.2),
                      ),
                      _buildStatItem(
                        Icons.currency_rupee_rounded,
                        'Total',
                        '₹${unsettledExpenses.fold<double>(0, (sum, e) => sum + e.amount).toStringAsFixed(0)}',
                        successColor,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

// ================= RECORD SETTLEMENT =================
  Future<void> _recordSettlement(String fromId, String toId, double amount,
      List<String> expenseIds) async {
    try {
      // Settlement record
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.group.id)
          .collection('settlements')
          .add({
        'fromUserId': fromId,
        'toUserId': toId,
        'amount': amount,
        'settledAt': FieldValue.serverTimestamp(),
        'note': 'Settlement payment',
        'relatedExpenses': expenseIds, // Related expense IDs
      });

      // Batch update
      final batch = FirebaseFirestore.instance.batch();
      for (var expenseId in expenseIds) {
        final expenseRef = FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.group.id)
            .collection('expenses')
            .doc(expenseId);

        batch.update(expenseRef, {
          'isSettled': true,
          'settledAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      if (!mounted) return;
      _showSnackBar('✅ Settlement recorded successfully!', successColor);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('❌ Failed to record settlement', errorColor);
    }
  }

  // ================= SHOW BALANCE OVERVIEW =================
  void showBalanceOverview(List<Expense> expenses) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );

    final unsettledExpenses =
        expenses.where((e) => !(e.isSettled ?? false)).toList();

    final balance = await getCurrentUserBalance(unsettledExpenses);
    final currentUserEmail =
        await getUserEmail(FirebaseAuth.instance.currentUser?.uid ?? '');

    if (!mounted) return;
    Navigator.pop(context);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [backgroundGradientStart, backgroundGradientEnd],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [primaryColor, secondaryColor]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_balance_rounded,
                        color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Balance',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                          ),
                        ),
                        Text(
                          currentUserEmail,
                          style: TextStyle(
                            fontSize: 12,
                            color: primaryColor.withOpacity(0.6),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Net Balance
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: balance['net'] >= 0
                        ? [
                            successColor.withOpacity(0.1),
                            successColor.withOpacity(0.2)
                          ]
                        : [
                            errorColor.withOpacity(0.1),
                            errorColor.withOpacity(0.2)
                          ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'Net Balance',
                      style: TextStyle(
                        fontSize: 14,
                        color: primaryColor.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      balance['net'] >= 0
                          ? '+₹${balance['net'].toStringAsFixed(2)}'
                          : '-₹${(-balance['net']).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: balance['net'] >= 0 ? successColor : errorColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      balance['net'] >= 0 ? 'You are owed' : 'You owe',
                      style: TextStyle(
                        fontSize: 12,
                        color: primaryColor.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Breakdown
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: successColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.arrow_downward_rounded,
                              color: successColor),
                          const SizedBox(height: 8),
                          Text(
                            '₹${balance['owed'].toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: successColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You are owed',
                            style: TextStyle(
                              fontSize: 11,
                              color: primaryColor.withOpacity(0.6),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.arrow_upward_rounded, color: errorColor),
                          const SizedBox(height: 8),
                          Text(
                            '₹${balance['owes'].toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: errorColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You owe',
                            style: TextStyle(
                              fontSize: 11,
                              color: primaryColor.withOpacity(0.6),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= SHOW PAYMENT HISTORY =================
  void showPaymentHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [primaryColor, secondaryColor],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text(
                    'Payment History',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            // Settlement List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('groups')
                    .doc(widget.group.id)
                    .collection('settlements')
                    .orderBy('settledAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                        child: CircularProgressIndicator(color: primaryColor));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_rounded,
                              size: 64, color: primaryColor.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text(
                            'No payment history yet',
                            style: TextStyle(
                              color: primaryColor.withOpacity(0.6),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final data = snapshot.data!.docs[index].data()
                          as Map<String, dynamic>;
                      final fromId = data['fromUserId'];
                      final toId = data['toUserId'];
                      final amount = (data['amount'] as num).toDouble();
                      final timestamp = data['settledAt'] as Timestamp?;

                      return FutureBuilder<List<String>>(
                        future: Future.wait([
                          getUserEmail(fromId),
                          getUserEmail(toId),
                        ]),
                        builder: (context, emailSnapshot) {
                          final fromEmail = emailSnapshot.data?[0] ?? fromId;
                          final toEmail = emailSnapshot.data?[1] ?? toId;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: successColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: successColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: successColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$fromEmail → $toEmail',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: primaryColor,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        timestamp != null
                                            ? _formatDate(timestamp.toDate())
                                            : 'Recently',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: primaryColor.withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₹${amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: successColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= SHOW ANALYTICS =================
  void showAnalytics(List<Expense> expenses) {
    // Calculate category-wise spending
    Map<String, double> categorySpending = {};
    for (var expense in expenses) {
      final category = expense.category ?? 'Other';
      categorySpending[category] =
          (categorySpending[category] ?? 0) + expense.amount;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [backgroundGradientStart, backgroundGradientEnd],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [primaryColor, secondaryColor]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.pie_chart_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Spending Analytics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Flexible(
                child: categorySpending.isEmpty
                    ? const Center(child: Text('No data to show'))
                    : ListView(
                        shrinkWrap: true,
                        children: categorySpending.entries.map((entry) {
                          final total = expenses.fold<double>(
                              0, (sum, e) => sum + e.amount);
                          final percentage = (entry.value / total * 100);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      categoryIcons[entry.key] ??
                                          Icons.more_horiz_rounded,
                                      color: primaryColor,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        entry.key,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: primaryColor,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '₹${entry.value.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: successColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: percentage / 100,
                                    backgroundColor:
                                        primaryColor.withOpacity(0.1),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        secondaryColor),
                                    minHeight: 6,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${percentage.toStringAsFixed(1)}% of total',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: primaryColor.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= EXPORT TO CSV =================
  void exportToCSV(List<Expense> expenses) async {
    try {
      String csv = 'Date,Title,Category,Amount,Paid By,Note\n';

      for (var expense in expenses) {
        final paidByEmail = await getUserEmail(expense.paidBy);
        csv +=
            '"${_formatDate(DateTime.now())}","${expense.title}","${expense.category ?? 'Other'}","${expense.amount}","$paidByEmail","${expense.note ?? ''}"\n';
      }

      // Get app's documents directory
      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/expenses_${DateTime.now().millisecondsSinceEpoch}.csv';

      // Write CSV to file
      final file = File(path);
      await file.writeAsString(csv);

      // ✅ iOS ke liye sharePositionOrigin add karo
      final box = context.findRenderObject() as RenderBox?;

      await Share.shareXFiles(
        [XFile(path)],
        subject: 'Expense Report - ${widget.group.name}',
        sharePositionOrigin:
            box!.localToGlobal(Offset.zero) & box.size, // ✅ YEH ADD KARO
      );

      _showSnackBar('✅ CSV exported successfully!', successColor);
    } catch (e) {
      _showSnackBar('❌ Export failed: $e', errorColor);
      debugPrint('Export error: $e');
    }
  }

  Widget _buildStatItem(
      IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: primaryColor.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  // ================= ADD EXPENSE =================
  Future<void> addExpense({
    required String title,
    required double amount,
    required String paidBy,
    required Map<String, double> split,
    String? category,
    String? note,
    bool? isRecurring,
    String? recurringFrequency,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.group.id)
          .collection('expenses')
          .add({
        'title': title,
        'amount': amount,
        'paidBy': paidBy,
        'split': split,
        'category': category ?? 'Other',
        'note': note ?? '',
        'isRecurring': isRecurring ?? false,
        'recurringFrequency': recurringFrequency ?? 'none',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showSnackBar('✅ Expense added successfully!', successColor);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('❌ Failed to add expense', errorColor);
    }
  }

  // ================= UPDATE EXPENSE =================
  Future<void> updateExpense({
    required String expenseId,
    required String title,
    required double amount,
    required String paidBy,
    required Map<String, double> split,
    String? category,
    String? note,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.group.id)
          .collection('expenses')
          .doc(expenseId)
          .update({
        'title': title,
        'amount': amount,
        'paidBy': paidBy,
        'split': split,
        'category': category ?? 'Other',
        'note': note ?? '',
      });

      if (!mounted) return;
      _showSnackBar('✅ Expense updated successfully!', successColor);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('❌ Failed to update expense', errorColor);
    }
  }

  // ================= DELETE EXPENSE =================
  Future<void> deleteExpense(String expenseId) async {
    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.group.id)
          .collection('expenses')
          .doc(expenseId)
          .delete();

      if (!mounted) return;
      _showSnackBar('✅ Expense deleted successfully!', successColor);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('❌ Failed to delete expense', errorColor);
    }
  }

  // ================= SHOW DELETE CONFIRMATION =================
  void showDeleteConfirmation(String expenseId, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: errorColor),
            const SizedBox(width: 12),
            const Text('Delete Expense?'),
          ],
        ),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: primaryColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: errorColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              deleteExpense(expenseId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ================= ADD EXPENSE BOTTOM SHEET =================
  void showAddExpenseDialog() {
    final members = widget.group.members;

    if (members.isEmpty) {
      _showSnackBar('Please add members first', errorColor);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExpenseFormBottomSheet(
        members: members,
        categories: categories.where((c) => c != 'All').toList(),
        onSubmit: (title, amount, paidBy, split, category, note, isRecurring,
                frequency) =>
            addExpense(
          title: title,
          amount: amount,
          paidBy: paidBy,
          split: split,
          category: category,
          note: note,
          isRecurring: isRecurring,
          recurringFrequency: frequency,
        ),
      ),
    );
  }

  // ================= EDIT EXPENSE BOTTOM SHEET =================
  void showEditExpenseDialog(Expense expense) {
    final members = widget.group.members;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExpenseFormBottomSheet(
        members: members,
        categories: categories.where((c) => c != 'All').toList(),
        existingExpense: expense,
        onSubmit: (title, amount, paidBy, split, category, note, _, __) =>
            updateExpense(
          expenseId: expense.id,
          title: title,
          amount: amount,
          paidBy: paidBy,
          split: split,
          category: category,
          note: note,
        ),
      ),
    );
  }

  // ================= DATE FORMATTER =================
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';

    // Custom date formatting without intl package
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // ================= SNACKBAR HELPER =================
  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ================= SHOW FILTER OPTIONS =================
  void showFilterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter by Category',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((category) {
                final isSelected = selectedCategory == category;
                return FilterChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      selectedCategory = category;
                    });
                    Navigator.pop(context);
                  },
                  backgroundColor: Colors.grey.shade100,
                  selectedColor: secondaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ================= SHOW MORE OPTIONS MENU =================
  void showMoreOptions(List<Expense> expenses) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.file_download_rounded, color: primaryColor),
              ),
              title: const Text('Export to CSV'),
              subtitle: const Text('Download expense data'),
              onTap: () {
                Navigator.pop(context);
                exportToCSV(expenses);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.account_balance_rounded, color: successColor),
              ),
              title: const Text('Your Balance'),
              subtitle: const Text('See what you owe/owed'),
              onTap: () {
                Navigator.pop(context);
                // ✅ SETTLED EXPENSES FILTER KARKE PASS KARO
                final unsettledExpenses =
                    expenses.where((e) => !(e.isSettled ?? false)).toList();
                showBalanceOverview(unsettledExpenses);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.pie_chart_rounded, color: warningColor),
              ),
              title: const Text('Analytics'),
              subtitle: const Text('View spending breakdown'),
              onTap: () {
                Navigator.pop(context);
                showAnalytics(expenses);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGradientStart,
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryColor, secondaryColor],
            ),
          ),
        ),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          widget.group.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          // Filter Button
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: selectedCategory != 'All'
                  ? Colors.white.withOpacity(0.3)
                  : Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.filter_list_rounded, color: Colors.white),
              onPressed: showFilterOptions,
            ),
          ),
          // Payment History Button
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.history_rounded, color: Colors.white),
              onPressed: showPaymentHistory,
            ),
          ),
          // Settlement Button
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('groups')
                  .doc(widget.group.id)
                  .collection('expenses')
                  .snapshots(),
              builder: (context, snapshot) {
                return IconButton(
                  icon: const Icon(Icons.account_balance_wallet_rounded,
                      color: Colors.white),
                  onPressed: () {
                    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                      // ✅ YAHA CHANGE - Settled expenses ko filter out karo
                      final expenses = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return !(data['isSettled'] ?? false); // Only unsettled
                      }).map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return Expense(
                          id: doc.id,
                          title: data['title'],
                          amount: (data['amount'] as num).toDouble(),
                          paidBy: data['paidBy'],
                          split: Map<String, double>.from(
                            (data['split'] as Map).map(
                              (k, v) =>
                                  MapEntry(k.toString(), (v as num).toDouble()),
                            ),
                          ),
                          category: data['category'],
                          note: data['note'],
                          isSettled: data['isSettled'] ?? false, // ✅ ADD
                          settledAt: data['settledAt'] != null // ✅ ADD
                              ? (data['settledAt'] as Timestamp).toDate()
                              : null,
                        );
                      }).toList();

                      // ✅ Check if there are unsettled expenses
                      if (expenses.isEmpty) {
                        _showSnackBar(
                            'All expenses are settled!', successColor);
                      } else {
                        showSettlementsDialog(context, expenses);
                      }
                    } else {
                      _showSnackBar('No expenses to settle', accentColor);
                    }
                  },
                );
              },
            ),
          ),
          // More Options
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('groups')
                  .doc(widget.group.id)
                  .collection('expenses')
                  .snapshots(),
              builder: (context, snapshot) {
                return IconButton(
                  icon:
                      const Icon(Icons.more_vert_rounded, color: Colors.white),
                  onPressed: () {
                    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                      // ✅ SETTLED EXPENSES FILTER KARO
                      final expenses = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return !(data['isSettled'] ?? false); // Only unsettled
                      }).map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return Expense(
                          id: doc.id,
                          title: data['title'],
                          amount: (data['amount'] as num).toDouble(),
                          paidBy: data['paidBy'],
                          split: Map<String, double>.from(
                            (data['split'] as Map).map(
                              (k, v) =>
                                  MapEntry(k.toString(), (v as num).toDouble()),
                            ),
                          ),
                          category: data['category'],
                          note: data['note'],
                          isSettled:
                              data['isSettled'] ?? false, // ✅ YEH ADD KARO
                          settledAt: data['settledAt'] != null
                              ? (data['settledAt'] as Timestamp).toDate()
                              : null,
                        );
                      }).toList();

                      showMoreOptions(expenses);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [backgroundGradientStart, backgroundGradientEnd],
          ),
        ),
        child: Column(
          children: [
            // Category Filter Indicator
            if (selectedCategory != 'All')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: secondaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: secondaryColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      categoryIcons[selectedCategory] ??
                          Icons.filter_list_rounded,
                      color: secondaryColor,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Filtering: $selectedCategory',
                      style: TextStyle(
                        color: secondaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => selectedCategory = 'All'),
                      child: Icon(Icons.close_rounded,
                          color: secondaryColor, size: 18),
                    ),
                  ],
                ),
              ),

            // Expense List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('groups')
                    .doc(widget.group.id)
                    .collection('expenses')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded,
                              size: 64, color: errorColor),
                          const SizedBox(height: 16),
                          Text(
                            'Something went wrong',
                            style: TextStyle(
                              fontSize: 18,
                              color: errorColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    );
                  }

                  var docs = snapshot.data!.docs;

// ✅ YEH 5 LINES ADD KARO - Filter out settled expenses
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return !(data['isSettled'] ?? false);
                  }).toList();

// Filter by category
                  if (selectedCategory != 'All') {
                    docs = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return (data['category'] ?? 'Other') == selectedCategory;
                    }).toList();
                  }

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.receipt_long_rounded,
                              size: 64,
                              color: primaryColor.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            selectedCategory != 'All'
                                ? 'No expenses in $selectedCategory'
                                : 'No expenses yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: primaryColor.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add your first expense to get started',
                            style: TextStyle(
                              fontSize: 14,
                              color: primaryColor.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final expense = Expense(
                        id: docs[index].id,
                        title: data['title'],
                        amount: (data['amount'] as num).toDouble(),
                        paidBy: data['paidBy'],
                        split: Map<String, double>.from(
                          (data['split'] as Map).map(
                            (k, v) =>
                                MapEntry(k.toString(), (v as num).toDouble()),
                          ),
                        ),
                        category: data['category'],
                        note: data['note'],
                        isRecurring: data['isRecurring'] ?? false,
                        recurringFrequency: data['recurringFrequency'],
                        isSettled: data['isSettled'] ?? false, // ✅ YEH ADD KARO
                        settledAt:
                            data['settledAt'] != null // ✅ YEH 3 LINES ADD KARO
                                ? (data['settledAt'] as Timestamp).toDate()
                                : null,
                      );

                      return _ExpenseCard(
                        expense: expense,
                        categoryIcon:
                            categoryIcons[expense.category ?? 'Other'] ??
                                Icons.more_horiz_rounded,
                        onEdit: () => showEditExpenseDialog(expense),
                        onDelete: () =>
                            showDeleteConfirmation(expense.id, expense.title),
                        getUserEmail: getUserEmail,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primaryColor, secondaryColor],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: showAddExpenseDialog,
          child: const Icon(Icons.add_rounded, size: 28, color: Colors.white),
        ),
      ),
    );
  }
}

// ================= EXPENSE CARD WIDGET =================
class _ExpenseCard extends StatelessWidget {
  final Expense expense;
  final IconData categoryIcon;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<String> Function(String) getUserEmail;

  const _ExpenseCard({
    required this.expense,
    required this.categoryIcon,
    required this.onEdit,
    required this.onDelete,
    required this.getUserEmail,
  });

  static const Color primaryColor = Color(0xFF1E3A8A);
  static const Color secondaryColor = Color(0xFF3B82F6);
  static const Color accentColor = Color(0xFF60A5FA);
  static const Color backgroundGradientStart = Color(0xFFF8FAFC);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color warningColor = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.white],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [primaryColor, secondaryColor],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      categoryIcon,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                expense.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                            if (expense.isRecurring ?? false)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: warningColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.refresh_rounded,
                                        size: 12, color: warningColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Recurring',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: warningColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                expense.category ?? 'Other',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: secondaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        FutureBuilder<String>(
                          future: getUserEmail(expense.paidBy),
                          builder: (context, snapshot) {
                            final displayEmail =
                                snapshot.data ?? expense.paidBy;
                            return Row(
                              children: [
                                Icon(
                                  Icons.person_rounded,
                                  size: 14,
                                  color: secondaryColor.withOpacity(0.7),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Paid by $displayEmail',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: secondaryColor.withOpacity(0.8),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '₹${expense.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: onEdit,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: secondaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.edit_rounded,
                                  size: 16,
                                  color: secondaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: onDelete,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: errorColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.delete_rounded,
                                  size: 16,
                                  color: errorColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Note (if exists)
              if (expense.note != null && expense.note!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: backgroundGradientStart,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.note_rounded,
                          size: 16, color: primaryColor.withOpacity(0.7)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          expense.note!,
                          style: TextStyle(
                            fontSize: 13,
                            color: primaryColor.withOpacity(0.8),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Split Details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: backgroundGradientStart,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.pie_chart_rounded,
                          size: 16,
                          color: primaryColor.withOpacity(0.7),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Split Details',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primaryColor.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...expense.split.entries.map(
                      (entry) => FutureBuilder<String>(
                        future: getUserEmail(entry.key),
                        builder: (context, snapshot) {
                          final displayEmail = snapshot.data ?? entry.key;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    displayEmail,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: primaryColor.withOpacity(0.7),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '₹${entry.value.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= EXPENSE FORM BOTTOM SHEET (Add/Edit) =================
class _ExpenseFormBottomSheet extends StatefulWidget {
  final List<String> members;
  final List<String> categories;
  final Function(String, double, String, Map<String, double>, String?, String?,
      bool?, String?) onSubmit;
  final Expense? existingExpense;

  const _ExpenseFormBottomSheet({
    required this.members,
    required this.categories,
    required this.onSubmit,
    this.existingExpense,
  });

  @override
  State<_ExpenseFormBottomSheet> createState() =>
      _ExpenseFormBottomSheetState();
}

class _ExpenseFormBottomSheetState extends State<_ExpenseFormBottomSheet> {
  static const Color primaryColor = Color(0xFF1E3A8A);
  static const Color secondaryColor = Color(0xFF3B82F6);
  static const Color accentColor = Color(0xFF60A5FA);
  static const Color backgroundGradientStart = Color(0xFFF8FAFC);
  static const Color errorColor = Color(0xFFEF4444);

  final titleController = TextEditingController();
  final amountController = TextEditingController();
  final noteController = TextEditingController();
  late String paidBy;
  late String selectedCategory;
  late Map<String, TextEditingController> splitControllers;
  bool isEqualSplit = true;
  bool isRecurring = false;
  String recurringFrequency = 'monthly';

  Map<String, String> memberEmails = {};
  bool loadingEmails = true;

  @override
  void initState() {
    super.initState();
    _loadMemberEmails();

    selectedCategory = widget.categories.first;

    if (widget.existingExpense != null) {
      titleController.text = widget.existingExpense!.title;
      amountController.text = widget.existingExpense!.amount.toString();
      paidBy = widget.existingExpense!.paidBy;
      selectedCategory =
          widget.existingExpense!.category ?? widget.categories.first;
      noteController.text = widget.existingExpense!.note ?? '';

      final values = widget.existingExpense!.split.values.toList();
      isEqualSplit = values.every((v) => (v - values.first).abs() < 0.01);

      splitControllers = {
        for (var m in widget.members)
          m: TextEditingController(
            text:
                widget.existingExpense!.split[m]?.toStringAsFixed(2) ?? '0.00',
          ),
      };
    } else {
      paidBy = widget.members.first;
      splitControllers = {
        for (var m in widget.members) m: TextEditingController(),
      };
    }
  }

  Future<void> _loadMemberEmails() async {
    final emails = <String, String>{};
    for (final memberId in widget.members) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(memberId)
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          emails[memberId] = userDoc.data()!['email'] ?? memberId;
        } else {
          emails[memberId] = memberId;
        }
      } catch (e) {
        emails[memberId] = memberId;
      }
    }
    if (mounted) {
      setState(() {
        memberEmails = emails;
        loadingEmails = false;
      });
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    noteController.dispose();
    for (var controller in splitControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _splitEvenly() {
    final total = double.tryParse(amountController.text) ?? 0;
    if (total > 0) {
      final splitAmount = total / widget.members.length;
      for (var controller in splitControllers.values) {
        controller.text = splitAmount.toStringAsFixed(2);
      }
    }
  }

  void _handleSplitToggle(bool isEqual) {
    setState(() {
      isEqualSplit = isEqual;
      if (isEqual) {
        _splitEvenly();
      }
    });
  }

  void _submitExpense() async {
    final title = titleController.text.trim();
    final total = double.tryParse(amountController.text) ?? 0;
    final note = noteController.text.trim();

    if (title.isEmpty || total <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Enter valid title & amount'),
          backgroundColor: errorColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    final Map<String, double> split = {};
    double sum = 0;

    for (var m in widget.members) {
      final value = double.tryParse(splitControllers[m]!.text) ?? 0;
      split[m] = value;
      sum += value;
    }

    if ((sum - total).abs() > 0.01) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Split total must equal amount'),
          backgroundColor: errorColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    await widget.onSubmit(
      title,
      total,
      paidBy,
      split,
      selectedCategory,
      note.isEmpty ? null : note,
      isRecurring,
      isRecurring ? recurringFrequency : null,
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingExpense != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              isEditing ? 'Edit Expense' : 'Add New Expense',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 24),

            // Expense Title
            Container(
              decoration: BoxDecoration(
                color: backgroundGradientStart,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentColor.withOpacity(0.3)),
              ),
              child: TextField(
                controller: titleController,
                style: const TextStyle(color: primaryColor),
                decoration: InputDecoration(
                  hintText: 'What was this expense for?',
                  hintStyle: TextStyle(color: primaryColor.withOpacity(0.5)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(20),
                  prefixIcon: Icon(
                    Icons.receipt_rounded,
                    color: primaryColor.withOpacity(0.7),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category Dropdown
            Container(
              decoration: BoxDecoration(
                color: backgroundGradientStart,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentColor.withOpacity(0.3)),
              ),
              child: DropdownButtonFormField<String>(
                value: selectedCategory,
                style: const TextStyle(color: primaryColor),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(20),
                  prefixIcon: Icon(
                    Icons.category_rounded,
                    color: primaryColor.withOpacity(0.7),
                  ),
                ),
                items: widget.categories
                    .map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => selectedCategory = v!),
              ),
            ),
            const SizedBox(height: 16),

            // Amount
            Container(
              decoration: BoxDecoration(
                color: backgroundGradientStart,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentColor.withOpacity(0.3)),
              ),
              child: TextField(
                controller: amountController,
                style: const TextStyle(color: primaryColor),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  if (isEqualSplit) {
                    _splitEvenly();
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Amount',
                  hintStyle: TextStyle(color: primaryColor.withOpacity(0.5)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(20),
                  prefixIcon: Icon(
                    Icons.currency_rupee_rounded,
                    color: primaryColor.withOpacity(0.7),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Note (Optional)
            Container(
              decoration: BoxDecoration(
                color: backgroundGradientStart,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentColor.withOpacity(0.3)),
              ),
              child: TextField(
                controller: noteController,
                style: const TextStyle(color: primaryColor),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Add a note (optional)',
                  hintStyle: TextStyle(color: primaryColor.withOpacity(0.5)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(20),
                  prefixIcon: Icon(
                    Icons.note_rounded,
                    color: primaryColor.withOpacity(0.7),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Recurring Expense Toggle
            if (!isEditing)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: backgroundGradientStart,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accentColor.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.refresh_rounded,
                            color: primaryColor.withOpacity(0.7)),
                        const SizedBox(width: 12),
                        const Text(
                          'Recurring Expense',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: isRecurring,
                          onChanged: (value) =>
                              setState(() => isRecurring = value),
                          activeColor: secondaryColor,
                        ),
                      ],
                    ),
                    if (isRecurring) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: recurringFrequency,
                        decoration: const InputDecoration(
                          labelText: 'Frequency',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'daily', child: Text('Daily')),
                          DropdownMenuItem(
                              value: 'weekly', child: Text('Weekly')),
                          DropdownMenuItem(
                              value: 'monthly', child: Text('Monthly')),
                        ],
                        onChanged: (value) =>
                            setState(() => recurringFrequency = value!),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Paid By Dropdown
            Container(
              decoration: BoxDecoration(
                color: backgroundGradientStart,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentColor.withOpacity(0.3)),
              ),
              child: DropdownButtonFormField<String>(
                value: paidBy,
                style: const TextStyle(color: primaryColor),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(20),
                  prefixIcon: Icon(
                    Icons.person_rounded,
                    color: primaryColor.withOpacity(0.7),
                  ),
                ),
                items: widget.members
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(memberEmails[m] ?? m),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => paidBy = v!),
              ),
            ),
            const SizedBox(height: 24),

            // Equal/Unequal Split Toggle
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: backgroundGradientStart,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _handleSplitToggle(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: isEqualSplit
                              ? const LinearGradient(
                                  colors: [primaryColor, secondaryColor],
                                )
                              : null,
                          color: isEqualSplit ? null : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.balance_rounded,
                              size: 18,
                              color: isEqualSplit
                                  ? Colors.white
                                  : primaryColor.withOpacity(0.6),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Equal Split',
                              style: TextStyle(
                                color: isEqualSplit
                                    ? Colors.white
                                    : primaryColor.withOpacity(0.6),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _handleSplitToggle(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: !isEqualSplit
                              ? const LinearGradient(
                                  colors: [primaryColor, secondaryColor],
                                )
                              : null,
                          color: !isEqualSplit ? null : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              size: 18,
                              color: !isEqualSplit
                                  ? Colors.white
                                  : primaryColor.withOpacity(0.6),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Custom Split',
                              style: TextStyle(
                                color: !isEqualSplit
                                    ? Colors.white
                                    : primaryColor.withOpacity(0.6),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Split Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: backgroundGradientStart,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.groups_rounded,
                        color: primaryColor.withOpacity(0.7),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Split Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...widget.members.map((member) {
                    final displayEmail = memberEmails[member] ?? member;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: accentColor.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: splitControllers[member],
                                style: const TextStyle(color: primaryColor),
                                keyboardType: TextInputType.number,
                                enabled: !isEqualSplit,
                                decoration: InputDecoration(
                                  labelText: '$displayEmail owes',
                                  labelStyle: TextStyle(
                                    color: primaryColor.withOpacity(0.7),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(16),
                                  prefixIcon: Icon(
                                    Icons.currency_rupee_rounded,
                                    color: primaryColor.withOpacity(0.5),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [primaryColor, secondaryColor],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _submitExpense,
                      child: Text(
                        isEditing ? 'Update Expense' : 'Add Expense',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
