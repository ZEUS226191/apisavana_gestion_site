import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Enum pour le mode de vente (détail/gros)
enum VenteMode { detail, gros }

class ConditionnementEditController extends GetxController {
  final Map<String, dynamic> lotFiltrage;
  ConditionnementEditController(this.lotFiltrage);

  final dateConditionnement = Rxn<DateTime>();
  final RxInt nbTotalPots = 0.obs;
  final RxDouble prixTotal = 0.0.obs;
  final RxMap<String, int> nbPotsParType = <String, int>{}.obs;
  final RxMap<String, double> prixTotalParType = <String, double>{}.obs;

  final RxString obsFlorale = ''.obs;

  // Emballages possibles
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

  // Conversion des types en kg
  final Map<String, double> typeToKg = const {
    "1.5Kg": 1.5,
    "1Kg": 1.0,
    "720g": 0.72,
    "500g": 0.5,
    "250g": 0.25,
    "30g": 0.03,
    "Pot alvéoles 30g": 0.03,
    "Stick 20g": 0.02,
    "7kg": 7.0,
  };

  // Prix par type et par mode pour MIEL MILLE FLEURS (standard)
  static const Map<String, double> prixGrosMilleFleurs = {
    "Stick 20g": 1500, // Paquet de 10
    "Pot alvéoles 30g": 36000, // Carton de 200
    "250g": 950,
    "500g": 1800,
    "1Kg": 3400,
    "720g": 2500,
    "1.5Kg": 4500,
    "7kg": 23000,
  };

  // Prix par type et par mode pour MIEL MONO FLEUR
  static const Map<String, double> prixGrosMonoFleur = {
    "250g": 1750,
    "500g": 3000,
    "1Kg": 5000,
    "720g": 3500,
    "1.5Kg": 6000,
    "7kg": 34000,
    // On garde les sticks et pots alvéoles au même prix que mille fleurs si pas précisé
    "Stick 20g": 1500,
    "Pot alvéoles 30g": 36000,
  };

  // Pour sticks/alvéole : mode de vente (détail/gros) par type (observable Rx)
  final RxMap<String, VenteMode> venteModeParType = <String, VenteMode>{}.obs;

  final Map<String, RxBool> emballageSelection = {};
  final Map<String, TextEditingController> nbPotsController = {};

  @override
  void onInit() {
    super.onInit();
    for (var type in typesEmballage) {
      emballageSelection[type] = false.obs;
      nbPotsController[type] = TextEditingController();
      nbPotsController[type]!.addListener(_recalcule);
      // Mode de vente par défaut
      if (type == "Stick 20g" || type == "Pot alvéoles 30g") {
        venteModeParType[type] = VenteMode.gros; // Toujours gros
      }
    }
    _initFlorale();
  }

  Future<void> _initFlorale() async {
    if ((lotFiltrage['predominanceFlorale'] ?? '').toString().isNotEmpty) {
      obsFlorale.value = lotFiltrage['predominanceFlorale'];
    } else {
      final lotNum = lotFiltrage['lot'];
      if (lotNum == null || lotNum.toString().isEmpty) {
        obsFlorale.value = '-';
        return;
      }
      final snap = await FirebaseFirestore.instance
          .collection('Controle')
          .where('numeroLot', isEqualTo: lotNum)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final ctrl = snap.docs.first.data();
        obsFlorale.value = ctrl['predominanceFlorale']?.toString() ?? '-';
      } else {
        obsFlorale.value = '-';
      }
    }
  }

  double get quantiteRecue =>
      (lotFiltrage['quantiteFiltree'] ??
          lotFiltrage['quantiteFiltrée'] ??
          0.0) *
      1.0;
  String get lotId =>
      lotFiltrage['collecteId']?.toString() ?? lotFiltrage['id'] ?? '';
  String get lotOrigine => lotFiltrage['lot']?.toString() ?? '';

  /// Calcule le bon prix selon la florale
  double getPrixGros(String type) {
    final florale = (obsFlorale.value ?? '').toLowerCase();
    if (_isMonoFleur(florale)) {
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

  double get totalConditionneKg {
    double total = 0.0;
    for (var type in typesEmballage) {
      if (emballageSelection[type]?.value == true) {
        final nb = int.tryParse(nbPotsController[type]!.text) ?? 0;
        if (type == "Stick 20g") {
          total += nb * 10 * 0.02;
        } else if (type == "Pot alvéoles 30g") {
          total += nb * 200 * 0.03;
        } else {
          total += nb * (typeToKg[type] ?? 0.0);
        }
      }
    }
    return total;
  }

  double get quantiteRestante =>
      (quantiteRecue - totalConditionneKg).clamp(0, double.infinity);

  void _recalcule() {
    int nbTotal = 0;
    double prixTotalAll = 0.0;
    nbPotsParType.clear();
    prixTotalParType.clear();
    for (var type in typesEmballage) {
      if (emballageSelection[type]?.value == true) {
        final nb = int.tryParse(nbPotsController[type]!.text) ?? 0;
        double prix = getPrixGros(type);
        if (type == "Stick 20g") {
          prixTotalParType[type] = nb * prix;
          nbPotsParType[type] = nb * 10;
          nbTotal += nb * 10;
        } else if (type == "Pot alvéoles 30g") {
          prixTotalParType[type] = nb * prix;
          nbPotsParType[type] = nb * 200;
          nbTotal += nb * 200;
        } else {
          prixTotalParType[type] = nb * prix;
          nbPotsParType[type] = nb;
          nbTotal += nb;
        }
        prixTotalAll += prixTotalParType[type] ?? 0.0;
      }
    }
    nbTotalPots.value = nbTotal;
    prixTotal.value = prixTotalAll;
  }

  bool get isReadyToSave =>
      dateConditionnement.value != null &&
      nbTotalPots.value > 0 &&
      totalConditionneKg > 0 &&
      (quantiteRecue - totalConditionneKg).abs() <= 10.0;

  Future<void> enregistrerConditionnement() async {
    if (!isReadyToSave) {
      Get.snackbar("Erreur",
          "Vérifiez vos saisies : la quantité conditionnée doit être au plus 10kg inférieure à la quantité reçue !");
      return;
    }

    final emballages = <Map<String, dynamic>>[];
    for (var type in typesEmballage) {
      if (emballageSelection[type]?.value == true) {
        final nb = int.tryParse(nbPotsController[type]!.text) ?? 0;
        double prix = getPrixGros(type);
        emballages.add({
          'type': type,
          'mode': type == "Stick 20g"
              ? "Paquet (10)"
              : type == "Pot alvéoles 30g"
                  ? "Carton (200)"
                  : "Gros",
          'nombre': type == "Stick 20g"
              ? nb * 10
              : type == "Pot alvéoles 30g"
                  ? nb * 200
                  : nb,
          'contenanceKg': typeToKg[type] ?? 0.0,
          'prixUnitaire': prix,
          'prixTotal': prixTotalParType[type] ?? 0.0,
        });
      }
    }

    await FirebaseFirestore.instance.collection('conditionnement').add({
      'date': dateConditionnement.value,
      'lotFiltrageId': lotFiltrage['id'] ?? lotFiltrage['id'].toString(),
      'collecteId':
          lotFiltrage['collecteId'] ?? lotFiltrage['collecteId'].toString(),
      'lotOrigine': lotFiltrage['lot'],
      'predominanceFlorale': obsFlorale.value,
      'quantiteRecue': quantiteRecue,
      'quantiteConditionnee': totalConditionneKg,
      'quantiteRestante': quantiteRestante,
      'emballages': emballages,
      'nbTotalPots': nbTotalPots.value,
      'prixTotal': prixTotal.value,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance
        .collection('filtrage')
        .doc(lotFiltrage['id'])
        .update({
      'statutConditionnement': 'Conditionné',
      'dateConditionnement': dateConditionnement.value,
      'quantiteConditionnee': totalConditionneKg,
      'predominanceFlorale': obsFlorale.value,
    });

    Get.snackbar("Succès", "Conditionnement enregistré !");
    reset();
    Get.offAllNamed('/conditionnement_home');
    Get.back();
  }

  void reset() {
    dateConditionnement.value = null;
    for (var type in typesEmballage) {
      emballageSelection[type]?.value = false;
      nbPotsController[type]?.clear();
    }
    nbTotalPots.value = 0;
    prixTotal.value = 0.0;
    nbPotsParType.clear();
    prixTotalParType.clear();
  }
}

class ConditionnementEditPage extends StatelessWidget {
  final Map<String, dynamic> lotFiltrage;
  ConditionnementEditPage({super.key, required this.lotFiltrage});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(ConditionnementEditController(lotFiltrage));
    return Scaffold(
      appBar: AppBar(
        title: const Text("Conditionnement du lot"),
        backgroundColor: Colors.amber[700],
      ),
      backgroundColor: Colors.amber[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Obx(() => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      color: Colors.amber[100],
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.batch_prediction,
                                    color: Colors.brown, size: 22),
                                const SizedBox(width: 10),
                                Text("Lot origine : ${c.lotOrigine}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Obx(() => Row(
                                  children: [
                                    Icon(Icons.local_florist,
                                        color: Colors.green, size: 18),
                                    const SizedBox(width: 6),
                                    Text("Florale : ${c.obsFlorale.value}",
                                        style: const TextStyle(fontSize: 15)),
                                  ],
                                )),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.water_drop,
                                    color: Colors.blue, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                    "Quantité filtrée : ${c.quantiteRecue.toStringAsFixed(2)} kg",
                                    style: const TextStyle(fontSize: 15)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _datePickerField(
                        "Date de conditionnement", c.dateConditionnement),
                    const SizedBox(height: 18),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            ...c.typesEmballage.map((type) {
                              final isSpecial = (type == "Stick 20g" ||
                                  type == "Pot alvéoles 30g");
                              return Obx(() => CheckboxListTile(
                                    title: Row(
                                      children: [
                                        Text(type),
                                        if (isSpecial)
                                          Row(
                                            children: [
                                              const SizedBox(width: 14),
                                              ToggleButtons(
                                                isSelected: [
                                                  true,
                                                  true,
                                                ],
                                                onPressed: null,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                selectedColor: Colors.white,
                                                fillColor: Colors.amber,
                                                children: [
                                                  Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 10),
                                                    child: Text(
                                                      type == "Stick 20g"
                                                          ? "Détail"
                                                          : "Détail",
                                                      style: const TextStyle(
                                                          color: Colors.grey,
                                                          fontWeight:
                                                              FontWeight.normal,
                                                          decoration:
                                                              TextDecoration
                                                                  .lineThrough),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 10),
                                                    child: Text(
                                                      type == "Stick 20g"
                                                          ? "Paquet (10)"
                                                          : "Carton (200)",
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.amber),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 7),
                                              const Text(
                                                "(gros uniquement)",
                                                style: TextStyle(
                                                    color: Colors.orange,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12),
                                              ),
                                            ],
                                          )
                                      ],
                                    ),
                                    value: c.emballageSelection[type]?.value ??
                                        false,
                                    onChanged: (v) {
                                      c.emballageSelection[type]?.value =
                                          v ?? false;
                                      c._recalcule();
                                    },
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    secondary:
                                        c.emballageSelection[type]?.value ==
                                                true
                                            ? Container(
                                                width: 120, // élargi ici
                                                child: TextFormField(
                                                  controller:
                                                      c.nbPotsController[type],
                                                  keyboardType:
                                                      TextInputType.number,
                                                  decoration: InputDecoration(
                                                    labelText: "Nb",
                                                    isDense: true,
                                                    helperText:
                                                        "Prix: ${c.getPrixGros(type).toStringAsFixed(0)} FCFA",
                                                  ),
                                                ),
                                              )
                                            : null,
                                  ));
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Obx(() => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ...c.nbPotsParType.entries.map((e) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 3),
                                      child: Row(
                                        children: [
                                          Text("${e.key}: ",
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          Text("${e.value} unités"),
                                          const SizedBox(width: 5),
                                          Text(
                                            " | ${c.prixTotalParType[e.key]?.toStringAsFixed(0) ?? '0'} FCFA",
                                            style: const TextStyle(
                                                color: Colors.green,
                                                fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    )),
                                Divider(),
                                Row(
                                  children: [
                                    const Text("Nombre total d'unités : ",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text("${c.nbTotalPots.value}"),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Text("Prix total : ",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                        "${c.prixTotal.value.toStringAsFixed(0)} FCFA"),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Text("Quantité reçue (filtrée): ",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                        "${c.quantiteRecue.toStringAsFixed(2)} kg"),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Text("Total conditionné : ",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                        "${c.totalConditionneKg.toStringAsFixed(2)} kg"),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Text("Quantité restante : ",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                        "${c.quantiteRestante.toStringAsFixed(2)} kg"),
                                  ],
                                ),
                                if (!c.isReadyToSave)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      "⚠️ La quantité conditionnée doit être au plus 10kg inférieure à la quantité reçue.",
                                      style: TextStyle(color: Colors.red[800]),
                                    ),
                                  ),
                              ],
                            )),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text("Enregistrer le conditionnement"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber[700]),
                        onPressed: c.isReadyToSave
                            ? () async {
                                await c.enregistrerConditionnement();
                                Navigator.pop(context);
                              }
                            : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                )),
          ),
        ),
      ),
    );
  }

  Widget _datePickerField(String label, Rxn<DateTime> dateRx) {
    final controller = TextEditingController(
        text: dateRx.value != null
            ? "${dateRx.value!.day}/${dateRx.value!.month}/${dateRx.value!.year}"
            : "Choisir une date");
    return Obx(() {
      if (dateRx.value != null) {
        controller.text =
            "${dateRx.value!.day}/${dateRx.value!.month}/${dateRx.value!.year}";
      } else {
        controller.text = "Choisir une date";
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: InkWell(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: Get.context!,
              initialDate: dateRx.value ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null && picked != dateRx.value) {
              dateRx.value = picked;
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              suffixIcon: const Icon(Icons.calendar_today),
              border: const OutlineInputBorder(),
            ),
            child: Text(
              dateRx.value != null
                  ? "${dateRx.value!.day}/${dateRx.value!.month}/${dateRx.value!.year}"
                  : "Choisir une date",
              style: TextStyle(
                color: dateRx.value != null ? Colors.black : Colors.grey,
              ),
            ),
          ),
        ),
      );
    });
  }
}
