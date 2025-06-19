import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PrelevementFormPage extends StatefulWidget {
  final Map<String, dynamic> lotConditionnement;
  const PrelevementFormPage({super.key, required this.lotConditionnement});

  @override
  State<PrelevementFormPage> createState() => _PrelevementFormPageState();
}

class _PrelevementFormPageState extends State<PrelevementFormPage> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _date;

  Map<String, dynamic>? currentUserDoc;
  String? currentUserId;
  String? currentUserRole;

  String? _magazinierId;
  String? _commercialId;
  List<Map<String, dynamic>> magasiniers = [];
  List<Map<String, dynamic>> commerciaux = [];

  final Map<String, double> potKg = {
    "1.5Kg": 1.5,
    "1Kg": 1.0,
    "720g": 0.72,
    "500g": 0.5,
    "250g": 0.25,
    "Pot alvéoles 30g": 0.03,
    "Stick 20g": 0.02,
    "7kg": 7.0,
  };

  final Map<String, IconData> potIcons = {
    "1.5Kg": Icons.local_drink,
    "1Kg": Icons.water,
    "720g": Icons.emoji_food_beverage,
    "500g": Icons.wine_bar,
    "250g": Icons.local_cafe,
    "Pot alvéoles 30g": Icons.coffee,
    "Stick 20g": Icons.sticky_note_2,
    "7kg": Icons.liquor,
  };

  // Ces prix sont donnés à titre d'exemple, adapte-les à ta logique
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

  Map<String, bool> emballageSelection = {};
  Map<String, TextEditingController> nbPotsController = {};
  List<String> typesEmballageDisponibles = [];
  Map<String, int> potsRestantsParType = {};

  double quantiteTotale = 0;
  double prixTotalEstime = 0;
  List<Map<String, dynamic>> _emballages = [];

  String? predominanceFlorale;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadPrRecuEtStock();
  }

  Future<void> _loadUserData() async {
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

    final snapMag = await FirebaseFirestore.instance
        .collection('utilisateurs')
        .where('role', isEqualTo: 'Magazinier')
        .get();
    final snapCom = await FirebaseFirestore.instance
        .collection('utilisateurs')
        .where('role', isEqualTo: 'Commercial')
        .get();

    setState(() {
      magasiniers = snapMag.docs
          .map((d) => {"id": d.id, ...d.data() as Map<String, dynamic>})
          .toList();
      commerciaux = snapCom.docs
          .map((d) => {"id": d.id, ...d.data() as Map<String, dynamic>})
          .toList();

      if (currentUserRole == "Magazinier") {
        _magazinierId = currentUserId;
        _commercialId = commerciaux.isNotEmpty ? commerciaux.first['id'] : null;
      } else if (currentUserRole == "Commercial(e)" ||
          currentUserRole == "Commercial") {
        _commercialId = currentUserId;
        _magazinierId = magasiniers.isNotEmpty ? magasiniers.first['id'] : null;
      }
    });
  }

  Future<void> _loadPrRecuEtStock() async {
    // On récupère le prélèvement (magasinier) reçu pour ce lot et ce magasinier
    final lotId = widget.lotConditionnement['id'];
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final prRecuSnap = await FirebaseFirestore.instance
        .collection('prelevements')
        .where('lotConditionnementId', isEqualTo: lotId)
        .where('typePrelevement', isEqualTo: 'magasinier')
        .where('magasinierDestId', isEqualTo: user.uid)
        .limit(1)
        .get();
    if (prRecuSnap.docs.isEmpty) {
      // Pas de stock reçu sur ce lot !
      setState(() {
        typesEmballageDisponibles = [];
        potsRestantsParType = {};
      });
      return;
    }
    final prRecu = prRecuSnap.docs.first.data();
    // Les types d'emballage et leur stock
    Map<String, int> stockInitial = {};
    if (prRecu['emballages'] != null) {
      for (var emb in prRecu['emballages']) {
        stockInitial[emb['type']] = emb['nombre'];
      }
    }
    // Calculer les prélèvements faits à des commerciaux
    final prelevComSnap = await FirebaseFirestore.instance
        .collection('prelevements')
        .where('lotConditionnementId', isEqualTo: lotId)
        .where('typePrelevement', isEqualTo: 'commercial')
        .where('magazinierId', isEqualTo: user.uid)
        .get();
    Map<String, int> stockRestant = Map<String, int>.from(stockInitial);
    for (var doc in prelevComSnap.docs) {
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
      typesEmballageDisponibles = stockInitial.keys.toList();
      potsRestantsParType = stockRestant;
      predominanceFlorale =
          prRecu['predominanceFlorale']?.toString().toLowerCase() ??
              (widget.lotConditionnement['predominanceFlorale'] ?? '')
                  .toString()
                  .toLowerCase();
      for (final t in typesEmballageDisponibles) {
        emballageSelection[t] = false;
        nbPotsController[t] = TextEditingController();
        nbPotsController[t]!.addListener(_recalc);
      }
    });
  }

  double getPrixAuto(String type) {
    final florale = predominanceFlorale ?? '';
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
    for (final type in typesEmballageDisponibles) {
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
    for (final type in typesEmballageDisponibles) {
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
        _commercialId != null &&
        _magazinierId != null;
  }

  Future<void> _save() async {
    if (!isFormValid) {
      Get.snackbar("Erreur", "Veuillez remplir tous les champs obligatoires.");
      return;
    }
    // Le stock total maximal pour ce mag simple
    final double lotConditionne = potsRestantsParType.values.fold<double>(
        0.0, (prev, val) => prev + ((val ?? 0) as int).toDouble());
    if (quantiteTotale > lotConditionne) {
      Get.snackbar("Erreur",
          "La quantité prélevée dépasse le stock disponible (${lotConditionne.toStringAsFixed(2)} pots) !");
      return;
    }
    for (final type in typesEmballageDisponibles) {
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

    await FirebaseFirestore.instance.collection('prelevements').add({
      "datePrelevement": _date,
      "commercialId": _commercialId,
      "commercialNom": commerciaux.firstWhere((c) => c['id'] == _commercialId,
              orElse: () => currentUserDoc ?? {})['nom'] ??
          "",
      "magazinierId": _magazinierId,
      "magasinierNom": magasiniers.firstWhere((m) => m['id'] == _magazinierId,
              orElse: () => currentUserDoc ?? {})['nom'] ??
          "",
      "emballages": _emballages,
      "quantiteTotale": quantiteTotale,
      "prixTotalEstime": prixTotalEstime,
      "lotConditionnementId": widget.lotConditionnement['id'],
      "typePrelevement": "commercial",
      "createdAt": FieldValue.serverTimestamp(),
    });

    Get.snackbar("Succès", "Prélèvement enregistré !");
    Get.back(result: true);

    setState(() {
      _date = null;
      emballageSelection.updateAll((key, value) => false);
      nbPotsController.forEach((key, controller) => controller.clear());
      quantiteTotale = 0;
      prixTotalEstime = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMagazinier = currentUserRole == "Magazinier";
    final isCommercial =
        currentUserRole == "Commercial" || currentUserRole == "Commercial(e)";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Nouveau prélèvement"),
        backgroundColor: Colors.green[700],
      ),
      body: (magasiniers.isEmpty && isCommercial) ||
              (commerciaux.isEmpty && isMagazinier)
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store_mall_directory,
                      color: Colors.orange, size: 50),
                  const SizedBox(height: 12),
                  Text(
                    isCommercial
                        ? "Aucun magasinier n'est enregistré !"
                        : "Aucun commercial n'est enregistré !",
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text("Rafraîchir"),
                    onPressed: () {
                      _loadUserData();
                      _loadPrRecuEtStock();
                    },
                  ),
                ],
              ),
            )
          : typesEmballageDisponibles.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(28.0),
                    child: Text(
                      "Vous n'avez reçu aucun stock sur ce lot.",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Date prélèvement
                        ListTile(
                          leading: const Icon(Icons.calendar_today,
                              color: Colors.green),
                          title: Text(
                            _date != null
                                ? "Date : ${_date!.day}/${_date!.month}/${_date!.year}"
                                : "Sélectionner la date de prélèvement",
                            style: TextStyle(
                                color:
                                    _date == null ? Colors.red : Colors.black),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_calendar,
                                color: Colors.green),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _date ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null)
                                setState(() => _date = picked);
                            },
                          ),
                        ),
                        if (_date == null)
                          const Padding(
                            padding: EdgeInsets.only(left: 16.0, bottom: 6),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text("La date est obligatoire.",
                                  style: TextStyle(
                                      color: Colors.red, fontSize: 12)),
                            ),
                          ),
                        const Divider(height: 25),
                        // Commercial (auto si commercial, dropdown si magazinier)
                        ListTile(
                          leading:
                              const Icon(Icons.person, color: Colors.indigo),
                          title: const Text("Commercial"),
                          subtitle: isCommercial
                              ? Text(currentUserDoc?['nom'] ?? "Chargement...",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold))
                              : DropdownButtonFormField<String>(
                                  value: _commercialId,
                                  items: commerciaux
                                      .map((c) => DropdownMenuItem<String>(
                                            value: c['id'] as String,
                                            child: Text(c['nom'] ??
                                                c['email'] ??
                                                "Commercial(e)"),
                                          ))
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _commercialId = v),
                                  decoration: const InputDecoration.collapsed(
                                      hintText: ""),
                                  validator: (v) =>
                                      v == null ? "Obligatoire" : null,
                                ),
                          trailing: CircleAvatar(
                            backgroundColor: Colors.indigo[100],
                            backgroundImage: isCommercial &&
                                    currentUserDoc?['photoUrl'] != null
                                ? NetworkImage(currentUserDoc!['photoUrl'])
                                : null,
                            child: (!isCommercial ||
                                    currentUserDoc?['photoUrl'] == null)
                                ? const Icon(Icons.person, color: Colors.indigo)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 7),
                        // Magasinier (auto si magasinier, dropdown si commercial)
                        ListTile(
                          leading: const Icon(Icons.store, color: Colors.brown),
                          title: const Text("Magazinier"),
                          subtitle: isMagazinier
                              ? Text(currentUserDoc?['nom'] ?? "Chargement...",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold))
                              : DropdownButtonFormField<String>(
                                  value: _magazinierId,
                                  items: magasiniers
                                      .map((m) => DropdownMenuItem<String>(
                                            value: m['id'] as String,
                                            child: Text(m['nom'] ??
                                                m['email'] ??
                                                "Magazinier"),
                                          ))
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _magazinierId = v),
                                  decoration: const InputDecoration.collapsed(
                                      hintText: ""),
                                  validator: (v) =>
                                      v == null ? "Obligatoire" : null,
                                ),
                          trailing: CircleAvatar(
                            backgroundColor: Colors.brown[100],
                            backgroundImage: isMagazinier &&
                                    currentUserDoc?['photoUrl'] != null
                                ? NetworkImage(currentUserDoc!['photoUrl'])
                                : null,
                            child: (!isMagazinier ||
                                    currentUserDoc?['photoUrl'] == null)
                                ? const Icon(Icons.store, color: Colors.brown)
                                : null,
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
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...typesEmballageDisponibles.map((type) {
                          final selected = emballageSelection[type] ?? false;
                          final stockRestant = potsRestantsParType[type] ?? 0;
                          return Card(
                            color:
                                selected ? Colors.amber[50] : Colors.grey[100],
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
                                        } else if ((nbPotsController[type]
                                                    ?.text ??
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
                                              (potsRestantsParType[type] ??
                                                  0)) {
                                            return "Max: ${(potsRestantsParType[type] ?? 0) ~/ 10}";
                                          }
                                        } else if (type == "Pot alvéoles 30g") {
                                          if ((n * 200) >
                                              (potsRestantsParType[type] ??
                                                  0)) {
                                            return "Max: ${(potsRestantsParType[type] ?? 0) ~/ 200}";
                                          }
                                        } else {
                                          if (n >
                                              (potsRestantsParType[type] ??
                                                  0)) {
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
                                              color: Colors.green[800],
                                              size: 18),
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
                            Icon(Icons.monetization_on,
                                color: Colors.green[800]),
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
                                  isFormValid ? Colors.green[700] : Colors.grey,
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
