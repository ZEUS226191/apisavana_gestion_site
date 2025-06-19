import 'package:cloud_firestore/cloud_firestore.dart';
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

    // 1. Tous les filtrages déjà faits
    final filtragesSnap =
        await FirebaseFirestore.instance.collection('filtrage').get();
    final filtrages = filtragesSnap.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();

    // 2. Toutes les extractions
    final extractionsSnap =
        await FirebaseFirestore.instance.collection('extraction').get();
    final extractions = extractionsSnap.docs.map((doc) => doc.data()).toList();

    // 3. Tous les contrôles validés (par produit)
    final controleSnap =
        await FirebaseFirestore.instance.collection('Controle').get();
    final controles = controleSnap.docs.map((doc) => doc.data()).toList();

    // Index les extractions pour accès rapide
    Map<String, Map> extractionByKey = {};
    for (final ext in extractions) {
      final key = [
        ext['collecteId'],
        ext['achatId'] ?? '',
        ext['detailIndex']?.toString() ?? ''
      ].join('|');
      extractionByKey[key] = ext;
    }

    // Index les filtrages pour accès rapide
    Map<String, Map> filtrageByKey = {};
    for (final f in filtrages) {
      final key = [
        f['collecteId'],
        f['achatId'] ?? '',
        f['detailIndex']?.toString() ?? ''
      ].join('|');
      filtrageByKey[key] = f;
    }

    for (final controle in controles) {
      final collecteId = controle['collecteId'];
      final recId = controle['recId'];
      final achatId = controle['achatId'];
      final detailIndex = controle['detailIndex'];
      final numeroLot = controle['numeroLot'];
      final typeCollecte = controle['typeCollecte'];
      final typeProduit =
          (controle['typeProduit'] ?? '').toString().toLowerCase();
      final poidsMiel =
          double.tryParse(controle['poidsMiel']?.toString() ?? "0") ?? 0;

      // Récupérer la collecte associée (infos affichage)
      final collecteSnap = await FirebaseFirestore.instance
          .collection('collectes')
          .doc(collecteId)
          .get();
      if (!collecteSnap.exists) continue;
      final collecte = collecteSnap.data()!;
      final dateCollecte = (collecte['dateCollecte'] as Timestamp?)?.toDate();
      final utilisateur = collecte['utilisateurNom'] ?? "";

      final key =
          [collecteId, achatId ?? '', detailIndex?.toString() ?? ''].join('|');
      final extraction = extractionByKey[key] ?? {};
      final filtrage = filtrageByKey[key];

      // 1. Statut et timer filtrage
      final statutFiltrage = filtrage?['statutFiltrage'] ?? "Non filtré";
      DateTime? expirationFiltrage;
      if (filtrage?['expirationFiltrage'] is Timestamp) {
        expirationFiltrage =
            (filtrage?['expirationFiltrage'] as Timestamp).toDate();
      } else if (statutFiltrage == "Filtrage total" &&
          filtrage?['dateFiltrage'] is Timestamp) {
        expirationFiltrage = (filtrage?['dateFiltrage'] as Timestamp)
            .toDate()
            .add(const Duration(minutes: 30));
      }
      bool isFiltrageTotal = statutFiltrage == "Filtrage total";
      bool isFiltrageEncoreValide = true;
      if (isFiltrageTotal && expirationFiltrage != null) {
        isFiltrageEncoreValide = DateTime.now().isBefore(expirationFiltrage);
      }
      if (isFiltrageTotal && !isFiltrageEncoreValide) continue;

      // 2. Calcul cumuls filtrage
      double quantiteEntree = filtrage?['quantiteEntree'] != null
          ? (filtrage?['quantiteEntree'] as num).toDouble()
          : 0.0;
      double quantiteFiltree = filtrage?['quantiteFiltree'] != null
          ? (filtrage?['quantiteFiltree'] as num).toDouble()
          : 0.0;
      double quantiteRestante = filtrage?['quantiteRestante'] != null
          ? (filtrage?['quantiteRestante'] as num).toDouble()
          : 0.0;

      double quantiteDepart = poidsMiel;
      if (extraction.isNotEmpty && extraction['quantiteFiltree'] != null) {
        final qF = double.tryParse(extraction['quantiteFiltree'].toString());
        if (qF != null && qF > 0) quantiteDepart = qF;
      }

      // Si pas de filtrage, fallback sur extraction/controle pour la carte (valeurs "brutes")
      if (statutFiltrage == "Non filtré") {
        quantiteEntree = 0.0;
        quantiteFiltree = 0.0;
        quantiteRestante = quantiteDepart;
      } else {
        // Pour garder une cohérence si la BDD a des anciens enregistrements sans quantiteRestante
        if (quantiteRestante == 0 && quantiteEntree > 0) {
          quantiteRestante = (quantiteDepart - quantiteEntree);
          if (quantiteRestante < 0) quantiteRestante = 0;
        }
      }

      // --- Récolte ---
      if (typeCollecte == "Récolte") {
        final extractionOk =
            extraction['statutExtraction'] == "Entièrement Extraite";
        final isMielFiltre =
            typeProduit.contains("filtré") || typeProduit.contains("filtre");
        if (!extractionOk && !isMielFiltre && !isFiltrageTotal) continue;

        final sousColl =
            await collecteSnap.reference.collection('Récolte').get();
        Map? r;
        if (recId != null) {
          r = sousColl.docs.firstWhereOrNull((doc) => doc.id == recId)?.data();
        } else if (sousColl.docs.isNotEmpty) {
          r = sousColl.docs.first.data();
        }
        if (r == null) continue;

        recoltes.add({
          'id': collecteId,
          'recId': recId,
          'detailIndex': detailIndex,
          'numeroLot': numeroLot,
          'producteurNom': r['nomRecolteur'] ?? "",
          'village': r['village'] ?? "",
          'commune': r['commune'] ?? "",
          'quartier': r['quartier'] ?? "",
          'dateCollecte': dateCollecte,
          'dateExtraction': extraction['dateExtraction'] is Timestamp
              ? (extraction['dateExtraction'] as Timestamp).toDate()
              : null,
          'typeProduit': controle['typeProduit'] ?? "",
          'typeRuche': controle['typeRuche'] ?? "",
          'quantite': quantiteDepart,
          'quantiteDepart': quantiteDepart,
          'unite': r['unite'] ?? '',
          'predominanceFlorale':
              controle['predominanceFlorale'] ?? r['predominanceFlorale'] ?? "",
          'dateControle': (controle['dateControle'] as Timestamp?)?.toDate(),
          'utilisateur': utilisateur,
          'statutFiltrage': statutFiltrage,
          'expirationFiltrage': expirationFiltrage,
          'quantiteEntree': quantiteEntree,
          'quantiteFiltree': quantiteFiltree,
          'quantiteRestante': quantiteRestante,
          'dateFiltrage': filtrage?['dateFiltrage'] is Timestamp
              ? (filtrage?['dateFiltrage'] as Timestamp).toDate()
              : null,
          'filtrageId': filtrage?['id'],
        });
      }

      // --- Achat SCOOPS ---
      else if (typeCollecte == "Achat - SCOOPS" ||
          typeCollecte == "Achat SCOOPS") {
        final isMielFiltre =
            typeProduit.contains("filtré") || typeProduit.contains("filtre");
        final extractionOk =
            extraction['statutExtraction'] == "Entièrement Extraite";
        if (!extractionOk && !isMielFiltre && !isFiltrageTotal) continue;

        final scoopsColl =
            await collecteSnap.reference.collection('SCOOP').get();
        Map? achat = scoopsColl.docs
            .firstWhereOrNull((doc) => doc.id == achatId)
            ?.data();
        if (achat == null) continue;
        final fournisseurColl = await FirebaseFirestore.instance
            .collection('collectes')
            .doc(collecteId)
            .collection('SCOOP')
            .doc(achatId)
            .collection('SCOOP_info')
            .get();
        final fournisseur = fournisseurColl.docs.isNotEmpty
            ? fournisseurColl.docs.first.data()
            : {};

        final details =
            achat['details'] is List ? achat['details'] as List : [];
        Map? detail;
        if (details.isNotEmpty && detailIndex != null) {
          detail = details.length > detailIndex ? details[detailIndex] : null;
        }

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
          'village': fournisseur['village'] ?? fournisseur['localite'] ?? "",
          'dateCollecte': dateCollecte,
          'dateExtraction': extraction['dateExtraction'] is Timestamp
              ? (extraction['dateExtraction'] as Timestamp).toDate()
              : null,
          'typeProduit': detail?['typeProduit'] ?? "",
          'typeRuche': detail?['typeRuche'] ?? "",
          'quantite': quantiteDepart,
          'quantiteDepart': quantiteDepart,
          'unite': detail?['unite'] ?? '',
          'predominanceFlorale': controle['predominanceFlorale'] ??
              fournisseur['predominanceFlorale'] ??
              "",
          'dateControle': (controle['dateControle'] as Timestamp?)?.toDate(),
          'utilisateur': utilisateur,
          'statutFiltrage': statutFiltrage,
          'expirationFiltrage': expirationFiltrage,
          'quantiteEntree': quantiteEntree,
          'quantiteFiltree': quantiteFiltree,
          'quantiteRestante': quantiteRestante,
          'dateFiltrage': filtrage?['dateFiltrage'] is Timestamp
              ? (filtrage?['dateFiltrage'] as Timestamp).toDate()
              : null,
          'filtrageId': filtrage?['id'],
        });
      }

      // --- Achat Individuel ---
      else if (typeCollecte == "Achat - Individuel" ||
          typeCollecte == "Achat Individuel") {
        final isMielFiltre =
            typeProduit.contains("filtré") || typeProduit.contains("filtre");
        final extractionOk =
            extraction['statutExtraction'] == "Entièrement Extraite";
        if (!extractionOk && !isMielFiltre && !isFiltrageTotal) continue;

        final indColl =
            await collecteSnap.reference.collection('Individuel').get();
        Map? achat =
            indColl.docs.firstWhereOrNull((doc) => doc.id == achatId)?.data();
        if (achat == null) continue;
        final fournisseurColl = await FirebaseFirestore.instance
            .collection('collectes')
            .doc(collecteId)
            .collection('Individuel')
            .doc(achatId)
            .collection('Individuel_info')
            .get();
        final fournisseur = fournisseurColl.docs.isNotEmpty
            ? fournisseurColl.docs.first.data()
            : {};

        final details =
            achat['details'] is List ? achat['details'] as List : [];
        Map? detail;
        if (details.isNotEmpty && detailIndex != null) {
          detail = details.length > detailIndex ? details[detailIndex] : null;
        }

        achatsIndividuels.add({
          'id': collecteId,
          'achatId': achatId,
          'detailIndex': detailIndex,
          'numeroLot': numeroLot,
          'producteurNom': fournisseur['nomPrenom'] ?? "",
          'producteurType': 'Individuel',
          'commune': fournisseur['commune'] ?? "",
          'quartier': fournisseur['quartier'] ?? "",
          'village': fournisseur['village'] ?? fournisseur['localite'] ?? "",
          'dateCollecte': dateCollecte,
          'dateExtraction': extraction['dateExtraction'] is Timestamp
              ? (extraction['dateExtraction'] as Timestamp).toDate()
              : null,
          'typeProduit': detail?['typeProduit'] ?? "",
          'typeRuche': detail?['typeRuche'] ?? "",
          'quantite': quantiteDepart,
          'quantiteDepart': quantiteDepart,
          'unite': detail?['unite'] ?? '',
          'predominanceFlorale': controle['predominanceFlorale'] ??
              fournisseur['predominanceFlorale'] ??
              "",
          'dateControle': (controle['dateControle'] as Timestamp?)?.toDate(),
          'utilisateur': utilisateur,
          'statutFiltrage': statutFiltrage,
          'expirationFiltrage': expirationFiltrage,
          'quantiteEntree': quantiteEntree,
          'quantiteFiltree': quantiteFiltree,
          'quantiteRestante': quantiteRestante,
          'dateFiltrage': filtrage?['dateFiltrage'] is Timestamp
              ? (filtrage?['dateFiltrage'] as Timestamp).toDate()
              : null,
          'filtrageId': filtrage?['id'],
        });
      }
    }
    isLoading.value = false;
  }
}

extension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
