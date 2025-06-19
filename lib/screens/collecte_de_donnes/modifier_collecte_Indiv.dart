import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class EditAchatIndividuelForm extends StatefulWidget {
  final String collecteId;
  final String achatDocId; // id du doc unique dans "Individuel"
  final int indexProduit; // index du produit dans le tableau details
  final String infoId;

  const EditAchatIndividuelForm({
    required this.collecteId,
    required this.achatDocId,
    required this.indexProduit,
    required this.infoId,
    super.key,
  });

  @override
  State<EditAchatIndividuelForm> createState() =>
      _EditAchatIndividuelFormState();
}

class _EditAchatIndividuelFormState extends State<EditAchatIndividuelForm> {
  final _formKey = GlobalKey<FormState>();

  final _quantiteAccepteeCtrl = TextEditingController();
  final _quantiteRejeteeCtrl = TextEditingController();
  final _prixUnitaireCtrl = TextEditingController();

  String? _nomIndiv;
  String? _typeRuche;
  String? _typeProduit;
  String? _unite;
  DateTime? _dateAchat;

  double? _quantiteAcceptee;
  double? _quantiteRejetee;
  double? _prixUnitaire;
  double? _prixTotal;

  List<String> individuelsConnus = [];
  final List<String> typesRuche = ['Traditionnelle', 'Moderne'];
  final List<String> typesProduit = ['Miel brut', 'Miel filtré', 'Cire'];
  final List<String> unites = ['kg', 'litre'];

  bool _loading = true;
  List<dynamic> _details = [];

  @override
  void initState() {
    super.initState();
    _fetchIndividuels().then((_) => _fetchData());
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

  Future<void> _fetchIndividuels() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('Individuels').get();
    setState(() {
      individuelsConnus =
          snapshot.docs.map((doc) => doc['nomPrenom'] as String).toList();
    });
  }

  Future<void> _fetchData() async {
    final achatDoc = await FirebaseFirestore.instance
        .collection('collectes')
        .doc(widget.collecteId)
        .collection('Individuel')
        .doc(widget.achatDocId)
        .get();
    final achatData = achatDoc.data();
    _details = (achatData?['details'] as List?) ?? [];

    final infoDoc = await FirebaseFirestore.instance
        .collection('collectes')
        .doc(widget.collecteId)
        .collection('Individuel')
        .doc(widget.achatDocId)
        .collection('Individuel_info')
        .doc(widget.infoId)
        .get();
    final infoData = infoDoc.data();

    if (_details.length > widget.indexProduit) {
      final prod = Map<String, dynamic>.from(_details[widget.indexProduit]);
      setState(() {
        _typeRuche = prod['typeRuche'] as String?;
        _typeProduit = prod['typeProduit'] as String?;
        _quantiteAcceptee = (prod['quantiteAcceptee'] as num?)?.toDouble();
        _quantiteRejetee = (prod['quantiteRejetee'] as num?)?.toDouble();
        _unite = prod['unite'] as String?;
        _prixUnitaire = (prod['prixUnitaire'] as num?)?.toDouble();
        _prixTotal = (prod['prixTotal'] as num?)?.toDouble();
        _dateAchat = achatData?['dateAchat'] is Timestamp
            ? (achatData?['dateAchat'] as Timestamp).toDate()
            : null;

        _nomIndiv = infoData?['nomPrenom'];
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

  Future<void> _updateData() async {
    try {
      List<dynamic> updatedDetails = List.from(_details);
      if (updatedDetails.length <= widget.indexProduit) {
        throw Exception("Index produit invalide");
      }
      Map<String, dynamic> prod =
          Map<String, dynamic>.from(updatedDetails[widget.indexProduit]);
      prod['typeRuche'] = _typeRuche;
      prod['typeProduit'] = _typeProduit;
      prod['quantiteAcceptee'] = _quantiteAcceptee;
      prod['quantiteRejetee'] = _quantiteRejetee;
      prod['unite'] = _unite;
      prod['prixUnitaire'] = _prixUnitaire;
      prod['prixTotal'] = _prixTotal;
      updatedDetails[widget.indexProduit] = prod;

      await FirebaseFirestore.instance
          .collection('collectes')
          .doc(widget.collecteId)
          .collection('Individuel')
          .doc(widget.achatDocId)
          .update({
        'details': updatedDetails,
        'dateAchat': _dateAchat,
      });

      await FirebaseFirestore.instance
          .collection('collectes')
          .doc(widget.collecteId)
          .collection('Individuel')
          .doc(widget.achatDocId)
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
      Navigator.of(context).pop(); // <-- Retour à la page précédente
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
      return Scaffold(
        appBar: AppBar(
          title: Text("Modifier Achat Individuel"),
          backgroundColor: Colors.amber[700],
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text("Modifier Achat Individuel"),
        backgroundColor: Colors.amber[700],
      ),
      body: Padding(
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
                validator: (v) =>
                    v == null ? "Sélectionner un producteur" : null,
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
                  text:
                      _prixTotal != null ? _prixTotal!.toStringAsFixed(2) : "",
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
      ),
    );
  }
}
