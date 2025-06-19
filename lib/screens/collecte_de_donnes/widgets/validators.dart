import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Affiche une snackbar d'erreur personnalisée
void showFieldError(String titre, String message) {
  Get.snackbar(
    titre,
    message,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: Colors.red[100],
    colorText: Colors.red[900],
    duration: Duration(seconds: 5),
    icon: Icon(Icons.error, color: Colors.red[900]),
  );
}

/// Valide qu'une valeur double est bien positive et requise
bool validateDouble(String? value, String champLabel) {
  if (value == null || value.isEmpty) {
    showFieldError("Champ requis", "Veuillez renseigner $champLabel.");
    return false;
  }
  final val = double.tryParse(value.replaceAll(",", "."));
  if (val == null || val < 0) {
    showFieldError(
        "Valeur incorrecte", "$champLabel doit être un nombre positif.");
    return false;
  }
  return true;
}

/// Valide qu'une valeur int est bien positive et requise
bool validateInt(String? value, String champLabel) {
  if (value == null || value.isEmpty) {
    showFieldError("Champ requis", "Veuillez renseigner $champLabel.");
    return false;
  }
  final val = int.tryParse(value);
  if (val == null || val < 0) {
    showFieldError(
        "Valeur incorrecte", "$champLabel doit être un entier positif.");
    return false;
  }
  return true;
}

/// Valide la sélection d'une dropdown
bool validateDropdown<T>(T? selected, String champLabel) {
  if (selected == null) {
    showFieldError("Sélection requise", "Veuillez sélectionner $champLabel.");
    return false;
  }
  return true;
}
