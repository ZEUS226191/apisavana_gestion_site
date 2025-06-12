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

  static const Map<String, double> prixPot = {
    "1.5Kg": 5000,
    "1Kg": 4000,
    "720g": 3000,
    "500g": 2100,
    "250g": 1200,
    "30g": 1800,
    "Stick 20g": 1800,
  };
  static const Map<String, double> potKg = {
    "1.5Kg": 1.5,
    "1Kg": 1.0,
    "720g": 0.72,
    "500g": 0.5,
    "250g": 0.25,
    "30g": 0.03,
    "Stick 20g": 0.02,
  };
  static const Map<String, IconData> potIcons = {
    "1.5Kg": Icons.local_drink,
    "1Kg": Icons.water,
    "720g": Icons.emoji_food_beverage,
    "500g": Icons.wine_bar,
    "250g": Icons.local_cafe,
    "30g": Icons.coffee,
    "Stick 20g": Icons.sticky_note_2,
  };

  Map<String, bool> emballageSelection = {};
  Map<String, TextEditingController> nbPotsController = {};

  double quantiteTotale = 0;
  double prixTotalEstime = 0;
  List<Map<String, dynamic>> _emballages = [];

  Map<String, int> potsRestantsParType = {};

  @override
  void initState() {
    super.initState();
    for (final t in prixPot.keys) {
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
      } else if (currentUserRole == "Commercial(e)") {
        _commercialId = currentUserId;
        _magazinierId = magasiniers.isNotEmpty ? magasiniers.first['id'] : null;
      }
    });
  }

  Future<void> _loadPotsRestants() async {
    // Calculer le stock restant pour chaque type d'emballage (sur ce lot)
    final lotId = widget.lotConditionnement['id'];
    final Map<String, int> stockInitial = {};
    if (widget.lotConditionnement['emballages'] != null) {
      for (var emb in widget.lotConditionnement['emballages']) {
        stockInitial[emb['type']] = emb['nombre'];
      }
    }
    // Charger tous les prélèvements déjà faits sur ce lot
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
  }

  void _recalc() {
    double qte = 0;
    double prix = 0;
    _emballages = [];
    for (final type in prixPot.keys) {
      if (!emballageSelection[type]!) continue;
      final n = int.tryParse(nbPotsController[type]?.text ?? '') ?? 0;
      final prixu = prixPot[type]!;
      final kg = potKg[type]!;
      if (n > 0) {
        qte += n * kg;
        prix += n * prixu;
        _emballages.add({
          "type": type,
          "nombre": n,
          "contenanceKg": kg,
          "prixUnitaire": prixu,
          "prixTotal": n * prixu,
        });
      }
    }
    setState(() {
      quantiteTotale = qte;
      prixTotalEstime = prix;
    });
  }

  bool get isValidEmballages {
    for (final type in prixPot.keys) {
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
    final double lotConditionne =
        (widget.lotConditionnement['quantiteConditionnee'] ?? 0.0).toDouble();
    if (quantiteTotale > lotConditionne) {
      Get.snackbar("Erreur",
          "La quantité prélevée dépasse le stock disponible (${lotConditionne.toStringAsFixed(2)} kg) !");
      return;
    }
    // Vérification finale pour chaque type d'emballage
    for (final type in prixPot.keys) {
      if (emballageSelection[type] == true) {
        final n = int.tryParse(nbPotsController[type]?.text ?? '') ?? 0;
        if (n > (potsRestantsParType[type] ?? 0)) {
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
      "magazinierNom": magasiniers.firstWhere((m) => m['id'] == _magazinierId,
              orElse: () => currentUserDoc ?? {})['nom'] ??
          "",
      "emballages": _emballages,
      "quantiteTotale": quantiteTotale,
      "prixTotalEstime": prixTotalEstime,
      "lotConditionnementId": widget.lotConditionnement['id'],
      "createdAt": FieldValue.serverTimestamp(),
    });

    Get.snackbar("Succès", "Prélèvement enregistré !");
    Get.back(result: true);
    Get.back(result: true);

    // Réinitialisation des champs
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
    final isCommercial = currentUserRole == "Commercial";

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
                          const Icon(Icons.calendar_today, color: Colors.green),
                      title: Text(
                        _date != null
                            ? "Date : ${_date!.day}/${_date!.month}/${_date!.year}"
                            : "Sélectionner la date de prélèvement",
                        style: TextStyle(
                            color: _date == null ? Colors.red : Colors.black),
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
                    // Commercial (auto si commercial, dropdown si magazinier)
                    ListTile(
                      leading: const Icon(Icons.person, color: Colors.indigo),
                      title: const Text("Commercial"),
                      subtitle: isCommercial
                          ? Text(currentUserDoc?['nom'] ?? "Chargement...",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold))
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
                              decoration:
                                  const InputDecoration.collapsed(hintText: ""),
                              validator: (v) =>
                                  v == null ? "Obligatoire" : null,
                            ),
                      trailing: CircleAvatar(
                        backgroundColor: Colors.indigo[100],
                        backgroundImage:
                            isCommercial && currentUserDoc?['photoUrl'] != null
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
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold))
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
                              decoration:
                                  const InputDecoration.collapsed(hintText: ""),
                              validator: (v) =>
                                  v == null ? "Obligatoire" : null,
                            ),
                      trailing: CircleAvatar(
                        backgroundColor: Colors.brown[100],
                        backgroundImage:
                            isMagazinier && currentUserDoc?['photoUrl'] != null
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
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...prixPot.keys.map((type) {
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
                                width: 90, // Agrandi ici
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
                                    suffixText: "/$stockRestant",
                                  ),
                                  validator: (v) {
                                    if (!selected) return null;
                                    if (v == null || v.isEmpty) return "!";
                                    final n = int.tryParse(v);
                                    if (n == null || n <= 0) return "!";
                                    if (n > stockRestant)
                                      return "Max: $stockRestant";
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
                                        "${prixPot[type]!.toStringAsFixed(0)} FCFA",
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
