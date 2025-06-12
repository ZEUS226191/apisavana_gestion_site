import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import 'login.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController nameController;
  late final TextEditingController emailController;
  late final TextEditingController passwordController;
  late final TextEditingController confirmPasswordController;

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  String? selectedRole;
  String? magazinierType; // "Principale" ou "Simple"
  String? localite; // "Koudougou", "Ouagadougou", "Bobo"
  bool passwordVisible = false;
  bool confirmPasswordVisible = false;

  File? _selectedImage;
  String? _imageUrl; // Stocke l'URL Cloudinary

  // Liste des rôles
  final List<String> roles = [
    "Admin",
    "Collecteur",
    "Contrôleur",
    "Extracteur",
    "Filtreur",
    "Conditionneur",
    "Commercial",
    "Gestionaire Commerciale",
    "Magazinier",
    "Caissier",
  ];

  final List<String> magazinierTypes = [
    "Principale",
    "Simple",
  ];

  final List<String> localites = [
    "Koudougou",
    "Ouagadougou",
    "Bobo",
  ];

  // Cloudinary instance (remplace par tes vraies valeurs)
  final cloudinary = CloudinaryPublic(
    'dq4mp3l7w', // <-- remplace
    'apisavana_proj', // <-- tu dois créer un 'unsigned upload preset' sur cloudinary console
    cache: false,
  );

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    emailController = TextEditingController();
    passwordController = TextEditingController();
    confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // Sélection ou prise de photo
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await showModalBottomSheet<XFile?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Choisir depuis la galerie'),
              onTap: () async {
                final image = await picker.pickImage(
                    source: ImageSource.gallery, imageQuality: 80);
                Navigator.pop(ctx, image);
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Prendre une photo'),
              onTap: () async {
                final image = await picker.pickImage(
                    source: ImageSource.camera, imageQuality: 80);
                Navigator.pop(ctx, image);
              },
            ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  // Upload image sur Cloudinary
  Future<String?> _uploadToCloudinary(File file) async {
    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(file.path,
            resourceType: CloudinaryResourceType.Image),
      );
      return response.secureUrl;
    } catch (e) {
      Get.snackbar('Erreur image', 'Upload image échoué : $e');
      return null;
    }
  }

  Future<void> signup() async {
    // Validation champs
    if (!_formKey.currentState!.validate() || selectedRole == null) return;
    // Validation Magazinier
    if (selectedRole == "Magazinier") {
      if (magazinierType == null) {
        errorMessage.value = "Veuillez choisir le type de magasinier.";
        return;
      }
      if (magazinierType == "Simple" && localite == null) {
        errorMessage.value = "Veuillez choisir la localité.";
        return;
      }
    }

    isLoading.value = true;
    errorMessage.value = '';
    if (passwordController.text != confirmPasswordController.text) {
      errorMessage.value = "Les mots de passe ne correspondent pas.";
      isLoading.value = false;
      return;
    }
    try {
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadToCloudinary(_selectedImage!);
        setState(() => _imageUrl = imageUrl);
      }

      UserCredential userCred =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      await FirebaseAuth.instance.currentUser
          ?.updateDisplayName(nameController.text.trim());

      // Préparation des données utilisateur (structure optimisée)
      Map<String, dynamic> userData = {
        "uid": userCred.user!.uid,
        "nom": nameController.text.trim(),
        "email": emailController.text.trim(),
        "role": selectedRole,
        "photoUrl": imageUrl,
        "createdAt": FieldValue.serverTimestamp(),
        "statistiques": {
          // Prêt pour de futures stats par utilisateur
          "nbConnexions": 1,
          "derniereConnexion": FieldValue.serverTimestamp(),
          // Ajoute d'autres stats ici si besoin
        },
      };

      // Gestion spécifique pour magazinier
      if (selectedRole == "Magazinier") {
        userData["magazinier"] = {
          "type": magazinierType,
          "localite": magazinierType == "Principale"
              ? "Koudougou"
              : localite, // automatique ou sélectionnée
        };
      }

      await FirebaseFirestore.instance
          .collection('utilisateurs')
          .doc(userCred.user!.uid)
          .set(userData);

      Get.offAllNamed('/login');
    } on FirebaseAuthException catch (e) {
      errorMessage.value = e.message ?? "Erreur lors de l'inscription";
      Get.snackbar('Compte non créé', "Erreur:  $e");
    } finally {
      isLoading.value = false;
    }
  }

  Widget magazinierFields() {
    if (selectedRole != "Magazinier") return SizedBox.shrink();

    return Column(
      children: [
        SizedBox(height: 12),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: "Type de magasinier",
            prefixIcon: Icon(Icons.storefront),
          ),
          value: magazinierType,
          items: magazinierTypes
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) {
            setState(() {
              magazinierType = v;
              if (magazinierType == "Principale") {
                localite = "Koudougou";
              } else {
                localite = null;
              }
            });
          },
          validator: (v) =>
              selectedRole == "Magazinier" && v == null ? "Obligatoire" : null,
        ),
        if (magazinierType == "Simple") ...[
          SizedBox(height: 12),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: "Localité",
              prefixIcon: Icon(Icons.location_on),
            ),
            value: localite,
            items: localites
                .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                .toList(),
            onChanged: (v) => setState(() => localite = v),
            validator: (v) =>
                magazinierType == "Simple" && v == null ? "Obligatoire" : null,
          ),
        ],
        if (magazinierType == "Principale") ...[
          SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.amber[800]),
              SizedBox(width: 8),
              Text(
                "Localité : KOUDOUGOU",
                style: TextStyle(
                    color: Colors.amber[800], fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.amber[50],
      body: Center(
        child: SingleChildScrollView(
          child: Card(
            margin: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: 390,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // LOGO ENTREPRISE
                      Image.asset(
                        "assets/logo/logo.jpeg",
                        height: 80,
                        fit: BoxFit.contain,
                      ),
                      SizedBox(height: 12),
                      Text(
                        "Créer un compte Apisavana",
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[800],
                        ),
                      ),
                      SizedBox(height: 18),

                      TextFormField(
                        key: ValueKey('signup-name'),
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: "Nom complet",
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? "Obligatoire"
                            : null,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        key: ValueKey('signup-email'),
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: "Email",
                          prefixIcon: Icon(Icons.email),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? "Obligatoire"
                            : null,
                      ),
                      SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: "Type d'utilisateur",
                          prefixIcon: Icon(Icons.account_box_outlined),
                        ),
                        value: selectedRole,
                        items: roles
                            .map((role) => DropdownMenuItem(
                                  value: role,
                                  child: Text(role),
                                ))
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            selectedRole = v;
                            magazinierType = null;
                            localite = null;
                          });
                        },
                        validator: (v) => v == null ? "Obligatoire" : null,
                      ),
                      magazinierFields(),
                      SizedBox(height: 16),
                      GestureDetector(
                        onTap: _pickImage,
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundImage: _selectedImage != null
                                  ? FileImage(_selectedImage!)
                                  : null,
                              backgroundColor: Colors.grey[200],
                              child: _selectedImage == null
                                  ? Icon(Icons.camera_alt,
                                      color: Colors.amber[600], size: 34)
                                  : null,
                            ),
                            SizedBox(height: 5),
                            Text(
                              "Ajouter une photo (optionnel)",
                              style: TextStyle(
                                  color: Colors.grey[700], fontSize: 13.5),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        key: ValueKey('signup-password'),
                        controller: passwordController,
                        obscureText: !passwordVisible,
                        decoration: InputDecoration(
                          labelText: "Mot de passe",
                          prefixIcon: Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(passwordVisible
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () {
                              setState(
                                  () => passwordVisible = !passwordVisible);
                            },
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? "Obligatoire" : null,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        key: ValueKey('signup-confirm-password'),
                        controller: confirmPasswordController,
                        obscureText: !confirmPasswordVisible,
                        decoration: InputDecoration(
                          labelText: "Confirmer le mot de passe",
                          prefixIcon: Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(confirmPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () {
                              setState(() => confirmPasswordVisible =
                                  !confirmPasswordVisible);
                            },
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? "Obligatoire" : null,
                      ),
                      SizedBox(height: 16),
                      Obx(() => errorMessage.value.isNotEmpty
                          ? Text(
                              errorMessage.value,
                              style: TextStyle(color: Colors.red),
                            )
                          : SizedBox.shrink()),
                      SizedBox(height: 16),
                      Obx(
                        () => ElevatedButton(
                          onPressed: isLoading.value ? null : signup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber[800],
                            minimumSize: Size(double.infinity, 48),
                          ),
                          child: isLoading.value
                              ? CircularProgressIndicator(color: Colors.white)
                              : Text("S'inscrire"),
                        ),
                      ),
                      SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Get.offAll(LoginPage()),
                        child: Text("Déjà un compte ? Se connecter"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
