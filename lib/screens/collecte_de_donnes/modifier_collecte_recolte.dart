import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class EditRecolteForm extends StatefulWidget {
  final String collecteId;
  final String?
      sousCollecteId; // Si jamais tu souhaites gérer une sous-collection à terme

  const EditRecolteForm({
    required this.collecteId,
    this.sousCollecteId,
    super.key,
  });

  @override
  State<EditRecolteForm> createState() => _EditRecolteFormState();
}

class _EditRecolteFormState extends State<EditRecolteForm> {
  final _formKey = GlobalKey<FormState>();

  // Champs
  DateTime? _dateCollecte;
  String? _nomRecolteur;
  String? _region;
  String? _province;
  String? _village;
  double? _quantiteKg;
  String? _predominanceFlorale;
  DateTime? _dateRecolte;

  // Pour la saisie fluide
  final _quantiteCtrl = TextEditingController();

  // Référence exacte des listes et maps du CollecteController
  final List<String> recolteurs = [
    'SEMDE Souleymane',
    'TRAORE Abdoul Aziz',
    'DIALLO Amidou',
    'SIRIMA Salia',
    'ZONGO Martial',
    'KANCO Epicma',
    'ZOUNGRANA Hypolite',
  ];

  final Map<String, List<String>> regionsParRecolteur = {
    'SEMDE Souleymane': ['Hauts-Bassins', 'Cascades'],
    'TRAORE Abdoul Aziz': ['Cascades'],
    'DIALLO Amidou': ['Cascades'],
    'SIRIMA Salia': ['Cascades', 'Sud-Ouest'],
    'ZONGO Martial': ['Hauts-Bassins'],
    'KANCO Epicma': ['Centre-Ouest', 'Centre-Sud'],
    'ZOUNGRANA Hypolite': ['Centre-Ouest'],
  };

  final Map<String, Map<String, List<String>>> provincesParRecolteurEtRegion = {
    'SEMDE Souleymane': {
      'Hauts-Bassins': ['Tuy'],
      'Cascades': ['Léraba'],
    },
    'TRAORE Abdoul Aziz': {
      'Cascades': ['Léraba', 'Comoé'],
    },
    'DIALLO Amidou': {
      'Cascades': ['Léraba', 'Comoé'],
    },
    'SIRIMA Salia': {
      'Cascades': ['Comoé'],
      'Sud-Ouest': ['Poni'],
    },
    'ZONGO Martial': {
      'Hauts-Bassins': ['Houet', 'Tuy'],
    },
    'KANCO Epicma': {
      'Centre-Ouest': ['Sanguié'],
      'Centre-Sud': ['Nahouri'],
    },
    'ZOUNGRANA Hypolite': {
      'Centre-Ouest': ['Sanguié'],
    },
  };

  final Map<String, Map<String, Map<String, List<String>>>>
      villagesParRecolteurEtRegionEtProvince = {
    'SEMDE Souleymane': {
      'Hauts-Bassins': {
        'Tuy': [
          'Mahon (Commune de Kangata)',
          'Silarasso (Commune de Koloko)',
          'Bebougou (Commune de Ouéléni)',
        ]
      },
      'Cascades': {
        'Léraba': [
          'Kokouna (Commune de Koloko)',
        ]
      },
    },
    'TRAORE Abdoul Aziz': {
      'Cascades': {
        'Léraba': [
          'Dionso (Commune de Kankalaba)',
          'Kolasso (Commune de Kankalaba)',
          'Niantonon (Commune de Kankalaba)',
        ],
        'Comoé': [
          'Nalerie (Commune de Ouéléni)',
          'Tinou (Commune de Ouéléni)',
          'Tena (Commune de Ouéléni)',
          'Namboena (Commune de Ouéléni)',
          'Kankalaba (Commune de Kankalaba)',
        ],
      },
    },
    'DIALLO Amidou': {
      'Cascades': {
        'Léraba': [
          'Douna (Commune de Douna)',
          'Bougoula (Commune de Kankalaba)',
        ],
        'Comoé': [
          'Kangoura (Commune de Lounana)',
          'Baguera (Commune de Lounana)',
          'Soumadougoudjan (Commune de Lounana)',
          'Dakoro (Commune de Dakoro)',
          'Monsonon (Commune de Sindou)',
        ],
      },
    },
    'SIRIMA Salia': {
      'Cascades': {
        'Comoé': [
          'Tourni (Commune de Sindou)',
          'Toussiamasso (Localité non précisée)',
          'Kourinion (Localité non précisée)',
          'Sipigui (Localité non précisée)',
        ],
      },
      'Sud-Ouest': {
        'Poni': [
          'Guena (Localité non précisée)',
          'Sidi (Localité non précisée)',
          'Moussodougou (Commune de Moussodougou)',
        ]
      },
    },
    'ZONGO Martial': {
      'Hauts-Bassins': {
        'Houet': [
          'Nounousso (Commune de Bobo-Dioulasso)',
          'Dafinaso (Commune de Bobo-Dioulasso)',
          'Doulfguisso (Commune de Bobo-Dioulasso)',
        ],
        'Tuy': [
          'Dereguan (Commune de Karangasso-Vigué)',
          'Gnafongo (Commune de Peni)',
          'Ouére (Commune de Dan)',
          'Satiri (Commune de Satiri)',
          'Sala (Commune de Satiri)',
          'Toussiana (Commune de Toussiana)',
        ],
      }
    },
    'KANCO Epicma': {
      'Centre-Ouest': {
        'Sanguié': [
          'Réo (Commune de Réo)',
          'Dassa (Localité non précisée)',
          'Didyr (Localité non précisée)',
          'Godyr (Localité non précisée)',
          'Kyon (Localité non précisée)',
          'Ténado (Localité non précisée)',
        ]
      },
      'Centre-Sud': {
        'Nahouri': ['Pô (Commune de Pô)']
      }
    },
    'ZOUNGRANA Hypolite': {
      'Centre-Ouest': {
        'Sanguié': ['Réo (Commune de Réo)']
      }
    }
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

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _quantiteCtrl.addListener(() {
      setState(() {
        _quantiteKg = double.tryParse(_quantiteCtrl.text);
      });
    });
  }

  @override
  void dispose() {
    _quantiteCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    // On suppose que la récolte est stockée dans la sous-collec "Récolte" de la collecte (logique du controller)
    QuerySnapshot recolteSnapshot = await FirebaseFirestore.instance
        .collection('collectes')
        .doc(widget.collecteId)
        .collection('Récolte')
        .limit(1)
        .get();

    if (recolteSnapshot.docs.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final data = recolteSnapshot.docs.first.data() as Map<String, dynamic>;
    setState(() {
      _nomRecolteur = data['nomRecolteur'];
      _region = data['region'];
      _province = data['province'];
      _village = data['village'];
      _quantiteKg = (data['quantiteKg'] as num?)?.toDouble();
      _predominanceFlorale = data['predominanceFlorale'];
      _dateRecolte = (data['dateRecolte'] as Timestamp?)?.toDate();
      _quantiteCtrl.text = _quantiteKg?.toString() ?? '';
      _loading = false;
    });

    // Date de collecte (champ du doc principal)
    final doc = await FirebaseFirestore.instance
        .collection('collectes')
        .doc(widget.collecteId)
        .get();
    final docData = doc.data();
    if (docData != null) {
      setState(() {
        _dateCollecte = (docData['dateCollecte'] as Timestamp?)?.toDate();
      });
    }
  }

  void _resetForm() {
    setState(() {
      _nomRecolteur = null;
      _region = null;
      _province = null;
      _village = null;
      _quantiteKg = null;
      _predominanceFlorale = null;
      _dateRecolte = null;
      _dateCollecte = null;
      _quantiteCtrl.clear();
      // ... idem pour les autres variables/controllers selon le formulaire
    });
  }

  Future<void> _updateData() async {
    try {
      // 1. Met à jour la sous-collec Récolte de cette collecte
      final recolteSnap = await FirebaseFirestore.instance
          .collection('collectes')
          .doc(widget.collecteId)
          .collection('Récolte')
          .limit(1)
          .get();

      if (recolteSnap.docs.isEmpty) {
        Get.snackbar("Erreur", "Impossible de trouver la récolte à modifier !");
        return;
      }
      final recolteId = recolteSnap.docs.first.id;

      await FirebaseFirestore.instance
          .collection('collectes')
          .doc(widget.collecteId)
          .collection('Récolte')
          .doc(recolteId)
          .update({
        'nomRecolteur': _nomRecolteur,
        'region': _region,
        'province': _province,
        'village': _village,
        'quantiteKg': _quantiteKg,
        'predominanceFlorale': _predominanceFlorale,
        'dateRecolte': _dateRecolte,
      });

      // 2. Met à jour la date de collecte dans le doc principal (optionnel)
      await FirebaseFirestore.instance
          .collection('collectes')
          .doc(widget.collecteId)
          .update({
        'dateCollecte': _dateCollecte,
      });

      Get.snackbar(
        "Succès",
        "Récolte modifiée !",
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
            ListTile(
              title: Text(_dateCollecte != null
                  ? "Date de collecte: ${_dateCollecte!.day}/${_dateCollecte!.month}/${_dateCollecte!.year}"
                  : "Date de collecte"),
              trailing: Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dateCollecte ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _dateCollecte = picked);
              },
            ),
            DropdownButtonFormField<String>(
              value: _nomRecolteur,
              decoration: InputDecoration(
                labelText: "Technicien (récolteur)",
                prefixIcon: Icon(Icons.person_pin, color: Colors.amber),
              ),
              items: recolteurs
                  .map((nom) => DropdownMenuItem(value: nom, child: Text(nom)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _nomRecolteur = v;
                  _region = null;
                  _province = null;
                  _village = null;
                });
              },
              validator: (v) => v == null ? "Sélectionner un technicien" : null,
            ),
            DropdownButtonFormField<String>(
              value: _region,
              decoration: InputDecoration(
                labelText: "Région",
                prefixIcon: Icon(Icons.map, color: Colors.green[800]),
              ),
              items: (_nomRecolteur != null
                      ? regionsParRecolteur[_nomRecolteur!] ?? []
                      : <String>[])
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _region = val;
                  _province = null;
                  _village = null;
                });
              },
              validator: (v) => v == null ? "Sélectionner une région" : null,
            ),
            DropdownButtonFormField<String>(
              value: _province,
              decoration: InputDecoration(
                labelText: "Province",
                prefixIcon: Icon(Icons.location_city, color: Colors.deepPurple),
              ),
              items: _nomRecolteur != null && _region != null
                  ? (provincesParRecolteurEtRegion[_nomRecolteur!]?[_region!] ??
                          [])
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList()
                  : <DropdownMenuItem<String>>[],
              onChanged: (val) {
                setState(() {
                  _province = val;
                  _village = null;
                });
              },
              validator: (v) => v == null ? "Sélectionner une province" : null,
            ),
            DropdownButtonFormField<String>(
              value: _village,
              decoration: InputDecoration(
                labelText: "Village",
                prefixIcon: Icon(Icons.place, color: Colors.teal),
              ),
              items: _nomRecolteur != null &&
                      _region != null &&
                      _province != null
                  ? (villagesParRecolteurEtRegionEtProvince[_nomRecolteur!]
                              ?[_region!]?[_province!] ??
                          [])
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList()
                  : <DropdownMenuItem<String>>[],
              onChanged: (val) => setState(() => _village = val),
              validator: (v) => v == null ? "Sélectionner un village" : null,
            ),
            TextFormField(
              controller: _quantiteCtrl,
              decoration: InputDecoration(
                  labelText: "Quantité (kg)",
                  suffixText: "kg",
                  prefixIcon: Icon(Icons.balance, color: Colors.brown[400])),
              keyboardType: TextInputType.number,
              validator: (v) =>
                  v == null || v.isEmpty || double.tryParse(v) == null
                      ? "Obligatoire"
                      : null,
            ),
            DropdownButtonFormField<String>(
              value: _predominanceFlorale,
              decoration: InputDecoration(
                labelText: "Prédominance florale",
                prefixIcon: Icon(Icons.local_florist, color: Colors.orange),
              ),
              items: flores
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (v) => setState(() => _predominanceFlorale = v),
              validator: (v) => v == null ? "Sélectionner une florale" : null,
            ),
            ListTile(
              title: Text(_dateRecolte != null
                  ? "Date de récolte: ${_dateRecolte!.day}/${_dateRecolte!.month}/${_dateRecolte!.year}"
                  : "Date de récolte"),
              trailing: Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dateRecolte ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _dateRecolte = picked);
              },
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
                icon: Icon(Icons.save),
                label: Text("Enregistrer les modifications"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[700]),
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
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
