import 'package:apisavana_gestion/controllers/filtrage_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'filtrage_form.dart';

class FiltragePage extends StatelessWidget {
  final FiltrageController c = Get.put(FiltrageController());

  FiltragePage({super.key});

  Future<void> _refreshAfterFiltrage(BuildContext context) async {
    await c.chargerCollectesFiltrables();
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
          title: Text("Filtrage / Maturation"),
          backgroundColor: Colors.blueGrey[700],
          elevation: 4,
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.blueGrey[100],
            tabs: [
              Tab(icon: Icon(Icons.eco), text: "Récoltes"),
              Tab(icon: Icon(Icons.groups), text: "Achat SCOOPS"),
              Tab(icon: Icon(Icons.person), text: "Achat Individuel"),
            ],
          ),
        ),
        backgroundColor: Colors.blueGrey[50],
        body: Obx(() {
          if (c.isLoading.value) {
            return Center(
              child: CircularProgressIndicator(
                color: Colors.blueGrey[700],
                strokeWidth: 4,
              ),
            );
          }
          return TabBarView(
            children: [
              _buildCollecteFiltrageSection(c.recoltes, "Récolte", context),
              _buildCollecteFiltrageSection(
                  c.achatsScoops, "Achat - SCOOPS", context),
              _buildCollecteFiltrageSection(
                  c.achatsIndividuels, "Achat - Individuel", context),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCollecteFiltrageSection(
      RxList<Map> list, String type, BuildContext context) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text("Aucune collecte à filtrer.",
              style: TextStyle(color: Colors.grey[600], fontSize: 18)),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 8 : 18),
          child: Column(
            children: list.asMap().entries.map((entry) {
              final e = entry.value;
              final statutFiltrage = e['statutFiltrage'] ?? "Non filtré";
              final unite = e['unite'] ?? '';

              // Quantités correctes en fonction du statut filtrage (cumuls)
              final quantiteDepart =
                  double.tryParse(e['quantiteDepart']?.toString() ?? "") ?? 0;
              final quantiteEntree =
                  double.tryParse(e['quantiteEntree']?.toString() ?? "") ?? 0;
              final quantiteFiltree =
                  double.tryParse(e['quantiteFiltree']?.toString() ?? "") ?? 0;
              final quantiteRestante =
                  double.tryParse(e['quantiteRestante']?.toString() ?? "") ??
                      (quantiteDepart - quantiteEntree)
                          .clamp(0, double.infinity);

              // Localité pour affichage (exactement comme Extraction)
              final commune = e['commune']?.toString() ?? "";
              final quartier = e['quartier']?.toString() ?? "";
              final village = e['village']?.toString() ?? "";
              String localiteAffichage;
              if (commune.isNotEmpty && quartier.isNotEmpty) {
                localiteAffichage = "$commune | $quartier";
              } else {
                localiteAffichage = village.isNotEmpty ? village : "-";
              }

              return Stack(
                children: [
                  Card(
                    elevation: 8,
                    margin: EdgeInsets.symmetric(vertical: isMobile ? 5 : 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          vertical: isMobile ? 7 : 13,
                          horizontal: isMobile ? 4 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // En-tête (producteur, lot, badge)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.blueGrey[100],
                                radius: 26,
                                child: Icon(
                                  type == "Récolte"
                                      ? Icons.eco
                                      : type == "Achat - SCOOPS"
                                          ? Icons.groups
                                          : Icons.person,
                                  color: Colors.blueGrey[800],
                                  size: 28,
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e['producteurNom']
                                              ?.toString()
                                              .toUpperCase() ??
                                          'Producteur inconnu',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                        color: Colors.blueGrey,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (e['numeroLot'] != null)
                                      Container(
                                        margin: EdgeInsets.only(top: 3),
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 9, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.amber[50],
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                              color: Colors.amber[400]!,
                                              width: 1.1),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.confirmation_number,
                                                color: Colors.amber[700],
                                                size: 17),
                                            SizedBox(width: 4),
                                            Text(
                                              "${e['numeroLot']}",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.amber[900],
                                                  fontSize: 14),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (statutFiltrage == "Filtrage total")
                                Padding(
                                  padding: const EdgeInsets.only(left: 6.0),
                                  child: Chip(
                                    avatar: Icon(Icons.check_circle,
                                        color: Colors.green[700], size: 17),
                                    label: Text("Complet",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green[900],
                                            fontSize: 13)),
                                    backgroundColor: Colors.green[50],
                                    shape: StadiumBorder(
                                        side: BorderSide(
                                            color: Colors.green[200]!,
                                            width: 1.1)),
                                  ),
                                ),
                              if (statutFiltrage == "Filtrage partiel")
                                Padding(
                                  padding: const EdgeInsets.only(left: 6.0),
                                  child: Chip(
                                    avatar: Icon(Icons.pending_actions,
                                        color: Colors.amber[900], size: 17),
                                    label: Text("Partiel",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber[900],
                                            fontSize: 13)),
                                    backgroundColor: Colors.amber[50],
                                    shape: StadiumBorder(
                                        side: BorderSide(
                                            color: Colors.amber[400]!,
                                            width: 1.1)),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 7),
                          // Infos principales
                          Wrap(
                            spacing: 8,
                            runSpacing: isMobile ? 8 : 4,
                            children: [
                              Chip(
                                avatar: Icon(Icons.inventory_2,
                                    color: Colors.teal[600], size: 16),
                                label: Text(
                                  "Départ: ${quantiteDepart.toStringAsFixed(2)} $unite",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[900],
                                  ),
                                ),
                                backgroundColor: Colors.teal[50],
                                shape: StadiumBorder(
                                    side: BorderSide(color: Colors.teal[100]!)),
                              ),
                              Chip(
                                label: Text(
                                  "Entrée: ${quantiteEntree.toStringAsFixed(2)} $unite",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueGrey[700],
                                  ),
                                ),
                                backgroundColor: Colors.blueGrey[50],
                                shape: StadiumBorder(
                                    side: BorderSide(
                                        color: Colors.blueGrey[100]!)),
                              ),
                              Chip(
                                avatar: Icon(Icons.opacity,
                                    color: Colors.blue[700], size: 16),
                                label: Text(
                                  "Filtré: ${quantiteFiltree.toStringAsFixed(2)} $unite",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[900]),
                                ),
                                backgroundColor: Colors.blue[50],
                                shape: StadiumBorder(
                                    side: BorderSide(color: Colors.blue[100]!)),
                              ),
                              if (statutFiltrage == "Filtrage partiel")
                                Chip(
                                  avatar: Icon(Icons.inventory_2,
                                      color: Colors.red[400], size: 16),
                                  label: Text(
                                    "Reste: ${quantiteRestante < 0 ? 0 : quantiteRestante.toStringAsFixed(2)} $unite",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red[700]),
                                  ),
                                  backgroundColor: Colors.red[50],
                                  shape: StadiumBorder(
                                      side:
                                          BorderSide(color: Colors.red[100]!)),
                                ),
                            ],
                          ),
                          SizedBox(height: 5),
                          // Dates : Collecte + Extraction + (Filtrage)
                          Row(
                            children: [
                              Icon(Icons.calendar_month,
                                  size: 16, color: Colors.blueGrey[400]),
                              SizedBox(width: 4),
                              if (e['dateCollecte'] != null)
                                Text(
                                  "Collecte: ${_formatDate(e['dateCollecte'])}",
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.blueGrey[900]),
                                ),
                              if (e['dateExtraction'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(left: 10.0),
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
                              if (e['dateFiltrage'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(left: 10.0),
                                  child: Row(
                                    children: [
                                      Icon(Icons.water_drop,
                                          size: 16, color: Colors.blue[700]),
                                      SizedBox(width: 4),
                                      Text(
                                        "Filtrage: ${_formatDate(e['dateFiltrage'])}",
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.blue[800],
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
                                localiteAffichage,
                                style: TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                          SizedBox(height: isMobile ? 7 : 11),
                          Row(
                            children: [
                              Expanded(
                                child: statutFiltrage == "Filtrage total"
                                    ? SizedBox.shrink()
                                    : ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blueGrey[700],
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          padding: EdgeInsets.symmetric(
                                              vertical: isMobile ? 9 : 13),
                                        ),
                                        icon: Icon(Icons.science, size: 21),
                                        label: Text(
                                          "Procéder au filtrage",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontSize: 15,
                                          ),
                                        ),
                                        onPressed: () async {
                                          await Get.to(() =>
                                              FiltrageFormPage(collecte: e));
                                          await _refreshAfterFiltrage(context);
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (statutFiltrage == "Filtrage total" &&
                      e['expirationFiltrage'] != null &&
                      DateTime.now().isBefore(e['expirationFiltrage']))
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: TimerWidget(expiration: e['expirationFiltrage']),
                    ),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
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
  // ignore: cancel_subscriptions
  late final ticker =
      Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());

  @override
  void initState() {
    super.initState();
    remaining = widget.expiration.difference(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: ticker,
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        remaining = widget.expiration.difference(now);
        if (remaining.inSeconds <= 0) return const SizedBox.shrink();
        final h = remaining.inHours;
        final m = remaining.inMinutes % 60;
        final s = remaining.inSeconds % 60;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blueGrey[100],
            borderRadius: BorderRadius.circular(16),
            boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: Row(
            children: [
              const Icon(Icons.timer, color: Colors.blueGrey, size: 18),
              const SizedBox(width: 4),
              Text(
                "$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.blueGrey),
              ),
            ],
          ),
        );
      },
    );
  }
}
