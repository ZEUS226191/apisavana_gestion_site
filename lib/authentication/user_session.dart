import 'package:get/get.dart';

class UserSession extends GetxController {
  String? uid;
  String? role;
  String? nom;
  String? email;
  String? photoUrl;

  void setUser({
    required String uid,
    required String role,
    required String nom,
    required String email,
    String? photoUrl,
  }) {
    this.uid = uid;
    this.role = role;
    this.nom = nom;
    this.email = email;
    this.photoUrl = photoUrl;
  }
}
