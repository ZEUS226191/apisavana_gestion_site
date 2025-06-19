import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'conditionnement_edit.dart';

class ConditionnementHomePage extends StatelessWidget {
  const ConditionnementHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: "Retour au Dashboard",
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Get.offAllNamed('/dashboard'),
        ),
        title: const Text("🧊 Conditionnement - Lots filtrés"),
        backgroundColor: Colors.amber[700],
      ),
      backgroundColor: Colors.amber[50],
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('filtrage')
            .where('statutFiltrage', isEqualTo: 'Filtrage total')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.amber));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text(
              "Aucun lot filtré disponible.",
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ));
          }
          final lots = snapshot.data!.docs;
          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              return ListView.separated(
                padding: EdgeInsets.symmetric(
                  vertical: isMobile ? 12 : 30,
                  horizontal: isMobile ? 7 : 20,
                ),
                itemCount: lots.length,
                separatorBuilder: (context, i) => const SizedBox(height: 18),
                itemBuilder: (context, i) {
                  final lot = lots[i];
                  final data = lot.data() as Map<String, dynamic>;
                  final dateFiltrage = data['dateFiltrage'] != null
                      ? (data['dateFiltrage'] as Timestamp).toDate()
                      : null;
                  final unite = data['unite'] ?? 'kg';

                  // On utilise quantiteFiltree pour "Reçue"
                  final quantiteRecue =
                      (data['quantiteFiltree'] ?? 0.0).toString();

                  // Reste après conditionnement (champ mis à jour après conditionnement, sinon fallback sur quantiteRestante du filtrage)
                  final reste = (data['quantiteRestante'] ?? 0.0).toString();

                  final florale =
                      data['predominanceFlorale']?.toString() ?? '-';

                  final bool estConditionne =
                      data.containsKey('statutConditionnement') &&
                          data['statutConditionnement'] == 'Conditionné';

                  Widget? infosConditionnement;
                  if (estConditionne) {
                    infosConditionnement = FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('conditionnement')
                          .where('lotFiltrageId', isEqualTo: lot.id)
                          .limit(1)
                          .get(),
                      builder: (context, condSnap) {
                        if (condSnap.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: LinearProgressIndicator(),
                          );
                        }
                        if (!condSnap.hasData || condSnap.data!.docs.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text("Conditionnement introuvable.",
                                style: TextStyle(
                                    color: Colors.red,
                                    fontStyle: FontStyle.italic)),
                          );
                        }
                        final cond = condSnap.data!.docs.first.data()
                            as Map<String, dynamic>;
                        final dateCond = cond['date'] != null
                            ? (cond['date'] as Timestamp).toDate()
                            : null;
                        final nbTotalPots = cond['nbTotalPots'] ?? '-';
                        final prixTotal = cond['prixTotal'] ?? '-';
                        final quantiteConditionnee =
                            cond['quantiteConditionnee'] ?? '-';
                        final quantiteRestanteCond =
                            cond['quantiteRestante'] ?? '-';
                        final emballages =
                            cond['emballages'] as List<dynamic>? ?? [];

                        return Container(
                          margin: const EdgeInsets.only(top: 8.0),
                          padding: const EdgeInsets.all(10.0),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle,
                                      color: Colors.green, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Conditionné le : ${dateCond != null ? "${dateCond.day}/${dateCond.month}/${dateCond.year}" : "-"}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text("Total pots/emballages : $nbTotalPots",
                                  style: const TextStyle(fontSize: 14)),
                              Text(
                                  "Quantité conditionnée : $quantiteConditionnee $unite",
                                  style: const TextStyle(fontSize: 14)),
                              Text(
                                  "Quantité restante : $quantiteRestanteCond $unite",
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.red)),
                              Text(
                                  "Prix total : ${prixTotal.toStringAsFixed(0)} FCFA",
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.green)),
                              if (emballages.isNotEmpty) ...[
                                const SizedBox(height: 7),
                                const Text("Détail des emballages :",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                ...emballages.map((e) => Padding(
                                      padding: const EdgeInsets.only(
                                          left: 12, bottom: 2),
                                      child: Row(
                                        children: [
                                          Icon(Icons.bubble_chart,
                                              color: Colors.amber[800],
                                              size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                              "${e['type']} | ${e['mode'] ?? '-'} | ${e['nombre']} x ${e['contenanceKg']}kg",
                                              style: const TextStyle(
                                                  fontSize: 13)),
                                          if (e['prixTotal'] != null)
                                            Text(
                                                " | ${e['prixTotal'].toStringAsFixed(0)} FCFA",
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.teal,
                                                    fontSize: 13)),
                                        ],
                                      ),
                                    )),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  }

                  return Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    color: Colors.white,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 9 : 20,
                        vertical: isMobile ? 10 : 18,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.amber[100],
                                radius: isMobile ? 22 : 28,
                                child: Icon(Icons.bubble_chart,
                                    size: isMobile ? 22 : 26,
                                    color: Colors.amber[900]),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          "Lot filtré ${data['lot'] ?? ''}",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: isMobile ? 15 : 18),
                                        ),
                                        const SizedBox(width: 8),
                                        if (estConditionne)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.green[200],
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              "Conditionné",
                                              style: TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (dateFiltrage != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          "Filtré le : ${dateFiltrage.day}/${dateFiltrage.month}/${dateFiltrage.year}",
                                          style: TextStyle(
                                              fontSize: isMobile ? 12 : 14,
                                              color: Colors.grey[800]),
                                        ),
                                      ),
                                    if (florale.isNotEmpty && florale != '-')
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 3.0),
                                        child: Row(
                                          children: [
                                            Icon(Icons.local_florist,
                                                color: Colors.amber[800],
                                                size: 17),
                                            const SizedBox(width: 4),
                                            Text(
                                              "Florale : $florale",
                                              style: TextStyle(
                                                  fontSize: isMobile ? 12 : 14,
                                                  color: Colors.green[900],
                                                  fontStyle: FontStyle.italic),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 11,
                            runSpacing: 3,
                            children: [
                              Chip(
                                label: Text("Reçue : $quantiteRecue $unite",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500)),
                                backgroundColor: Colors.teal[50],
                              ),
                              Chip(
                                label: Text("Reste : $reste $unite",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.red)),
                                backgroundColor: Colors.red[50],
                              ),
                            ],
                          ),
                          if (infosConditionnement != null)
                            infosConditionnement,
                          if (!estConditionne)
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                icon: const Icon(
                                    Icons.precision_manufacturing_rounded),
                                label: const Text("Conditionner"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber[700],
                                  foregroundColor: Colors.black,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30)),
                                ),
                                onPressed: () {
                                  data['id'] = lot.id;
                                  Get.to(() => ConditionnementEditPage(
                                      lotFiltrage: data));
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
