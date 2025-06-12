import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class EditAchatIndividuelForm extends StatefulWidget {
  final String collecteId;
  final String achatId;
  final String infoId;

  // Il faut fournir l'id du doc dans "Individuel" et celui de "Individuel_info"
  const EditAchatIndividuelForm({
    required this.collecteId,
    required this.achatId,
    required this.infoId,
    super.key,
  });

  @override
  State<EditAchatIndividuelForm> createState() =>
      _EditAchatIndividuelFormState();
}

class _EditAchatIndividuelFormState extends State<EditAchatIndividuelForm> {
  final _formKey = GlobalKey<FormState>();

  // Contrôleurs
  final _quantiteCtrl = TextEditingController();
  final _prixUnitaireCtrl = TextEditingController();

  String? _nomIndiv;
  String? _typeRuche;
  String? _typeProduit;
  String? _unite;
  DateTime? _dateAchat;

  double? _quantite;
  double? _prixUnitaire;
  double? _prixTotal;

  List<String> individuelsConnus = [];
  final List<String> typesRuche = ['Traditionnelle', 'Moderne'];
  final List<String> typesProduit = ['Miel brut', 'Miel filtré', 'Cire'];
  final List<String> unites = ['kg', 'litre'];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchIndividuels().then((_) => _fetchData());
    _quantiteCtrl.addListener(_calcAndSetPrixTotal);
    _prixUnitaireCtrl.addListener(_calcAndSetPrixTotal);
  }

  @override
  void dispose() {
    _quantiteCtrl.dispose();
    _prixUnitaireCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchIndividuels() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('Individuels').get();
    setState(() {
      individuelsConnus =
          snapshot.docs.map((doc) => doc['nomPrenom'] as String).toList();
    });
  }

  Future<void> _fetchData() async {
    // 1. Récupérer les infos de l'achat (dans la sous-collection Individuel)
    final achatDoc = await FirebaseFirestore.instance
        .collection('collectes')
        .doc(widget.collecteId)
        .collection('Individuel')
        .doc(widget.achatId)
        .get();
    final achatData = achatDoc.data();

    // 2. Récupérer les infos du producteur (dans la sous-sous-collection Individuel_info)
    final infoDoc = await FirebaseFirestore.instance
        .collection('collectes')
        .doc(widget.collecteId)
        .collection('Individuel')
        .doc(widget.achatId)
        .collection('Individuel_info')
        .doc(widget.infoId)
        .get();
    final infoData = infoDoc.data();

    if (achatData != null && infoData != null) {
      setState(() {
        _quantite = (achatData['quantite'] as num?)?.toDouble();
        _prixUnitaire = (achatData['prixUnitaire'] as num?)?.toDouble();
        _prixTotal = (achatData['prixTotal'] as num?)?.toDouble();
        _typeProduit = achatData['typeProduit'];
        _typeRuche = achatData['typeRuche'];
        _unite = achatData['unite'];
        _dateAchat = (achatData['dateAchat'] as Timestamp?)?.toDate();

        _nomIndiv = infoData['nomPrenom'];

        _quantiteCtrl.text = _quantite?.toString() ?? '';
        _prixUnitaireCtrl.text = _prixUnitaire?.toString() ?? '';
        _calcAndSetPrixTotal();
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
      });
    }
  }

  void _calcAndSetPrixTotal() {
    final q = double.tryParse(_quantiteCtrl.text) ?? 0;
    final pu = double.tryParse(_prixUnitaireCtrl.text) ?? 0;
    setState(() {
      _quantite = q == 0 ? null : q;
      _prixUnitaire = pu == 0 ? null : pu;
      if (_quantite != null && _prixUnitaire != null) {
        _prixTotal = _quantite! * _prixUnitaire!;
      } else {
        _prixTotal = null;
      }
    });
  }

  void _resetForm() {
    setState(() {
      _nomIndiv = null;
      _typeRuche = null;
      _typeProduit = null;
      _quantite = null;
      _unite = null;
      _prixUnitaire = null;
      _prixTotal = null;
      _dateAchat = null;
      _quantiteCtrl.clear();
      _prixUnitaireCtrl.clear();
    });
  }

  Future<void> _updateData() async {
    try {
      // 1. Mettre à jour les infos de l'achat
      await FirebaseFirestore.instance
          .collection('collectes')
          .doc(widget.collecteId)
          .collection('Individuel')
          .doc(widget.achatId)
          .update({
        'typeRuche': _typeRuche,
        'typeProduit': _typeProduit,
        'quantite': _quantite,
        'unite': _unite,
        'prixUnitaire': _prixUnitaire,
        'prixTotal': _prixTotal,
        'dateAchat': _dateAchat,
      });

      // 2. Mettre à jour les infos du producteur individuel associé
      await FirebaseFirestore.instance
          .collection('collectes')
          .doc(widget.collecteId)
          .collection('Individuel')
          .doc(widget.achatId)
          .collection('Individuel_info')
          .doc(widget.infoId)
          .update({
        'nomPrenom': _nomIndiv,
      });

      Get.snackbar(
        "Succès",
        "Achat individuel modifié !",
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      _resetForm();
      Get.back();
    } catch (e) {
      Get.snackbar(
        "Erreur",
        "La modification a échoué. ${e.toString()}",
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  bool _allFieldsFilled() {
    return _nomIndiv != null &&
        _typeRuche != null &&
        _typeProduit != null &&
        _quantite != null &&
        _unite != null &&
        _prixUnitaire != null &&
        _prixTotal != null &&
        _dateAchat != null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(child: CircularProgressIndicator());
    }
    return Padding(
      padding: EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            DropdownButtonFormField<String>(
              value: _nomIndiv,
              decoration: InputDecoration(labelText: "Producteur individuel"),
              items: individuelsConnus
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _nomIndiv = v),
              validator: (v) => v == null ? "Sélectionner un producteur" : null,
            ),
            DropdownButtonFormField<String>(
              value: _typeRuche,
              decoration: InputDecoration(labelText: "Type de ruche"),
              items: typesRuche
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _typeRuche = v),
              validator: (v) =>
                  v == null ? "Sélectionner le type de ruche" : null,
            ),
            DropdownButtonFormField<String>(
              value: _typeProduit,
              decoration: InputDecoration(labelText: "Type de produit"),
              items: typesProduit
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _typeProduit = v),
              validator: (v) =>
                  v == null ? "Sélectionner le type de produit" : null,
            ),
            TextFormField(
              controller: _quantiteCtrl,
              decoration: InputDecoration(labelText: "Quantité"),
              keyboardType: TextInputType.number,
              validator: (v) =>
                  v == null || v.isEmpty || double.tryParse(v) == null
                      ? "Obligatoire"
                      : null,
            ),
            DropdownButtonFormField<String>(
              value: _unite,
              decoration: InputDecoration(labelText: "Unité"),
              items: unites
                  .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                  .toList(),
              onChanged: (v) => setState(() => _unite = v),
              validator: (v) => v == null ? "Sélectionner l'unité" : null,
            ),
            TextFormField(
              controller: _prixUnitaireCtrl,
              decoration: InputDecoration(labelText: "Prix unitaire"),
              keyboardType: TextInputType.number,
              validator: (v) =>
                  v == null || v.isEmpty || double.tryParse(v) == null
                      ? "Obligatoire"
                      : null,
            ),
            TextFormField(
              enabled: false,
              decoration: InputDecoration(labelText: "Prix total"),
              style: TextStyle(
                  color: Colors.blueGrey[600], fontWeight: FontWeight.bold),
              controller: TextEditingController(
                text: _prixTotal != null ? _prixTotal!.toStringAsFixed(2) : "",
              ),
            ),
            ListTile(
              title: Text(_dateAchat != null
                  ? "Date d'achat: ${_dateAchat!.day}/${_dateAchat!.month}/${_dateAchat!.year}"
                  : "Date d'achat"),
              trailing: Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dateAchat ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _dateAchat = picked);
              },
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
                icon: Icon(Icons.save),
                label: Text("Enregistrer les modifications"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[700]),
                onPressed: () {
                  if ((_formKey.currentState?.validate() ?? false) &&
                      _allFieldsFilled()) {
                    _updateData();
                  } else {
                    Get.snackbar(
                        "Erreur", "Veuillez remplir tous les champs !");
                  }
                }),
          ],
        ),
      ),
    );
  }
}
