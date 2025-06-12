import 'package:apisavana_gestion/controllers/collecte_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MultiSelectFlorale extends StatelessWidget {
  final CollecteController c;
  final String label;
  final bool showLabel;

  const MultiSelectFlorale(this.c,
      {this.label = "Prédominance florale", this.showLabel = true, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        Wrap(
          spacing: 8,
          children: c.flores.map((florale) {
            return Obx(() => FilterChip(
                  label: Text(florale),
                  selected: c.predominancesFloralesSelected.contains(florale),
                  onSelected: (selected) {
                    if (selected) {
                      c.predominancesFloralesSelected.add(florale);
                    } else {
                      c.predominancesFloralesSelected.remove(florale);
                      // On retire aussi la saisie manuelle si "Autres" est décoché
                      if (florale == "Autres") {
                        c.autrePredominanceCtrl.clear();
                      }
                    }
                  },
                ));
          }).toList(),
        ),
        // Champ de saisie si "Autres" sélectionné
        Obx(() => c.predominancesFloralesSelected.contains("Autres")
            ? Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: c.autrePredominanceCtrl,
                        decoration: InputDecoration(
                          labelText: "Saisir la prédominance florale",
                        ),
                        onFieldSubmitted: (val) {
                          final text = val.trim();
                          if (text.isNotEmpty &&
                              !c.predominancesFloralesSelected.contains(text)) {
                            c.predominancesFloralesSelected.add(text);
                            c.autrePredominanceCtrl.clear();
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add),
                      tooltip: "Ajouter",
                      onPressed: () {
                        final text = c.autrePredominanceCtrl.text.trim();
                        if (text.isNotEmpty &&
                            !c.predominancesFloralesSelected.contains(text)) {
                          c.predominancesFloralesSelected.add(text);
                          c.autrePredominanceCtrl.clear();
                        }
                      },
                    )
                  ],
                ),
              )
            : SizedBox.shrink()),
        // Affichage des prédominances sélectionnées avec possibilité de suppression
        Obx(() => Wrap(
              spacing: 8,
              children: c.predominancesFloralesSelected
                  .where((p) => !c.flores
                      .contains(p)) // On n'affiche ici que les personnalisées
                  .map((e) => Chip(
                        label: Text(e),
                        onDeleted: () =>
                            c.predominancesFloralesSelected.remove(e),
                      ))
                  .toList(),
            )),
      ],
    );
  }
}
