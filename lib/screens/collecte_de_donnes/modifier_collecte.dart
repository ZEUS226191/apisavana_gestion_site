import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'modifier_collecte_Indiv.dart';
import 'modifier_collecte_SCOOP.dart';
import 'modifier_collecte_recolte.dart';

class EditCollectePage extends StatelessWidget {
  final String collecteId;
  final String collecteType; // "récolte" ou "achat"

  const EditCollectePage({
    required this.collecteId,
    required this.collecteType,
    super.key,
  });

  Future<Map<String, dynamic>> _detectAchatSubTypeAndDocIds() async {
    final docRef =
        FirebaseFirestore.instance.collection('collectes').doc(collecteId);

    // On récupère le premier doc de chaque sous-collec
    final scoopSnap = await docRef.collection('SCOOP').limit(1).get();
    final indivSnap = await docRef.collection('Individuel').limit(1).get();

    // Gestion SCOOPS
    if (scoopSnap.docs.isNotEmpty) {
      final achatDoc = scoopSnap.docs.first;
      final scoopInfoSnap = await docRef
          .collection('SCOOP')
          .doc(achatDoc.id)
          .collection('SCOOP_info')
          .limit(1)
          .get();

      final scoopInfoId =
          scoopInfoSnap.docs.isNotEmpty ? scoopInfoSnap.docs.first.id : null;

      // Récupérer la liste des produits (details)
      final details = (achatDoc.data()['details'] as List?) ?? [];
      // On retourne la liste d'index produits pour édition multiple :
      List<int> indexProduits = [];
      for (var i = 0; i < details.length; i++) {
        final p = details[i];
        if (p is Map && p['typeRuche'] != null && p['typeProduit'] != null) {
          indexProduits.add(i);
        }
      }

      return {
        "type": "achat_scoop",
        "achatDocId": achatDoc.id,
        "infoId": scoopInfoId,
        "details": details,
        "indexProduits": indexProduits,
      };
    }

    // Gestion Individuel
    if (indivSnap.docs.isNotEmpty) {
      final achatDoc = indivSnap.docs.first;
      final indivInfoSnap = await docRef
          .collection('Individuel')
          .doc(achatDoc.id)
          .collection('Individuel_info')
          .limit(1)
          .get();

      final indivInfoId =
          indivInfoSnap.docs.isNotEmpty ? indivInfoSnap.docs.first.id : null;

      final details = (achatDoc.data()['details'] as List?) ?? [];
      List<int> indexProduits = [];
      for (var i = 0; i < details.length; i++) {
        final p = details[i];
        if (p is Map && p['typeRuche'] != null && p['typeProduit'] != null) {
          indexProduits.add(i);
        }
      }

      return {
        "type": "achat_individuel",
        "achatDocId": achatDoc.id,
        "infoId": indivInfoId,
        "details": details,
        "indexProduits": indexProduits,
      };
    }

    return {"type": "achat_inconnu"};
  }

  @override
  Widget build(BuildContext context) {
    if (collecteType == "récolte") {
      return Scaffold(
        appBar: AppBar(title: Text("Modifier la collecte")),
        body: EditRecolteForm(collecteId: collecteId),
      );
    } else if (collecteType == "achat") {
      return FutureBuilder<Map<String, dynamic>>(
        future: _detectAchatSubTypeAndDocIds(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
                appBar: AppBar(title: Text("Modifier la collecte")),
                body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Scaffold(
                appBar: AppBar(title: Text("Modifier la collecte")),
                body: Center(
                    child:
                        Text("Erreur lors de la détection du type d'achat.")));
          }
          final type = snapshot.data?["type"];

          if (type == "achat_scoop") {
            final achatDocId = snapshot.data?["achatDocId"];
            final infoId = snapshot.data?["infoId"];
            final indexProduits = snapshot.data?["indexProduits"] as List<int>;
            // Affichage multi-produits SCOOPS (un formulaire par produit)
            return Scaffold(
              appBar: AppBar(title: Text("Modifier Achat (SCOOPS)")),
              body: ListView.builder(
                padding: EdgeInsets.all(12),
                itemCount: indexProduits.length,
                itemBuilder: (ctx, idx) => Card(
                  margin: EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: EditAchatSCOOPForm(
                      collecteId: collecteId,
                      achatDocId: achatDocId,
                      indexProduit: indexProduits[idx],
                      infoId: infoId,
                    ),
                  ),
                ),
              ),
            );
          } else if (type == "achat_individuel") {
            final achatDocId = snapshot.data?["achatDocId"];
            final infoId = snapshot.data?["infoId"];
            final indexProduits = snapshot.data?["indexProduits"] as List<int>;
            // Affichage multi-produits Individuel (un formulaire par produit)
            return Scaffold(
              appBar: AppBar(title: Text("Modifier Achat (Individuel)")),
              body: ListView.builder(
                padding: EdgeInsets.all(12),
                itemCount: indexProduits.length,
                itemBuilder: (ctx, idx) => Card(
                  margin: EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: EditAchatIndividuelForm(
                      collecteId: collecteId,
                      achatDocId: achatDocId,
                      indexProduit: indexProduits[idx],
                      infoId: infoId,
                    ),
                  ),
                ),
              ),
            );
          } else {
            return Scaffold(
                appBar: AppBar(title: Text("Modifier la collecte")),
                body: Center(
                    child: Text("Impossible de déterminer le type d'achat.")));
          }
        },
      );
    } else {
      return Scaffold(
          appBar: AppBar(title: Text("Modifier la collecte")),
          body: Center(child: Text("Type de collecte inconnu")));
    }
  }
}
