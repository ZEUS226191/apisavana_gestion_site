import 'package:apisavana_gestion/data/geographe/geographie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum TypeCollecte { recolte, achat }

enum OrigineAchat { scoops, individuel }

class CollecteController extends GetxController {
  //############################################################################################################
  //############################################################################################################
  late final RxDouble prixTotalRx = RxDouble(0.0);

  // Communs
  final dateCollecte = Rxn<DateTime>();
  final typeCollecte = Rxn<TypeCollecte>();

  final nbFemmeScoopsAjout = 0.obs;
  final prixTotalScoopsAjout = 0.0.obs;
  final prixTotalScoops = 0.0.obs;

  // --- RECOLTE
  final nomRecolteur = RxnString();
  //final region = RxnString();
  //final province = RxnString();
  //final village = RxnString();
  final dateRecolte = Rxn<DateTime>();
  final quantiteRecolte = RxnDouble();
  final predominanceFloraleRecolte = RxnString();
  final nbRuchesRecoltees = RxnInt();

  // --- Techniciens (recolteurs) & leur organisation ---
  // --- LISTE DÉFINITIVE DES TECHNICIENS & GÉOGRAPHIE ---
  // Liste plate des techniciens

  final RxList<String> scoopsConnues = <String>[].obs;
  final RxList<String> individuelsConnus = <String>[].obs;

  // --- ACHAT
  final origineAchat = Rxn<OrigineAchat>();

  //############################################################################################################
  //############################################################################################################

  // Pour la sélection géographique
  final region = RxnString();
  final province = RxnString();
  final commune = RxnString();
  final village = RxnString(); // tu complèteras plus tard
  final List<String> techniciens = [
    "ZOUNGRANA	Valentin",
    "ROAMBA	F Y Ferdinand",
    "YAMEOGO	A Clément",
    "SANOU	Sitelé",
    "YAMEOGO	Justin",
    "Sanogo	Issouf",
    "OUATTARA	Baladji",
    "OUTTARA	Lassina",
    "YAMEOGO	Innocent",
    "OUEDRAOGO 	Issouf",
    "YAMEOGO	Hippolyte",
    "TRAORE	Abdoul Aziz",
    "SIEMDE	Souleymane",
    "KABORE	Adama",
    "OUEDRAOGO	Adama",
    "Milogo	Anicet",
  ];

  List<String> getProvincesForRegion(String? region) =>
      region == null ? [] : provincesParRegion[region] ?? [];

  List<String> getCommunesForProvince(String? province) =>
      province == null ? [] : communesParProvince[province] ?? [];

  List<String> getVillagesForCommune(String? commune) =>
      commune == null ? [] : villagesParCommune[commune] ?? [];

  // Ajoute dans le controller
  final RxList<String> predominancesFloralesSelected = <String>[].obs;
  final TextEditingController autrePredominanceCtrl = TextEditingController();

  final quantiteAccepteeScoopsCtrl = TextEditingController();
  final quantiteRejeteeScoopsCtrl = TextEditingController();
  final prixUnitaireScoopsCtrl = TextEditingController();

  // --- ACHAT > SCOOPS déjà enregistrée
  final selectedSCOOPS = RxnString();
  final dateAchatScoops = Rxn<DateTime>();
  final typeRucheAchatScoops = RxnString();
  final typeProduitAchatScoops = RxnString();
  final quantiteAccepteeScoops = RxnDouble();
  final quantiteRejeteeScoops = RxnDouble();
  final prixUnitaireScoops = RxnDouble();
  final prixTotalIndiv = 0.0.obs;
  RxDouble get prixTotalSIndiv =>
      RxDouble((quantiteIndiv.value ?? 0) * (prixUnitaireIndiv.value ?? 0));

  // --- ACHAT > SCOOPS > Ajouter SCOOPS
  // Champs pour ajouter une nouvelle SCOOPS
  final nomScoopsAjout = TextEditingController();
  final nomPresidentAjout = TextEditingController();
  final localiteScoopsAjout = RxnString();
  final predominanceFloraleScoopsAjout = RxnString();
  final nbRuchesTradScoopsAjout = TextEditingController();
  final nbRuchesModScoopsAjout = TextEditingController();
  final nbMembreScoopsAjout = TextEditingController();
  final nbHommeScoopsAjout = TextEditingController();
  final nbJeuneScoopsAjout = TextEditingController();
  final nbVieuxScoopsAjout = 0.obs;
  final recipiseFile = RxnString(); // Chemin ou nom du PDF
  final quantiteScoopsAjout = TextEditingController();
  final uniteQuantiteScoopsAjout = RxnString();
  final typeRucheScoopsAjout = RxnString();
  final prixUnitaireScoopsAjout = TextEditingController();

  // --- ACHAT > INDIVIDUEL déjà enregistré
  final selectedIndividuel = RxnString();
  final dateAchatIndiv = Rxn<DateTime>();
  final quantiteIndiv = RxnDouble();
  final uniteQuantiteIndiv = RxnString();
  final quantiteScoop = TextEditingController();
  final uniteQuantiteScoop = RxnString();
  final typeProduitIndiv = RxnString();
  final typeRucheIndiv = RxnString();
  final prixUnitaireIndiv = RxnDouble();

  // --- ACHAT > INDIVIDUEL > Ajouter individuel
  final nomPrenomIndivAjout = TextEditingController();
  final localiteIndivAjout = RxnString();
  final sexeIndivAjout = RxnString();
  final ageIndivAjout = RxnString();
  final cooperativeIndivAjout = RxnString();
  final predominanceFloraleIndivAjout = RxnString();
  final nbRuchesTradIndivAjout = TextEditingController();
  final nbRuchesModIndivAjout = TextEditingController();
  final quantiteIndivAjout = TextEditingController();
  final uniteQuantiteIndivAjout = RxnString();
  final typeRucheIndivAjout = RxnString();
  final prixUnitaireIndivAjout = TextEditingController();
  RxDouble get prixTotalIndivAjout {
    final q = double.tryParse(quantiteIndivAjout.text) ?? 0;
    final pu = double.tryParse(prixUnitaireIndivAjout.text) ?? 0;
    return RxDouble(q * pu);
  }

  // Pour afficher/masquer les sous-formulaires
  final isAddingSCOOPS = false.obs;
  final isAddingIndividuel = false.obs;

  // Ajoute ces lignes dans la classe CollecteController :
  final quantiteIndivCtrl = TextEditingController();
  final prixUnitaireIndivCtrl = TextEditingController();

  // --- Données fictives pour listes déroulantes ---
  final List<String> sitesRucher = ['Rucher A', 'Rucher B', 'Rucher C'];
  final Map<String, List<String>> recolteursParSite = {
    'Rucher A': ['Alice', 'Bob'],
    'Rucher B': ['Charles', 'Denis'],
    'Rucher C': ['Eve', 'Fatou'],
  };
  final List<String> flores = [
    'Karité',
    'Néré',
    'Manguier',
    'Baobab',
    'NEEMIER',
    'Ekalptus',
    'Autres'
  ];
  /*final List<String> scoopsConnues = [
    'SCOOPS Yam',
    'SCOOPS Faso',
    'SCOOPS Api'
  ];*/
  final List<String> typesRuche = ['Moderne', 'Traditionnelle'];
  final List<String> typesProduit = ['Miel brut', 'Miel filtré', 'Cire'];
  // Dans ta classe CollecteController
  List<String> previousSelection = [];

  final List<String> sexes = ['Masculin', 'Féminin'];
  final List<String> cooperatives = ['Coop Yam', 'Coop Faso', 'Coop Api'];

  @override
  void onInit() {
    super.onInit();
    // Calcul automatique Nb femmes
    nbMembreScoopsAjout.addListener(_updateNbFemmes);
    nbMembreScoopsAjout.addListener(_updateNbJeunes);
    nbHommeScoopsAjout.addListener(_updateNbFemmes);
    nbJeuneScoopsAjout.addListener(_updateNbJeunes);

    // Calcul automatique Prix total
    quantiteScoopsAjout.addListener(_updatePrixTotal);
    prixUnitaireScoopsAjout.addListener(_updatePrixTotal);

    quantiteAccepteeScoopsCtrl.addListener(_updatePrixTotalScoops);
    prixUnitaireScoopsCtrl.addListener(_updatePrixTotalScoops);

    ever<double?>(quantiteAccepteeScoops, (_) => _updatePrixTotalScoops());
    ever<double?>(prixUnitaireScoops, (_) => _updatePrixTotalScoops());

    chargerScoopsConnues();
    chargerIndividuelsConnus();

    // Quand l'utilisateur tape dans le champ, on update le Rx
    quantiteIndivCtrl.addListener(() {
      quantiteIndiv.value = double.tryParse(quantiteIndivCtrl.text);
    });
    prixUnitaireIndivCtrl.addListener(() {
      prixUnitaireIndiv.value = double.tryParse(prixUnitaireIndivCtrl.text);
    });

    // Quand le Rx est modifié en code (ex: reset, édition), on update le champ texte
    ever<double?>(quantiteIndiv, (val) {
      if ((quantiteIndivCtrl.text != (val?.toString() ?? ""))) {
        quantiteIndivCtrl.text = val?.toString() ?? "";
      }
    });
    ever<double?>(prixUnitaireIndiv, (val) {
      if ((prixUnitaireIndivCtrl.text != (val?.toString() ?? ""))) {
        prixUnitaireIndivCtrl.text = val?.toString() ?? "";
      }
    });

    // Calcul automatique prix total
    everAll(
        [quantiteIndiv, prixUnitaireIndiv], (_) => calculerPrixTotalIndiv());

    quantiteAccepteeScoopsCtrl.addListener(() {
      quantiteAccepteeScoops.value =
          double.tryParse(quantiteAccepteeScoopsCtrl.text);
    });
    quantiteRejeteeScoopsCtrl.addListener(() {
      quantiteRejeteeScoops.value =
          double.tryParse(quantiteRejeteeScoopsCtrl.text);
    });
    prixUnitaireScoopsCtrl.addListener(() {
      prixUnitaireScoops.value = double.tryParse(prixUnitaireScoopsCtrl.text);
    });
  }

  void _updatePrixTotalScoops() {
    final q = quantiteAccepteeScoops.value ?? 0.0;
    final pu = prixUnitaireScoops.value ?? 0.0;
    prixTotalScoops.value = q * pu;
  }

  void _updateNbFemmes() {
    final total = int.tryParse(nbMembreScoopsAjout.text) ?? 0;
    final hommes = int.tryParse(nbHommeScoopsAjout.text) ?? 0;
    nbFemmeScoopsAjout.value = (total - hommes).clamp(0, total);
  }

  void _updateNbJeunes() {
    final total = int.tryParse(nbMembreScoopsAjout.text) ?? 0;
    final jeunes = int.tryParse(nbJeuneScoopsAjout.text) ?? 0;
    nbVieuxScoopsAjout.value = (total - jeunes).clamp(0, total);
  }

  void _updatePrixTotal() {
    final q = double.tryParse(quantiteScoopsAjout.text) ?? 0.0;
    final pu = double.tryParse(prixUnitaireScoopsAjout.text) ?? 0.0;
    prixTotalScoopsAjout.value = q * pu;
  }

  void calculerPrixTotalIndiv() {
    final quantite = quantiteIndiv.value ?? 0.0;
    final prixUnitaire = prixUnitaireIndiv.value ?? 0.0;
    prixTotalIndiv.value = quantite * prixUnitaire;
  }
  //methode utilitaire !!!
  //############################################################################################################
  //############################################################################################################
  //############################################################################################################
  //############################################################################################################
  //############################################################################################################

  // --- Achat INDIVIDUEL
  // Multi-ruche/produit pour achat individuel
  final RxList<String> typesRucheAchatIndivMulti = <String>[].obs;
  final Map<String, RxList<String>> typesProduitAchatIndivMulti = {};
  final Map<String, Map<String, AchatProduitData>> achatsIndivParRucheProduit =
      {};
  RxMap<String, Map<String, AchatProduitData>> achatsParRucheProduit =
      <String, Map<String, AchatProduitData>>{}.obs;

  // Toggle multi-ruche
  void toggleTypeRucheAchatIndiv(String ruche, bool selected) {
    if (selected) {
      if (!typesRucheAchatIndivMulti.contains(ruche)) {
        typesRucheAchatIndivMulti.add(ruche);
        typesProduitAchatIndivMulti[ruche] = <String>[].obs;
        achatsIndivParRucheProduit[ruche] = {};
      }
    } else {
      typesRucheAchatIndivMulti.remove(ruche);
      typesProduitAchatIndivMulti.remove(ruche);
      achatsIndivParRucheProduit.remove(ruche);
    }
  }

// Toggle multi-produit
  void toggleTypeProduitAchatIndiv(
      String ruche, String produit, bool selected) {
    if (!typesProduitAchatIndivMulti.containsKey(ruche)) return;
    if (selected) {
      if (!typesProduitAchatIndivMulti[ruche]!.contains(produit)) {
        typesProduitAchatIndivMulti[ruche]!.add(produit);
        achatsIndivParRucheProduit[ruche] ??= {};
        achatsIndivParRucheProduit[ruche]![produit] =
            AchatProduitData(unite: (produit == 'Cire') ? 'kg' : 'litre');
      }
    } else {
      typesProduitAchatIndivMulti[ruche]!.remove(produit);
      achatsIndivParRucheProduit[ruche]?.remove(produit);
    }
  }

  // Génération du document d'achat individuel pour Firestore
  Map<String, dynamic> generateAchatIndivData() {
    final List<Map<String, dynamic>> details = [];
    for (final ruche in typesRucheAchatIndivMulti) {
      final produits = typesProduitAchatIndivMulti[ruche] ?? [];
      for (final produit in produits) {
        final achat = achatsIndivParRucheProduit[ruche]?[produit];
        if (achat != null) {
          details.add({
            'typeRuche': ruche,
            'typeProduit': produit,
            'quantiteAcceptee': achat.quantiteAcceptee.value,
            'quantiteRejetee': achat.quantiteRejetee.value,
            'unite': achat.unite,
            'prixUnitaire': achat.prixUnitaire.value,
            'prixTotal': achat.prixTotal.value,
          });
        }
      }
    }
    return {
      'details': details,
      'dateAchat': DateTime.now(),
    };
  }

  // --- AJOUT INDIVIDUEL / SCOOPS : Localisation avancée
  final regionIndivAjout = RxnString();
  final provinceIndivAjout = RxnString();
  final communeIndivAjout = RxnString();
  final villageIndivAjout = RxnString();

  final regionScoopsAjout = RxnString();
  final provinceScoopsAjout = RxnString();
  final communeScoopsAjout = RxnString();
  final villageScoopsAjout = RxnString();
  final secteur = RxnString();
  final quartier = RxnString();
  final arrondissement = RxnString();

  // Pour formulaire Individuel
  final arrondissementIndivAjout = RxnString();
  final secteurIndivAjout = RxnString();
  final quartierIndivAjout = RxnString();

  // Pour formulaire SCOOPS

  final arrondissementScoopsAjout = RxnString();
  final secteurScoopsAjout = RxnString();
  final quartierScoopsAjout = RxnString();

  // --- ACHAT > SCOOPS : Sélection multiple de types de ruche/produit et gestion dynamique
  final RxList<String> typesRucheAchatScoopsMulti =
      <String>[].obs; // multi sélection
  final Map<String, RxList<String>> typesProduitAchatScoopsMulti =
      {}; // par type de ruche

  // Méthode utilitaire pour initialiser les sous-cartes dynamiquement
  void toggleTypeRucheAchatScoops(String ruche, bool selected) {
    if (selected) {
      if (!typesRucheAchatScoopsMulti.contains(ruche)) {
        typesRucheAchatScoopsMulti.add(ruche);
        typesProduitAchatScoopsMulti[ruche] = <String>[].obs;
        achatsParRucheProduit[ruche] = {};
      }
    } else {
      typesRucheAchatScoopsMulti.remove(ruche);
      typesProduitAchatScoopsMulti.remove(ruche);
      achatsParRucheProduit.remove(ruche);
    }
  }

  void toggleTypeProduitAchatScoops(
      String ruche, String produit, bool selected) {
    if (!typesProduitAchatScoopsMulti.containsKey(ruche)) return;
    if (selected) {
      if (!typesProduitAchatScoopsMulti[ruche]!.contains(produit)) {
        typesProduitAchatScoopsMulti[ruche]!.add(produit);
        achatsParRucheProduit[ruche] ??= {};
        achatsParRucheProduit[ruche]![produit] =
            AchatProduitData(unite: (produit == 'Cire') ? 'kg' : 'litre');
      }
    } else {
      typesProduitAchatScoopsMulti[ruche]!.remove(produit);
      achatsParRucheProduit[ruche]?.remove(produit);
    }
  }

  // Pour Ajout Individuel/SCOOPS
  void resetLocaliteIndiv() {
    regionIndivAjout.value = null;
    provinceIndivAjout.value = null;
    communeIndivAjout.value = null;
    villageIndivAjout.value = null;
  }

  void resetLocaliteScoops() {
    regionScoopsAjout.value = null;
    provinceScoopsAjout.value = null;
    communeScoopsAjout.value = null;
    villageScoopsAjout.value = null;
  }

  // Génération du document d'achat SCOOPS pour Firestore
  Map<String, dynamic> generateAchatScoopsData() {
    final List<Map<String, dynamic>> details = [];
    for (final ruche in typesRucheAchatScoopsMulti) {
      final produits = typesProduitAchatScoopsMulti[ruche] ?? [];
      for (final produit in produits) {
        final achat = achatsParRucheProduit[ruche]?[produit];
        if (achat != null) {
          details.add({
            'typeRuche': ruche,
            'typeProduit': produit,
            'quantiteAcceptee': achat.quantiteAcceptee.value,
            'quantiteRejetee': achat.quantiteRejetee.value,
            'unite': achat.unite,
            'prixUnitaire': achat.prixUnitaire.value,
            'prixTotal': achat.prixTotal.value,
          });
        }
      }
    }
    return {
      'details': details,
      'dateAchat': DateTime.now(),
    };
  }

  final couleurCireScoops = RxnString();
  final couleurCireIndiv = RxnString();

  final TextEditingController numeroPresidentCtrl = TextEditingController();
  final TextEditingController numeroIndividuelCtrl = TextEditingController();

// Fonction utilitaire pour vérifier si tous les champs obligatoires sont remplis
  // --- Validation récolte adaptée
  bool validateRecolteForm() {
    return dateCollecte.value != null &&
        nomRecolteur.value != null &&
        region.value != null &&
        province.value != null &&
        village.value != null &&
        quantiteRecolte.value != null &&
        dateCollecte.value != null &&
        predominancesFloralesSelected.isNotEmpty;
  }

  bool validateAchatScoopsForm() {
    bool isCire = typeProduitAchatScoops.value?.toLowerCase() == "cire";
    return selectedSCOOPS.value != null &&
        dateCollecte.value != null &&
        typeRucheAchatScoops.value != null &&
        typeProduitAchatScoops.value != null &&
        quantiteAccepteeScoops.value != null &&
        quantiteRejeteeScoops.value != null &&
        prixUnitaireScoops.value != null &&
        (!isCire || couleurCireScoops.value != null);
  }

  bool validateAchatIndividuelForm() {
    bool isCire = typeProduitIndiv.value?.toLowerCase() == "cire";
    return selectedIndividuel.value != null &&
        dateCollecte.value != null &&
        quantiteIndiv.value != null &&
        uniteQuantiteIndiv.value != null &&
        typeProduitIndiv.value != null &&
        typeRucheIndiv.value != null &&
        prixUnitaireIndiv.value != null &&
        (!isCire || couleurCireIndiv.value != null);
  }

  bool validateAjouterScoopsForm() {
    return nomScoopsAjout.text.isNotEmpty &&
        nomPresidentAjout.text.isNotEmpty &&
        localiteScoopsAjout.value != null &&
        // après
        predominancesFloralesSelected.isNotEmpty &&
        nbRuchesTradScoopsAjout.text.isNotEmpty &&
        nbRuchesModScoopsAjout.text.isNotEmpty &&
        nbMembreScoopsAjout.text.isNotEmpty &&
        nbHommeScoopsAjout.text.isNotEmpty &&
        nbJeuneScoopsAjout.text.isNotEmpty;
  }

  bool validateAjouterIndividuelForm() {
    return nomPrenomIndivAjout.text.isNotEmpty &&
        localiteIndivAjout.value != null &&
        sexeIndivAjout.value != null &&
        ageIndivAjout.value != null &&
        cooperativeIndivAjout.value != null &&
        // après
        predominancesFloralesSelected.isNotEmpty &&
        nbRuchesTradIndivAjout.text.isNotEmpty &&
        nbRuchesModIndivAjout.text.isNotEmpty;
  }

  void initAchatProduitForm({required String ruche, required String produit}) {
    if (achatsParRucheProduit[ruche] == null) {
      achatsParRucheProduit[ruche] = <String, AchatProduitData>{}.obs;
    }
    if (achatsParRucheProduit[ruche]![produit] == null) {
      achatsParRucheProduit[ruche]![produit] =
          AchatProduitData(); // Adapte le constructeur selon ton modèle
    }
  }

  List<String> champsManquantsScoops() {
    final List<String> manquants = [];
    if (nomScoopsAjout.text.isEmpty) manquants.add("Nom SCOOPS");
    if (nomPresidentAjout.text.isEmpty) manquants.add("Nom Président");
    if (numeroPresidentCtrl.text.isEmpty) manquants.add("Numéro Président");
    if (regionScoopsAjout.value == null) manquants.add("Région");
    if (provinceScoopsAjout.value == null) manquants.add("Province");
    if (communeScoopsAjout.value == null) manquants.add("Commune");
    if (["Ouagadougou", "BOBO-DIOULASSO", "Bobo-Dioulasso"]
        .contains(communeScoopsAjout.value)) {
      if (arrondissementScoopsAjout.value == null)
        manquants.add("Arrondissement");
      if (secteurScoopsAjout.value == null) manquants.add("Secteur");
      if (quartierScoopsAjout.value == null) manquants.add("Quartier");
    } else {
      if (villageScoopsAjout.value == null || villageScoopsAjout.value!.isEmpty)
        manquants.add("Village");
    }
    if (nbRuchesTradScoopsAjout.text.isEmpty)
      manquants.add("Nb ruches traditionnelles");
    if (nbRuchesModScoopsAjout.text.isEmpty)
      manquants.add("Nb ruches modernes");
    if (nbMembreScoopsAjout.text.isEmpty) manquants.add("Nb membres");
    if (nbHommeScoopsAjout.text.isEmpty) manquants.add("Nb hommes");
    if (nbJeuneScoopsAjout.text.isEmpty) manquants.add("Nb jeunes");
    if (predominancesFloralesSelected.isEmpty) manquants.add("Florale");
    return manquants;
  }

  /// Enregistre une nouvelle SCOOPS dans la collection SCOOPS
  /// Enregistre une nouvelle SCOOPS dans la collection SCOOPS
  Future<DocumentReference?> enregistrerNouvelleSCOOPS() async {
    final champs = champsManquantsScoops();
    if (champs.isNotEmpty) {
      Get.snackbar(
        "Erreur",
        "Veuillez remplir les champs suivants :\n${champs.join(", ")}",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
        duration: Duration(seconds: 6),
        icon: Icon(Icons.error, color: Colors.red[900]),
      );
      return null;
    }

    final scoopsData = {
      'nom': nomScoopsAjout.text,
      'nomPresident': nomPresidentAjout.text,
      "numeroPresident": numeroPresidentCtrl.text,
      'region': regionScoopsAjout.value,
      'province': provinceScoopsAjout.value,
      'commune': communeScoopsAjout.value,
      'predominanceFlorale': predominancesFloralesSelected.toList(),
      'nbRuchesTrad': int.parse(nbRuchesTradScoopsAjout.text),
      'nbRuchesMod': int.parse(nbRuchesModScoopsAjout.text),
      'nbMembres': int.parse(nbMembreScoopsAjout.text),
      'nbHommes': int.parse(nbHommeScoopsAjout.text),
      'nbFemmes': nbFemmeScoopsAjout.value,
      'nbJeunes': int.parse(nbJeuneScoopsAjout.text),
      'nbVieux': nbVieuxScoopsAjout.value,
      'recipise': recipiseFile.value ?? "",
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Champs géographiques dynamiques
    if (["Ouagadougou", "BOBO-DIOULASSO", "Bobo-Dioulasso"]
        .contains(communeScoopsAjout.value)) {
      scoopsData['arrondissement'] = arrondissementScoopsAjout.value;
      scoopsData['secteur'] = secteurScoopsAjout.value;
      scoopsData['quartier'] = quartierScoopsAjout.value;
    } else {
      scoopsData['village'] = villageScoopsAjout.value;
    }

    final ref =
        await FirebaseFirestore.instance.collection('SCOOPS').add(scoopsData);
    Get.snackbar("Succès", "SCOOPS ajoutée !");
    reset();
    await chargerScoopsConnues();
    return ref;
  }

  /// Enregistre un nouvel Individuel dans la collection Individuels
  Future<DocumentReference?> enregistrerNouvelIndividuel() async {
    final indivData = {
      'nomPrenom': nomPrenomIndivAjout.text,
      "numeroIndividuel": numeroIndividuelCtrl.text,
      'region': regionIndivAjout.value,
      'province': provinceIndivAjout.value,
      'commune': communeIndivAjout.value,
      // Dynamique pour Ouaga/Bobo ou Village classique
      if (["Ouagadougou", "BOBO-DIOULASSO", "Bobo-Dioulasso"]
          .contains(communeIndivAjout.value)) ...{
        'arrondissement': arrondissementIndivAjout.value,
        'secteur': secteurIndivAjout.value,
        'quartier': quartierIndivAjout.value,
      } else
        'village': villageIndivAjout.value,
      'sexe': sexeIndivAjout.value,
      'age': ageIndivAjout.value,
      'cooperative': cooperativeIndivAjout.value,
      'predominanceFlorale': predominancesFloralesSelected.toList(),
      'nbRuchesTrad': int.parse(nbRuchesTradIndivAjout.text),
      'nbRuchesMod': int.parse(nbRuchesModIndivAjout.text),
      'createdAt': FieldValue.serverTimestamp(),
    };
    final ref = await FirebaseFirestore.instance
        .collection('Individuels')
        .add(indivData);
    Get.snackbar("Succès", "Producteur individuel ajouté !");
    await chargerIndividuelsConnus();
    reset();
    return ref;
  }

  // ENREGISTREMENT DANS FIRESTORE
  Future<void> enregistrerCollecteRecolte() async {
    if (dateCollecte.value == null ||
        nomRecolteur.value == null ||
        region.value == null ||
        province.value == null ||
        commune.value == null ||
        quantiteRecolte.value == null ||
        nbRuchesRecoltees.value == null ||
        predominancesFloralesSelected.isEmpty ||
        // Pour Ouaga/Bobo : tout doit être rempli jusqu'à quartier
        ((commune.value == "Ouagadougou" ||
                commune.value == "BOBO-DIOULASSO" ||
                commune.value == "Bobo-Dioulasso") &&
            (arrondissement.value == null ||
                secteur.value == null ||
                quartier.value == null)) ||
        // Autres cas : village doit être renseigné
        (!["Ouagadougou", "BOBO-DIOULASSO", "Bobo-Dioulasso"]
                .contains(commune.value) &&
            (village.value == null || village.value!.isEmpty))) {
      Get.snackbar("Erreur", "Veuillez remplir tous les champs !");
      return;
    }

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Get.snackbar("Erreur", "Utilisateur non connecté !");
      return;
    }

    final collecteRef =
        await FirebaseFirestore.instance.collection('collectes').add({
      'type': 'récolte',
      'dateCollecte': dateCollecte.value ?? DateTime.now(),
      'utilisateurId': user.uid,
      'utilisateurNom': user.displayName ?? user.email ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final Map<String, dynamic> sousDocData = {
      'nomRecolteur': nomRecolteur.value,
      'region': region.value,
      'province': province.value,
      'commune': commune.value,
      'quantiteKg': quantiteRecolte.value,
      'nbRuchesRecoltees': nbRuchesRecoltees.value,
      'predominanceFlorale': predominancesFloralesSelected.toList(),
      'dateRecolte': dateCollecte.value,
      "typeProduit": "Miel brute",
    };
    if (["Ouagadougou", "BOBO-DIOULASSO", "Bobo-Dioulasso"]
        .contains(commune.value)) {
      sousDocData['arrondissement'] = arrondissement.value;
      sousDocData['secteur'] = secteur.value;
      sousDocData['quartier'] = quartier.value;
    } else {
      sousDocData['village'] = village.value;
    }

    await collecteRef.collection('Récolte').add(sousDocData);

    Get.snackbar("Succès", "Collecte (Récolte) enregistrée !");
    reset();
    Get.back();
  }

  /// Enregistre une collecte de type ACHAT
  /// Enregistre une collecte de type ACHAT
  Future<void> enregistrerCollecteAchat({
    required bool isScoops,
    required Map<String, dynamic> achatDetails,
    required Map<String, dynamic> fournisseurDetails,
  }) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Get.snackbar("Erreur", "Utilisateur non connecté !");
      return;
    }

    final collecteRef =
        await FirebaseFirestore.instance.collection('collectes').add({
      'type': 'achat',
      'dateCollecte': dateCollecte.value ?? DateTime.now(),
      'utilisateurId': user.uid,
      'utilisateurNom': user.displayName ?? user.email ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      if (isScoops) 'nomSCOOPS': selectedSCOOPS.value,
      if (!isScoops) 'nomIndividuel': selectedIndividuel.value,
    });

    final String sousCollection = isScoops ? 'SCOOP' : 'Individuel';

    // On ajoute la dateAchat ici si elle n'est pas déjà dans achatDetails
    final Map<String, dynamic> achatData = {
      ...achatDetails,
      'dateAchat': achatDetails['dateAchat'] ?? DateTime.now(),
      if (isScoops &&
          (typeProduitAchatScoops.value?.toLowerCase() == 'cire') &&
          couleurCireScoops.value != null)
        'cireCouleur': couleurCireScoops.value,
      if (!isScoops &&
          (typeProduitIndiv.value?.toLowerCase() == 'cire') &&
          couleurCireIndiv.value != null)
        'cireCouleur': couleurCireIndiv.value,
    };

    final achatDocRef =
        await collecteRef.collection(sousCollection).add(achatData);

    final String fournisseurCollection =
        isScoops ? 'SCOOP_info' : 'Individuel_info';

    // LOGIQUE LOCALISATION AVANCÉE POUR SCOOPS / INDIVIDUEL
    final commune =
        isScoops ? communeScoopsAjout.value : communeIndivAjout.value;
    final quartier =
        isScoops ? quartierScoopsAjout.value : quartierIndivAjout.value;
    final arrondissement = isScoops
        ? arrondissementScoopsAjout.value
        : arrondissementIndivAjout.value;
    final secteur =
        isScoops ? secteurScoopsAjout.value : secteurIndivAjout.value;
    final village =
        isScoops ? villageScoopsAjout.value : villageIndivAjout.value;

    Map<String, dynamic> fournisseurDetailsFinal = {
      ...fournisseurDetails,
      'commune': commune,
      'region': isScoops ? regionScoopsAjout.value : regionIndivAjout.value,
      'province':
          isScoops ? provinceScoopsAjout.value : provinceIndivAjout.value,
    };

    if (["Ouagadougou", "BOBO-DIOULASSO", "Bobo-Dioulasso"].contains(commune)) {
      fournisseurDetailsFinal["arrondissement"] = arrondissement;
      fournisseurDetailsFinal["secteur"] = secteur;
      fournisseurDetailsFinal["quartier"] = quartier;
      fournisseurDetailsFinal["localite"] =
          "${quartier ?? ''} || ${commune ?? ''}";
    } else {
      fournisseurDetailsFinal["village"] = village;
      fournisseurDetailsFinal["localite"] = village;
    }

    await achatDocRef
        .collection(fournisseurCollection)
        .add(fournisseurDetailsFinal);

    Get.snackbar("Succès", "Collecte (Achat) enregistrée !");
    reset();
    Get.back();
  }

  /// Enregistre une collecte de type ACHAT SCOOPS (multi-ruche, multi-produit)

  Future<void> chargerScoopsConnues() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('SCOOPS').get();
    scoopsConnues.clear();
    scoopsConnues.addAll(snapshot.docs.map((doc) => doc['nom'] as String));
  }

  Future<void> chargerIndividuelsConnus() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('Individuels').get();
    individuelsConnus.clear();
    individuelsConnus
        .addAll(snapshot.docs.map((doc) => doc['nomPrenom'] as String));
  }

  String _getUniteForProduct(String produit) {
    if (produit.toLowerCase().contains('miel')) return 'kg';
    if (produit.toLowerCase().contains('cire')) return 'kg';
    return 'unité';
  }

  List<String> _processSelection(dynamic selectedItems) {
    if (selectedItems is List<String>) return selectedItems;
    if (selectedItems is String) return [selectedItems];
    if (selectedItems is Iterable)
      return selectedItems.map((e) => e.toString()).toList();
    return [];
  }

// Réinitialise tout le formulaire

  //############################################################################################################
  //############################################################################################################
  //############################################################################################################
  //############################################################################################################
  //############################################################################################################

  void reset() {
    // Commun
    dateCollecte.value = null;
    typeCollecte.value = null;

    nbFemmeScoopsAjout.value = 0;
    prixTotalScoopsAjout.value = 0.0;

    // Récolte
    dateRecolte.value = null;
    nomRecolteur.value = null;
    region.value = null;
    province.value = null;
    village.value = null;
    quantiteRecolte.value = null;
    predominanceFloraleRecolte.value = null;
    predominancesFloralesSelected.value = [];

    // --- ACHAT
    origineAchat.value = null;

    // --- ACHAT > SCOOPS déjà enregistrée
    selectedSCOOPS.value = null;
    dateAchatScoops.value = null;
    typeRucheAchatScoops.value = null;
    typeProduitAchatScoops.value = null;
    quantiteAccepteeScoops.value = null;
    quantiteRejeteeScoops.value = null;
    prixUnitaireScoops.value = null;
    prixTotalIndiv.value = 0.0;
    quantiteAccepteeScoopsCtrl.clear();
    quantiteRejeteeScoopsCtrl.clear();
    prixUnitaireScoopsCtrl.clear();

    // --- ACHAT > SCOOPS > Ajouter SCOOPS
    nomScoopsAjout.clear();
    nomPresidentAjout.clear();
    localiteScoopsAjout.value = null;
    predominanceFloraleScoopsAjout.value = null;
    nbRuchesTradScoopsAjout.clear();
    nbRuchesModScoopsAjout.clear();
    nbMembreScoopsAjout.clear();
    nbHommeScoopsAjout.clear();
    nbJeuneScoopsAjout.clear();
    recipiseFile.value = null;
    quantiteScoopsAjout.clear();
    uniteQuantiteScoopsAjout.value = null;
    typeRucheScoopsAjout.value = null;
    prixUnitaireScoopsAjout.clear();
    couleurCireScoops.value = null;

    // --- ACHAT > INDIVIDUEL déjà enregistré
    selectedIndividuel.value = null;
    dateAchatIndiv.value = null;
    quantiteIndiv.value = null;
    uniteQuantiteIndiv.value = null;
    quantiteScoop.clear();
    uniteQuantiteScoop.value = null;
    typeProduitIndiv.value = null;
    typeRucheIndiv.value = null;
    prixUnitaireIndiv.value = null;
    // ...
    quantiteIndiv.value = null;
    quantiteIndivCtrl.clear();
    prixUnitaireIndiv.value = null;
    prixUnitaireIndivCtrl.clear();
    couleurCireIndiv.value = null;
    // ...

    // --- ACHAT > INDIVIDUEL > Ajouter individuel
    nomPrenomIndivAjout.clear();
    localiteIndivAjout.value = null;
    sexeIndivAjout.value = null;
    ageIndivAjout.value = null;
    cooperativeIndivAjout.value = null;
    predominanceFloraleIndivAjout.value = null;
    nbRuchesTradIndivAjout.clear();
    nbRuchesModIndivAjout.clear();
    quantiteIndivAjout.clear();
    uniteQuantiteIndivAjout.value = null;
    typeRucheIndivAjout.value = null;
    prixUnitaireIndivAjout.clear();

    // Pour afficher/masquer les sous-formulaires
    isAddingSCOOPS.value = false;
    isAddingIndividuel.value = false;

    arrondissement.value = null;
    secteur.value = null;
    quartier.value = null;
    nomRecolteur.value = null;
    quantiteRecolte.value = null;
    nbRuchesRecoltees.value = null;
    dateCollecte.value = null;
  }

// Pour Individuel
  List<String> champsManquantsIndiv() {
    List<String> manquants = [];
    if (nomPrenomIndivAjout.text.isEmpty) manquants.add("Nom et prénom");
    if (regionIndivAjout.value == null) manquants.add("Région");
    if (provinceIndivAjout.value == null) manquants.add("Province");
    if (communeIndivAjout.value == null) manquants.add("Commune");
    if (villageIndivAjout.value == null || villageIndivAjout.value!.isEmpty)
      manquants.add("Village");
    if (numeroIndividuelCtrl.text.isEmpty) manquants.add("Numéro Individuel");
    if (sexeIndivAjout.value == null) manquants.add("Sexe");
    if (ageIndivAjout.value == null) manquants.add("Âge");
    if (cooperativeIndivAjout.value == null)
      manquants.add("Appartenance/Coopérative");
    if (predominancesFloralesSelected.isEmpty) manquants.add("Florale");
    if (nbRuchesTradIndivAjout.text.isEmpty)
      manquants.add("Nb ruches traditionnelles");
    if (nbRuchesModIndivAjout.text.isEmpty) manquants.add("Nb ruches modernes");
    // Ajoute ici d'autres validations si besoin
    return manquants;
  }
}

// Modèle pour gérer dynamiquement les sous-cartes d'achat par (ruche, produit)
class AchatProduitData {
  RxDouble quantiteAcceptee = 0.0.obs;
  RxDouble quantiteRejetee = 0.0.obs;
  String unite = 'kg'; // ou 'litre'
  RxDouble prixUnitaire = 0.0.obs;
  RxDouble prixTotal = 0.0.obs;

  AchatProduitData({this.unite = 'kg'}) {
    quantiteAcceptee.listen((_) => updateTotal());
    prixUnitaire.listen((_) => updateTotal());
  }
  void updateTotal() {
    prixTotal.value = (quantiteAcceptee.value) * (prixUnitaire.value);
  }
}
