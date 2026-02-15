import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ================= CREATE GROUP =================
  static Future<void> createGroup({
    required String name,
  }) async {
    final uid = _auth.currentUser!.uid;

    await _db.collection('groups').add({
      'name': name,
      'createdBy': uid,
      'members': [uid],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ================= GET USER GROUPS =================
  static Stream<QuerySnapshot> getUserGroups() {
    final uid = _auth.currentUser!.uid;

    return _db
        .collection('groups')
        .where('members', arrayContains: uid)
        .snapshots();
  }

  // ================= ADD EXPENSE =================
  static Future<void> addExpense({
    required String groupId,
    required String title,
    required double amount,
    required String paidBy,
    required Map<String, double> split,
  }) async {
    await _db.collection('groups').doc(groupId).collection('expenses').add({
      'title': title,
      'amount': amount,
      'paidBy': paidBy,
      'split': split,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
