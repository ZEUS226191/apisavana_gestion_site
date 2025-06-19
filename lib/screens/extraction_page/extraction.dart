import 'dart:async';

import 'package:apisavana_gestion/controllers/extraction_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'extraction_form.dart';

class ExtractionPage extends StatelessWidget {
  final ExtractionController c = Get.put(ExtractionController());

  ExtractionPage({super.key});

  Future<void> _refreshAfterExtraction(BuildContext context) async {
    await c.chargerCollectesControlees();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: "Retour au Dashboard",
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Get.offAllNamed('/dashboard'),
          ),
          title: Text("Extraction"),
          backgroundColor: Colors.teal[700],
          elevation: 4,
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.teal[100],
            tabs: [
              Tab(icon: Icon(Icons.eco), text: "Récoltes"),
              Tab(icon: Icon(Icons.groups), text: "Achat SCOOPS"),
              Tab(icon: Icon(Icons.person), text: "Achat Individuel"),
            ],
          ),
        ),
        backgroundColor: Colors.teal[50],
        body: Obx(() {
          if (c.isLoading.value) {
            return Center(
              child: CircularProgressIndicator(
                color: Colors.teal[700],
                strokeWidth: 4,
              ),
            );
          }
          return TabBarView(
            children: [
              _buildCollecteExtractionSection(c.recoltes, "Récolte", context),
              _buildCollecteExtractionSection(
                  c.achatsScoops, "Achat - SCOOPS", context),
              _buildCollecteExtractionSection(
                  c.achatsIndividuels, "Achat - Individuel", context),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCollecteExtractionSection(
      RxList<Map> list, String type, BuildContext context) {
    final filteredList = list
        .where((entry) =>
            (entry['typeProduit']?.toString().toLowerCase() ?? '') ==
                "miel brute" ||
            (entry['typeProduit']?.toString().toLowerCase() ?? '') ==
                "miel brut")
        .where((entry) =>
            entry['statutExtraction'] != "Entièrement Extraite" ||
            (entry['expirationExtraction'] != null &&
                DateTime.now().isBefore(entry['expirationExtraction'])))
        .toList();

    if (filteredList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text("Aucune collecte contrôlée à extraire (Miel Brute).",
              style: TextStyle(color: Colors.grey[600], fontSize: 18)),
        ),
      );
    }
    return SingleChildScrollView(
      padding: EdgeInsets.all(18),
      child: Column(
        children: filteredList.asMap().entries.map((entry) {
          final e = entry.value;
          final quantiteDepart =
              double.tryParse(e['quantite']?.toString() ?? "0") ?? 0;
          final quantiteRestante =
              double.tryParse(e['quantiteRestante']?.toString() ?? "") ??
                  quantiteDepart;
          final quantiteFiltree =
              double.tryParse(e['quantiteFiltree']?.toString() ?? "") ?? 0;
          final quantiteEntree =
              double.tryParse(e['quantiteEntree']?.toString() ?? "") ?? 0;
          final dechets = double.tryParse(e['dechets']?.toString() ?? "") ?? 0;
          final statutExtraction = e['statutExtraction'] ?? "Non extraite";
          final extrait = e['extrait'] ?? false;
          final unite = e['unite'] ?? '';
          return Stack(children: [
            Card(
              elevation: 6,
              margin: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal[100],
                    radius: 28,
                    child: Icon(
                      type == "Récolte"
                          ? Icons.eco
                          : type == "Achat - SCOOPS"
                              ? Icons.groups
                              : Icons.person,
                      color: Colors.teal[800],
                      size: 32,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          e['producteurNom']?.toString().toUpperCase() ??
                              'Producteur inconnu',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 0.4,
                            color: Colors.teal,
                          ),
                        ),
                      ),
                      if (e['numeroLot'] != null)
                        Container(
                          margin: EdgeInsets.only(left: 6),
                          padding:
                              EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.amber[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.amber[400]!, width: 1.2),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.confirmation_number,
                                  color: Colors.amber[700], size: 18),
                              SizedBox(width: 4),
                              Text(
                                "${e['numeroLot']}",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber[900],
                                    fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                      if (statutExtraction == "Entièrement Extraite")
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Chip(
                            avatar: Icon(Icons.check_circle,
                                color: Colors.green[700], size: 18),
                            label: Text("Extraction Complète",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[900])),
                            backgroundColor: Colors.green[50],
                            shape: StadiumBorder(
                                side: BorderSide(
                                    color: Colors.green[200]!, width: 1.1)),
                          ),
                        ),
                      if (statutExtraction == "Extraite en Partie")
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Chip(
                            avatar: Icon(Icons.pending_actions,
                                color: Colors.amber[900], size: 18),
                            label: Text("Extraite en Partie",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber[900])),
                            backgroundColor: Colors.amber[50],
                            shape: StadiumBorder(
                                side: BorderSide(
                                    color: Colors.amber[400]!, width: 1.1)),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            if (e['typeProduit'] != null)
                              Chip(
                                label: Text(
                                  "Type: ${e['typeProduit']}",
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.teal[900]),
                                ),
                                backgroundColor: Colors.teal[50],
                                shape: StadiumBorder(
                                    side: BorderSide(color: Colors.teal[100]!)),
                              ),
                            if (e['typeRuche'] != null)
                              Chip(
                                label: Text(
                                  "Ruche: ${e['typeRuche']}",
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.teal[900]),
                                ),
                                backgroundColor: Colors.teal[50],
                                shape: StadiumBorder(
                                    side: BorderSide(color: Colors.teal[100]!)),
                              ),
                            Chip(
                              label: Text(
                                "Départ: ${quantiteDepart.toStringAsFixed(2)} $unite",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      (statutExtraction == 'Extraite en Partie')
                                          ? Colors.orange[900]
                                          : Colors.teal[700],
                                ),
                              ),
                              backgroundColor:
                                  (statutExtraction == 'Extraite en Partie')
                                      ? Colors.orange[50]
                                      : Colors.teal[50],
                              shape: StadiumBorder(
                                  side: BorderSide(
                                      color: (statutExtraction ==
                                              'Extraite en Partie')
                                          ? Colors.orange[200]!
                                          : Colors.teal[100]!)),
                            ),
                            if (statutExtraction != "Non extraite")
                              Chip(
                                avatar: Icon(Icons.inventory_2,
                                    color: Colors.red[400], size: 16),
                                label: Text(
                                  "Restant: ${quantiteRestante < 0 ? 0 : quantiteRestante.toStringAsFixed(2)} $unite",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red[900]),
                                ),
                                backgroundColor: Colors.red[50],
                                shape: StadiumBorder(
                                    side: BorderSide(color: Colors.red[100]!)),
                              ),
                            if (statutExtraction == "Extraite en Partie" &&
                                (quantiteFiltree > 0 || dechets > 0))
                              Padding(
                                padding: const EdgeInsets.only(
                                    top: 5.0, bottom: 4.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.water_drop,
                                        size: 17, color: Colors.blue[700]),
                                    SizedBox(width: 4),
                                    Text(
                                      "Cumul filtré: ",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[900],
                                          fontSize: 13),
                                    ),
                                    Text(
                                      "${quantiteFiltree.toStringAsFixed(2)} L",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[700],
                                          fontSize: 13),
                                    ),
                                    SizedBox(width: 14),
                                    Icon(Icons.delete_outline,
                                        size: 17, color: Colors.brown[700]),
                                    SizedBox(width: 4),
                                    Text(
                                      "Cumul déchets: ",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.brown[900],
                                          fontSize: 13),
                                    ),
                                    Text(
                                      "${dechets.toStringAsFixed(2)} kg",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.brown[700],
                                          fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            if (statutExtraction == "Entièrement Extraite")
                              Chip(
                                avatar: Icon(Icons.opacity,
                                    color: Colors.blue[700], size: 16),
                                label: Text(
                                  "Filtré: ${quantiteFiltree.toStringAsFixed(2)} L",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[900]),
                                ),
                                backgroundColor: Colors.blue[50],
                                shape: StadiumBorder(
                                    side: BorderSide(color: Colors.blue[100]!)),
                              ),
                            if (statutExtraction == "Entièrement Extraite")
                              Chip(
                                avatar: Icon(Icons.delete_outline,
                                    color: Colors.brown[400], size: 16),
                                label: Text(
                                  "Déchets: ${dechets.toStringAsFixed(2)} Kg",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.brown[900]),
                                ),
                                backgroundColor: Colors.brown[50],
                                shape: StadiumBorder(
                                    side:
                                        BorderSide(color: Colors.brown[100]!)),
                              ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_month,
                                size: 16, color: Colors.teal[400]),
                            SizedBox(width: 4),
                            if (e['dateCollecte'] != null)
                              Text(
                                "Collecte: ${_formatDate(e['dateCollecte'])}",
                                style: TextStyle(
                                    fontSize: 13, color: Colors.teal[900]),
                              ),
                            if (e['dateControle'] != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 10.0),
                                child: Text(
                                  "Contrôle: ${_formatDate(e['dateControle'])}",
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.teal[900]),
                                ),
                              ),
                            if (e['dateExtraction'] != null)
                              Padding(
                                padding: EdgeInsets.only(left: 10.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.science_outlined,
                                        size: 16, color: Colors.teal[700]),
                                    SizedBox(width: 4),
                                    Text(
                                      "Extraction: ${_formatDate(e['dateExtraction'])}",
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.teal[800],
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.local_florist,
                                size: 15, color: Colors.amber[700]),
                            SizedBox(width: 4),
                            Text(
                              "Florale: ${formatFlorale(e['predominanceFlorale'])}",
                              style: TextStyle(fontSize: 13),
                            ),
                            SizedBox(width: 12),
                            Icon(Icons.location_on,
                                size: 15, color: Colors.red[300]),
                            SizedBox(width: 2),
                            // GESTION LOCALITE/QUARTIER
                            Text(
                              _getLocalitePourAffichage(e),
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                        if (e['prixUnitaire'] != null)
                          Row(
                            children: [
                              Icon(Icons.attach_money,
                                  color: Colors.green[700], size: 16),
                              SizedBox(width: 2),
                              Text(
                                "PU: ${e['prixUnitaire']} F",
                                style: TextStyle(fontSize: 13),
                              ),
                              if (e['prixTotal'] != null) ...[
                                SizedBox(width: 10),
                                Text(
                                  "Total: ${e['prixTotal']} F",
                                  style: TextStyle(fontSize: 13),
                                ),
                              ]
                            ],
                          ),
                      ],
                    ),
                  ),
                  isThreeLine: true,
                  trailing: (statutExtraction == "Entièrement Extraite")
                      ? null
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal[700],
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text("Procéder à l'extraction"),
                          onPressed: () async {
                            await Get.to(() => ExtractionFormPage(collecte: e));
                            await _refreshAfterExtraction(context);
                          },
                        ),
                ),
              ),
            ),
            if (statutExtraction == "Entièrement Extraite" &&
                e['expirationExtraction'] != null &&
                DateTime.now().isBefore(e['expirationExtraction']))
              Positioned(
                bottom: 10,
                right: 10,
                child: TimerWidget(expiration: e['expirationExtraction']),
              ),
          ]);
        }).toList(),
      ),
    );
  }

  /// Affiche "Commune | Quartier" si possible, sinon le village
  String _getLocalitePourAffichage(Map e) {
    final commune = e['commune']?.toString();
    final quartier = e['quartier']?.toString();
    final village = e['village']?.toString();
    if (commune != null &&
        commune.isNotEmpty &&
        quartier != null &&
        quartier.isNotEmpty) {
      return "$commune | $quartier";
    }
    return village ?? "-";
  }

  String formatFlorale(dynamic florale) {
    if (florale == null) return "-";
    if (florale is String) return florale;
    if (florale is List) return florale.join(", ");
    return florale.toString();
  }

  String _formatDate(dynamic date) {
    if (date == null) return "";
    if (date is DateTime) {
      return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    }
    return date.toString();
  }
}

class TimerWidget extends StatefulWidget {
  final DateTime expiration;
  const TimerWidget({required this.expiration, super.key});
  @override
  State<TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget> {
  late Duration remaining;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    timer =
        Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  void _updateRemaining() {
    setState(() {
      remaining = widget.expiration.difference(DateTime.now());
      if (remaining.isNegative) remaining = Duration.zero;
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (remaining.inSeconds <= 0) return const SizedBox.shrink();
    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    final s = remaining.inSeconds % 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.teal[100],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          const Icon(Icons.timer, color: Colors.teal, size: 18),
          const SizedBox(width: 4),
          Text(
            "$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}",
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.teal),
          ),
        ],
      ),
    );
  }

  String formatFlorale(dynamic florale) {
    if (florale == null) return "-";
    if (florale is String) return florale;
    if (florale is List) return florale.join(", ");
    return florale.toString();
  }
}
