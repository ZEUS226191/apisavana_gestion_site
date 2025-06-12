import 'package:apisavana_gestion/screens/controle_de_donnes/formulaire_controle.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

class ControleController extends GetxController {
  final recoltes = <Map>[].obs;
  final achatsScoops = <Map>[].obs;
  final achatsIndividuels = <Map>[].obs;
  final isLoading = true.obs; // <= ici

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

    final collSnapshot =
        await FirebaseFirestore.instance.collection('collectes').get();

    for (final doc in collSnapshot.docs) {
      final data = doc.data();
      final type = data['type'];
      final controle = data['controle'] ?? false;
      final dateCollecte = (data['dateCollecte'] as Timestamp?)?.toDate();
      final utilisateur = data['utilisateurNom'] ?? "";

      // On ne montre que les collectes NON contrôlées
      if (controle == true) continue;

      // RÉCOLTE classique
      if (type == 'récolte') {
        final sousColl = await doc.reference.collection('Récolte').get();
        for (final rec in sousColl.docs) {
          final r = rec.data();
          recoltes.add({
            'id': doc.id,
            'producteurNom': r['nomRecolteur'] ?? "",
            'producteurType': 'Récolteur',
            'village': r['village'] ?? "",
            'dateCollecte': dateCollecte,
            'typeProduit': "Miel",
            'quantite': r['quantiteKg'] ?? 0,
            'unite': 'kg',
            'predominanceFlorale': r['predominanceFlorale'] ?? "",
            'utilisateur': utilisateur,
            'source': 'Récolte',
          });
        }
      }

      // ACHAT SCOOPS (données multi-produits)
      if (type == 'achat') {
        // --- SCOOPS ---
        final scoopsColl = await doc.reference.collection('SCOOP').get();
        for (final achat in scoopsColl.docs) {
          final a = achat.data();
          final fournisseurColl =
              await achat.reference.collection('SCOOP_info').get();
          final fournisseur = fournisseurColl.docs.isNotEmpty
              ? fournisseurColl.docs.first.data()
              : {};
          // --- NOUVEAU : unfold du tableau details ---
          final List details = a['details'] is List ? a['details'] : [];
          if (details.isNotEmpty) {
            for (final detail in details) {
              achatsScoops.add({
                'id': doc.id,
                'producteurNom': fournisseur['nom'] ?? "",
                'producteurType': 'SCOOPS',
                'nomPresident': fournisseur['nomPresident'] ?? "",
                'village': fournisseur['village'] ?? "",
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
            achatsScoops.add({
              'id': doc.id,
              'producteurNom': fournisseur['nom'] ?? "",
              'producteurType': 'SCOOPS',
              'nomPresident': fournisseur['nomPresident'] ?? "",
              'village': fournisseur['village'] ?? "",
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

        // --- INDIVIDUEL ---
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
            for (final detail in details) {
              achatsIndividuels.add({
                'id': doc.id,
                'producteurNom': fournisseur['nomPrenom'] ?? "",
                'producteurType': 'Individuel',
                'village': fournisseur['village'] ?? "",
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
            achatsIndividuels.add({
              'id': doc.id,
              'producteurNom': fournisseur['nomPrenom'] ?? "",
              'producteurType': 'Individuel',
              'village': fournisseur['village'] ?? "",
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
    // Attend le résultat de la page formulaire
    final result =
        await Get.to(() => ControleFormPage(collecte: collecte, type: type));
    if (result == true) {
      // Si le formulaire a enregistré et qu'on a pop avec "true"
      await chargerCollectes();
    }
  }
}
