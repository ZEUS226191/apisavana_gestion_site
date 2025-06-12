import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:get/get.dart';

class FiltrageController extends GetxController {
  final recoltes = <Map>[].obs;
  final achatsScoops = <Map>[].obs;
  final achatsIndividuels = <Map>[].obs;
  final isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    chargerCollectesFiltrables();
  }

  Future<void> chargerCollectesFiltrables() async {
    isLoading.value = true;
    recoltes.clear();
    achatsScoops.clear();
    achatsIndividuels.clear();

    // 1. Récupère toutes les extractions
    final extractionsSnap =
        await FirebaseFirestore.instance.collection('extraction').get();
    final extractions = extractionsSnap.docs.map((doc) => doc.data()).toList();

    // 2. Récupère tous les filtrages déjà faits
    final filtragesSnap =
        await FirebaseFirestore.instance.collection('filtrage').get();
    final filtrages = filtragesSnap.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();

    // 3. Récupère tous les contrôles validés
    final controleSnap =
        await FirebaseFirestore.instance.collection('Controle').get();

    // ========= Ajout des collectes issues d'une extraction totale =========
    for (final controleDoc in controleSnap.docs) {
      final controle = controleDoc.data();
      final collecteId = controle['collecteId'];
      final numeroLot = controle['numeroLot'];

      final collecteSnap = await FirebaseFirestore.instance
          .collection('collectes')
          .doc(collecteId)
          .get();
      if (!collecteSnap.exists) continue;
      final collecte = collecteSnap.data()!;
      final type = collecte['type']?.toString()?.toLowerCase();
      final dateCollecte = (collecte['dateCollecte'] as Timestamp?)?.toDate();
      final utilisateur = collecte['utilisateurNom'] ?? "";

      final extraction = extractions.firstWhereOrNull(
        (e) =>
            e['collecteId'] == collecteId &&
            e['statutExtraction'] == "Entièrement Extraite",
      );
      final filtrage = filtrages.firstWhereOrNull(
        (f) => f['collecteId'] == collecteId,
      );

      // ===== RECOLTE =====
      if (type == "récolte") {
        final sousColl =
            await collecteSnap.reference.collection('Récolte').get();
        for (final sousDoc in sousColl.docs) {
          if (extraction != null) {
            final r = sousDoc.data();
            final extractionExpiration =
                extraction['expirationExtraction'] is Timestamp
                    ? (extraction['expirationExtraction'] as Timestamp).toDate()
                    : null;
            final extractionExpiree = extractionExpiration != null &&
                extractionExpiration.isBefore(DateTime.now());

            recoltes.add({
              'id': collecteId,
              'numeroLot': numeroLot,
              'producteurNom': r['nomRecolteur'] ?? "",
              'village': r['village'] ?? "",
              'dateCollecte': dateCollecte,
              'typeProduit': "Miel Filtré",
              'quantite': extraction['quantiteFiltree'] ?? 0,
              'unite': 'kg',
              'predominanceFlorale': r['predominanceFlorale'] ?? "",
              'dateControle':
                  (controle['dateControle'] as Timestamp?)?.toDate(),
              'utilisateur': utilisateur,
              'statutFiltrage': filtrage?['statutFiltrage'] ?? "Non filtré",
              'quantiteEntree': filtrage?['quantiteEntree'],
              'quantiteFiltree': filtrage?['quantiteFiltree'],
              'dateFiltrage': filtrage?['dateFiltrage'] is Timestamp
                  ? (filtrage?['dateFiltrage'] as Timestamp).toDate()
                  : null,
              'expirationExtraction': extractionExpiration,
              'extractionExpiree': extractionExpiree,
              'filtrageId': filtrage?['id'],
            });
          }
        }
      }

      // ===== ACHAT - SCOOPS =====
      if (type == "achat") {
        // SCOOPS
        final scoopsColl =
            await collecteSnap.reference.collection('SCOOP').get();
        for (final achat in scoopsColl.docs) {
          if (extraction != null) {
            final a = achat.data();
            final fournisseurColl =
                await achat.reference.collection('SCOOP_info').get();
            final fournisseur = fournisseurColl.docs.isNotEmpty
                ? fournisseurColl.docs.first.data()
                : {};
            final extractionExpiration =
                extraction['expirationExtraction'] is Timestamp
                    ? (extraction['expirationExtraction'] as Timestamp).toDate()
                    : null;
            final extractionExpiree = extractionExpiration != null &&
                extractionExpiration.isBefore(DateTime.now());

            achatsScoops.add({
              'id': collecteId,
              'numeroLot': numeroLot,
              'producteurNom': fournisseur['nom'] ?? "",
              'village': fournisseur['localite'] ?? "",
              'dateCollecte': dateCollecte,
              'typeProduit': a['typeProduit'] ?? "Miel Filtré",
              'quantite': extraction['quantiteFiltree'] ?? 0,
              'unite': a['unite'] ?? '',
              'predominanceFlorale': fournisseur['predominanceFlorale'] ?? "",
              'dateControle':
                  (controle['dateControle'] as Timestamp?)?.toDate(),
              'utilisateur': utilisateur,
              'statutFiltrage': filtrage?['statutFiltrage'] ?? "Non filtré",
              'quantiteEntree': filtrage?['quantiteEntree'],
              'quantiteFiltree': filtrage?['quantiteFiltree'],
              'dateFiltrage': filtrage?['dateFiltrage'] is Timestamp
                  ? (filtrage?['dateFiltrage'] as Timestamp).toDate()
                  : null,
              'expirationExtraction': extractionExpiration,
              'extractionExpiree': extractionExpiree,
              'filtrageId': filtrage?['id'],
            });
          }
        }
        // ===== ACHAT - INDIVIDUEL =====
        final indColl =
            await collecteSnap.reference.collection('Individuel').get();
        for (final achat in indColl.docs) {
          if (extraction != null) {
            final a = achat.data();
            final fournisseurColl =
                await achat.reference.collection('Individuel_info').get();
            final fournisseur = fournisseurColl.docs.isNotEmpty
                ? fournisseurColl.docs.first.data()
                : {};
            final extractionExpiration =
                extraction['expirationExtraction'] is Timestamp
                    ? (extraction['expirationExtraction'] as Timestamp).toDate()
                    : null;
            final extractionExpiree = extractionExpiration != null &&
                extractionExpiration.isBefore(DateTime.now());

            achatsIndividuels.add({
              'id': collecteId,
              'numeroLot': numeroLot,
              'producteurNom': fournisseur['nomPrenom'] ?? "",
              'village': fournisseur['localite'] ?? "",
              'dateCollecte': dateCollecte,
              'typeProduit': a['typeProduit'] ?? "Miel Filtré",
              'quantite': extraction['quantiteFiltree'] ?? 0,
              'unite': a['unite'] ?? '',
              'predominanceFlorale': fournisseur['predominanceFlorale'] ?? "",
              'dateControle':
                  (controle['dateControle'] as Timestamp?)?.toDate(),
              'utilisateur': utilisateur,
              'statutFiltrage': filtrage?['statutFiltrage'] ?? "Non filtré",
              'quantiteEntree': filtrage?['quantiteEntree'],
              'quantiteFiltree': filtrage?['quantiteFiltree'],
              'dateFiltrage': filtrage?['dateFiltrage'] is Timestamp
                  ? (filtrage?['dateFiltrage'] as Timestamp).toDate()
                  : null,
              'expirationExtraction': extractionExpiration,
              'extractionExpiree': extractionExpiree,
              'filtrageId': filtrage?['id'],
            });
          }
        }
      }
    }

    // ========= Ajout des collectes contrôlées "Miel filtré" SANS extraction =========
    final collectesSnap = await FirebaseFirestore.instance
        .collection('collectes')
        .where('controle', isEqualTo: true)
        .get();

    for (final doc in collectesSnap.docs) {
      final collecte = doc.data();
      final collecteId = doc.id;
      final type = collecte['type']?.toString()?.toLowerCase();

      // On cherche le controle associé
      final controle = controleSnap.docs
          .map((d) => d.data())
          .firstWhereOrNull((c) => c['collecteId'] == collecteId);

      if (controle == null) {
        Get.snackbar("Contrôle manquant",
            "Aucun contrôle trouvé pour la collecte $collecteId",
            duration: Duration(seconds: 5));
        continue;
      }

      // Pour les achats, le typeProduit est dans la sous-collection, donc on ne teste pas ici
      if (type == 'récolte') {
        final sousColl = await doc.reference.collection('Récolte').get();
        for (final sousDoc in sousColl.docs) {
          final r = sousDoc.data();
          final typeProduit = r['typeProduit']?.toString()?.toLowerCase();
          if (typeProduit == null) {
            Get.snackbar("Type produit absent",
                "Le typeProduit est manquant dans une Récolte de $collecteId",
                duration: Duration(seconds: 5));
            continue;
          }
          if (typeProduit != 'miel filtré') {
            // Pas grave de ne pas notifier ici, mais tu peux log si besoin
            continue;
          }
          final filtrage = filtrages.firstWhereOrNull(
            (f) => f['collecteId'] == collecteId,
          );
          recoltes.add({
            'id': collecteId,
            'numeroLot': controle['numeroLot'],
            'producteurNom': r['nomRecolteur'] ?? "",
            'village': r['village'] ?? "",
            'dateCollecte': (collecte['dateCollecte'] as Timestamp?)?.toDate(),
            'typeProduit': "Miel Filtré",
            'quantite': r['quantiteKg'] ?? 0,
            'unite': 'kg',
            'predominanceFlorale': r['predominanceFlorale'] ?? "",
            'dateControle': (controle['dateControle'] as Timestamp?)?.toDate(),
            'utilisateur': collecte['utilisateurNom'] ?? "",
            'statutFiltrage': filtrage?['statutFiltrage'] ?? "Non filtré",
            'quantiteEntree': filtrage?['quantiteEntree'],
            'quantiteFiltree': filtrage?['quantiteFiltree'],
            'dateFiltrage': filtrage?['dateFiltrage'] is Timestamp
                ? (filtrage?['dateFiltrage'] as Timestamp).toDate()
                : null,
            'filtrageId': filtrage?['id'],
          });
        }
      } else if (type == 'achat') {
        // SCOOPS
        final scoopsColl = await doc.reference.collection('SCOOP').get();
        for (final achat in scoopsColl.docs) {
          final a = achat.data();
          final typeProduit = a['typeProduit']?.toString()?.toLowerCase();
          if (typeProduit == null) {
            Get.snackbar("Type produit absent",
                "Le typeProduit est manquant dans un achat SCOOP de $collecteId",
                duration: Duration(seconds: 5));
            continue;
          }
          if (typeProduit != "miel filtré") {
            // Get.snackbar("Type Produit différent", "type produit: $typeProduit (SCOOP $collecteId)", duration: Duration(seconds: 3));
            continue;
          }
          final fournisseurColl =
              await achat.reference.collection('SCOOP_info').get();
          final fournisseur = fournisseurColl.docs.isNotEmpty
              ? fournisseurColl.docs.first.data()
              : {};
          final filtrage = filtrages.firstWhereOrNull(
            (f) => f['collecteId'] == collecteId,
          );
          achatsScoops.add({
            'id': collecteId,
            'numeroLot': controle['numeroLot'],
            'producteurNom': fournisseur['nom'] ?? "",
            'village': fournisseur['localite'] ?? "",
            'dateCollecte': (collecte['dateCollecte'] as Timestamp?)?.toDate(),
            'typeProduit': a['typeProduit'] ?? "Miel Filtré",
            'quantite': a['quantite'] ?? 0,
            'unite': a['unite'] ?? '',
            'predominanceFlorale': fournisseur['predominanceFlorale'] ?? "",
            'dateControle': (controle['dateControle'] as Timestamp?)?.toDate(),
            'utilisateur': collecte['utilisateurNom'] ?? "",
            'statutFiltrage': filtrage?['statutFiltrage'] ?? "Non filtré",
            'quantiteEntree': filtrage?['quantiteEntree'],
            'quantiteFiltree': filtrage?['quantiteFiltree'],
            'dateFiltrage': filtrage?['dateFiltrage'] is Timestamp
                ? (filtrage?['dateFiltrage'] as Timestamp).toDate()
                : null,
            'filtrageId': filtrage?['id'],
          });
        }
        // INDIVIDUEL
        final indColl = await doc.reference.collection('Individuel').get();
        for (final achat in indColl.docs) {
          final a = achat.data();
          final typeProduit = a['typeProduit']?.toString()?.toLowerCase();
          if (typeProduit == null) {
            Get.snackbar("Type produit absent",
                "Le typeProduit est manquant dans un achat Individuel de $collecteId",
                duration: Duration(seconds: 5));
            continue;
          }
          if (typeProduit != "miel filtré") {
            // Get.snackbar("Type Produit différent", "type produit: $typeProduit (Ind $collecteId)", duration: Duration(seconds: 3));
            continue;
          }
          final fournisseurColl =
              await achat.reference.collection('Individuel_info').get();
          final fournisseur = fournisseurColl.docs.isNotEmpty
              ? fournisseurColl.docs.first.data()
              : {};
          final filtrage = filtrages.firstWhereOrNull(
            (f) => f['collecteId'] == collecteId,
          );
          achatsIndividuels.add({
            'id': collecteId,
            'numeroLot': controle['numeroLot'],
            'producteurNom': fournisseur['nomPrenom'] ?? "",
            'village': fournisseur['localite'] ?? "",
            'dateCollecte': (collecte['dateCollecte'] as Timestamp?)?.toDate(),
            'typeProduit': a['typeProduit'] ?? "Miel Filtré",
            'quantite': a['quantite'] ?? 0,
            'unite': a['unite'] ?? '',
            'predominanceFlorale': fournisseur['predominanceFlorale'] ?? "",
            'dateControle': (controle['dateControle'] as Timestamp?)?.toDate(),
            'utilisateur': collecte['utilisateurNom'] ?? "",
            'statutFiltrage': filtrage?['statutFiltrage'] ?? "Non filtré",
            'quantiteEntree': filtrage?['quantiteEntree'],
            'quantiteFiltree': filtrage?['quantiteFiltree'],
            'dateFiltrage': filtrage?['dateFiltrage'] is Timestamp
                ? (filtrage?['dateFiltrage'] as Timestamp).toDate()
                : null,
            'filtrageId': filtrage?['id'],
          });
        }
      }
    }

    // Liste toutes les collectes à vérifier (même si pas filtrées du tout)
    final allCollectes = [...recoltes, ...achatsScoops, ...achatsIndividuels];

    for (final collecte in allCollectes) {
      final collecteId = collecte['id']?.toString();
      final numeroLot = collecte['numeroLot']?.toString() ?? '';
      final quantiteRecu =
          double.tryParse(collecte['quantite']?.toString() ?? '0') ?? 0;
      final unite = collecte['unite'] ?? 'kg';

      // Vérifie si la collecte existe déjà dans la collection filtrage
      final dejaFiltrage = filtrages.firstWhereOrNull(
        (f) => f['collecteId']?.toString() == collecteId,
      );

      if (dejaFiltrage == null) {
        // Crée un doc filtrage par défaut
        await FirebaseFirestore.instance.collection('filtrage').add({
          "collecteId": collecteId,
          "lot": numeroLot,
          "quantiteEntree": 0.0,
          "quantiteFiltree": 0.0,
          "quantiteRecu": quantiteRecu,
          "unite": unite,
          "statutFiltrage": "Non filtré",
          "dateFiltrage": null,
          "createdAt": DateTime.now(),
        });
      }
    }

    isLoading.value = false;
  }

  /// Enregistre dans la collection filtrage toutes les collectes listées,
  /// si absentes (pas de doc filtrage pour cette collecteId).
}
