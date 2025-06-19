import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PrelevementMagasinierFormPage extends StatefulWidget {
  final Map<String, dynamic> lotConditionnement;
  const PrelevementMagasinierFormPage({
    super.key,
    required this.lotConditionnement,
  });

  @override
  State<PrelevementMagasinierFormPage> createState() =>
      _PrelevementMagasinierFormPageState();
}

class _PrelevementMagasinierFormPageState
    extends State<PrelevementMagasinierFormPage> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _date;

  Map<String, dynamic>? currentUserDoc;
  String? currentUserId;
  String? currentUserRole;

  String? _magasinierSourceId;
  String? _magasinierDestId;
  List<Map<String, dynamic>> magasiniers = [];

  // Prix gros mille fleurs
  static const Map<String, double> prixGrosMilleFleurs = {
    "Stick 20g": 1500,
    "Pot alvéoles 30g": 36000,
    "250g": 950,
    "500g": 1800,
    "1Kg": 3400,
    "720g": 2500,
    "1.5Kg": 4500,
    "7kg": 23000,
  };

  // Prix gros mono fleur
  static const Map<String, double> prixGrosMonoFleur = {
    "250g": 1750,
    "500g": 3000,
    "1Kg": 5000,
    "720g": 3500,
    "1.5Kg": 6000,
    "7kg": 34000,
    "Stick 20g": 1500,
    "Pot alvéoles 30g": 36000,
  };

  static const Map<String, double> potKg = {
    "1.5Kg": 1.5,
    "1Kg": 1.0,
    "720g": 0.72,
    "500g": 0.5,
    "250g": 0.25,
    "Pot alvéoles 30g": 0.03,
    "Stick 20g": 0.02,
    "7kg": 7.0,
  };

  static const Map<String, IconData> potIcons = {
    "1.5Kg": Icons.local_drink,
    "1Kg": Icons.water,
    "720g": Icons.emoji_food_beverage,
    "500g": Icons.wine_bar,
    "250g": Icons.local_cafe,
    "Pot alvéoles 30g": Icons.coffee,
    "Stick 20g": Icons.sticky_note_2,
    "7kg": Icons.liquor,
  };

  final List<String> typesEmballage = [
    "1.5Kg",
    "1Kg",
    "720g",
    "500g",
    "250g",
    "Pot alvéoles 30g",
    "Stick 20g",
    "7kg",
  ];

  Map<String, bool> emballageSelection = {};
  Map<String, TextEditingController> nbPotsController = {};

  double quantiteTotale = 0;
  double prixTotalEstime = 0;
  List<Map<String, dynamic>> _emballages = [];

  Map<String, int> potsRestantsParType = {};

  String get predominanceFlorale {
    final f = (widget.lotConditionnement['predominanceFlorale'] ?? '')
        .toString()
        .toLowerCase();
    return f;
  }

  @override
  void initState() {
    super.initState();
    for (final t in typesEmballage) {
      emballageSelection[t] = false;
      nbPotsController[t] = TextEditingController();
      nbPotsController[t]!.addListener(_recalc);
    }
    _loadData();
    _loadPotsRestants();
  }

  @override
  void dispose() {
    nbPotsController.values.forEach((c) => c.dispose());
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final userDoc = await FirebaseFirestore.instance
          .collection('utilisateurs')
          .doc(user.uid)
          .get();
      final data = userDoc.data() ?? {};
      final role = data['role'];
      setState(() {
        currentUserId = user.uid;
        currentUserDoc = data;
        currentUserRole = role;
      });

      // Récupère tous les magasiniers SIMPLES uniquement
      final snapMag = await FirebaseFirestore.instance
          .collection('utilisateurs')
          .where('role', isEqualTo: 'Magazinier')
          .get();

      final allMags = snapMag.docs
          .map((d) => {
                "id": d.id,
                ...d.data() as Map<String, dynamic>,
                "magazinier":
                    (d.data() as Map<String, dynamic>)["magazinier"] ?? {}
              })
          .where((m) =>
              (m['magazinier']?['type'] ?? '').toString().toLowerCase() ==
              'simple')
          .toList();

      setState(() {
        magasiniers = allMags;

        // Source: PRINCIPALE ou utilisateur courant si SIMPLE
        _magasinierSourceId = currentUserId;
        // Destinataire: un magasinier simple différent du source
        _magasinierDestId = magasiniers
            .where((m) => m['id'] != _magasinierSourceId)
            .map((m) => m['id'] as String)
            .firstOrNull;
      });
    } catch (e) {
      Get.snackbar("Erreur", "Chargement magasiniers : $e");
    }
  }

  Future<void> _loadPotsRestants() async {
    try {
      final lotId = widget.lotConditionnement['id'];
      final Map<String, int> stockInitial = {};
      if (widget.lotConditionnement['emballages'] != null) {
        for (var emb in widget.lotConditionnement['emballages']) {
          stockInitial[emb['type']] = emb['nombre'];
        }
      }
      final prelevSnap = await FirebaseFirestore.instance
          .collection('prelevements')
          .where('lotConditionnementId', isEqualTo: lotId)
          .get();
      final Map<String, int> stockRestant = Map<String, int>.from(stockInitial);
      for (var doc in prelevSnap.docs) {
        final data = doc.data();
        if (data['emballages'] != null) {
          for (var emb in data['emballages']) {
            final t = emb['type'];
            stockRestant[t] =
                (stockRestant[t] ?? 0) - ((emb['nombre'] ?? 0) as num).toInt();
          }
        }
      }
      setState(() {
        potsRestantsParType = stockRestant;
      });
    } catch (e) {
      Get.snackbar("Erreur", "Chargement stock restant : $e");
    }
  }

  double getPrixAuto(String type) {
    final florale = predominanceFlorale;
    final isMono = _isMonoFleur(florale);
    if (isMono) {
      return prixGrosMonoFleur[type] ?? prixGrosMilleFleurs[type] ?? 0.0;
    } else {
      return prixGrosMilleFleurs[type] ?? 0.0;
    }
  }

  bool _isMonoFleur(String florale) {
    if (florale.contains("mono")) return true;
    if (florale.contains("mille") || florale.contains("mixte")) return false;
    if (florale.contains("+") || florale.contains(",")) return false;
    return florale.trim().isNotEmpty;
  }

  void _recalc() {
    double qte = 0;
    double prix = 0;
    _emballages = [];
    for (final type in typesEmballage) {
      if (!emballageSelection[type]!) continue;
      final n = int.tryParse(nbPotsController[type]?.text ?? '') ?? 0;
      final prixu = getPrixAuto(type);
      final kg = potKg[type] ?? 0.0;
      if (n > 0) {
        if (type == "Stick 20g") {
          qte += n * 10 * 0.02;
          prix += n * prixu;
          _emballages.add({
            "type": type,
            "mode": "Paquet (10)",
            "nombre": n * 10,
            "contenanceKg": 0.02,
            "prixUnitaire": prixu,
            "prixTotal": n * prixu,
          });
        } else if (type == "Pot alvéoles 30g") {
          qte += n * 200 * 0.03;
          prix += n * prixu;
          _emballages.add({
            "type": type,
            "mode": "Carton (200)",
            "nombre": n * 200,
            "contenanceKg": 0.03,
            "prixUnitaire": prixu,
            "prixTotal": n * prixu,
          });
        } else {
          qte += n * kg;
          prix += n * prixu;
          _emballages.add({
            "type": type,
            "mode": "Gros",
            "nombre": n,
            "contenanceKg": kg,
            "prixUnitaire": prixu,
            "prixTotal": n * prixu,
          });
        }
      }
    }
    setState(() {
      quantiteTotale = qte;
      prixTotalEstime = prix;
    });
  }

  bool get isValidEmballages {
    for (final type in typesEmballage) {
      if (emballageSelection[type] == true) {
        final txt = nbPotsController[type]?.text ?? '';
        final n = int.tryParse(txt);
        if (n != null && n > 0 && n <= (potsRestantsParType[type] ?? 0)) {
          return true;
        }
      }
    }
    return false;
  }

  bool get isFormValid {
    return _formKey.currentState?.validate() == true &&
        isValidEmballages &&
        _date != null &&
        _magasinierSourceId != null &&
        _magasinierDestId != null &&
        _magasinierSourceId != _magasinierDestId;
  }

  Future<void> _save() async {
    if (!isFormValid) {
      Get.snackbar("Erreur", "Veuillez remplir tous les champs obligatoires.");
      return;
    }
    final double lotConditionne =
        (widget.lotConditionnement['quantiteConditionnee'] ?? 0.0).toDouble();
    if (quantiteTotale > lotConditionne) {
      Get.snackbar("Erreur",
          "La quantité prélevée dépasse le stock disponible (${lotConditionne.toStringAsFixed(2)} kg) !");
      return;
    }
    for (final type in typesEmballage) {
      if (emballageSelection[type] == true) {
        final n = int.tryParse(nbPotsController[type]?.text ?? '') ?? 0;
        if (type == "Stick 20g" &&
            (n * 10 > (potsRestantsParType[type] ?? 0))) {
          Get.snackbar("Erreur",
              "Vous ne pouvez pas prélever plus de ${potsRestantsParType[type] ?? 0} sticks (par paquets de 10) pour $type.");
          return;
        }
        if (type == "Pot alvéoles 30g" &&
            (n * 200 > (potsRestantsParType[type] ?? 0))) {
          Get.snackbar("Erreur",
              "Vous ne pouvez pas prélever plus de ${potsRestantsParType[type] ?? 0} pots alvéoles (par cartons de 200) pour $type.");
          return;
        }
        if (type != "Stick 20g" &&
            type != "Pot alvéoles 30g" &&
            (n > (potsRestantsParType[type] ?? 0))) {
          Get.snackbar("Erreur",
              "Vous ne pouvez pas prélever plus de ${potsRestantsParType[type] ?? 0} pots pour $type.");
          return;
        }
      }
    }

    try {
      await FirebaseFirestore.instance.collection('prelevements').add({
        "datePrelevement": _date,
        "magasinierSourceId": _magasinierSourceId,
        "magasinierSourceNom": magasiniers.firstWhere(
                (m) => m['id'] == _magasinierSourceId,
                orElse: () => currentUserDoc ?? {})['magazinier']?['nom'] ??
            magasiniers.firstWhere((m) => m['id'] == _magasinierSourceId,
                orElse: () => currentUserDoc ?? {})['nom'] ??
            "",
        "magasinierDestId": _magasinierDestId,
        "magasinierDestNom": magasiniers.firstWhere(
                (m) => m['id'] == _magasinierDestId,
                orElse: () => {})['magazinier']?['nom'] ??
            magasiniers.firstWhere((m) => m['id'] == _magasinierDestId,
                orElse: () => {})['nom'] ??
            "",
        "emballages": _emballages,
        "quantiteTotale": quantiteTotale,
        "prixTotalEstime": prixTotalEstime,
        "lotConditionnementId": widget.lotConditionnement['id'],
        "createdAt": FieldValue.serverTimestamp(),
        "typePrelevement": "magasinier",
      });

      Get.snackbar("Succès", "Prélèvement entre magasiniers enregistré !");
      Get.back(result: true);

      setState(() {
        _date = null;
        emballageSelection.updateAll((key, value) => false);
        nbPotsController.forEach((key, controller) => controller.clear());
        quantiteTotale = 0;
        prixTotalEstime = 0;
      });
    } catch (e) {
      Get.snackbar("Erreur", "Enregistrement échoué : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    String? sourceValue =
        (magasiniers.any((m) => m['id'] == _magasinierSourceId))
            ? _magasinierSourceId
            : null;
    String? destValue = (magasiniers.any((m) => m['id'] == _magasinierDestId) &&
            _magasinierDestId != _magasinierSourceId)
        ? _magasinierDestId
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Prélèvement à un magasinier simple"),
        backgroundColor: Colors.brown[700],
      ),
      body: magasiniers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store, color: Colors.brown, size: 50),
                  const SizedBox(height: 12),
                  const Text(
                    "Aucun magasinier simple n'est enregistré !",
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text("Rafraîchir"),
                    onPressed: () {
                      _loadData();
                      _loadPotsRestants();
                    },
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Date prélèvement
                    ListTile(
                      leading:
                          const Icon(Icons.calendar_today, color: Colors.brown),
                      title: Text(
                        _date != null
                            ? "Date : ${_date!.day}/${_date!.month}/${_date!.year}"
                            : "Sélectionner la date de prélèvement",
                        style: TextStyle(
                            color: _date == null ? Colors.red : Colors.black),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_calendar,
                            color: Colors.brown),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _date ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setState(() => _date = picked);
                        },
                      ),
                    ),
                    if (_date == null)
                      const Padding(
                        padding: EdgeInsets.only(left: 16.0, bottom: 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text("La date est obligatoire.",
                              style:
                                  TextStyle(color: Colors.red, fontSize: 12)),
                        ),
                      ),
                    const Divider(height: 25),
                    // Magasinier Source (non éditable, auto: utilisateur courant)
                    ListTile(
                      leading: const Icon(Icons.store, color: Colors.brown),
                      title: const Text("Magasinier source (vous)"),
                      subtitle: Text(
                        magasiniers.firstWhereOrNull((m) =>
                                m['id'] ==
                                _magasinierSourceId)?['magazinier']?['nom'] ??
                            currentUserDoc?['magazinier']?['nom'] ??
                            currentUserDoc?['nom'] ??
                            "Vous",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: CircleAvatar(
                        backgroundColor: Colors.brown[100],
                        child: const Icon(Icons.store, color: Colors.brown),
                      ),
                    ),
                    const SizedBox(height: 7),
                    // Magasinier Destinataire (uniquement simple, différent du source)
                    ListTile(
                      leading: const Icon(Icons.store, color: Colors.green),
                      title: const Text("Magasinier destinataire (qui reçoit)"),
                      subtitle: DropdownButtonFormField<String>(
                        value: destValue,
                        items: magasiniers
                            .where((m) => m['id'] != _magasinierSourceId)
                            .map((m) => DropdownMenuItem<String>(
                                  value: m['id'] as String,
                                  child: Text(
                                      "${m['magazinier']?['nom'] ?? m['nom'] ?? m['email'] ?? "Magasinier simple"}"
                                      "  [${m['magazinier']?['type'] ?? ''}]"),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _magasinierDestId = v),
                        decoration:
                            const InputDecoration.collapsed(hintText: ""),
                        validator: (v) => v == null ? "Obligatoire" : null,
                      ),
                      trailing: CircleAvatar(
                        backgroundColor: Colors.green[100],
                        child: const Icon(Icons.store, color: Colors.green),
                      ),
                    ),
                    const Divider(height: 30),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: const [
                          Icon(Icons.inventory, color: Colors.amber),
                          SizedBox(width: 8),
                          Text("Type d'emballage prélevé",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...typesEmballage.map((type) {
                      final selected = emballageSelection[type]!;
                      final stockRestant = potsRestantsParType[type] ?? 0;
                      return Card(
                        color: selected ? Colors.amber[50] : Colors.grey[100],
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 7, horizontal: 10),
                          child: Row(
                            children: [
                              Switch(
                                value: selected,
                                activeColor: Colors.amber[700],
                                onChanged: (v) {
                                  setState(() {
                                    emballageSelection[type] = v;
                                    if (!v) {
                                      nbPotsController[type]?.clear();
                                    } else if ((nbPotsController[type]?.text ??
                                            "")
                                        .isEmpty) {
                                      nbPotsController[type]?.text = "1";
                                    }
                                    _recalc();
                                  });
                                },
                              ),
                              Icon(potIcons[type],
                                  color: Colors.amber[900], size: 27),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(type,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 150,
                                child: TextFormField(
                                  enabled: selected,
                                  controller: nbPotsController[type],
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: "Nb",
                                    isDense: true,
                                    prefixIcon: const Icon(
                                        Icons.confirmation_number,
                                        size: 18),
                                    suffixText: type == "Stick 20g"
                                        ? "/${(potsRestantsParType[type] ?? 0) ~/ 10} paquets"
                                        : type == "Pot alvéoles 30g"
                                            ? "/${(potsRestantsParType[type] ?? 0) ~/ 200} cartons"
                                            : "/$stockRestant",
                                  ),
                                  validator: (v) {
                                    if (!selected) return null;
                                    if (v == null || v.isEmpty) return "!";
                                    final n = int.tryParse(v);
                                    if (n == null || n <= 0) return "!";
                                    if (type == "Stick 20g") {
                                      if ((n * 10) >
                                          (potsRestantsParType[type] ?? 0)) {
                                        return "Max: ${(potsRestantsParType[type] ?? 0) ~/ 10}";
                                      }
                                    } else if (type == "Pot alvéoles 30g") {
                                      if ((n * 200) >
                                          (potsRestantsParType[type] ?? 0)) {
                                        return "Max: ${(potsRestantsParType[type] ?? 0) ~/ 200}";
                                      }
                                    } else {
                                      if (n >
                                          (potsRestantsParType[type] ?? 0)) {
                                        return "Max: $stockRestant";
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text("Prix",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                  Row(
                                    children: [
                                      Icon(Icons.monetization_on,
                                          color: Colors.green[800], size: 18),
                                      const SizedBox(width: 2),
                                      Text(
                                        "${getPrixAuto(type).toStringAsFixed(0)} FCFA",
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    const Divider(height: 30),
                    Row(
                      children: [
                        Icon(Icons.scale, color: Colors.amber[700]),
                        const SizedBox(width: 8),
                        Text("Quantité totale : ",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("${quantiteTotale.toStringAsFixed(2)} kg"),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.monetization_on, color: Colors.green[800]),
                        const SizedBox(width: 8),
                        Text("Prix estimé : ",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("${prixTotalEstime.toStringAsFixed(0)} FCFA"),
                      ],
                    ),
                    const SizedBox(height: 22),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text("Enregistrer le prélèvement"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isFormValid ? Colors.brown[700] : Colors.grey,
                          minimumSize: const Size(220, 45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          )),
                      onPressed: isFormValid ? _save : null,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
