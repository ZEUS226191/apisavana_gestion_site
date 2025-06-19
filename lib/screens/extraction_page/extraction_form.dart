import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class ExtractionFormPage extends StatefulWidget {
  final Map collecte;

  ExtractionFormPage({required this.collecte});

  @override
  State<ExtractionFormPage> createState() => _ExtractionFormPageState();
}

class _ExtractionFormPageState extends State<ExtractionFormPage> {
  final _formKey = GlobalKey<FormState>();
  DateTime? dateExtraction;
  String? technologie;
  late String lot;
  double? quantiteEntree;
  double? quantiteFiltree;

  // Pour gérer l'extraction en partie
  late double quantiteInitiale;
  late double quantiteRestante;
  String? statutExtractionPrecedent;
  double? quantiteEntreeCumul = 0;
  double? quantiteFiltreeCumul = 0;
  double? dechetsCumul = 0;

  double? get dechets {
    if (quantiteEntree != null && quantiteFiltree != null) {
      final d = quantiteEntree! - (quantiteFiltree! * 1.42);
      return d < 0 ? 0 : d;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    lot = widget.collecte['numeroLot']?.toString() ?? '';
    quantiteInitiale =
        double.tryParse(widget.collecte['quantite']?.toString() ?? "0") ?? 0;
    quantiteRestante = widget.collecte['quantiteRestante'] != null
        ? double.tryParse(widget.collecte['quantiteRestante'].toString()) ??
            quantiteInitiale
        : quantiteInitiale;
    statutExtractionPrecedent = widget.collecte['statutExtraction'];
    quantiteEntreeCumul =
        double.tryParse(widget.collecte['quantiteEntree']?.toString() ?? "") ??
            0;
    quantiteFiltreeCumul =
        double.tryParse(widget.collecte['quantiteFiltree']?.toString() ?? "") ??
            0;
    dechetsCumul =
        double.tryParse(widget.collecte['dechets']?.toString() ?? "") ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final quantiteMaxPourExtraire = quantiteRestante;

    // -- GESTION LOCALITÉ POUR AFFICHAGE --
    final commune = widget.collecte['commune']?.toString();
    final quartier = widget.collecte['quartier']?.toString();
    final village = widget.collecte['village']?.toString();
    String localiteAffichage;
    if (commune != null &&
        commune.isNotEmpty &&
        quartier != null &&
        quartier.isNotEmpty) {
      localiteAffichage = "$commune | $quartier";
    } else {
      localiteAffichage = village ?? "-";
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.science_outlined, color: Colors.amber[200], size: 26),
            SizedBox(width: 8),
            Text("Extraction"),
          ],
        ),
        backgroundColor: Colors.teal[700],
        actions: [
          IconButton(
            icon: Icon(Icons.history, color: Colors.white),
            onPressed: () {
              // TODO: Historique des extractions pour ce lot
            },
            tooltip: "Historique d'extraction",
          )
        ],
      ),
      backgroundColor: Colors.teal[50],
      body: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Center(
                child: Text("🧴 Extraction",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 23,
                        color: Colors.teal[900],
                        letterSpacing: 0.5)),
              ),
              SizedBox(height: 13),
              _infoRow(Icons.person, "Collecte",
                  widget.collecte['producteurNom'] ?? ''),
              SizedBox(height: 5),
              _infoRow(Icons.confirmation_number, "Lot", lot),
              SizedBox(height: 5),
              _infoRow(Icons.scale, "Quantité de départ",
                  "${quantiteInitiale.toStringAsFixed(2)} ${widget.collecte['unite'] ?? 'kg'}"),
              if (statutExtractionPrecedent == "Extraite en Partie" ||
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
                        Text("Extraction en partie déjà effectuée",
                            style: TextStyle(
                                color: Colors.amber[900],
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ],
                    ),
                    SizedBox(height: 4),
                    _infoRow(Icons.inventory_2, "Déjà extrait",
                        "${quantiteEntreeCumul!.toStringAsFixed(2)} ${widget.collecte['unite'] ?? 'kg'}"),
                    _infoRow(Icons.water_drop, "Déjà filtré",
                        "${quantiteFiltreeCumul!.toStringAsFixed(2)} L"),
                    _infoRow(Icons.delete_outline, "Déjà déchets",
                        "${dechetsCumul!.toStringAsFixed(2)} kg"),
                    _infoRow(Icons.inventory_2, "Quantité restante à extraire",
                        "${quantiteRestante < 0 ? 0 : quantiteRestante.toStringAsFixed(2)} ${widget.collecte['unite'] ?? 'kg'}"),
                  ],
                ),
              SizedBox(height: 5),
              _infoRow(Icons.spa, "Florale",
                  formatFlorale(widget.collecte['predominanceFlorale'])),
              SizedBox(height: 5),
              _infoRow(Icons.villa, "Localité", localiteAffichage),
              SizedBox(height: 16),
              _label("Date d'extraction", icon: Icons.event),
              InkWell(
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: dateExtraction ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => dateExtraction = picked);
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.teal[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal[100]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.today, color: Colors.teal[400]),
                      SizedBox(width: 8),
                      Text(
                          dateExtraction != null
                              ? DateFormat('dd/MM/yyyy').format(dateExtraction!)
                              : "Choisir une date",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: dateExtraction != null
                                ? Colors.teal[900]
                                : Colors.teal[200],
                          )),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              _label("Technologie utilisée", icon: Icons.build_circle),
              DropdownButtonFormField<String>(
                value: technologie,
                items: [
                  DropdownMenuItem(
                    value: "Extracteur manuel",
                    child: Row(
                      children: [
                        Icon(Icons.settings, color: Colors.blueGrey),
                        SizedBox(width: 6),
                        Text("Extracteur manuel"),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: "Extracteur électrique",
                    child: Row(
                      children: [
                        Icon(Icons.electric_bolt, color: Colors.amber),
                        SizedBox(width: 6),
                        Text("Extracteur électrique"),
                      ],
                    ),
                  ),
                ],
                onChanged: (val) => setState(() => technologie = val),
                validator: (v) => v == null ? "Obligatoire" : null,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.build_circle, color: Colors.teal[300]),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9)),
                ),
              ),
              SizedBox(height: 16),
              _label("Lot concerné", icon: Icons.confirmation_number),
              TextFormField(
                initialValue: lot,
                enabled: false,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.teal[50],
                  prefixIcon:
                      Icon(Icons.confirmation_number, color: Colors.teal),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9)),
                ),
              ),
              SizedBox(height: 16),
              _label("Quantité à extraire (kg)", icon: Icons.input),
              TextFormField(
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.input, color: Colors.teal[700]),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9)),
                  hintText: "ex : 12.50",
                ),
                onChanged: (v) {
                  final value = double.tryParse(v);
                  setState(() {
                    if (value != null && value <= quantiteMaxPourExtraire) {
                      quantiteEntree = value;
                    } else if (value != null &&
                        value > quantiteMaxPourExtraire) {
                      quantiteEntree = null;
                      Get.snackbar(
                        "Erreur",
                        "La quantité ne peut pas dépasser la quantité restante (${quantiteMaxPourExtraire.toStringAsFixed(2)} ${widget.collecte['unite'] ?? 'kg'})",
                        colorText: Colors.white,
                        backgroundColor: Colors.red[400],
                      );
                    } else {
                      quantiteEntree = null;
                    }
                  });
                },
                validator: (v) {
                  final value = double.tryParse(v ?? '');
                  if (v == null || v.isEmpty) return "Obligatoire";
                  if (value == null) return "Entrée invalide";
                  if (value > quantiteMaxPourExtraire) {
                    return "Ne peut pas dépasser la quantité restante (${quantiteMaxPourExtraire.toStringAsFixed(2)})";
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              _label("Quantité filtrée (litre)", icon: Icons.water_drop),
              TextFormField(
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.water_drop, color: Colors.blue),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9)),
                  hintText: "ex : 6.30",
                ),
                onChanged: (v) =>
                    setState(() => quantiteFiltree = double.tryParse(v)),
                validator: (v) => v == null || v.isEmpty ? "Obligatoire" : null,
              ),
              SizedBox(height: 18),
              _label("Déchets (kg)", icon: Icons.delete_outline),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.yellow[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal[100]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.orange[800]),
                    SizedBox(width: 7),
                    Text(
                      (dechets != null && !dechets!.isNaN)
                          ? "${dechets!.toStringAsFixed(2)} kg"
                          : "--",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.teal[900]),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 26),
              _buildExtractionStatusBadge(context),
              SizedBox(height: 18),
              _buildResteSection(quantiteMaxPourExtraire),
              SizedBox(height: 24),
              Center(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700],
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 34, vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  icon: Icon(Icons.save_rounded),
                  label: Text("Enregistrer l'extraction"),
                  onPressed: () async {
                    if (_formKey.currentState?.validate() ?? false) {
                      if (dateExtraction == null) {
                        Get.snackbar("Erreur", "Veuillez choisir la date !");
                        return;
                      }
                      if (quantiteEntree == null ||
                          quantiteFiltree == null ||
                          dechets == null ||
                          quantiteEntree! > quantiteMaxPourExtraire) {
                        Get.snackbar("Erreur",
                            "Remplir correctement les champs quantité !");
                        return;
                      }

                      // Calcul du nouveau reste
                      double reste = double.parse(
                          (quantiteMaxPourExtraire - quantiteEntree!)
                              .toStringAsFixed(2));
                      String statutExtraction = reste <= 0.1
                          ? "Entièrement Extraite"
                          : "Extraite en Partie";

                      // Cumul des extractions pour historique d'affichage
                      double newCumulEntree =
                          quantiteEntreeCumul! + quantiteEntree!;
                      double newCumulFiltre =
                          quantiteFiltreeCumul! + (quantiteFiltree ?? 0);
                      double newCumulDechets = dechetsCumul! + (dechets ?? 0);

                      // Enregistrement extraction Firestore
                      final now = DateTime.now();
                      final expiration = now.add(Duration(hours: 48));

                      // Cherche s'il existe déjà une extraction pour cette collecte
                      final extractionRef = await FirebaseFirestore.instance
                          .collection('extraction')
                          .where('collecteId', isEqualTo: widget.collecte['id'])
                          .where('recId', isEqualTo: widget.collecte['recId'])
                          .where('achatId',
                              isEqualTo: widget.collecte['achatId'])
                          .where('detailIndex',
                              isEqualTo: widget.collecte['detailIndex'])
                          .limit(1)
                          .get();

                      final extractionData = {
                        "collecteId": widget.collecte['id'] ?? '',
                        // Ajoute ceci :
                        "recId": widget.collecte['recId'],
                        "achatId": widget.collecte['achatId'],
                        "detailIndex": widget.collecte['detailIndex'],
                        // ...
                        "producteurNom": widget.collecte['producteurNom'] ?? '',
                        "lot": lot,
                        "dateExtraction": now,
                        "technologie": technologie,
                        "quantiteEntree": newCumulEntree,
                        "quantiteFiltree": newCumulFiltre,
                        "dechets": newCumulDechets,
                        "statutExtraction": statutExtraction,
                        "quantiteRestante": reste < 0 ? 0 : reste,
                        "expirationExtraction":
                            statutExtraction == "Entièrement Extraite"
                                ? expiration
                                : null,
                        "createdAt": now,
                      };

                      if (extractionRef.docs.isNotEmpty) {
                        // On met à jour le document existant
                        await FirebaseFirestore.instance
                            .collection('extraction')
                            .doc(extractionRef.docs.first.id)
                            .update(extractionData);
                      } else {
                        // On crée un nouveau document
                        await FirebaseFirestore.instance
                            .collection('extraction')
                            .add(extractionData);
                      }

                      // Mise à jour du statut/quantité sur la collecte de base
                      await FirebaseFirestore.instance
                          .collection('collectes')
                          .doc(widget.collecte['id'])
                          .update({
                        "statutExtraction": statutExtraction,
                        "quantiteRestante": reste < 0 ? 0 : reste,
                        "extrait": reste <= 0.1,
                        "quantiteEntree": newCumulEntree,
                        "quantiteFiltree": newCumulFiltre,
                        "dechets": newCumulDechets,
                      });

                      Get.snackbar(
                          "Succès", "Extraction enregistrée avec succès !");
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

  String formatFlorale(dynamic florale) {
    if (florale == null) return "-";
    if (florale is String) return florale;
    if (florale is List) return florale.join(", ");
    return florale.toString();
  }

  Widget _infoRow(IconData icon, String label, String value) => Row(
        children: [
          Icon(icon, color: Colors.teal[700], size: 20),
          SizedBox(width: 7),
          Text(
            "$label: ",
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.teal[900],
                fontSize: 15),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[800],
                  fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );

  Widget _label(String txt, {IconData? icon}) => Padding(
        padding: const EdgeInsets.only(bottom: 4.0, left: 2),
        child: Row(
          children: [
            if (icon != null) Icon(icon, color: Colors.teal[400], size: 18),
            if (icon != null) SizedBox(width: 6),
            Text(txt,
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.teal[900])),
          ],
        ),
      );

  Widget _buildExtractionStatusBadge(BuildContext context) {
    final reste = quantiteRestante - (quantiteEntree ?? 0);
    if (quantiteEntree == null &&
        (statutExtractionPrecedent == null ||
            statutExtractionPrecedent == "Non extraite"))
      return SizedBox.shrink();
    String statut = statutExtractionPrecedent ?? "";
    if (quantiteEntree != null) {
      statut = (reste <= 0.1) ? "Entièrement Extraite" : "Extraite en Partie";
    }
    if (statut == "Entièrement Extraite") {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Chip(
            avatar:
                Icon(Icons.check_circle, color: Colors.green[700], size: 22),
            label: Text("Extraction Complète",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.green[900])),
            backgroundColor: Colors.green[50],
            shape: StadiumBorder(
                side: BorderSide(color: Colors.green[200]!, width: 1.1)),
          ),
        ],
      );
    } else if (statut == "Extraite en Partie") {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Chip(
            avatar:
                Icon(Icons.pending_actions, color: Colors.amber[900], size: 22),
            label: Text("Extraite en Partie",
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

  Widget _buildResteSection(double quantiteMaxPourExtraire) {
    if (quantiteEntree == null &&
        (statutExtractionPrecedent == null ||
            statutExtractionPrecedent == "Non extraite"))
      return SizedBox.shrink();
    final reste = quantiteMaxPourExtraire - (quantiteEntree ?? 0);
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.inventory_2, color: Colors.red[400], size: 20),
            SizedBox(width: 7),
            Text(
              "Quantité restante: ",
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
