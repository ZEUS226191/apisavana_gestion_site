import 'package:apisavana_gestion/screens/controle_de_donnes/formulaire_controle.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

class ControleController extends GetxController {
  final recoltes = <Map>[].obs;
  final achatsScoops = <Map>[].obs;
  final achatsIndividuels = <Map>[].obs;
  final isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    chargerCollectes();
  }

  Future<void> chargerCollectes() async {
    isLoading.value = true;
    recoltes.clear();
    achatsScoops.clear();
    achatsIndividuels.clear();

    // Récupère tous les contrôles existants (pour tous les produits)
    final controleSnap =
        await FirebaseFirestore.instance.collection('Controle').get();
    final controles = controleSnap.docs.map((doc) => doc.data()).toList();

    final collSnapshot =
        await FirebaseFirestore.instance.collection('collectes').get();

    for (final doc in collSnapshot.docs) {
      final data = doc.data();
      final type = data['type'];
      final dateCollecte = (data['dateCollecte'] as Timestamp?)?.toDate();
      final utilisateur = data['utilisateurNom'] ?? "";

      // RÉCOLTE (multi-produits)
      if (type == 'récolte') {
        final sousColl = await doc.reference.collection('Récolte').get();
        for (final rec in sousColl.docs) {
          final r = rec.data();
          final details = r['details'] as List?;
          if (details != null && details.isNotEmpty) {
            for (int i = 0; i < details.length; i++) {
              final detail = details[i];
              // Ne pas ajouter si ce produit est déjà contrôlé
              final isControlled = controles.any((ctrl) =>
                  ctrl['collecteId'] == doc.id &&
                  ctrl['recId'] == rec.id &&
                  ctrl['detailIndex'] == i);
              if (isControlled) continue;
              recoltes.add({
                'id': doc.id,
                'recId': rec.id,
                'detailIndex': i,
                'producteurNom': r['nomRecolteur'] ?? "",
                'producteurType': 'Récolteur',
                'village': r['village'] ?? "",
                'commune': r['commune'] ?? "",
                'quartier': r['quartier'] ?? "",
                'dateCollecte': dateCollecte,
                'typeProduit': detail['typeProduit'] ?? "",
                'typeRuche': detail['typeRuche'] ?? "",
                'quantite': detail['quantite'] ?? 0,
                'unite': detail['unite'] ?? "",
                'predominanceFlorale': detail['predominanceFlorale'] ??
                    r['predominanceFlorale'] ??
                    "",
                'utilisateur': utilisateur,
                'source': 'Récolte',
              });
            }
          } else {
            // Ancien modèle : un seul produit par doc
            final isControlled = controles.any((ctrl) =>
                ctrl['collecteId'] == doc.id &&
                ctrl['recId'] == rec.id &&
                (ctrl['detailIndex'] == null || ctrl['detailIndex'] == 0));
            if (isControlled) continue;
            recoltes.add({
              'id': doc.id,
              'recId': rec.id,
              'detailIndex': null,
              'producteurNom': r['nomRecolteur'] ?? "",
              'producteurType': 'Récolteur',
              'village': r['village'] ?? "",
              'commune': r['commune'] ?? "",
              'quartier': r['quartier'] ?? "",
              'dateCollecte': dateCollecte,
              'typeProduit': r['typeProduit'] ?? "",
              'typeRuche': r['typeRuche'] ?? "",
              'quantite': r['quantiteKg'] ?? 0,
              'unite': 'kg',
              'predominanceFlorale': r['predominanceFlorale'] ?? "",
              'utilisateur': utilisateur,
              'source': 'Récolte',
            });
          }
        }
      }

      // ACHAT SCOOPS (multi-produits)
      if (type == 'achat') {
        final scoopsColl = await doc.reference.collection('SCOOP').get();
        for (final achat in scoopsColl.docs) {
          final a = achat.data();
          final fournisseurColl =
              await achat.reference.collection('SCOOP_info').get();
          final fournisseur = fournisseurColl.docs.isNotEmpty
              ? fournisseurColl.docs.first.data()
              : {};
          final List details = a['details'] is List ? a['details'] : [];
          if (details.isNotEmpty) {
            for (int i = 0; i < details.length; i++) {
              final detail = details[i];
              final isControlled = controles.any((ctrl) =>
                  ctrl['collecteId'] == doc.id &&
                  ctrl['achatId'] == achat.id &&
                  ctrl['detailIndex'] == i);
              if (isControlled) continue;
              achatsScoops.add({
                'id': doc.id,
                'achatId': achat.id,
                'detailIndex': i,
                'producteurNom': fournisseur['nom'] ?? "",
                'producteurType': 'SCOOPS',
                'nomPresident': fournisseur['nomPresident'] ?? "",
                'village': fournisseur['village'] ?? "",
                'commune': fournisseur['commune'] ?? "",
                'quartier': fournisseur['quartier'] ?? "",
                'dateCollecte': dateCollecte,
                'dateAchat': (a['dateAchat'] as Timestamp?)?.toDate(),
                'typeProduit': detail['typeProduit'] ?? "",
                'typeRuche': detail['typeRuche'] ?? "",
                'quantite': detail['quantiteAcceptee'] ?? 0,
                'quantiteRejetee': detail['quantiteRejetee'] ?? 0,
                'unite': detail['unite'] ?? "",
                'prixUnitaire': detail['prixUnitaire'] ?? "",
                'prixTotal': detail['prixTotal'] ?? "",
                'predominanceFlorale': fournisseur['predominanceFlorale'] ?? "",
                'utilisateur': utilisateur,
                'source': 'AchatSCOOPS',
              });
            }
          } else {
            // fallback : ancienne structure
            final isControlled = controles.any((ctrl) =>
                ctrl['collecteId'] == doc.id &&
                ctrl['achatId'] == achat.id &&
                (ctrl['detailIndex'] == null || ctrl['detailIndex'] == 0));
            if (isControlled) continue;
            achatsScoops.add({
              'id': doc.id,
              'achatId': achat.id,
              'detailIndex': null,
              'producteurNom': fournisseur['nom'] ?? "",
              'producteurType': 'SCOOPS',
              'nomPresident': fournisseur['nomPresident'] ?? "",
              'village': fournisseur['village'] ?? "",
              'commune': fournisseur['commune'] ?? "",
              'quartier': fournisseur['quartier'] ?? "",
              'dateCollecte': dateCollecte,
              'dateAchat': (a['dateAchat'] as Timestamp?)?.toDate(),
              'typeProduit': a['typeProduit'] ?? "",
              'typeRuche': a['typeRuche'] ?? "",
              'quantite': a['quantite'] ?? 0,
              'quantiteRejetee': a['quantiteRejetee'] ?? 0,
              'unite': a['unite'] ?? "",
              'prixUnitaire': a['prixUnitaire'] ?? "",
              'prixTotal': a['prixTotal'] ?? "",
              'predominanceFlorale': fournisseur['predominanceFlorale'] ?? "",
              'utilisateur': utilisateur,
              'source': 'AchatSCOOPS',
            });
          }
        }

        // INDIVIDUEL (multi-produits)
        final indColl = await doc.reference.collection('Individuel').get();
        for (final achat in indColl.docs) {
          final a = achat.data();
          final fournisseurColl =
              await achat.reference.collection('Individuel_info').get();
          final fournisseur = fournisseurColl.docs.isNotEmpty
              ? fournisseurColl.docs.first.data()
              : {};
          final List details = a['details'] is List ? a['details'] : [];
          if (details.isNotEmpty) {
            for (int i = 0; i < details.length; i++) {
              final detail = details[i];
              final isControlled = controles.any((ctrl) =>
                  ctrl['collecteId'] == doc.id &&
                  ctrl['achatId'] == achat.id &&
                  ctrl['detailIndex'] == i);
              if (isControlled) continue;
              achatsIndividuels.add({
                'id': doc.id,
                'achatId': achat.id,
                'detailIndex': i,
                'producteurNom': fournisseur['nomPrenom'] ?? "",
                'producteurType': 'Individuel',
                'village': fournisseur['village'] ?? "",
                'commune': fournisseur['commune'] ?? "",
                'quartier': fournisseur['quartier'] ?? "",
                'dateCollecte': dateCollecte,
                'dateAchat': (a['dateAchat'] as Timestamp?)?.toDate(),
                'typeProduit': detail['typeProduit'] ?? "",
                'typeRuche': detail['typeRuche'] ?? "",
                'quantite': detail['quantiteAcceptee'] ?? 0,
                'quantiteRejetee': detail['quantiteRejetee'] ?? 0,
                'unite': detail['unite'] ?? "",
                'prixUnitaire': detail['prixUnitaire'] ?? "",
                'prixTotal': detail['prixTotal'] ?? "",
                'predominanceFlorale': fournisseur['predominanceFlorale'] ?? "",
                'utilisateur': utilisateur,
                'source': 'AchatIndividuel',
              });
            }
          } else {
            // fallback ancienne structure
            final isControlled = controles.any((ctrl) =>
                ctrl['collecteId'] == doc.id &&
                ctrl['achatId'] == achat.id &&
                (ctrl['detailIndex'] == null || ctrl['detailIndex'] == 0));
            if (isControlled) continue;
            achatsIndividuels.add({
              'id': doc.id,
              'achatId': achat.id,
              'detailIndex': null,
              'producteurNom': fournisseur['nomPrenom'] ?? "",
              'producteurType': 'Individuel',
              'village': fournisseur['village'] ?? "",
              'commune': fournisseur['commune'] ?? "",
              'quartier': fournisseur['quartier'] ?? "",
              'dateCollecte': dateCollecte,
              'dateAchat': (a['dateAchat'] as Timestamp?)?.toDate(),
              'typeProduit': a['typeProduit'] ?? "",
              'typeRuche': a['typeRuche'] ?? "",
              'quantite': a['quantite'] ?? 0,
              'quantiteRejetee': a['quantiteRejetee'] ?? 0,
              'unite': a['unite'] ?? "",
              'prixUnitaire': a['prixUnitaire'] ?? "",
              'prixTotal': a['prixTotal'] ?? "",
              'predominanceFlorale': fournisseur['predominanceFlorale'] ?? "",
              'utilisateur': utilisateur,
              'source': 'AchatIndividuel',
            });
          }
        }
      }
    }
    isLoading.value = false;
  }

  void goToControle(BuildContext context, Map collecte, String type) async {
    final result =
        await Get.to(() => ControleFormPage(collecte: collecte, type: type));
    if (result == true) {
      await chargerCollectes();
    }
  }
}
