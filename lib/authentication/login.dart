import 'package:apisavana_gestion/authentication/user_session.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController emailController;
  late final TextEditingController passwordController;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController();
    passwordController = TextEditingController();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void login() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      UserCredential userCred =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      // Récupère le rôle depuis Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('utilisateurs')
          .doc(userCred.user!.uid)
          .get();

      if (!userDoc.exists) {
        errorMessage.value = "Compte utilisateur non trouvé dans la base.";
        isLoading.value = false;
        return;
      }

      final userData = userDoc.data()!;
      // Stocke le rôle dans GetX (simple)
      Get.put(UserSession()).setUser(
        uid: userCred.user!.uid,
        role: userData['role'] ?? '',
        nom: userData['nom'] ?? '',
        email: userData['email'] ?? '',
        photoUrl: userData['photoUrl'],
      );

      Get.offAllNamed('/dashboard');
    } on FirebaseAuthException catch (e) {
      errorMessage.value = e.message ?? "Erreur lors de la connexion";
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.amber[50],
      body: Center(
        child: Card(
          margin: EdgeInsets.symmetric(horizontal: 24),
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: 350,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ajout du logo en haut
                  Image.asset(
                    "assets/logo/logo.jpeg", // Mets ton logo ici
                    height: 90,
                  ),
                  SizedBox(height: 12),
                  Text(
                    "Connexion Apisavana",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber[800],
                    ),
                  ),
                  SizedBox(height: 24),
                  TextField(
                    key: ValueKey('login-email'),
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: "Email",
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    key: ValueKey('login-password'),
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Mot de passe",
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  SizedBox(height: 16),
                  Obx(() => errorMessage.value.isNotEmpty
                      ? Text(
                          errorMessage.value,
                          style: TextStyle(color: Colors.red),
                        )
                      : SizedBox.shrink()),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Obx(
                        () => Expanded(
                          child: ElevatedButton(
                            onPressed: isLoading.value ? null : login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber[800],
                              minimumSize: Size(double.infinity, 48),
                            ),
                            child: isLoading.value
                                ? CircularProgressIndicator(color: Colors.white)
                                : Text("Se connecter"),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: () => Get.offAllNamed('/signup'),
                          child: Text("Créer un compte"),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
