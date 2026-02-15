import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MembersScreen extends StatefulWidget {
  final List<String> members; // Yeh UIDs ki list honi chahiye

  const MembersScreen({super.key, required this.members});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  late List<String> membersUids;
  final Color primaryColor = const Color(0xFF2D62ED);
  final Color accentColor = const Color(0xFF1A1C1E);

  @override
  void initState() {
    super.initState();
    membersUids = List.from(widget.members);
  }

  // ================= FETCH MEMBER DETAILS =================
  // Kyunki members list mein sirf UIDs hain, hume Firestore se unka email/name chahiye
  Stream<DocumentSnapshot> getUserDetails(String uid) {
    return FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
  }

  // ================= REMOVE MEMBER =================
  void removeMember(int index) {
    if (membersUids.length == 1) {
      _showSnack('At least 1 member is required', Colors.orange);
      return;
    }
    setState(() {
      membersUids.removeAt(index);
    });
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: accentColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Manage Members',
            style: TextStyle(
                color: accentColor, fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, membersUids),
            child: Text('Done',
                style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: membersUids.length,
              itemBuilder: (context, index) {
                final uid = membersUids[index];

                return StreamBuilder<DocumentSnapshot>(
                  stream: getUserDetails(uid),
                  builder: (context, snapshot) {
                    String title = "Loading...";
                    String subtitle = "User ID: $uid";

                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data =
                          snapshot.data!.data() as Map<String, dynamic>;
                      title = data['email'] ?? 'Unknown User';
                      subtitle = "Member";
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: primaryColor.withOpacity(0.1),
                          child: Icon(Icons.person, color: primaryColor),
                        ),
                        title: Text(title,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: accentColor)),
                        subtitle: Text(subtitle,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded,
                              color: Colors.redAccent),
                          onPressed: () => removeMember(index),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
