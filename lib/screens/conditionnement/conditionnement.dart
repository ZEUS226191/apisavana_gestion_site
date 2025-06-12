import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ConditionnementController extends GetxController {
  final dateConditionnement = Rxn<DateTime>();
  final lotOrigine = RxnString();

  // Emballages possibles
  final List<String> typesEmballage = [
    "1.5Kg",
    "1Kg",
    "720g",
    "500g",
    "250g",
    "30g",
    "Stick 20g"
  ];

  // Map<typeEmballage, bool> pour sélection, Map<typeEmballage, nombre>, Map<typeEmballage, prix>
  final Map<String, RxBool> emballageSelection = {};
  final Map<String, TextEditingController> nbPotsController = {};
  final Map<String, TextEditingController> prixPotController = {};

  final RxInt nbTotalPots = 0.obs;
  final RxDouble prixTotal = 0.0.obs;
  final RxMap<String, int> nbPotsParType = <String, int>{}.obs;
  final RxMap<String, double> prixTotalParType = <String, double>{}.obs;

  // Champs issus du lot sélectionné
  final RxDouble quantiteRecue = 0.0.obs;
  final RxDouble quantiteRestante = 0.0.obs;

  // Lots filtrés
  final lotsFiltrage = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    for (var type in typesEmballage) {
      emballageSelection[type] = false.obs;
      nbPotsController[type] = TextEditingController();
      prixPotController[type] = TextEditingController();
      nbPotsController[type]!.addListener(_recalcule);
      prixPotController[type]!.addListener(_recalcule);
    }
    ever(lotOrigine, (_) async {
      await majInfosLot();
      _recalcule();
    });
    loadLotsFiltrage();
  }

  // Récupère les lots filtrés (statutFiltrage=filtré)
  Future<void> loadLotsFiltrage() async {
    final snap = await FirebaseFirestore.instance
        .collection('filtrage')
        .where('statutFiltrage', isEqualTo: 'filtré')
        .get();
    lotsFiltrage.assignAll(snap.docs.map((e) {
      final data = e.data();
      data['id'] = e.id;
      return data;
    }).toList());
  }

  // Met à jour la quantité reçue en fonction du lot sélectionné
  Future<void> majInfosLot() async {
    final lot =
        lotsFiltrage.firstWhereOrNull((e) => e['id'] == lotOrigine.value);
    quantiteRecue.value = (lot?['quantiteFiltre'] ?? 0.0) * 1.0;
    _recalcule();
  }

  // Calculs automatiques
  void _recalcule() {
    int nbTotal = 0;
    double prixTotalAll = 0.0;
    nbPotsParType.clear();
    prixTotalParType.clear();
    for (var type in typesEmballage) {
      if (emballageSelection[type]?.value == true) {
        final nb = int.tryParse(nbPotsController[type]!.text) ?? 0;
        final prix = double.tryParse(prixPotController[type]!.text) ?? 0.0;
        nbPotsParType[type] = nb;
        prixTotalParType[type] = nb * prix;
        nbTotal += nb;
        prixTotalAll += nb * prix;
      }
    }
    nbTotalPots.value = nbTotal;
    prixTotal.value = prixTotalAll;
    quantiteRestante.value =
        (quantiteRecue.value - nbTotalPots.value).clamp(0, double.infinity);
  }

  // Enregistrement du conditionnement
  Future<void> enregistrerConditionnement() async {
    if (dateConditionnement.value == null || lotOrigine.value == null) {
      Get.snackbar("Erreur", "Sélectionnez une date et un lot d'origine !");
      return;
    }
    if (nbTotalPots.value <= 0) {
      Get.snackbar("Erreur", "Ajoutez au moins un pot !");
      return;
    }
    final emballages = <Map<String, dynamic>>[];
    for (var type in typesEmballage) {
      if (emballageSelection[type]?.value == true) {
        emballages.add({
          'type': type,
          'nombre': nbPotsParType[type] ?? 0,
          'prixUnitaire':
              double.tryParse(prixPotController[type]?.text ?? "") ?? 0.0,
          'prixTotal': prixTotalParType[type] ?? 0.0,
        });
      }
    }
    await FirebaseFirestore.instance.collection('conditionnement').add({
      'date': dateConditionnement.value,
      'lotOrigine': lotOrigine.value,
      'emballages': emballages,
      'nbTotalPots': nbTotalPots.value,
      'prixTotal': prixTotal.value,
      'quantiteRecue': quantiteRecue.value,
      'quantiteRestante': quantiteRestante.value,
      'createdAt': FieldValue.serverTimestamp(),
    });
    Get.snackbar("Succès", "Conditionnement enregistré !");
    reset();
  }

  void reset() {
    dateConditionnement.value = null;
    lotOrigine.value = null;
    for (var type in typesEmballage) {
      emballageSelection[type]?.value = false;
      nbPotsController[type]?.clear();
      prixPotController[type]?.clear();
    }
    nbTotalPots.value = 0;
    prixTotal.value = 0.0;
    quantiteRecue.value = 0.0;
    quantiteRestante.value = 0.0;
    nbPotsParType.clear();
    prixTotalParType.clear();
  }
}

// ---------- PAGE UI -----------
class ConditionnementPage extends StatelessWidget {
  final ConditionnementController c = Get.put(ConditionnementController());

  ConditionnementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("🧊 Module 4 – Conditionnement"),
        backgroundColor: Colors.amber[700],
      ),
      backgroundColor: Colors.amber[50],
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 700),
            child: Obx(() => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle("Informations de conditionnement"),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                    child: _datePickerField(
                                        "Date", c.dateConditionnement)),
                                SizedBox(width: 16),
                                Expanded(
                                    child: Obx(() =>
                                        DropdownButtonFormField<String>(
                                          value: c.lotOrigine.value,
                                          decoration: InputDecoration(
                                            labelText:
                                                "Lot d'origine (issu du filtrage)",
                                            prefixIcon:
                                                Icon(Icons.batch_prediction),
                                          ),
                                          items: c.lotsFiltrage
                                              .map((lot) =>
                                                  DropdownMenuItem<String>(
                                                    value: lot['id'].toString(),
                                                    child: Text(
                                                        "Lot #${lot['id']} - ${lot['quantiteFiltre']}kg"),
                                                  ))
                                              .toList(),
                                          onChanged: (v) {
                                            c.lotOrigine.value = v;
                                            c.majInfosLot();
                                          },
                                          validator: (v) => v == null
                                              ? "Sélectionner un lot"
                                              : null,
                                        ))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 18),
                    _sectionTitle("Type d'emballage et nombre de pots"),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            ...c.typesEmballage
                                .map((type) => Obx(() => CheckboxListTile(
                                      title: Text(type),
                                      value:
                                          c.emballageSelection[type]?.value ??
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
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 60,
                                                  child: TextFormField(
                                                    controller: c
                                                        .nbPotsController[type],
                                                    keyboardType:
                                                        TextInputType.number,
                                                    decoration: InputDecoration(
                                                      labelText: "Nb",
                                                      isDense: true,
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 12),
                                                Container(
                                                  width: 80,
                                                  child: TextFormField(
                                                    controller:
                                                        c.prixPotController[
                                                            type],
                                                    keyboardType:
                                                        TextInputType.number,
                                                    decoration: InputDecoration(
                                                      labelText: "Prix pot",
                                                      suffixText: "FCFA",
                                                      isDense: true,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : null,
                                    )))
                                .toList(),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    _sectionTitle("Quantités"),
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
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          Text("${e.value} pots"),
                                          SizedBox(width: 5),
                                          Text(
                                            " | ${c.prixTotalParType[e.key]?.toStringAsFixed(0) ?? '0'} FCFA",
                                            style: TextStyle(
                                                color: Colors.green[700],
                                                fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    )),
                                Divider(),
                                Row(
                                  children: [
                                    Text("Nombre total de pots : ",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text("${c.nbTotalPots.value}"),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text("Prix total : ",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                        "${c.prixTotal.value.toStringAsFixed(0)} FCFA"),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text("Quantité reçue (filtrée): ",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                        "${c.quantiteRecue.value.toStringAsFixed(2)} kg"),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text("Quantité restante : ",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                        "${c.quantiteRestante.value.toStringAsFixed(2)} kg"),
                                  ],
                                ),
                              ],
                            )),
                      ),
                    ),
                    SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.save),
                        label: Text("Enregistrer le conditionnement"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber[700]),
                        onPressed: c.nbTotalPots.value > 0
                            ? () async {
                                await c.enregistrerConditionnement();
                              }
                            : null,
                      ),
                    ),
                    SizedBox(height: 22),
                  ],
                )),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          t,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.amber[900]),
        ),
      );

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
      return InkWell(
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
            suffixIcon: Icon(Icons.calendar_today),
            border: OutlineInputBorder(),
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
      );
    });
  }
}
