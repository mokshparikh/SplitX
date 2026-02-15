import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'group_model.dart';
import '../expenses/expense_screen.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  // ============= ROYAL BLUE THEME COLORS =============
  final Color primaryColor = const Color(0xFF1E3A8A); // Royal Blue
  final Color secondaryColor = const Color(0xFF3B82F6); // Lighter Blue
  final Color accentColor = const Color(0xFF60A5FA); // Light Blue
  final Color backgroundGradientStart =
      const Color(0xFFF8FAFC); // Very Light Blue
  final Color backgroundGradientEnd =
      const Color(0xFFE2E8F0); // Light Gray-Blue
  final Color archiveColor = const Color(0xFF6B7280); // Gray for archived

  bool showArchived = false; // Toggle for showing archived groups

  @override
  void initState() {
    super.initState();
    checkUsersCollection();
  }

  Future<void> checkUsersCollection() async {
    print('🔍 CHECKING USERS COLLECTION...');

    try {
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').limit(10).get();

      print('📊 Total users in Firestore: ${usersSnapshot.docs.length}');

      if (usersSnapshot.docs.isEmpty) {
        print('❌ USERS COLLECTION IS EMPTY!');
        print('   This is why member add is not working!');
      } else {
        print('✅ Users found:');
        for (var doc in usersSnapshot.docs) {
          final data = doc.data();
          print('   - UID: ${doc.id}');
          print('     Email: ${data['email'] ?? 'NO EMAIL FIELD'}');
        }
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        print('🔍 CHECKING CURRENT USER...');
        final currentUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (currentUserDoc.exists) {
          print('✅ Current user EXISTS in Firestore');
          print('   Email: ${currentUserDoc.data()?['email']}');
        } else {
          print('❌ Current user NOT FOUND in Firestore!');
          print('   UID: ${currentUser.uid}');
          print('   Auth Email: ${currentUser.email}');

          print('🔧 AUTO-FIXING: Adding current user to Firestore...');
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .set({
            'email': currentUser.email!.toLowerCase(),
            'createdAt': FieldValue.serverTimestamp(),
          });
          print('✅ Current user added to Firestore!');
        }
      }
    } catch (e) {
      print('❌ Error checking users: $e');
    }
  }

  // ================= ADD GROUP =================
  Future<void> addGroup(String name) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance.collection('groups').add({
      'name': name,
      'ownerId': uid,
      'members': [uid],
      'isArchived': false, // New groups are not archived by default
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ================= TOGGLE ARCHIVE STATUS =================
  Future<void> toggleArchiveStatus(String groupId, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .update({
        'isArchived': !currentStatus,
      });

      if (!mounted) return;
      _snack(
        context,
        currentStatus ? 'Group unarchived!' : 'Group archived!',
        const Color(0xFF10B981),
      );
    } catch (e) {
      if (!mounted) return;
      _snack(context, 'Failed to update group', const Color(0xFFEF4444));
    }
  }

  // ================= EDIT GROUP NAME =================
  Future<void> editGroupName(
    BuildContext context,
    String groupId,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);

    final newName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Edit Group Name',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: backgroundGradientStart,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentColor.withOpacity(0.3)),
              ),
              child: TextField(
                controller: controller,
                style: TextStyle(color: primaryColor),
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Enter new group name',
                  hintStyle: TextStyle(color: primaryColor.withOpacity(0.5)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(20),
                  prefixIcon: Icon(Icons.edit_rounded,
                      color: primaryColor.withOpacity(0.7)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      border: Border.all(color: primaryColor.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
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
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
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
                      onPressed: () {
                        if (controller.text.isNotEmpty &&
                            controller.text != currentName) {
                          Navigator.pop(context, controller.text);
                        }
                      },
                      child: const Text(
                        'Save',
                        style: TextStyle(
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

    if (newName != null && newName.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .update({'name': newName});

        if (!mounted) return;
        _snack(context, 'Group name updated successfully',
            const Color(0xFF10B981));
      } catch (e) {
        if (!mounted) return;
        _snack(context, 'Error updating group name: ${e.toString()}',
            const Color(0xFFEF4444));
      }
    }
  }

  // ================= DELETE GROUP (OWNER ONLY) =================
  Future<void> deleteGroup(BuildContext context, String groupId) async {
    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .delete();

      if (!mounted) return;
      _snack(context, 'Group deleted successfully', const Color(0xFFEF4444));
    } catch (e) {
      if (!mounted) return;
      _snack(context, e.toString(), const Color(0xFFEF4444));
    }
  }

  // ================= REMOVE MEMBER =================
  Future<void> removeMember(
    BuildContext context,
    String groupId,
    String memberId,
    String memberEmail,
    bool isOwner,
  ) async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser!.uid;

      // Owner cannot remove themselves
      if (memberId == currentUid && isOwner) {
        _snack(
          context,
          'Group owner cannot leave. Delete the group instead.',
          const Color(0xFFF59E0B),
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .update({
        'members': FieldValue.arrayRemove([memberId]),
      });

      if (!mounted) return;
      _snack(
        context,
        'Member removed successfully',
        const Color(0xFF10B981),
      );
    } catch (e) {
      if (!mounted) return;
      _snack(context, 'Error removing member: ${e.toString()}',
          const Color(0xFFEF4444));
    }
  }

  // ================= ADD MEMBER (FIXED VERSION) =================
  Future<void> addMemberByEmail(
    BuildContext context,
    String groupId,
    String groupName,
    String email,
  ) async {
    final cleanEmail = email.trim().toLowerCase();

    print('🔍 ========== ADD MEMBER DEBUG START ==========');
    print('📧 Input Email: "$email"');
    print('🧹 Cleaned Email: "$cleanEmail"');
    print('🏷️  Group ID: $groupId');
    print('👤 Current User: ${FirebaseAuth.instance.currentUser?.uid}');
    print('');

    try {
      // Check if member already exists in group
      print('🔍 STEP 1: Checking if member already in group...');
      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .get();

      if (groupDoc.exists) {
        final members = List<String>.from(groupDoc.data()?['members'] ?? []);
        print('👥 Current members: $members');

        // Check if user is trying to add themselves
        if (cleanEmail ==
            FirebaseAuth.instance.currentUser?.email?.toLowerCase()) {
          print('⚠️  User trying to add themselves!');
          if (!mounted) return;
          _snack(context, 'You are already in this group',
              const Color(0xFFF59E0B));
          return;
        }
      }

      // Enhanced user search
      print('');
      print('🔍 STEP 2: Searching for user in database...');
      print('   Query: users WHERE email == "$cleanEmail"');

      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();

      print('📊 Search Results:');
      print('   - Docs found: ${userSnap.docs.length}');
      print('   - Is empty: ${userSnap.docs.isEmpty}');

      if (userSnap.docs.isNotEmpty) {
        final userDoc = userSnap.docs.first;
        final newUid = userDoc.id;
        final userData = userDoc.data();

        print('');
        print('✅ USER FOUND!');
        print('   - UID: $newUid');
        print('   - Email in DB: ${userData['email']}');
        print('   - Doc ID: ${userDoc.id}');

        // Check if already a member
        final groupSnapshot = await FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .get();

        final currentMembers =
            List<String>.from(groupSnapshot.data()?['members'] ?? []);

        if (currentMembers.contains(newUid)) {
          print('⚠️  User is ALREADY a member!');
          if (!mounted) return;
          _snack(context, 'This user is already a group member',
              const Color(0xFFF59E0B));
          return;
        }

        print('');
        print('🔍 STEP 3: Adding member to group...');

        await FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .update({
          'members': FieldValue.arrayUnion([newUid]),
        });

        print('✅ SUCCESS! Member added to group');
        print('');
        if (!mounted) return;
        _snack(context, '✓ Member added successfully', const Color(0xFF10B981));
      } else {
        print('');
        print('❌ USER NOT FOUND IN DATABASE');
        print('   Searched email: "$cleanEmail"');
        print('');
        print('🔍 STEP 3: Debugging - Listing all users...');

        final allUsers = await FirebaseFirestore.instance
            .collection('users')
            .limit(20)
            .get();

        print('📋 All users in database (first 20):');
        if (allUsers.docs.isEmpty) {
          print('   ⚠️  USERS COLLECTION IS EMPTY!');
        } else {
          for (var doc in allUsers.docs) {
            final data = doc.data();
            print('   - ${doc.id}: ${data['email']}');
          }
        }

        print('');
        print('📧 CREATING INVITATION INSTEAD...');

        await FirebaseFirestore.instance.collection('invitations').add({
          'email': cleanEmail,
          'groupId': groupId,
          'groupName': groupName,
          'invitedBy': FirebaseAuth.instance.currentUser!.email,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        });

        print('✅ Invitation created successfully');
        print('');
        if (!mounted) return;
        _snack(
          context,
          '📨 Invitation sent - User will be notified when they sign up',
          accentColor,
        );
      }
    } catch (e, stackTrace) {
      print('');
      print('❌ ERROR OCCURRED!');
      print('   Error: $e');
      print('   Stack trace: $stackTrace');
      print('');

      if (!mounted) return;
      _snack(context, 'Error: ${e.toString()}', const Color(0xFFEF4444));
    }

    print('🔍 ========== ADD MEMBER DEBUG END ==========');
    print('');
  }

  // ================= SHOW MEMBERS LIST =================
  void _showMembersList(
      BuildContext context, String groupId, String groupName, String ownerId) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final isOwner = currentUid == ownerId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, secondaryColor],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Group Members',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    groupName,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Members List
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('groups')
                    .doc(groupId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    );
                  }

                  final members =
                      List<String>.from(snapshot.data!['members'] ?? []);

                  if (members.isEmpty) {
                    return Center(
                      child: Text(
                        'No members yet',
                        style: TextStyle(
                          color: primaryColor.withOpacity(0.6),
                          fontSize: 16,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final memberId = members[index];

                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(memberId)
                            .get(),
                        builder: (context, userSnapshot) {
                          if (!userSnapshot.hasData) {
                            return const SizedBox();
                          }

                          final userData = userSnapshot.data!.data()
                              as Map<String, dynamic>?;
                          final email = userData?['email'] ?? 'Unknown User';
                          final isMemberOwner = memberId == ownerId;
                          final isCurrentUser = memberId == currentUid;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.white, backgroundGradientStart],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isMemberOwner
                                    ? primaryColor.withOpacity(0.3)
                                    : accentColor.withOpacity(0.2),
                                width: isMemberOwner ? 2 : 1,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isMemberOwner
                                        ? [primaryColor, secondaryColor]
                                        : [accentColor, secondaryColor],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    email[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      email,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: primaryColor,
                                        fontSize: 15,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isCurrentUser)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: accentColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'You',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  isMemberOwner ? 'Group Owner' : 'Member',
                                  style: TextStyle(
                                    color: isMemberOwner
                                        ? primaryColor.withOpacity(0.8)
                                        : secondaryColor.withOpacity(0.7),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              trailing: (isOwner && !isMemberOwner)
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.person_remove_rounded,
                                        color: const Color(0xFFEF4444),
                                      ),
                                      onPressed: () {
                                        _confirmRemoveMember(
                                          context,
                                          groupId,
                                          memberId,
                                          email,
                                          isOwner,
                                        );
                                      },
                                    )
                                  : (isMemberOwner
                                      ? Icon(
                                          Icons.star_rounded,
                                          color: primaryColor,
                                        )
                                      : null),
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

  // ================= SHOW GROUP OPTIONS =================
  void _showGroupOptions(
    BuildContext context,
    String groupId,
    String groupName,
    String ownerId,
    bool isArchived,
  ) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final isOwner = currentUid == ownerId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                groupName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Archive/Unarchive Option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: archiveColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
                  color: archiveColor,
                ),
              ),
              title: Text(
                isArchived ? 'Unarchive Group' : 'Archive Group',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: archiveColor,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                toggleArchiveStatus(groupId, isArchived);
              },
            ),
            // View Members Option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.people_rounded, color: primaryColor),
              ),
              title: Text(
                'View Members',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _showMembersList(context, groupId, groupName, ownerId);
              },
            ),
            // Edit Name Option (Owner Only, not for archived)
            if (isOwner && !isArchived)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: secondaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.edit_rounded, color: primaryColor),
                ),
                title: Text(
                  'Edit Group Name',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  editGroupName(context, groupId, groupName);
                },
              ),
            // Delete Group Option (Owner Only)
            if (isOwner)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_rounded,
                      color: Color(0xFFEF4444)),
                ),
                title: const Text(
                  'Delete Group',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFEF4444),
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final confirmed = await _confirmDelete(context, groupName);
                  if (confirmed == true) {
                    deleteGroup(context, groupId);
                  }
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
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: backgroundGradientStart,
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryColor, secondaryColor],
            ),
          ),
        ),
        title: const Text(
          'My Groups',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          // Archive Toggle Button
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: showArchived
                  ? Colors.white.withOpacity(0.3)
                  : Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                showArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  showArchived = !showArchived;
                });
              },
            ),
          ),
          // Logout Button
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
              onPressed: () => FirebaseAuth.instance.signOut(),
            ),
          ),
        ],
      ),

      // ================= GROUP LIST =================
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [backgroundGradientStart, backgroundGradientEnd],
          ),
        ),
        child: Column(
          children: [
            // Filter Indicator
            if (showArchived)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: archiveColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: archiveColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.archive_rounded, color: archiveColor, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Showing Archived Groups',
                      style: TextStyle(
                        color: archiveColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            // Groups List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('groups')
                    .where('members', arrayContains: uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    );
                  }

                  final allDocs = snapshot.data!.docs;

                  // Filter based on archive status
                  final docs = allDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final isArchived = data['isArchived'] ?? false;
                    return showArchived ? isArchived : !isArchived;
                  }).toList();

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
                              showArchived
                                  ? Icons.archive_rounded
                                  : Icons.group_add_rounded,
                              size: 64,
                              color: primaryColor.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            showArchived
                                ? 'No archived groups'
                                : 'No active groups',
                            style: TextStyle(
                              fontSize: 18,
                              color: primaryColor.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            showArchived
                                ? 'Archive groups to see them here'
                                : 'Create your first group to get started',
                            style: TextStyle(
                              fontSize: 14,
                              color: primaryColor.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final sortedDocs = docs.toList()
                    ..sort((a, b) {
                      final aTime = a['createdAt'] as Timestamp?;
                      final bTime = b['createdAt'] as Timestamp?;
                      if (aTime == null || bTime == null) return 0;
                      return bTime.compareTo(aTime);
                    });

                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: sortedDocs.length,
                    itemBuilder: (context, index) {
                      final data =
                          sortedDocs[index].data() as Map<String, dynamic>;
                      final group = Group(
                        id: sortedDocs[index].id,
                        name: data['name'],
                        members: List<String>.from(data['members']),
                        expenses: [],
                      );

                      final isOwner = data['ownerId'] == uid;
                      final isArchived = data['isArchived'] ?? false;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isArchived
                                  ? [Colors.grey.shade200, Colors.grey.shade300]
                                  : [
                                      Colors.white,
                                      Colors.white.withOpacity(0.9)
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: isArchived
                                    ? archiveColor.withOpacity(0.1)
                                    : primaryColor.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(20),
                            title: Text(
                              group.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                                color: isArchived ? archiveColor : primaryColor,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: InkWell(
                                onTap: () => _showMembersList(
                                  context,
                                  group.id,
                                  group.name,
                                  data['ownerId'],
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.people_rounded,
                                      size: 16,
                                      color: (isArchived
                                              ? archiveColor
                                              : secondaryColor)
                                          .withOpacity(0.7),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${group.members.length} members',
                                      style: TextStyle(
                                        color: (isArchived
                                                ? archiveColor
                                                : secondaryColor)
                                            .withOpacity(0.8),
                                        fontWeight: FontWeight.w500,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 12,
                                      color: (isArchived
                                              ? archiveColor
                                              : secondaryColor)
                                          .withOpacity(0.5),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            leading: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isArchived
                                      ? [archiveColor, archiveColor]
                                      : [primaryColor, secondaryColor],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isArchived
                                            ? archiveColor
                                            : primaryColor)
                                        .withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  isArchived
                                      ? Icons.archive_rounded
                                      : Icons.group_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Add Member Button (only for active groups)
                                if (!isArchived)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: accentColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: IconButton(
                                      icon: Icon(Icons.person_add_rounded,
                                          color: primaryColor),
                                      onPressed: () => _showAddMemberSheet(
                                        context,
                                        group.id,
                                        group.name,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                // More Options Button
                                Container(
                                  decoration: BoxDecoration(
                                    color: (isArchived
                                            ? archiveColor
                                            : secondaryColor)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: IconButton(
                                    icon: Icon(Icons.more_vert_rounded,
                                        color: isArchived
                                            ? archiveColor
                                            : primaryColor),
                                    onPressed: () => _showGroupOptions(
                                      context,
                                      group.id,
                                      group.name,
                                      data['ownerId'],
                                      isArchived,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            onTap: isArchived
                                ? null
                                : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ExpenseScreen(group: group),
                                      ),
                                    ),
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
      ),

      // ================= FLOATING ACTION BUTTON (only for active view) =================
      floatingActionButton: !showArchived
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
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
                child: const Icon(Icons.add_rounded,
                    size: 28, color: Colors.white),
                onPressed: () => _showAddGroupSheet(context),
              ),
            )
          : null,
    );
  }

  // ================= ADD GROUP SHEET =================
  void _showAddGroupSheet(BuildContext context) {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Create New Group',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: backgroundGradientStart,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentColor.withOpacity(0.3)),
              ),
              child: TextField(
                controller: controller,
                style: TextStyle(color: primaryColor),
                decoration: InputDecoration(
                  hintText: 'Enter group name',
                  hintStyle: TextStyle(color: primaryColor.withOpacity(0.5)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(20),
                  prefixIcon: Icon(Icons.group_rounded,
                      color: primaryColor.withOpacity(0.7)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
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
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    addGroup(controller.text);
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  'Create Group',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= ADD MEMBER SHEET =================
  void _showAddMemberSheet(
    BuildContext context,
    String groupId,
    String groupName,
  ) {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Add Member',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'to $groupName',
              style: TextStyle(
                fontSize: 16,
                color: primaryColor.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: backgroundGradientStart,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentColor.withOpacity(0.3)),
              ),
              child: TextField(
                controller: controller,
                style: TextStyle(color: primaryColor),
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Enter email address',
                  hintStyle: TextStyle(color: primaryColor.withOpacity(0.5)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(20),
                  prefixIcon: Icon(Icons.email_rounded,
                      color: primaryColor.withOpacity(0.7)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
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
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    addMemberByEmail(
                      context,
                      groupId,
                      groupName,
                      controller.text,
                    );
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  'Add Member',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= HELPERS =================
  void _snack(BuildContext context, String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
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

  Future<bool?> _confirmDelete(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Group',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to delete "$name"? This action cannot be undone.',
          style: TextStyle(color: primaryColor.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: primaryColor.withOpacity(0.7)),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Delete',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemoveMember(
    BuildContext context,
    String groupId,
    String memberId,
    String email,
    bool isOwner,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remove Member',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to remove "$email" from this group?',
          style: TextStyle(color: primaryColor.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: primaryColor.withOpacity(0.7)),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Remove',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      removeMember(context, groupId, memberId, email, isOwner);
    }
  }
}
