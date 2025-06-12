// Widgets utilitaires à placer dans un fichier partagé (ex: formulaires_utilitaires.dart)

import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Champ texte avec icône et validation
Widget _textFieldWithIcon(
    String label, TextEditingController ctrl, IconData icon, String erreur) {
  return TextFormField(
    controller: ctrl,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.amber),
    ),
    validator: (v) => v == null || v.isEmpty ? erreur : null,
  );
}

// Menu déroulant avec icône et validation
Widget _dropdownWithIcon(String label, List<String> data, RxnString sel,
    IconData icon, String erreur) {
  return Obx(() => DropdownButtonFormField<String>(
        value: sel.value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.green),
        ),
        items: data
            .map((d) => DropdownMenuItem(value: d, child: Text(d)))
            .toList(),
        onChanged: (v) => sel.value = v,
        validator: (v) => v == null ? erreur : null,
      ));
}

// Champ numérique avec icône et validation
Widget _numberFieldCtrlWithIcon(
    String label, TextEditingController ctrl, IconData icon, String erreur) {
  return TextFormField(
    controller: ctrl,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.brown),
    ),
    keyboardType: TextInputType.number,
    validator: (v) => v == null || v.isEmpty ? erreur : null,
  );
}
