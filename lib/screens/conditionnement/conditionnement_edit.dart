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

  // Emballages possibles
  final List<String> typesEmballage = [
    "1.5Kg",
    "1Kg",
    "720g",
    "500g",
    "250g",
    "30g",
    "Stick 20g",
  ];

  // Conversion des types en kg
  final Map<String, double> typeToKg = const {
    "1.5Kg": 1.5,
    "1Kg": 1.0,
    "720g": 0.72,
    "500g": 0.5,
    "250g": 0.25,
    "30g": 0.03,
    "Stick 20g": 0.02,
  };

  // Prix par type et par mode
  final Map<String, Map<VenteMode, double>> prixUnitaire = {
    "Stick 20g": {
      VenteMode.detail: 180,
      VenteMode.gros: 1500
    }, // 1500 le paquet de 10
    "30g": {
      VenteMode.detail: 200,
      VenteMode.gros: 36000
    }, // 36000 le carton de 200
    "250g": {VenteMode.detail: 950, VenteMode.gros: 950},
    "500g": {VenteMode.detail: 1800, VenteMode.gros: 1800},
    "1Kg": {VenteMode.detail: 3400, VenteMode.gros: 3400},
    "1.5Kg": {VenteMode.detail: 4500, VenteMode.gros: 4500},
    "720g": {VenteMode.detail: 2500, VenteMode.gros: 2500},
    "7kg": {VenteMode.detail: 23000, VenteMode.gros: 23000},
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
      if (type == "Stick 20g" || type == "30g") {
        venteModeParType[type] = VenteMode.detail;
      }
    }
  }

  double get quantiteRecue => (lotFiltrage['quantiteFiltree'] ?? 0.0) * 1.0;
  String get lotId =>
      lotFiltrage['collecteId']?.toString() ?? lotFiltrage['id'] ?? '';
  String get lotOrigine => lotFiltrage['lot']?.toString() ?? '';

  /// Calcul du total conditionné en kg (tous types confondus)
  double get totalConditionneKg {
    double total = 0.0;
    for (var type in typesEmballage) {
      if (emballageSelection[type]?.value == true) {
        final nb = int.tryParse(nbPotsController[type]!.text) ?? 0;
        final poidsKg = typeToKg[type] ?? 0.0;
        // Récupère le mode courant
        VenteMode mode = venteModeParType[type] ?? VenteMode.detail;
        if (type == "Stick 20g" && mode == VenteMode.gros) {
          // 1 paquet = 10 sticks de 20g = 0.2kg
          total += nb * 10 * 0.02;
        } else if (type == "30g" && mode == VenteMode.gros) {
          // 1 carton = 200 pots de 30g = 6kg
          total += nb * 200 * 0.03;
        } else {
          total += nb * poidsKg;
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
        VenteMode mode = venteModeParType[type] ?? VenteMode.detail;
        double prix = prixUnitaire[type]?[mode] ?? 0.0;
        // Pour le prix total
        if (type == "Stick 20g" && mode == VenteMode.gros) {
          prixTotalParType[type] = nb * prix;
          nbPotsParType[type] = nb * 10; // nombre d'unités de stick
          nbTotal += nb * 10;
        } else if (type == "30g" && mode == VenteMode.gros) {
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
      (totalConditionneKg - quantiteRecue).abs() <
          1.501; // doit être égal à la quantité reçue

  // Après l'enregistrement du conditionnement
  Future<void> enregistrerConditionnement() async {
    if (!isReadyToSave) {
      Get.snackbar("Erreur",
          "Vérifiez vos saisies : la quantité conditionnée doit être égale à la quantité reçue !");
      return;
    }

    final emballages = <Map<String, dynamic>>[];
    for (var type in typesEmballage) {
      if (emballageSelection[type]?.value == true) {
        final nb = int.tryParse(nbPotsController[type]!.text) ?? 0;
        VenteMode mode = venteModeParType[type] ?? VenteMode.detail;
        double prix = prixUnitaire[type]?[mode] ?? 0.0;
        emballages.add({
          'type': type,
          'mode': mode == VenteMode.gros
              ? (type == "Stick 20g"
                  ? "Paquet (10)"
                  : type == "30g"
                      ? "Carton (200)"
                      : "Gros")
              : "Détail",
          'nombre': (type == "Stick 20g" && mode == VenteMode.gros)
              ? nb * 10
              : (type == "30g" && mode == VenteMode.gros)
                  ? nb * 200
                  : nb,
          'contenanceKg': typeToKg[type] ?? 0.0,
          'prixUnitaire': prix,
          'prixTotal': prixTotalParType[type] ?? 0.0,
        });
      }
    }

    // Enregistre dans 'conditionnement'
    await FirebaseFirestore.instance.collection('conditionnement').add({
      'date': dateConditionnement.value,
      'lotFiltrageId': lotFiltrage['id'] ?? lotFiltrage['id'].toString(),
      'collecteId':
          lotFiltrage['collecteId'] ?? lotFiltrage['collecteId'].toString(),
      'lotOrigine': lotFiltrage['lot'],
      'quantiteRecue': quantiteRecue,
      'quantiteConditionnee': totalConditionneKg,
      'quantiteRestante': quantiteRestante,
      'emballages': emballages,
      'nbTotalPots': nbTotalPots.value,
      'prixTotal': prixTotal.value,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Mets à jour le document filtrage
    await FirebaseFirestore.instance
        .collection('filtrage')
        .doc(lotFiltrage['id'])
        .update({
      'statutConditionnement': 'Conditionné',
      'dateConditionnement': dateConditionnement.value,
      'quantiteConditionnee': totalConditionneKg,
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
      if (venteModeParType.containsKey(type)) {
        venteModeParType[type] = VenteMode.detail;
      }
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
        title: const Text("Conditionnement du lot filtré"),
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
                            Text("Lot filtré #${c.lotId}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 17)),
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
                            if (c.lotOrigine.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 5.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.link,
                                        color: Colors.grey[700], size: 16),
                                    const SizedBox(width: 6),
                                    Text("Lot d'origine : ${c.lotOrigine}",
                                        style: const TextStyle(fontSize: 15)),
                                  ],
                                ),
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
                              final isSpecial =
                                  (type == "Stick 20g" || type == "30g");
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
                                                  c.venteModeParType[type] ==
                                                      VenteMode.detail,
                                                  c.venteModeParType[type] ==
                                                      VenteMode.gros,
                                                ],
                                                onPressed: (i) {
                                                  if (i == 0) {
                                                    c.venteModeParType[type] =
                                                        VenteMode.detail;
                                                  } else {
                                                    c.venteModeParType[type] =
                                                        VenteMode.gros;
                                                  }
                                                  c._recalcule();
                                                },
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
                                                      style: TextStyle(
                                                          fontWeight:
                                                              c.venteModeParType[
                                                                          type] ==
                                                                      VenteMode
                                                                          .detail
                                                                  ? FontWeight
                                                                      .bold
                                                                  : FontWeight
                                                                      .normal),
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
                                                      style: TextStyle(
                                                          fontWeight:
                                                              c.venteModeParType[
                                                                          type] ==
                                                                      VenteMode
                                                                          .gros
                                                                  ? FontWeight
                                                                      .bold
                                                                  : FontWeight
                                                                      .normal),
                                                    ),
                                                  ),
                                                ],
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
                                    secondary: c.emballageSelection[type]
                                                ?.value ==
                                            true
                                        ? Container(
                                            width: 60,
                                            child: TextFormField(
                                              controller:
                                                  c.nbPotsController[type],
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: "Nb",
                                                isDense: true,
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
                                      "⚠️ La quantité conditionnée doit être exactement égale à la quantité reçue.",
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
