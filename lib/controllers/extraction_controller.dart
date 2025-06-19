import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class ExtractionController extends GetxController {
  final recoltes = <Map>[].obs;
  final achatsScoops = <Map>[].obs;
  final achatsIndividuels = <Map>[].obs;
  final isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    chargerCollectesControlees();
  }

  Future<void> chargerCollectesControlees() async {
    isLoading.value = true;
    recoltes.clear();
    achatsScoops.clear();
    achatsIndividuels.clear();

    // On récupère toutes les extractions (pour tous les produits)
    final extractionsSnap =
        await FirebaseFirestore.instance.collection('extraction').get();
    final extractions = extractionsSnap.docs.map((doc) => doc.data()).toList();

    // 1. On récupère tous les contrôles validés (par produit)
    final controleSnap =
        await FirebaseFirestore.instance.collection('Controle').get();

    for (final controleDoc in controleSnap.docs) {
      final controle = controleDoc.data();
      final collecteId = controle['collecteId'];
      final recId = controle['recId'];
      final achatId = controle['achatId'];
      final detailIndex = controle['detailIndex'];
      final numeroLot = controle['numeroLot'];
      final typeCollecte = controle['typeCollecte'];
      final poidsMiel =
          controle['poidsMiel'] ?? 0; // <-- le poids calculé au contrôle

      // 2. On récupère la collecte associée pour plus d'infos
      final collecteSnap = await FirebaseFirestore.instance
          .collection('collectes')
          .doc(collecteId)
          .get();
      if (!collecteSnap.exists) continue;
      final collecte = collecteSnap.data()!;
      final dateCollecte = (collecte['dateCollecte'] as Timestamp?)?.toDate();
      final utilisateur = collecte['utilisateurNom'] ?? "";

      // --- Cherche la DERNIÈRE extraction pour CE produit (avec detailIndex, recId/achatId)
      Map<String, dynamic>? extraction;
      for (final e in extractions) {
        if (e['collecteId'] == collecteId &&
            (e['detailIndex'] == detailIndex ||
                (e['detailIndex'] == null && detailIndex == null)) &&
            (recId == null || e['recId'] == recId) &&
            (achatId == null || e['achatId'] == achatId)) {
          if (extraction == null) {
            extraction = e;
          } else {
            final prev = extraction['dateExtraction'];
            final curr = e['dateExtraction'];
            if ((curr is Timestamp ? curr.toDate() : null) != null &&
                (prev == null ||
                    ((curr is Timestamp ? curr.toDate() : null)!.isAfter(
                        prev is Timestamp ? prev.toDate() : DateTime(2000))))) {
              extraction = e;
            }
          }
        }
      }
      extraction ??= {};

      // 3. Selon le type, on va chercher les bons détails
      if (typeCollecte == "Récolte") {
        final sousColl =
            await collecteSnap.reference.collection('Récolte').get();
        for (final rec in sousColl.docs) {
          if (recId != null && rec.id != recId) continue;
          final r = rec.data();
          final details = r['details'] as List?;
          if (details != null && detailIndex != null) {
            final detail = (detailIndex >= 0 && detailIndex < details.length)
                ? details[detailIndex]
                : null;
            if (detail == null) continue;
            final extractionExpiration =
                extraction['expirationExtraction'] is Timestamp
                    ? (extraction['expirationExtraction'] as Timestamp).toDate()
                    : null;
            final extractionExpiree = extractionExpiration != null &&
                extractionExpiration.isBefore(DateTime.now());
            recoltes.add({
              'id': collecteId,
              'recId': recId,
              'detailIndex': detailIndex,
              'numeroLot': numeroLot,
              'producteurNom': r['nomRecolteur'] ?? "",
              'producteurType': 'Récolteur',
              'village': r['village'] ?? "",
              'commune': r['commune'] ?? "",
              'quartier': r['quartier'] ?? "",
              'dateCollecte': dateCollecte,
              'typeProduit': detail['typeProduit'] ?? "",
              'typeRuche': detail['typeRuche'] ?? "",
              // === ici on prend le poidsMiel du contrôle ===
              'quantite': poidsMiel,
              'unite': detail['unite'] ?? "",
              'predominanceFlorale': detail['predominanceFlorale'] ??
                  r['predominanceFlorale'] ??
                  "",
              'dateControle':
                  (controle['dateControle'] as Timestamp?)?.toDate(),
              'utilisateur': utilisateur,
              'source': 'Récolte',
              'statutExtraction':
                  extraction['statutExtraction'] ?? "Non extraite",
              'quantiteRestante': extraction['quantiteRestante'],
              'quantiteFiltree': extraction['quantiteFiltree'],
              'quantiteEntree': extraction['quantiteEntree'],
              'dechets': extraction['dechets'],
              'dateExtraction': extraction['dateExtraction'] is Timestamp
                  ? (extraction['dateExtraction'] as Timestamp).toDate()
                  : null,
              'technologie': extraction['technologie'],
              'extrait':
                  extraction['statutExtraction'] == "Entièrement Extraite",
              'expirationExtraction': extractionExpiration,
              'extractionExpiree': extractionExpiree,
            });
          } else if (details == null) {
            // Ancien modèle (pas de details, un seul produit)
            final extractionExpiration =
                extraction['expirationExtraction'] is Timestamp
                    ? (extraction['expirationExtraction'] as Timestamp).toDate()
                    : null;
            final extractionExpiree = extractionExpiration != null &&
                extractionExpiration.isBefore(DateTime.now());
            recoltes.add({
              'id': collecteId,
              'recId': recId,
              'detailIndex': null,
              'numeroLot': numeroLot,
              'producteurNom': r['nomRecolteur'] ?? "",
              'producteurType': 'Récolteur',
              'village': r['village'] ?? "",
              'commune': r['commune'] ?? "",
              'quartier': r['quartier'] ?? "",
              'dateCollecte': dateCollecte,
              'typeProduit': r['typeProduit'] ?? "",
              'typeRuche': r['typeRuche'] ?? "",
              // === ici aussi ===
              'quantite': poidsMiel,
              'unite': 'kg',
              'predominanceFlorale': r['predominanceFlorale'] ?? "",
              'dateControle':
                  (controle['dateControle'] as Timestamp?)?.toDate(),
              'utilisateur': utilisateur,
              'source': 'Récolte',
              'statutExtraction':
                  extraction['statutExtraction'] ?? "Non extraite",
              'quantiteRestante': extraction['quantiteRestante'],
              'quantiteFiltree': extraction['quantiteFiltree'],
              'quantiteEntree': extraction['quantiteEntree'],
              'dechets': extraction['dechets'],
              'dateExtraction': extraction['dateExtraction'] is Timestamp
                  ? (extraction['dateExtraction'] as Timestamp).toDate()
                  : null,
              'technologie': extraction['technologie'],
              'extrait':
                  extraction['statutExtraction'] == "Entièrement Extraite",
              'expirationExtraction': extractionExpiration,
              'extractionExpiree': extractionExpiree,
            });
          }
        }
      } else if (typeCollecte == "Achat - SCOOPS" ||
          typeCollecte == "Achat SCOOPS") {
        final scoopsColl =
            await collecteSnap.reference.collection('SCOOP').get();
        for (final achatDoc in scoopsColl.docs) {
          if (achatId != null && achatDoc.id != achatId) continue;
          final a = achatDoc.data();
          final fournisseurColl =
              await achatDoc.reference.collection('SCOOP_info').get();
          final fournisseur = fournisseurColl.docs.isNotEmpty
              ? fournisseurColl.docs.first.data()
              : {};
          final List details = a['details'] is List ? a['details'] : [];
          if (details.isNotEmpty && detailIndex != null) {
            final detail = (detailIndex >= 0 && detailIndex < details.length)
                ? details[detailIndex]
                : null;
            if (detail == null) continue;
            final extractionExpiration =
                extraction['expirationExtraction'] is Timestamp
                    ? (extraction['expirationExtraction'] as Timestamp).toDate()
                    : null;
            final extractionExpiree = extractionExpiration != null &&
                extractionExpiration.isBefore(DateTime.now());
            achatsScoops.add({
              'id': collecteId,
              'achatId': achatId,
              'detailIndex': detailIndex,
              'numeroLot': numeroLot,
              'producteurNom': fournisseur['nom'] ?? "",
              'producteurType': 'SCOOPS',
              'nomPresident': fournisseur['nomPresident'] ?? "",
              'commune': fournisseur['commune'] ?? "",
              'quartier': fournisseur['quartier'] ?? "",
              'village': fournisseur['village'] ?? "",
              'dateCollecte': dateCollecte,
              'dateAchat': (a['dateAchat'] as Timestamp?)?.toDate(),
              'typeProduit': detail['typeProduit'] ?? "",
              'typeRuche': detail['typeRuche'] ?? "",
              // === ici aussi ===
              'quantite': poidsMiel,
              'quantiteAcceptee': detail['quantiteAcceptee'] ?? 0,
              'quantiteRejetee': detail['quantiteRejetee'] ?? 0,
              'unite': detail['unite'] ?? "",
              'prixUnitaire': detail['prixUnitaire'] ?? "",
              'prixTotal': detail['prixTotal'] ?? "",
              'predominanceFlorale': fournisseur['predominanceFlorale'] ?? "",
              'dateControle':
                  (controle['dateControle'] as Timestamp?)?.toDate(),
              'utilisateur': utilisateur,
              'source': 'AchatSCOOPS',
              'statutExtraction':
                  extraction['statutExtraction'] ?? "Non extraite",
              'quantiteRestante': extraction['quantiteRestante'],
              'quantiteFiltree': extraction['quantiteFiltree'],
              'quantiteEntree': extraction['quantiteEntree'],
              'dechets': extraction['dechets'],
              'dateExtraction': extraction['dateExtraction'] is Timestamp
                  ? (extraction['dateExtraction'] as Timestamp).toDate()
                  : null,
              'technologie': extraction['technologie'],
              'extrait':
                  extraction['statutExtraction'] == "Entièrement Extraite",
              'expirationExtraction': extractionExpiration,
              'extractionExpiree': extractionExpiree,
            });
          } else if (details.isEmpty) {
            // fallback ancienne structure
            final extractionExpiration =
                extraction['expirationExtraction'] is Timestamp
                    ? (extraction['expirationExtraction'] as Timestamp).toDate()
                    : null;
            final extractionExpiree = extractionExpiration != null &&
                extractionExpiration.isBefore(DateTime.now());
            achatsScoops.add({
              'id': collecteId,
              'achatId': achatId,
              'detailIndex': null,
              'numeroLot': numeroLot,
              'producteurNom': fournisseur['nom'] ?? "",
              'producteurType': 'SCOOPS',
              'nomPresident': fournisseur['nomPresident'] ?? "",
              'commune': fournisseur['commune'] ?? "",
              'quartier': fournisseur['quartier'] ?? "",
              'village': fournisseur['village'] ?? "",
              'dateCollecte': dateCollecte,
              'dateAchat': (a['dateAchat'] as Timestamp?)?.toDate(),
              'typeProduit': a['typeProduit'] ?? "",
              'typeRuche': a['typeRuche'] ?? "",
              'quantite': poidsMiel,
              'quantiteAcceptee': a['quantite'] ?? 0,
              'quantiteRejetee': a['quantiteRejetee'] ?? 0,
              'unite': a['unite'] ?? "",
              'prixUnitaire': a['prixUnitaire'] ?? "",
              'prixTotal': a['prixTotal'] ?? "",
              'predominanceFlorale': fournisseur['predominanceFlorale'] ?? "",
              'dateControle':
                  (controle['dateControle'] as Timestamp?)?.toDate(),
              'utilisateur': utilisateur,
              'source': 'AchatSCOOPS',
              'statutExtraction':
                  extraction['statutExtraction'] ?? "Non extraite",
              'quantiteRestante': extraction['quantiteRestante'],
              'quantiteFiltree': extraction['quantiteFiltree'],
              'quantiteEntree': extraction['quantiteEntree'],
              'dechets': extraction['dechets'],
              'dateExtraction': extraction['dateExtraction'] is Timestamp
                  ? (extraction['dateExtraction'] as Timestamp).toDate()
                  : null,
              'technologie': extraction['technologie'],
              'extrait':
                  extraction['statutExtraction'] == "Entièrement Extraite",
              'expirationExtraction': extractionExpiration,
              'extractionExpiree': extractionExpiree,
            });
          }
        }
      } else if (typeCollecte == "Achat - Individuel" ||
          typeCollecte == "Achat Individuel") {
        final indColl =
            await collecteSnap.reference.collection('Individuel').get();
        for (final achatDoc in indColl.docs) {
          if (achatId != null && achatDoc.id != achatId) continue;
          final a = achatDoc.data();
          final fournisseurColl =
              await achatDoc.reference.collection('Individuel_info').get();
          final fournisseur = fournisseurColl.docs.isNotEmpty
              ? fournisseurColl.docs.first.data()
              : {};
          final List details = a['details'] is List ? a['details'] : [];
          if (details.isNotEmpty && detailIndex != null) {
            final detail = (detailIndex >= 0 && detailIndex < details.length)
                ? details[detailIndex]
                : null;
            if (detail == null) continue;
            final extractionExpiration =
                extraction['expirationExtraction'] is Timestamp
                    ? (extraction['expirationExtraction'] as Timestamp).toDate()
                    : null;
            final extractionExpiree = extractionExpiration != null &&
                extractionExpiration.isBefore(DateTime.now());
            achatsIndividuels.add({
              'id': collecteId,
              'achatId': achatId,
              'detailIndex': detailIndex,
              'numeroLot': numeroLot,
              'producteurNom': fournisseur['nomPrenom'] ?? "",
              'producteurType': 'Individuel',
              'commune': fournisseur['commune'] ?? "",
              'quartier': fournisseur['quartier'] ?? "",
              'village': fournisseur['village'] ?? "",
              'dateCollecte': dateCollecte,
              'dateAchat': (a['dateAchat'] as Timestamp?)?.toDate(),
              'typeProduit': detail['typeProduit'] ?? "",
              'typeRuche': detail['typeRuche'] ?? "",
              // === ici aussi ===
              'quantite': poidsMiel,
              'quantiteAcceptee': detail['quantiteAcceptee'] ?? 0,
              'quantiteRejetee': detail['quantiteRejetee'] ?? 0,
              'unite': detail['unite'] ?? "",
              'prixUnitaire': detail['prixUnitaire'] ?? "",
              'prixTotal': detail['prixTotal'] ?? "",
              'predominanceFlorale': fournisseur['predominanceFlorale'] ?? "",
              'dateControle':
                  (controle['dateControle'] as Timestamp?)?.toDate(),
              'utilisateur': utilisateur,
              'source': 'AchatIndividuel',
              'statutExtraction':
                  extraction['statutExtraction'] ?? "Non extraite",
              'quantiteRestante': extraction['quantiteRestante'],
              'quantiteFiltree': extraction['quantiteFiltree'],
              'quantiteEntree': extraction['quantiteEntree'],
              'dechets': extraction['dechets'],
              'dateExtraction': extraction['dateExtraction'] is Timestamp
                  ? (extraction['dateExtraction'] as Timestamp).toDate()
                  : null,
              'technologie': extraction['technologie'],
              'extrait':
                  extraction['statutExtraction'] == "Entièrement Extraite",
              'expirationExtraction': extractionExpiration,
              'extractionExpiree': extractionExpiree,
            });
          } else if (details.isEmpty) {
            final extractionExpiration =
                extraction['expirationExtraction'] is Timestamp
                    ? (extraction['expirationExtraction'] as Timestamp).toDate()
                    : null;
            final extractionExpiree = extractionExpiration != null &&
                extractionExpiration.isBefore(DateTime.now());
            achatsIndividuels.add({
              'id': collecteId,
              'achatId': achatId,
              'detailIndex': null,
              'numeroLot': numeroLot,
              'producteurNom': fournisseur['nomPrenom'] ?? "",
              'producteurType': 'Individuel',
              'commune': fournisseur['commune'] ?? "",
              'quartier': fournisseur['quartier'] ?? "",
              'village': fournisseur['village'] ?? "",
              'dateCollecte': dateCollecte,
              'dateAchat': (a['dateAchat'] as Timestamp?)?.toDate(),
              'typeProduit': a['typeProduit'] ?? "",
              'typeRuche': a['typeRuche'] ?? "",
              'quantite': poidsMiel,
              'quantiteAcceptee': a['quantite'] ?? 0,
              'quantiteRejetee': a['quantiteRejetee'] ?? 0,
              'unite': a['unite'] ?? "",
              'prixUnitaire': a['prixUnitaire'] ?? "",
              'prixTotal': a['prixTotal'] ?? "",
              'predominanceFlorale': fournisseur['predominanceFlorale'] ?? "",
              'dateControle':
                  (controle['dateControle'] as Timestamp?)?.toDate(),
              'utilisateur': utilisateur,
              'source': 'AchatIndividuel',
              'statutExtraction':
                  extraction['statutExtraction'] ?? "Non extraite",
              'quantiteRestante': extraction['quantiteRestante'],
              'quantiteFiltree': extraction['quantiteFiltree'],
              'quantiteEntree': extraction['quantiteEntree'],
              'dechets': extraction['dechets'],
              'dateExtraction': extraction['dateExtraction'] is Timestamp
                  ? (extraction['dateExtraction'] as Timestamp).toDate()
                  : null,
              'technologie': extraction['technologie'],
              'extrait':
                  extraction['statutExtraction'] == "Entièrement Extraite",
              'expirationExtraction': extractionExpiration,
              'extractionExpiree': extractionExpiree,
            });
          }
        }
      }
    }
    isLoading.value = false;
  }
}
