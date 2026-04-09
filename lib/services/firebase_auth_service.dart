import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:jk_inventory_system/firebase_options.dart';
import 'package:jk_inventory_system/models/app_user_profile.dart';

class FirebaseAuthService {
  FirebaseAuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<AppUserProfile> signInWithUsernamePin({
    required String username,
    required String pin,
  }) async {
    final usernameLower = username.trim().toLowerCase();
    if (usernameLower.isEmpty) {
      throw const AuthFlowException('Username is required.');
    }
    if (!_isValidPin(pin)) {
      throw const AuthFlowException('PIN must be exactly 6 digits.');
    }

    final query = await _users
        .where('usernameLower', isEqualTo: usernameLower)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw const AuthFlowException('Username not found.');
    }

    final data = query.docs.first.data();
    final email = (data['authEmail'] ?? '') as String;
    if (email.isEmpty) {
      throw const AuthFlowException('Account is not configured for sign-in.');
    }

    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: pin,
    );

    final profile = await getProfile(credential.user?.uid);
    if (profile == null) {
      throw const AuthFlowException('Account profile is missing.');
    }
    return profile;
  }

  Future<AppUserProfile?> getProfile(String? uid) async {
    if (uid == null || uid.isEmpty) return null;
    final snapshot = await _users.doc(uid).get();
    if (!snapshot.exists) return null;
    return AppUserProfile.fromMap(snapshot.data()!);
  }

  Future<AppUserProfile> registerAccount({
    required String username,
    required String pin,
    required AppRole role,
  }) async {
    final trimmedUsername = username.trim();
    final usernameLower = trimmedUsername.toLowerCase();

    if (trimmedUsername.isEmpty) {
      throw const AuthFlowException('Username is required.');
    }
    if (!_isValidPin(pin)) {
      throw const AuthFlowException('PIN must be exactly 6 digits.');
    }

    final duplicateCheck = await _users
        .where('usernameLower', isEqualTo: usernameLower)
        .limit(1)
        .get();
    if (duplicateCheck.docs.isNotEmpty) {
      throw const AuthFlowException('Username is already taken.');
    }

    final authEmail = _usernameToAuthEmail(usernameLower);
    final createdByUid = _auth.currentUser?.uid;

    final secondaryApp = await Firebase.initializeApp(
      name: 'register-${DateTime.now().microsecondsSinceEpoch}',
      options: DefaultFirebaseOptions.currentPlatform,
    );

    UserCredential credential;
    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: authEmail,
        password: pin,
      );
      await secondaryAuth.signOut();
    } on FirebaseAuthException catch (error) {
      await secondaryApp.delete();
      throw AuthFlowException(_mapFirebaseAuthError(error));
    } catch (_) {
      await secondaryApp.delete();
      throw const AuthFlowException('Failed to create account.');
    }

    await secondaryApp.delete();

    final createdUid = credential.user?.uid;
    if (createdUid == null || createdUid.isEmpty) {
      throw const AuthFlowException(
        'Created account does not have a valid uid.',
      );
    }

    final now = DateTime.now();
    final profile = AppUserProfile(
      uid: createdUid,
      username: trimmedUsername,
      role: role,
      isActive: true,
      createdAt: now,
      updatedAt: now,
      authEmail: authEmail,
      createdByUid: createdByUid,
    );

    await _users.doc(createdUid).set(profile.toMap());
    return profile;
  }

  Future<void> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    final normalizedCurrentPin = currentPin.trim();
    final normalizedNewPin = newPin.trim();

    if (!_isValidPin(normalizedCurrentPin)) {
      throw const AuthFlowException('Current PIN must be exactly 6 digits.');
    }
    if (!_isValidPin(normalizedNewPin)) {
      throw const AuthFlowException('New PIN must be exactly 6 digits.');
    }
    if (normalizedCurrentPin == normalizedNewPin) {
      throw const AuthFlowException(
        'New PIN must be different from current PIN.',
      );
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFlowException('No signed-in user found.');
    }

    var authEmail = user.email;
    if (authEmail == null || authEmail.trim().isEmpty) {
      final profile = await getProfile(user.uid);
      authEmail = profile?.authEmail;
    }

    if (authEmail == null || authEmail.trim().isEmpty) {
      throw const AuthFlowException('Account email is missing for PIN update.');
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: authEmail.trim(),
        password: normalizedCurrentPin,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(normalizedNewPin);

      await _users.doc(user.uid).set({
        'updatedAt': DateTime.now(),
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (error) {
      switch (error.code) {
        case 'invalid-credential':
        case 'wrong-password':
          throw const AuthFlowException('Current PIN is incorrect.');
        case 'weak-password':
          throw const AuthFlowException('New PIN must be exactly 6 digits.');
        case 'requires-recent-login':
          throw const AuthFlowException(
            'Session expired. Please log out and log back in, then try again.',
          );
        default:
          throw AuthFlowException(error.message ?? 'Failed to update PIN.');
      }
    }
  }

  Future<void> signOut() => _auth.signOut();

  bool _isValidPin(String pin) {
    final trimmed = pin.trim();
    if (trimmed.length != 6) {
      return false;
    }
    return int.tryParse(trimmed) != null;
  }

  String _usernameToAuthEmail(String usernameLower) {
    final safe = usernameLower.replaceAll(RegExp(r'[^a-z0-9._-]'), '_');
    return '$safe@bnm.local';
  }

  String _mapFirebaseAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'Username is already taken.';
      case 'weak-password':
        return 'PIN is invalid. Use exactly 6 digits.';
      case 'invalid-email':
        return 'Generated auth email is invalid.';
      default:
        return error.message ?? 'Authentication error.';
    }
  }
}

class AuthFlowException implements Exception {
  const AuthFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}
