import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class FiltrageFormPage extends StatefulWidget {
  final Map collecte;

  FiltrageFormPage({required this.collecte});

  @override
  State<FiltrageFormPage> createState() => _FiltrageFormPageState();
}

class _FiltrageFormPageState extends State<FiltrageFormPage> {
  final _formKey = GlobalKey<FormState>();
  DateTime? dateFiltrage;
  late String lot;
  double? quantiteEntree;
  double? quantiteFiltree;

  // Pour gestion partielle/totale/affichage cumuls
  late double quantiteInitiale;
  late double quantiteRestante;
  String? statutFiltragePrecedent;
  double? quantiteEntreeCumul = 0;
  double? quantiteFiltreeCumul = 0;
  String? filtrageId;

  @override
  void initState() {
    super.initState();
    lot = widget.collecte['numeroLot']?.toString() ?? '';
    quantiteInitiale =
        double.tryParse(widget.collecte['quantite']?.toString() ?? "0") ?? 0;

    statutFiltragePrecedent = widget.collecte['statutFiltrage'] ?? "Non filtré";
    filtrageId = widget.collecte['filtrageId'];
    quantiteEntreeCumul =
        double.tryParse(widget.collecte['quantiteEntree']?.toString() ?? "") ??
            0;
    quantiteFiltreeCumul =
        double.tryParse(widget.collecte['quantiteFiltree']?.toString() ?? "") ??
            0;

    quantiteRestante = quantiteInitiale - (quantiteEntreeCumul ?? 0);
    if (quantiteRestante < 0) quantiteRestante = 0;
  }

  @override
  Widget build(BuildContext context) {
    final unite = widget.collecte['unite'] ?? 'kg';
    final quantiteMaxPourFiltrage = quantiteRestante;

    // ------------ GESTION LOCALITE POUR AFFICHAGE (comme extraction) -------------
    final commune = widget.collecte['commune']?.toString() ?? "";
    final quartier = widget.collecte['quartier']?.toString() ?? "";
    final village = widget.collecte['village']?.toString() ?? "";
    String localiteAffichage;
    if (commune.isNotEmpty && quartier.isNotEmpty) {
      localiteAffichage = "$commune | $quartier";
    } else {
      localiteAffichage = village.isNotEmpty ? village : "-";
    }
    // ------------------------------------------------------------------------------

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.water_drop, color: Colors.amber[200], size: 26),
            SizedBox(width: 8),
            Text("Filtrage / Maturation"),
          ],
        ),
        backgroundColor: Colors.blueGrey[700],
      ),
      backgroundColor: Colors.blueGrey[50],
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Center(
                child: Text("🧴 Filtrage / Maturation",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 23,
                        color: Colors.blueGrey[900],
                        letterSpacing: 0.5)),
              ),
              SizedBox(height: 13),
              _infoRow(Icons.person, "Collecte",
                  widget.collecte['producteurNom'] ?? ''),
              SizedBox(height: 5),
              _infoRow(Icons.confirmation_number, "Lot", lot),
              SizedBox(height: 5),
              _infoRow(Icons.scale, "Quantité de départ",
                  "${quantiteInitiale.toStringAsFixed(2)} $unite"),
              if (statutFiltragePrecedent == "Filtrage partiel" ||
                  quantiteEntreeCumul! > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.pending_actions,
                            color: Colors.amber[900], size: 19),
                        SizedBox(width: 6),
                        Text("Filtrage partiel déjà effectué",
                            style: TextStyle(
                                color: Colors.amber[900],
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ],
                    ),
                    SizedBox(height: 3),
                    _infoRow(Icons.inventory_2, "Déjà Entrer",
                        "${quantiteEntreeCumul!.toStringAsFixed(2)} $unite"),
                    _infoRow(Icons.opacity, "Déjà filtré (kg/l)",
                        "${quantiteFiltreeCumul!.toStringAsFixed(2)} $unite"),
                    _infoRow(Icons.inventory_2, "Quantité restante à filtrer",
                        "${quantiteRestante < 0 ? 0 : quantiteRestante.toStringAsFixed(2)} $unite"),
                  ],
                ),
              SizedBox(height: 5),
              _infoRow(Icons.spa, "Florale",
                  formatFlorale(widget.collecte['predominanceFlorale'])),
              SizedBox(height: 5),
              // ----------- GESTION VILLAGE / LOCALITE AFFICHEE ----------
              _infoRow(Icons.villa, "Localité", localiteAffichage),
              SizedBox(height: 16),
              _label("Date de filtrage / maturation", icon: Icons.event),
              InkWell(
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: dateFiltrage ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => dateFiltrage = picked);
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blueGrey[100]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.today, color: Colors.blueGrey[400]),
                      SizedBox(width: 8),
                      Text(
                          dateFiltrage != null
                              ? DateFormat('dd/MM/yyyy').format(dateFiltrage!)
                              : "Choisir une date",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: dateFiltrage != null
                                ? Colors.blueGrey[900]
                                : Colors.blueGrey[200],
                          )),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              _label("Lot concerné", icon: Icons.confirmation_number),
              TextFormField(
                initialValue: lot,
                enabled: false,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.blueGrey[50],
                  prefixIcon:
                      Icon(Icons.confirmation_number, color: Colors.blueGrey),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9)),
                ),
              ),
              SizedBox(height: 16),
              _label("Quantité entrée (kg)", icon: Icons.input),
              TextFormField(
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.input, color: Colors.blueGrey[700]),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9)),
                    hintText: "ex : 12.50",
                  ),
                  onChanged: (v) => setState(() =>
                      quantiteEntree = double.tryParse(v.replaceAll(',', '.'))),
                  validator: (v) {
                    final value =
                        double.tryParse(v?.replaceAll(',', '.') ?? '');
                    if (v == null || v.isEmpty) return "Obligatoire";
                    if (value == null) return "Entrée invalide";
                    if (value > quantiteMaxPourFiltrage) {
                      return "Ne peut pas dépasser la quantité à filtrer (${quantiteMaxPourFiltrage.toStringAsFixed(2)})";
                    }
                    if (value + quantiteEntreeCumul! > quantiteInitiale) {
                      return "Le cumul de l'entrée dépasse la quantité initiale (${quantiteInitiale.toStringAsFixed(2)})";
                    }
                    return null;
                  }),
              SizedBox(height: 16),
              _label("Quantité filtrée (kg/l)", icon: Icons.opacity),
              TextFormField(
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.opacity, color: Colors.blue[700]),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9)),
                  hintText: "ex : 6.30",
                ),
                onChanged: (v) => setState(() =>
                    quantiteFiltree = double.tryParse(v.replaceAll(',', '.'))),
                validator: (v) => v == null || v.isEmpty ? "Obligatoire" : null,
              ),
              SizedBox(height: 18),
              _buildFiltrageStatusBadge(context, quantiteMaxPourFiltrage),
              SizedBox(height: 18),
              _buildResteSection(quantiteMaxPourFiltrage),
              SizedBox(height: 18),
              Center(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey[700],
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 34, vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  icon: Icon(Icons.save_rounded),
                  label: Text("Enregistrer le filtrage"),
                  onPressed: () async {
                    if ((quantiteEntree ?? 0) + quantiteEntreeCumul! >
                        quantiteInitiale) {
                      Get.snackbar("Erreur",
                          "Le cumul des quantités entrées dépasse la quantité de départ !");
                      return;
                    }

                    if (_formKey.currentState?.validate() ?? false) {
                      if (dateFiltrage == null) {
                        Get.snackbar(
                            "Erreur", "Veuillez choisir la date de filtrage !");
                        return;
                      }
                      if (quantiteEntree == null ||
                          quantiteFiltree == null ||
                          quantiteEntree! > quantiteMaxPourFiltrage) {
                        Get.snackbar("Erreur",
                            "Remplir correctement les champs quantité !");
                        return;
                      }

                      double reste = double.parse(
                          (quantiteMaxPourFiltrage - quantiteEntree!)
                              .toStringAsFixed(2));
                      String statutFiltrage =
                          reste <= 0.1 ? "Filtrage total" : "Filtrage partiel";

                      // Cumul pour historique (optionnel)
                      double newCumulEntree =
                          quantiteEntreeCumul! + quantiteEntree!;
                      double newCumulFiltre =
                          quantiteFiltreeCumul! + (quantiteFiltree ?? 0);

                      final now = DateTime.now();

                      // Ajoute achatId et detailIndex si présents pour clé filtrage unique
                      final filtrageData = {
                        "collecteId": widget.collecte['id'] ?? '',
                        "achatId": widget.collecte['achatId'] ?? '',
                        "detailIndex": widget.collecte['detailIndex'] ?? '',
                        "lot": lot,
                        "dateFiltrage": dateFiltrage,
                        "quantiteEntree": newCumulEntree,
                        "quantiteFiltree": newCumulFiltre,
                        "statutFiltrage": statutFiltrage,
                        "quantiteRestante": reste < 0 ? 0 : reste,
                        "createdAt": now,
                        // Ajoute la localisation :
                        "village": widget.collecte['village'] ?? "",
                        "commune": widget.collecte['commune'] ?? "",
                        "quartier": widget.collecte['quartier'] ?? "",
                      };

                      // Calcul expirationFiltrage : date de filtrage (jour du formulaire mais heure/minute courantes) + 30min
                      DateTime? expirationFiltrage;
                      if (statutFiltrage == "Filtrage total" &&
                          dateFiltrage != null) {
                        final current = DateTime.now();
                        expirationFiltrage = DateTime(
                          dateFiltrage!.year,
                          dateFiltrage!.month,
                          dateFiltrage!.day,
                          current.hour,
                          current.minute,
                          current.second,
                        ).add(const Duration(minutes: 30));
                        filtrageData["expirationFiltrage"] = expirationFiltrage;
                      }

                      if (filtrageId != null) {
                        // update
                        await FirebaseFirestore.instance
                            .collection('filtrage')
                            .doc(filtrageId)
                            .update(filtrageData);
                      } else {
                        // add
                        await FirebaseFirestore.instance
                            .collection('filtrage')
                            .add(filtrageData);
                      }

                      // Mets à jour le doc collecte pour status/cumul
                      await FirebaseFirestore.instance
                          .collection('collectes')
                          .doc(widget.collecte['id'])
                          .update({
                        "statutFiltrage": statutFiltrage,
                        "quantiteRestante": reste < 0 ? 0 : reste,
                        "filtré": reste <= 0.1,
                        "quantiteEntree": newCumulEntree,
                        "quantiteFiltree": newCumulFiltre,
                        "expirationFiltrage": expirationFiltrage,
                      });

                      Get.snackbar("Succès",
                          "Filtrage/maturation enregistré avec succès !");
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.blueGrey[700], size: 20),
            SizedBox(width: 7),
            Text(
              "$label: ",
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey[900],
                  fontSize: 15),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[800],
                    fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );

  Widget _label(String txt, {IconData? icon}) => Padding(
        padding: const EdgeInsets.only(bottom: 4.0, left: 2),
        child: Row(
          children: [
            if (icon != null) Icon(icon, color: Colors.blueGrey[400], size: 18),
            if (icon != null) SizedBox(width: 6),
            Text(txt,
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.blueGrey[900])),
          ],
        ),
      );

  Widget _buildFiltrageStatusBadge(BuildContext context, double quantiteMax) {
    if (quantiteEntree == null &&
        (statutFiltragePrecedent == null ||
            statutFiltragePrecedent == "Non filtré")) return SizedBox.shrink();
    double reste = quantiteMax - (quantiteEntree ?? 0);
    String statut = statutFiltragePrecedent ?? "";
    if (quantiteEntree != null) {
      statut = (reste <= 0.1) ? "Filtrage total" : "Filtrage partiel";
    }
    if (statut == "Filtrage total") {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Chip(
            avatar:
                Icon(Icons.check_circle, color: Colors.green[700], size: 22),
            label: Text("Filtrage Complet",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.green[900])),
            backgroundColor: Colors.green[50],
            shape: StadiumBorder(
                side: BorderSide(color: Colors.green[200]!, width: 1.1)),
          ),
        ],
      );
    } else if (statut == "Filtrage partiel") {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Chip(
            avatar:
                Icon(Icons.pending_actions, color: Colors.amber[900], size: 22),
            label: Text("Filtrage partiel",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.amber[900])),
            backgroundColor: Colors.amber[50],
            shape: StadiumBorder(
                side: BorderSide(color: Colors.amber[400]!, width: 1.1)),
          ),
        ],
      );
    }
    return SizedBox.shrink();
  }

  String formatFlorale(dynamic florale) {
    if (florale == null) return "-";
    if (florale is String) return florale;
    if (florale is List) return florale.join(", ");
    return florale.toString();
  }

  Widget _buildResteSection(double quantiteMaxPourFiltrage) {
    if (quantiteEntree == null &&
        (statutFiltragePrecedent == null ||
            statutFiltragePrecedent == "Non filtré")) return SizedBox.shrink();
    final reste = quantiteMaxPourFiltrage - (quantiteEntree ?? 0);
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.inventory_2, color: Colors.red[400], size: 20),
            SizedBox(width: 7),
            Text(
              "Quantité restante à filtrer: ",
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.red[900]),
            ),
            Text(
              "${reste < 0 ? 0 : reste.toStringAsFixed(2)} ${widget.collecte['unite'] ?? 'kg'}",
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.red[700]),
            ),
          ],
        ),
      ],
    );
  }
}
