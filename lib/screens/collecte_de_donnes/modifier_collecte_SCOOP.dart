import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class EditAchatSCOOPForm extends StatefulWidget {
  final String collecteId;
  final String achatId;
  final String infoId;

  // On attend maintenant aussi achatId et infoId
  const EditAchatSCOOPForm({
    required this.collecteId,
    required this.achatId,
    required this.infoId,
    super.key,
  });

  @override
  State<EditAchatSCOOPForm> createState() => _EditAchatSCOOPFormState();
}

class _EditAchatSCOOPFormState extends State<EditAchatSCOOPForm> {
  final _formKey = GlobalKey<FormState>();

  // Controllers pour focus et édition fluide
  final _quantiteAccepteeCtrl = TextEditingController();
  final _quantiteRejeteeCtrl = TextEditingController();
  final _prixUnitaireCtrl = TextEditingController();

  String? _nomSCOOPS;
  String? _typeRuche;
  String? _typeProduit;
  String? _unite;
  DateTime? _dateAchat;

  double? _quantiteAcceptee;
  double? _quantiteRejetee;
  double? _prixUnitaire;
  double? _prixTotal;

  List<String> scoopsConnues = [];
  final List<String> typesRuche = ['Traditionnelle', 'Moderne'];
  final List<String> typesProduit = ['Miel brut', 'Miel filtré', 'Cire'];
  final List<String> unites = ['kg', 'litre'];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchScoops().then((_) => _fetchData());
    _quantiteAccepteeCtrl.addListener(_calcAndSetPrixTotal);
    _prixUnitaireCtrl.addListener(_calcAndSetPrixTotal);
  }

  @override
  void dispose() {
    _quantiteAccepteeCtrl.dispose();
    _quantiteRejeteeCtrl.dispose();
    _prixUnitaireCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchScoops() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('SCOOPS').get();
    setState(() {
      scoopsConnues = snapshot.docs.map((doc) => doc['nom'] as String).toList();
    });
  }

  Future<void> _fetchData() async {
    // 1. Récupérer l'achat dans la sous-collec SCOOP
    final achatDoc = await FirebaseFirestore.instance
        .collection('collectes')
        .doc(widget.collecteId)
        .collection('SCOOP')
        .doc(widget.achatId)
        .get();
    final achatData = achatDoc.data();

    // 2. Récupérer l'info de la SCOOPS associée
    final infoDoc = await FirebaseFirestore.instance
        .collection('collectes')
        .doc(widget.collecteId)
        .collection('SCOOP')
        .doc(widget.achatId)
        .collection('SCOOP_info')
        .doc(widget.infoId)
        .get();
    final infoData = infoDoc.data();

    if (achatData != null && infoData != null) {
      setState(() {
        _typeRuche = achatData['typeRuche'];
        _typeProduit = achatData['typeProduit'];
        _quantiteAcceptee = (achatData['quantite'] as num?)?.toDouble();
        _quantiteRejetee = (achatData['quantiteRejetee'] as num?)?.toDouble();
        _unite = achatData['unite'];
        _prixUnitaire = (achatData['prixUnitaire'] as num?)?.toDouble();
        _prixTotal = (achatData['prixTotal'] as num?)?.toDouble();
        _dateAchat = (achatData['dateAchat'] as Timestamp?)?.toDate();

        _nomSCOOPS = infoData['nom'];

        _quantiteAccepteeCtrl.text = _quantiteAcceptee?.toString() ?? '';
        _quantiteRejeteeCtrl.text = _quantiteRejetee?.toString() ?? '';
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
    final q = double.tryParse(_quantiteAccepteeCtrl.text) ?? 0;
    final pu = double.tryParse(_prixUnitaireCtrl.text) ?? 0;
    setState(() {
      _quantiteAcceptee = q == 0 ? null : q;
      _prixUnitaire = pu == 0 ? null : pu;
      if (_quantiteAcceptee != null && _prixUnitaire != null) {
        _prixTotal = _quantiteAcceptee! * _prixUnitaire!;
      } else {
        _prixTotal = null;
      }
    });
  }

  void _resetForm() {
    setState(() {
      _nomSCOOPS = null;
      _typeRuche = null;
      _typeProduit = null;
      _quantiteAcceptee = null;
      _quantiteRejetee = null;
      _unite = null;
      _prixUnitaire = null;
      _prixTotal = null;
      _dateAchat = null;
      _quantiteAccepteeCtrl.clear();
      _quantiteRejeteeCtrl.clear();
      _prixUnitaireCtrl.clear();
    });
  }

  Future<void> _updateData() async {
    try {
      // 1. Mettre à jour les infos d'achat
      await FirebaseFirestore.instance
          .collection('collectes')
          .doc(widget.collecteId)
          .collection('SCOOP')
          .doc(widget.achatId)
          .update({
        'typeRuche': _typeRuche,
        'typeProduit': _typeProduit,
        'quantite': _quantiteAcceptee,
        'quantiteRejetee': _quantiteRejetee,
        'unite': _unite,
        'prixUnitaire': _prixUnitaire,
        'prixTotal': _prixTotal,
        'dateAchat': _dateAchat,
      });

      // 2. Mettre à jour les infos de la SCOOPS associée
      await FirebaseFirestore.instance
          .collection('collectes')
          .doc(widget.collecteId)
          .collection('SCOOP')
          .doc(widget.achatId)
          .collection('SCOOP_info')
          .doc(widget.infoId)
          .update({
        'nom': _nomSCOOPS,
      });

      Get.snackbar(
        "Succès",
        "Achat SCOOPS modifié !",
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
    return _nomSCOOPS != null &&
        _typeRuche != null &&
        _typeProduit != null &&
        _quantiteAcceptee != null &&
        _quantiteRejetee != null &&
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
              value: _nomSCOOPS,
              decoration: InputDecoration(labelText: "SCOOPS"),
              items: scoopsConnues
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _nomSCOOPS = v),
              validator: (v) => v == null ? "Sélectionner une SCOOPS" : null,
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
              controller: _quantiteAccepteeCtrl,
              decoration: InputDecoration(labelText: "Quantité acceptée"),
              keyboardType: TextInputType.number,
              validator: (v) =>
                  v == null || v.isEmpty || double.tryParse(v) == null
                      ? "Obligatoire"
                      : null,
            ),
            TextFormField(
              controller: _quantiteRejeteeCtrl,
              decoration: InputDecoration(labelText: "Quantité rejetée"),
              keyboardType: TextInputType.number,
              onChanged: (v) =>
                  setState(() => _quantiteRejetee = double.tryParse(v)),
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
