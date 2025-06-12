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

    // On récupère toutes les extractions
    final extractionsSnap =
        await FirebaseFirestore.instance.collection('extraction').get();
    final extractions = extractionsSnap.docs.map((doc) => doc.data()).toList();

    // 1. On récupère tous les contrôles validés
    final controleSnap =
        await FirebaseFirestore.instance.collection('Controle').get();

    for (final controleDoc in controleSnap.docs) {
      final controle = controleDoc.data();
      final collecteId = controle['collecteId'];
      final numeroLot = controle['numeroLot'];
      final typeCollecte = controle['typeCollecte'];

      // 2. On récupère la collecte associée pour plus d'infos
      final collecteSnap = await FirebaseFirestore.instance
          .collection('collectes')
          .doc(collecteId)
          .get();
      if (!collecteSnap.exists) continue;
      final collecte = collecteSnap.data()!;
      final dateCollecte = (collecte['dateCollecte'] as Timestamp?)?.toDate();
      final utilisateur = collecte['utilisateurNom'] ?? "";

      // --- JOINTURE extraction (si extraction existe pour cette collecte)
      final extraction = extractions
          .where((e) => e['collecteId'] == collecteId)
          .toList()
          .fold<Map<String, dynamic>>({}, (prev, e) {
        // on garde la dernière extraction pour ce lot si plusieurs
        if (prev.isEmpty ||
            (e['dateExtraction'] != null &&
                (prev['dateExtraction'] == null ||
                    (e['dateExtraction'] as Timestamp).toDate().isAfter(
                        (prev['dateExtraction'] as Timestamp?)?.toDate() ??
                            DateTime(2000))))) {
          return e;
        }
        return prev;
      });

      // 3. Selon le type, on va chercher les bons détails
      if (typeCollecte == "Récolte") {
        // Sous-collec Récolte
        final sousColl =
            await collecteSnap.reference.collection('Récolte').get();
        if (sousColl.docs.isEmpty) continue;
        final r = sousColl.docs.first.data();
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
          'producteurType': 'Récolteur',
          'village': r['village'] ?? "",
          'dateCollecte': dateCollecte,
          'typeProduit': "Miel Brute",
          'quantite': r['quantiteKg'] ?? 0,
          'unite': 'kg',
          'predominanceFlorale': r['predominanceFlorale'] ?? "",
          'dateControle': (controle['dateControle'] as Timestamp?)?.toDate(),
          'utilisateur': utilisateur,
          'source': 'Récolte',
          // Infos Extraction (s'il y en a)
          'statutExtraction': extraction['statutExtraction'] ?? "Non extraite",
          'quantiteRestante': extraction['quantiteRestante'],
          'quantiteFiltree': extraction['quantiteFiltree'],
          'quantiteEntree': extraction['quantiteEntree'],
          'dechets': extraction['dechets'],
          'dateExtraction': extraction['dateExtraction'] is Timestamp
              ? (extraction['dateExtraction'] as Timestamp).toDate()
              : null,
          'technologie': extraction['technologie'],
          'extrait': extraction['statutExtraction'] == "Entièrement Extraite",

          'expirationExtraction': extractionExpiration,
          'extractionExpiree': extractionExpiree,
        });
      } else if (typeCollecte == "Achat - SCOOPS" ||
          typeCollecte == "Achat SCOOPS") {
        final scoopsColl =
            await collecteSnap.reference.collection('SCOOP').get();
        if (scoopsColl.docs.isEmpty) continue;
        final a = scoopsColl.docs.first.data();
        final fournisseurColl = await scoopsColl.docs.first.reference
            .collection('SCOOP_info')
            .get();
        final fournisseur = fournisseurColl.docs.isNotEmpty
            ? fournisseurColl.docs.first.data()
            : {};

        final extractionExpiration =
            extraction['expirationExtraction'] is Timestamp
                ? (extraction['expirationExtraction'] as Timestamp).toDate()
                : null;
        achatsScoops.add({
          'id': collecteId,
          'numeroLot': numeroLot,
          'producteurNom': fournisseur['nom'] ?? "",
          'producteurType': 'SCOOPS',
          'nomPresident': fournisseur['nomPresident'] ?? "",
          'village': fournisseur['localite'] ?? "",
          'dateCollecte': dateCollecte,
          'dateAchat': (a['dateAchat'] as Timestamp?)?.toDate(),
          'typeProduit': a['typeProduit'] ?? "",
          'typeRuche': a['typeRuche'] ?? "",
          'quantite': a['quantite'] ?? 0,
          'unite': a['unite'] ?? "",
          'predominanceFlorale': fournisseur['predominanceFlorale'] ?? "",
          'dateControle': (controle['dateControle'] as Timestamp?)?.toDate(),
          'utilisateur': utilisateur,
          'source': 'AchatSCOOPS',
          // Extraction
          'statutExtraction': extraction['statutExtraction'] ?? "Non extraite",
          'quantiteRestante': extraction['quantiteRestante'],
          'quantiteFiltree': extraction['quantiteFiltree'],
          'quantiteEntree': extraction['quantiteEntree'],
          'dechets': extraction['dechets'],
          'dateExtraction': extraction['dateExtraction'] is Timestamp
              ? (extraction['dateExtraction'] as Timestamp).toDate()
              : null,
          'technologie': extraction['technologie'],
          'extrait': extraction['statutExtraction'] == "Entièrement Extraite",
          'expirationExtraction': extractionExpiration,
          'extractionExpiree': extractionExpiration != null &&
              extractionExpiration.isBefore(DateTime.now()),
        });
      } else if (typeCollecte == "Achat - Individuel" ||
          typeCollecte == "Achat Individuel") {
        final indColl =
            await collecteSnap.reference.collection('Individuel').get();
        if (indColl.docs.isEmpty) continue;
        final a = indColl.docs.first.data();
        final fournisseurColl = await indColl.docs.first.reference
            .collection('Individuel_info')
            .get();
        final fournisseur = fournisseurColl.docs.isNotEmpty
            ? fournisseurColl.docs.first.data()
            : {};
        final extractionExpiration =
            extraction['expirationExtraction'] is Timestamp
                ? (extraction['expirationExtraction'] as Timestamp).toDate()
                : null;
        achatsIndividuels.add({
          'id': collecteId,
          'numeroLot': numeroLot,
          'producteurNom': fournisseur['nomPrenom'] ?? "",
          'producteurType': 'Individuel',
          'village': fournisseur['localite'] ?? "",
          'dateCollecte': dateCollecte,
          'dateAchat': (a['dateAchat'] as Timestamp?)?.toDate(),
          'typeProduit': a['typeProduit'] ?? "",
          'typeRuche': a['typeRuche'] ?? "",
          'quantite': a['quantite'] ?? 0,
          'unite': a['unite'] ?? "",
          'predominanceFlorale': fournisseur['predominanceFlorale'] ?? "",
          'dateControle': (controle['dateControle'] as Timestamp?)?.toDate(),
          'utilisateur': utilisateur,
          'source': 'AchatIndividuel',
          // Extraction
          'statutExtraction': extraction['statutExtraction'] ?? "Non extraite",
          'quantiteRestante': extraction['quantiteRestante'],
          'quantiteFiltree': extraction['quantiteFiltree'],
          'quantiteEntree': extraction['quantiteEntree'],
          'dechets': extraction['dechets'],
          'dateExtraction': extraction['dateExtraction'] is Timestamp
              ? (extraction['dateExtraction'] as Timestamp).toDate()
              : null,
          'technologie': extraction['technologie'],
          'extrait': extraction['statutExtraction'] == "Entièrement Extraite",
          'expirationExtraction': extractionExpiration,
          'extractionExpiree': extractionExpiration != null &&
              extractionExpiration.isBefore(DateTime.now()),
        });
      }
    }
    isLoading.value = false;
  }
}
