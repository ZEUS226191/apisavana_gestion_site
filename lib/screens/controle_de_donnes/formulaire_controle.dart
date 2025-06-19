import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Ce formulaire fonctionne pour collecte type "Récolte", "Achat SCOOPS" ou "Achat Individuel" (en fonction de la map reçue)

class ControleFormPage extends StatefulWidget {
  final Map collecte;
  final String type;

  ControleFormPage({required this.collecte, required this.type});
  @override
  State<ControleFormPage> createState() => _ControleFormPageState();
}

class _ControleFormPageState extends State<ControleFormPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Champs contrôleurs
  late TextEditingController producteurCtrl;
  String? villageSelected;
  String? quartierSelected;
  String? communeSelected;
  String? localiteDisplay;
  String? periodeCollecte;
  late String natureMiel;
  String? contenant;
  final poidsContenantCtrl = TextEditingController();
  final poidsEnsembleCtrl = TextEditingController();
  double? poidsMiel;
  String? qualite;
  final teneurEauCtrl = TextEditingController();
  late List<String> predominanceFloraleList;
  bool? conformite;
  final causeNonConformiteCtrl = TextEditingController();
  final quantiteNonConformeCtrl = TextEditingController();
  String? uniteNonConforme;
  String? uniteEnsemble;
  String? errorMessage;
  String? lotNumber;
  bool lotCheckLoading = false;

  // Animations
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  String determinerQualite(double teneurEau) {
    if (teneurEau > 22) {
      return "MAUVAIS";
    } else if (teneurEau >= 21) {
      return "BON";
    } else {
      return "TRES BON";
    }
  }

  @override
  void initState() {
    super.initState();
    try {
      producteurCtrl = TextEditingController(
        text: widget.collecte['producteurNom'] ?? "",
      );

      // Gestion commune/quartier ou village
      communeSelected = widget.collecte['commune']?.toString();
      quartierSelected = widget.collecte['quartier']?.toString();
      villageSelected = widget.collecte['village']?.toString();

      if (communeSelected != null &&
          communeSelected!.isNotEmpty &&
          quartierSelected != null &&
          quartierSelected!.isNotEmpty) {
        localiteDisplay = "${communeSelected} | ${quartierSelected}";
      } else {
        localiteDisplay = villageSelected;
      }

      periodeCollecte = widget.collecte['periodeCollecte'];
      natureMiel = widget.collecte['typeProduit']?.toString() ??
          widget.collecte['natureMiel']?.toString() ??
          "Brut";

      contenant = widget.collecte['contenant'];
      qualite = widget.collecte['qualite'];
      uniteEnsemble = widget.collecte['unite']?.toString() ?? "kg";

      var pf = widget.collecte['predominanceFlorale'];
      if (pf is List) {
        predominanceFloraleList =
            List<String>.from(pf.map((e) => e.toString()));
      } else if (pf is String && pf.isNotEmpty) {
        predominanceFloraleList = [pf];
      } else {
        predominanceFloraleList = [];
      }

      if (widget.collecte['poidsContenant'] != null) {
        poidsContenantCtrl.text = widget.collecte['poidsContenant'].toString();
      }
      if (widget.collecte['poidsEnsemble'] != null) {
        poidsEnsembleCtrl.text = widget.collecte['poidsEnsemble'].toString();
      }
      if (widget.collecte['teneurEau'] != null) {
        teneurEauCtrl.text = widget.collecte['teneurEau'].toString();
      }
      _calculPoidsMiel();
      errorMessage = null;
    } catch (e) {
      errorMessage = "Erreur de chargement des données : $e";
      predominanceFloraleList = [];
    }

    _animCtrl =
        AnimationController(vsync: this, duration: Duration(milliseconds: 900));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _animCtrl.forward();

    teneurEauCtrl.addListener(_autoSetQualite);
  }

  bool _isOuagaBobo(String? commune) {
    return commune == "Ouagadougou" ||
        commune == "BOBO-DIOULASSO" ||
        commune == "Bobo-Dioulasso";
  }

  void _autoSetQualite() {
    final te = double.tryParse(teneurEauCtrl.text);
    if (te != null) {
      setState(() {
        qualite = determinerQualite(te);
      });
    }
  }

  bool isPreFilled(String key) {
    final v = widget.collecte[key];
    if (v == null) return false;
    if (v is List) return v.isNotEmpty;
    return v.toString().isNotEmpty;
  }

  @override
  void dispose() {
    producteurCtrl.dispose();
    poidsContenantCtrl.dispose();
    poidsEnsembleCtrl.dispose();
    teneurEauCtrl.dispose();
    causeNonConformiteCtrl.dispose();
    quantiteNonConformeCtrl.dispose();
    _animCtrl.dispose();
    teneurEauCtrl.removeListener(_autoSetQualite);
    super.dispose();
  }

  void _calculPoidsMiel() {
    try {
      final poidsContenant = double.tryParse(poidsContenantCtrl.text) ?? 0;
      final poidsEnsemble = double.tryParse(poidsEnsembleCtrl.text) ?? 0;
      setState(() {
        poidsMiel = (poidsEnsemble - poidsContenant).clamp(0, double.infinity);
      });
    } catch (e) {
      setState(() {
        poidsMiel = 0.0;
        errorMessage = "Erreur de calcul du poids de miel : $e";
      });
    }
  }

  Future<String?> _generateUniqueLotNumber() async {
    final random = Random();
    String randomAlphaNum() {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      return List.generate(3, (index) => chars[random.nextInt(chars.length)])
          .join();
    }

    for (int i = 0; i < 50; i++) {
      final candidate = "BCE-${randomAlphaNum()}";
      try {
        final exists = await FirebaseFirestore.instance
            .collection('Controle')
            .where('numeroLot', isEqualTo: candidate)
            .limit(1)
            .get();
        if (exists.docs.isEmpty) return candidate;
      } catch (e) {
        Get.snackbar("Erreur", "Vérification du numéro de lot impossible : $e");
        return null;
      }
    }
    return null;
  }

  Future<void> _onSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      Get.snackbar("Erreur", "Veuillez remplir tous les champs obligatoires !");
      return;
    }
    if (lotNumber == null) {
      Get.snackbar("Erreur", "Veuillez générer et attribuer un N° de lot !");
      return;
    }

    // Récupérer les identifiants uniques du produit spécifique
    final collecteId = widget.collecte['id'];
    final recId = widget.collecte['recId'];
    final achatId = widget.collecte['achatId'];
    final detailIndex = widget.collecte['detailIndex'];

    if (collecteId == null) {
      Get.snackbar("Erreur", "Impossible de retrouver la collecte liée !");
      return;
    }

    // Enregistre le contrôle pour CE produit spécifique
    final controleData = {
      "collecteId": collecteId,
      if (recId != null) "recId": recId,
      if (achatId != null) "achatId": achatId,
      if (detailIndex != null) "detailIndex": detailIndex,
      "typeCollecte": widget.type,
      "typeProduit": widget.collecte['typeProduit'] ?? "",
      "typeRuche": widget.collecte['typeRuche'] ?? "",
      "producteur": producteurCtrl.text,
      if (_isOuagaBobo(communeSelected) &&
          quartierSelected != null &&
          quartierSelected!.isNotEmpty)
        "localite": "$communeSelected | $quartierSelected"
      else
        "village": villageSelected,
      "periodeCollecte": periodeCollecte,
      "natureMiel": natureMiel,
      "contenant": contenant,
      "poidsContenant": double.tryParse(poidsContenantCtrl.text) ?? 0,
      "poidsEnsemble": double.tryParse(poidsEnsembleCtrl.text) ?? 0,
      "uniteEnsemble": uniteEnsemble,
      "poidsMiel": poidsMiel ?? 0,
      "qualite": qualite,
      "teneurEau": double.tryParse(teneurEauCtrl.text) ?? 0,
      "predominanceFlorale": predominanceFloraleList,
      "conformite": conformite,
      "causeNonConformite":
          conformite == false ? causeNonConformiteCtrl.text : null,
      "quantiteNonConforme": conformite == false
          ? double.tryParse(quantiteNonConformeCtrl.text) ?? 0
          : null,
      "uniteNonConforme": conformite == false ? uniteNonConforme : null,
      "numeroLot": lotNumber,
      "dateControle": DateTime.now(),
    };

    try {
      await FirebaseFirestore.instance.collection("Controle").add(controleData);

      // (Optionnel) : mettre à jour l'état "controle" ou "lot" sur CE produit dans la collecte :
      // Si structure en tableau : update array element (avancé, nécessite un script)
      // Sinon, tu peux faire un update sur le sous-doc ou le détail par index

      Get.snackbar("Succès", "Contrôle et réception enregistrés !",
          backgroundColor: Colors.green[100]);
      Navigator.pop(context, true);
    } catch (e) {
      Get.snackbar("Erreur", "Échec de l'enregistrement : $e",
          backgroundColor: Colors.red[100]);
    }
  }

  @override
  Widget build(BuildContext context) {
    // On détermine le titre du champ localité/village
    final isOuagaBoboQuartier = _isOuagaBobo(communeSelected) &&
        quartierSelected != null &&
        quartierSelected!.isNotEmpty;
    final champLocalisationLabel =
        isOuagaBoboQuartier ? "Localité" : "Village apicole";
    final champLocalisationValue =
        isOuagaBoboQuartier ? localiteDisplay : villageSelected;

    return Scaffold(
      appBar: AppBar(
        title: Text("Contrôle de la collecte"),
        backgroundColor: Colors.amber[800],
      ),
      backgroundColor: Colors.amber[50],
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 570),
              child: Card(
                elevation: 7,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.all(22.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (errorMessage != null)
                          Container(
                            margin: EdgeInsets.only(bottom: 16),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red[300]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error, color: Colors.red[800]),
                                SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    errorMessage!,
                                    style: TextStyle(
                                        color: Colors.red[900],
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Text("Informations sur la collecte",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 17)),
                        SizedBox(height: 11),

                        // Producteur - prérempli & désactivé
                        _label("Producteur"),
                        TextFormField(
                          controller: producteurCtrl,
                          enabled: false,
                          decoration: InputDecoration(
                            prefixIcon:
                                Icon(Icons.person, color: Colors.grey[700]),
                            filled: true,
                            fillColor: Colors.amber[50],
                          ),
                        ),
                        SizedBox(height: 9),

                        // Village apicole OU Localité
                        _label(champLocalisationLabel),
                        DropdownButtonFormField<String>(
                          value: champLocalisationValue,
                          items: [
                            if (champLocalisationValue != null &&
                                champLocalisationValue!.isNotEmpty)
                              DropdownMenuItem(
                                  value: champLocalisationValue,
                                  child: Text(champLocalisationValue!)),
                          ],
                          onChanged: null,
                          decoration: InputDecoration(
                              filled: true, fillColor: Colors.amber[50]),
                          validator: (v) =>
                              v == null ? "Sélectionner la localité" : null,
                          disabledHint: champLocalisationValue != null
                              ? Text(champLocalisationValue!)
                              : null,
                        ),
                        SizedBox(height: 9),

                        // Période de collecte - éditable
                        _label("Période de collecte"),
                        DropdownButtonFormField<String>(
                          value: periodeCollecte,
                          items: [
                            DropdownMenuItem(
                                value: "Petite Miélliée",
                                child: Text("Petite Miélliée")),
                            DropdownMenuItem(
                                value: "Grande Miélliée",
                                child: Text("Grande Miélliée")),
                          ],
                          onChanged: (s) => setState(() => periodeCollecte = s),
                          decoration: InputDecoration(
                              filled: true, fillColor: Colors.amber[50]),
                          validator: (v) =>
                              v == null ? "Sélectionner la période" : null,
                        ),
                        SizedBox(height: 9),

                        // Nature du miel
                        _label("Nature du miel"),
                        TextFormField(
                          enabled: false,
                          initialValue: natureMiel,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.amber[50],
                            prefixIcon: Icon(Icons.emoji_nature,
                                color: Colors.amber[700]),
                          ),
                        ),
                        SizedBox(height: 9),

                        // Contenant
                        _label("Contenant"),
                        DropdownButtonFormField<String>(
                          value: contenant,
                          items: [
                            DropdownMenuItem(
                                value: "Bidon", child: Text("Bidon")),
                            DropdownMenuItem(
                                value: "Sceau", child: Text("Sceau")),
                          ],
                          onChanged: isPreFilled('contenant')
                              ? null
                              : (s) => setState(() => contenant = s),
                          decoration: InputDecoration(
                              filled: true, fillColor: Colors.amber[50]),
                          validator: (v) =>
                              v == null ? "Sélectionner le contenant" : null,
                          disabledHint:
                              contenant != null ? Text(contenant!) : null,
                        ),
                        SizedBox(height: 9),

                        // Poids du contenant & Poids de l'ensemble
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label("Poids du contenant (kg)"),
                                  TextFormField(
                                    controller: poidsContenantCtrl,
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: InputDecoration(
                                      suffixText: "kg",
                                      filled: true,
                                      fillColor: Colors.amber[50],
                                    ),
                                    validator: (v) => (v == null ||
                                            v.isEmpty ||
                                            double.tryParse(v) == null)
                                        ? "Obligatoire"
                                        : null,
                                    onChanged: isPreFilled('poidsContenant')
                                        ? null
                                        : (v) => _calculPoidsMiel(),
                                    enabled: !isPreFilled('poidsContenant'),
                                    readOnly: isPreFilled('poidsContenant'),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label("Poids de l'ensemble"),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: poidsEnsembleCtrl,
                                          keyboardType:
                                              TextInputType.numberWithOptions(
                                                  decimal: true),
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: Colors.amber[50],
                                          ),
                                          validator: (v) => (v == null ||
                                                  v.isEmpty ||
                                                  double.tryParse(v) == null)
                                              ? "Obligatoire"
                                              : null,
                                          onChanged:
                                              isPreFilled('poidsEnsemble')
                                                  ? null
                                                  : (v) => _calculPoidsMiel(),
                                          enabled:
                                              !isPreFilled('poidsEnsemble'),
                                          readOnly:
                                              isPreFilled('poidsEnsemble'),
                                        ),
                                      ),
                                      SizedBox(width: 7),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            vertical: 8, horizontal: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.amber[50],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: Colors.amber[100]!),
                                        ),
                                        child: Text(
                                          uniteEnsemble ?? "kg",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.brown[800]),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 7),

                        _label("Poids du miel (auto-calculé)"),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                              vertical: 10, horizontal: 15),
                          decoration: BoxDecoration(
                            color: Colors.yellow[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber[100]!),
                          ),
                          child: Text(
                            "${poidsMiel?.toStringAsFixed(2) ?? "0.00"} kg",
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.brown[700]),
                          ),
                        ),
                        SizedBox(height: 9),

                        // Teneur en eau
                        _label("Teneur en eau (%)"),
                        TextFormField(
                          controller: teneurEauCtrl,
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            suffixText: "%",
                            filled: true,
                            fillColor: Colors.amber[50],
                          ),
                          validator: (v) => (v == null ||
                                  v.isEmpty ||
                                  double.tryParse(v) == null)
                              ? "Obligatoire"
                              : null,
                          enabled: !isPreFilled('teneurEau'),
                          readOnly: isPreFilled('teneurEau'),
                        ),
                        SizedBox(height: 9),

                        // Qualité
                        _label("Qualité"),
                        DropdownButtonFormField<String>(
                          value: qualite,
                          items: [
                            DropdownMenuItem(
                                value: "MAUVAIS", child: Text("MAUVAIS")),
                            DropdownMenuItem(value: "BON", child: Text("BON")),
                            DropdownMenuItem(
                                value: "TRES BON", child: Text("TRES BON")),
                          ],
                          onChanged: null, // Désactive le champ
                          decoration: InputDecoration(
                              filled: true, fillColor: Colors.amber[50]),
                          validator: (v) =>
                              v == null ? "Sélectionner la qualité" : null,
                          disabledHint: qualite != null ? Text(qualite!) : null,
                        ),
                        SizedBox(height: 9),

                        // Prédominance florale
                        _label("Prédominance florale"),
                        TextFormField(
                          enabled: false,
                          initialValue: predominanceFloraleList.join(', '),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.amber[50],
                          ),
                        ),
                        SizedBox(height: 9),

                        // Conformité
                        _label("Conformité"),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<bool>(
                                value: true,
                                groupValue: conformite,
                                title: Text("Oui"),
                                onChanged: (v) =>
                                    setState(() => conformite = v),
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<bool>(
                                value: false,
                                groupValue: conformite,
                                title: Text("Non"),
                                onChanged: (v) =>
                                    setState(() => conformite = v),
                              ),
                            ),
                          ],
                        ),
                        if (conformite == false) ...[
                          SizedBox(height: 7),
                          _label("Cause non-conformité"),
                          TextFormField(
                            controller: causeNonConformiteCtrl,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.amber[50],
                            ),
                            validator: (v) => (conformite == false &&
                                    (v == null || v.isEmpty))
                                ? "Obligatoire"
                                : null,
                          ),
                          SizedBox(height: 7),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _label("Quantité non conforme"),
                                    TextFormField(
                                      controller: quantiteNonConformeCtrl,
                                      keyboardType:
                                          TextInputType.numberWithOptions(
                                              decimal: true),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.amber[50],
                                      ),
                                      validator: (v) => (conformite == false &&
                                              (v == null ||
                                                  v.isEmpty ||
                                                  double.tryParse(v) == null))
                                          ? "Obligatoire"
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _label("Unité"),
                                    DropdownButtonFormField<String>(
                                      value: uniteNonConforme,
                                      items: ["kg", "litre"]
                                          .map((e) => DropdownMenuItem(
                                              value: e, child: Text(e)))
                                          .toList(),
                                      onChanged: (s) =>
                                          setState(() => uniteNonConforme = s),
                                      decoration: InputDecoration(
                                          filled: true,
                                          fillColor: Colors.amber[50]),
                                      validator: (v) => (conformite == false &&
                                              (v == null || v.isEmpty))
                                          ? "Obligatoire"
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                        SizedBox(height: 25),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label("Attribuer un N° de lot (obligatoire)"),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  icon: Icon(Icons.confirmation_number,
                                      color: Colors.white),
                                  label:
                                      Text(lotNumber ?? "Générer un n° de lot"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green[700],
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: lotCheckLoading
                                      ? null
                                      : () async {
                                          setState(
                                              () => lotCheckLoading = true);
                                          final lot =
                                              await _generateUniqueLotNumber();
                                          setState(() {
                                            lotNumber = lot;
                                            lotCheckLoading = false;
                                          });
                                          if (lot == null) {
                                            Get.snackbar("Erreur",
                                                "Impossible de générer un numéro unique, réessayez !");
                                          }
                                        },
                                ),
                                SizedBox(width: 12),
                                if (lotCheckLoading)
                                  SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator()),
                                if (lotNumber != null)
                                  Padding(
                                    padding: EdgeInsets.only(left: 6),
                                    child: Text(
                                      "N°: $lotNumber",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[800],
                                          fontSize: 15),
                                    ),
                                  ),
                              ],
                            ),
                            if (lotNumber == null)
                              Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text("Ce champ est obligatoire !",
                                    style: TextStyle(
                                        color: Colors.red, fontSize: 13)),
                              ),
                            SizedBox(height: 10),
                          ],
                        ),
                        SizedBox(height: 25),
                        Center(
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.save, color: Colors.white),
                              label: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 6.0, horizontal: 6.0),
                                child: Text(
                                  "Enregistrer le contrôle et la réception",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber[800],
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 28, vertical: 13),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                elevation: 4,
                              ),
                              onPressed: _onSave,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String txt) => Padding(
        padding: const EdgeInsets.only(left: 1.0, bottom: 2.0, top: 1.0),
        child: Text(txt,
            style: TextStyle(
                fontWeight: FontWeight.w600, color: Colors.brown[800])),
      );
}

String determinerQualite(double teneurEau) {
  if (teneurEau > 22) {
    return "MAUVAIS";
  } else if (teneurEau > 21) {
    return "BON";
  } else {
    return "TRES BON";
  }
}
