// lib/login_screen.dart - v1.4.1 (Fixes referralDocId undefined error, increments currentUses)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart'; // Assuming HomePage is in main.dart
import 'public_browse_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _referralCodeController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : null,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Validates referral code. Returns a Map with 'id' and 'data' if valid, else null.
  Future<Map<String, dynamic>?> _validateReferralCode(String codeValue) async {
    if (codeValue.isEmpty) return null;
    print('Validating referral code: $codeValue');
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('referral_codes')
          .where('codeValue', isEqualTo: codeValue.trim())
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        DocumentSnapshot doc = querySnapshot.docs.first;
        print('Referral code "$codeValue" is valid. Doc ID: ${doc.id}');
        return {
          'id': doc.id, // This is the Firestore document ID of the referral code
          'data': doc.data() as Map<String, dynamic>,
        };
      } else {
        print('Referral code "$codeValue" is invalid or not active.');
        return null;
      }
    } catch (e) {
      print('Error validating referral code "$codeValue": $e');
      // If PERMISSION_DENIED, it means rules are not allowing the query.
      // Make sure Firestore rules for 'referral_codes' collection allow 'list' operation for unauthenticated/signing-up users.
      // Example rule: match /referral_codes/{document=**} { allow list: if true; }
      _showSnackBar('Could not validate referral code. Please try again.', isError: true);
      return null;
    }
  }

  // Creates/updates user document in Firestore
  Future<void> _updateUserDocumentInFirestore(User user, {String? usedReferralCode, String? referredByInfluencerId}) async {
    if (!mounted) return;
    print('Attempting to update/create user document for UID: ${user.uid}');
    DocumentReference userDocRef = _firestore.collection('users').doc(user.uid);

    // Initial data map, primarily for new user creation.
    // Some of these will also be used for updates if user logs in.
    Map<String, dynamic> userDataToSet = {
      'email': user.email,
      'displayName': user.displayName, // Ensure this is set; might be null from User object initially for email/pass
      'lastLoginAt': FieldValue.serverTimestamp(),
      'userId': user.uid, // Good to have this explicitly in the document too
    };

    // Add referral information to the map if provided (typically on sign-up)
    if (usedReferralCode != null && usedReferralCode.isNotEmpty) {
      userDataToSet['usedReferralCode'] = usedReferralCode;
      userDataToSet['referralBenefitApplied'] = true; // Assuming benefit is applied by using the code
      if (referredByInfluencerId != null && referredByInfluencerId.isNotEmpty) {
        userDataToSet['referredByInfluencerId'] = referredByInfluencerId;
      }
    }

    try {
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot userDocSnapshot = await transaction.get(userDocRef);

        if (!userDocSnapshot.exists) {
          // New user: add createdAt and currentTier
          userDataToSet['createdAt'] = FieldValue.serverTimestamp();
          userDataToSet['currentTier'] = 'free'; // <-- **** ADDED THIS LINE ****
          transaction.set(userDocRef, userDataToSet);
          print('Created new user document in Firestore for UID: ${user.uid} with tier: free and referral: $usedReferralCode');
        } else {
          // Existing user: update specific fields like lastLoginAt, and potentially displayName/email if they can change
          Map<String, dynamic> updateData = {
            'email': user.email, // Sync email, useful if user changes it with provider
            'displayName': user.displayName, // Sync displayName
            'lastLoginAt': FieldValue.serverTimestamp(),
            // We DO NOT set 'currentTier' here for existing users,
            // as they might have upgraded. It's only set on creation.
          };

          // This logic allows adding a referral code if an existing user somehow didn't have one
          // and is now providing one. This might be an edge case.
          if (usedReferralCode != null && usedReferralCode.isNotEmpty &&
              (userDocSnapshot.data() as Map<String,dynamic>?)?['usedReferralCode'] == null) {
                updateData['usedReferralCode'] = usedReferralCode;
                updateData['referralBenefitApplied'] = true;
                if (referredByInfluencerId != null && referredByInfluencerId.isNotEmpty) {
                  updateData['referredByInfluencerId'] = referredByInfluencerId;
                }
          }
          transaction.update(userDocRef, updateData);
          print('Updated user document in Firestore for UID: ${user.uid}');
        }
      });
    } catch (e) {
      print('Error creating/updating user document in Firestore: $e');
      if (mounted) _showSnackBar('Could not update user profile data.', isError: true);
    }
  }

  // Handles Google Sign-In
  Future<UserCredential?> _signInWithGoogle() async {
    // ... (This method remains the same as v1.3/v1.4 - calls _updateUserDocumentInFirestore without referral data)
    if (_isLoading) return null;
    setState(() => _isLoading = true);
    UserCredential? userCredential;
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) { if (mounted) setState(() => _isLoading = false); return null; }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
      userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await _updateUserDocumentInFirestore(userCredential.user!); 
      }
      return userCredential;
    } catch (e) {
      _showSnackBar('An error occurred during Google Sign-In: ${e.toString()}', isError: true);
      return null;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Handles Email/Password Login or Sign Up
  Future<void> _submitEmailPasswordForm() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String referralCodeInput = _referralCodeController.text.trim();

    Map<String, dynamic>? validatedReferralInfo; // To store ID and data of a valid code

    try {
      UserCredential userCredential;

      if (_isLogin) {
        userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
        _showSnackBar('Login successful!');
        if (userCredential.user != null) {
          await _updateUserDocumentInFirestore(userCredential.user!);
        }
      } else { // Sign Up Logic
        print('Sign Up Mode: Starting referral code check if provided.');
        if (referralCodeInput.isNotEmpty) {
          validatedReferralInfo = await _validateReferralCode(referralCodeInput);
          if (validatedReferralInfo == null) {
            if (!mounted) { setState(() => _isLoading = false); return; }
            bool continueSignup = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext dialogContext) {
                    return AlertDialog(
                      title: const Text('Invalid Referral Code'),
                      content: Text('The referral code "$referralCodeInput" is not valid or has expired. Continue without referral benefits?'),
                      actions: <Widget>[
                        TextButton(child: const Text('Cancel Sign Up'), onPressed: () => Navigator.of(dialogContext).pop(false)),
                        TextButton(child: const Text('Continue Anyway'), onPressed: () => Navigator.of(dialogContext).pop(true)),
                      ],
                    );
                  },
                ) ?? false; 

            if (!continueSignup) {
              print('User chose to cancel sign-up due to invalid referral code.');
              if (mounted) setState(() => _isLoading = false);
              return; 
            }
            print('User chose to continue sign-up without referral benefits.');
          } else {
            final String? validCodeValue = (validatedReferralInfo['data'] as Map<String,dynamic>?)?['codeValue'] as String?;
            _showSnackBar('Referral code "$validCodeValue" applied!');
            print('Valid referral code applied: $validCodeValue');
          }
        }

        userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
        _showSnackBar('Sign Up successful!');
        
        if (userCredential.user != null) {
          // Extract data from validatedReferralInfo to pass to _updateUserDocumentInFirestore
          final String? actualUsedCode = (validatedReferralInfo?['data'] as Map<String,dynamic>?)?['codeValue'] as String?;
          final String? influencer = (validatedReferralInfo?['data'] as Map<String,dynamic>?)?['influencerId'] as String?;

          await _updateUserDocumentInFirestore(
            userCredential.user!,
            usedReferralCode: actualUsedCode,
            referredByInfluencerId: influencer,
          );

          // Increment currentUses for the referral code if it was valid
          if (validatedReferralInfo != null) {
            final String? referralDocId = validatedReferralInfo['id'] as String?; // Get the Firestore doc ID of the code
            if (referralDocId != null) {
              try {
                await _firestore.collection('referral_codes').doc(referralDocId).update({
                  'currentUses': FieldValue.increment(1),
                });
                print('Incremented currentUses for referral code ID: $referralDocId');
              } catch (e) {
                print('Error incrementing currentUses for code ID $referralDocId (code: ${actualUsedCode ?? referralCodeInput}): $e');
                // Non-critical for user sign-up, but log for admin.
              }
            }
          }
        }
      }
      
      if (mounted && userCredential.user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An authentication error: ${e.message}';
      if ((e.code == 'user-not-found' || e.code == 'invalid-credential') && _isLogin) errorMessage = 'Invalid email or password.';
      else if (e.code == 'wrong-password' && _isLogin) errorMessage = 'Wrong password provided.';
      else if (e.code == 'weak-password' && !_isLogin) errorMessage = 'Password must be at least 6 characters.';
      else if (e.code == 'email-already-in-use' && !_isLogin) errorMessage = 'An account already exists for that email.';
      else if (e.code == 'invalid-email') errorMessage = 'The email address is not valid.';
      _showSnackBar(errorMessage, isError: true);
      print('FirebaseAuthException: ${e.code} - ${e.message}');
    } catch (e) {
      print('Unexpected error during form submission: $e');
      _showSnackBar('An unexpected error occurred. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Block comment: This build method constructs the UI for the Login/Sign Up screen.
    // It includes TextFormFields for email, password, and an optional referral code (in sign-up mode).
    // Buttons for submitting the form, toggling between login/sign-up, Google Sign-In, and Browse public stories.
    // A loading indicator is shown during asynchronous operations.
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'storystork Login' : 'Create Account'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0))),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_isLoading,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Please enter your email.';
                      if (!value.contains('@') || !value.contains('.')) return 'Please enter a valid email.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16.0),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(labelText: 'Password', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0))),
                    obscureText: true,
                    enabled: !_isLoading,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Please enter your password.';
                      if (!_isLogin && value.trim().length < 6) return 'Password must be at least 6 characters.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16.0),
                  if (!_isLogin) ...[
                    TextFormField(
                      controller: _referralCodeController,
                      decoration: InputDecoration(labelText: 'Referral Code (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0))),
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 24.0),
                  ],
                  if (_isLogin) const SizedBox(height: 24.0),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _submitEmailPasswordForm,
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12.0), textStyle: const TextStyle(fontSize: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0))),
                          child: Text(_isLogin ? 'Login' : 'Sign Up'),
                        ),
                  const SizedBox(height: 16.0),
                  TextButton(
                    onPressed: _isLoading ? null : () {
                      setState(() { _isLogin = !_isLogin; });
                      _formKey.currentState?.reset();
                      _emailController.clear(); _passwordController.clear(); _referralCodeController.clear();
                    },
                    child: Text(_isLogin ? 'Don\'t have an account? Sign Up' : 'Already have an account? Login'),
                  ),
                  const SizedBox(height: 24.0),
                  if (!_isLoading)
                    ElevatedButton.icon(
                      onPressed: () async {
                        if (_isLoading) return;
                        UserCredential? userCredential = await _signInWithGoogle();
                        if (userCredential != null && mounted) {
                          _showSnackBar('Google Sign-In successful!');
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage()));
                        }
                      },
                      icon: Image.asset('assets/images/google_logo.png', height: 24.0),
                      label: const Text('Sign in with Google'),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12.0),textStyle: const TextStyle(fontSize: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)), backgroundColor: Colors.white, foregroundColor: Colors.black87),
                    ),
                  const SizedBox(height: 16.0),
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PublicBrowseScreen())),
                    child: const Text('Browse Public Stories & Poems'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}