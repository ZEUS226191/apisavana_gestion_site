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

  Future<Map<String, String?>> _detectAchatSubTypeAndDocIds() async {
    final docRef =
        FirebaseFirestore.instance.collection('collectes').doc(collecteId);

    // On récupère le premier doc de chaque sous-collec
    final futures = [
      docRef.collection('SCOOP').limit(1).get(),
      docRef.collection('Individuel').limit(1).get(),
    ];
    final results = await Future.wait(futures);

    if (results[0].docs.isNotEmpty) {
      final achatId = results[0].docs.first.id;
      // On récupère le premier doc de SCOOP_info
      final scoopInfoSnap = await docRef
          .collection('SCOOP')
          .doc(achatId)
          .collection('SCOOP_info')
          .limit(1)
          .get();
      final scoopInfoId =
          scoopInfoSnap.docs.isNotEmpty ? scoopInfoSnap.docs.first.id : null;
      return {"type": "achat_scoop", "achatId": achatId, "infoId": scoopInfoId};
    }
    if (results[1].docs.isNotEmpty) {
      final achatId = results[1].docs.first.id;
      // On récupère le premier doc de Individuel_info
      final indivInfoSnap = await docRef
          .collection('Individuel')
          .doc(achatId)
          .collection('Individuel_info')
          .limit(1)
          .get();
      final indivInfoId =
          indivInfoSnap.docs.isNotEmpty ? indivInfoSnap.docs.first.id : null;
      return {
        "type": "achat_individuel",
        "achatId": achatId,
        "infoId": indivInfoId
      };
    }
    return {"type": "achat_inconnu", "achatId": null, "infoId": null};
  }

  @override
  Widget build(BuildContext context) {
    if (collecteType == "récolte") {
      return Scaffold(
        appBar: AppBar(title: Text("Modifier la collecte")),
        body: EditRecolteForm(collecteId: collecteId),
      );
    } else if (collecteType == "achat") {
      return FutureBuilder<Map<String, String?>>(
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
          final achatId = snapshot.data?["achatId"];
          final infoId = snapshot.data?["infoId"];

          if (type == "achat_scoop" && achatId != null && infoId != null) {
            return Scaffold(
                appBar: AppBar(title: Text("Modifier la collecte (SCOOPS)")),
                body: EditAchatSCOOPForm(
                    collecteId: collecteId, achatId: achatId, infoId: infoId));
          } else if (type == "achat_individuel" &&
              achatId != null &&
              infoId != null) {
            return Scaffold(
                appBar:
                    AppBar(title: Text("Modifier la collecte (Individuel)")),
                body: EditAchatIndividuelForm(
                    collecteId: collecteId, achatId: achatId, infoId: infoId));
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
