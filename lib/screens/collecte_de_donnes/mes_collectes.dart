import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'modifier_collecte.dart';
import 'modifier_collecte_Indiv.dart';
import 'modifier_collecte_SCOOP.dart';

class MesCollectesPage extends StatefulWidget {
  const MesCollectesPage({super.key});
  @override
  State<MesCollectesPage> createState() => _MesCollectesPageState();
}

class _MesCollectesPageState extends State<MesCollectesPage> {
  Map<String, bool> sectionOpen = {
    'Récolte': true,
    'SCOOPS': false,
    'Individuel': false,
  };

  String? adminSelectedUserId; // For admin filtering
  String? adminSelectedUserNom;
  List<Map<String, String>> allUsers = []; // {uid, nom}

  @override
  void initState() {
    super.initState();
    _loadAllUsersForAdmin();
  }

  Future<void> _loadAllUsersForAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final adminDoc = await FirebaseFirestore.instance
        .collection('utilisateurs')
        .doc(user.uid)
        .get();
    final role = adminDoc.data()?['role']?.toString();
    if (role == 'Admin') {
      final usersSnap =
          await FirebaseFirestore.instance.collection('utilisateurs').get();
      setState(() {
        allUsers = usersSnap.docs
            .map((d) => {
                  'uid': d.id,
                  'nom': d.data()['nom']?.toString() ??
                      d.data()['email']?.toString() ??
                      d.id,
                })
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text("Mes collectes")),
        body: Center(child: Text("Non connecté.")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("Mes collectes"),
        backgroundColor: Colors.amber[700],
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: CircleAvatar(
              backgroundColor: Colors.amber[100],
              child: Icon(Icons.person, color: Colors.amber[800]),
            ),
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('utilisateurs')
            .doc(user.uid)
            .get(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          final userRole = userSnap.data?.data() is Map<String, dynamic>
              ? (userSnap.data!.data() as Map<String, dynamic>)['role']
                  ?.toString()
              : null;
          final isAdmin = userRole == "Admin";

          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('collectes')
                .orderBy('dateCollecte', descending: true)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text("Aucune collecte trouvée."));
              }
              List<QueryDocumentSnapshot> docs = snapshot.data!.docs;
              // Filtrage pour admin
              if (isAdmin &&
                  adminSelectedUserId != null &&
                  adminSelectedUserId != "") {
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['utilisateurId'] == adminSelectedUserId;
                }).toList();
              } else if (!isAdmin) {
                // Utilisateur normal : ne voir que ses propres collectes
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['utilisateurId'] == user.uid;
                }).toList();
              }
              // Séparation des types
              final recoltes = docs
                  .where((doc) => (doc.data() as Map)['type'] == 'récolte')
                  .toList();
              final achats = docs
                  .where((doc) => (doc.data() as Map)['type'] == 'achat')
                  .toList();

              return FutureBuilder<Map<String, List<QueryDocumentSnapshot>>>(
                future: _triAchats(achats),
                builder: (context, achatsSnap) {
                  if (!achatsSnap.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }
                  final achatsScoops = achatsSnap.data!['SCOOPS']!;
                  final achatsIndividuels = achatsSnap.data!['Individuel']!;
                  return ListView(
                    padding: EdgeInsets.all(18),
                    children: [
                      // Dashboard résumé
                      Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                        color: Colors.amber[50],
                        elevation: 2,
                        margin: EdgeInsets.only(bottom: 18),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: 18, horizontal: 22),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.amber[100],
                                radius: 32,
                                child: Icon(Icons.account_circle,
                                    color: Colors.amber[800], size: 44),
                              ),
                              SizedBox(width: 24),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        isAdmin
                                            ? "Bienvenue, ADMIN"
                                            : "Bienvenue, ${user.displayName ?? user.email ?? user.uid}",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18)),
                                    SizedBox(height: 8),
                                    Text(
                                      "Total : ${docs.length} collectes",
                                      style: TextStyle(
                                          color: Colors.amber[900],
                                          fontSize: 16),
                                    ),
                                    Row(
                                      children: [
                                        Chip(
                                            label: Text(
                                                "Récolte : ${recoltes.length}"),
                                            backgroundColor: Colors.green[100]),
                                        SizedBox(width: 6),
                                        Chip(
                                            label: Text(
                                                "SCOOPS : ${achatsScoops.length}"),
                                            backgroundColor: Colors.blue[50]),
                                        SizedBox(width: 6),
                                        Chip(
                                            label: Text(
                                                "Individuel : ${achatsIndividuels.length}"),
                                            backgroundColor: Colors.purple[50]),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isAdmin)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14.0),
                          child: Row(
                            children: [
                              const Icon(Icons.person_search,
                                  color: Colors.amber),
                              const SizedBox(width: 10),
                              Text("Filtrer par collecteur : ",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  value: adminSelectedUserId,
                                  hint: const Text("Tous les collecteurs"),
                                  items: [
                                    DropdownMenuItem(
                                        value: "",
                                        child: Text("Tous les collecteurs")),
                                    ...allUsers.map((u) => DropdownMenuItem(
                                        value: u['uid'],
                                        child: Text(u['nom']!))),
                                  ],
                                  onChanged: (v) {
                                    setState(() {
                                      adminSelectedUserId =
                                          (v == "" || v == null) ? null : v;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Accordion sections
                      _section(
                        title: "Récolte",
                        icon: Icons.eco_rounded,
                        color: Colors.green[600]!,
                        isOpen: sectionOpen['Récolte']!,
                        onTap: () => setState(() =>
                            sectionOpen['Récolte'] = !sectionOpen['Récolte']!),
                        children: recoltes.isEmpty
                            ? [
                                Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Text("Aucune récolte."))
                              ]
                            : recoltes
                                .map((doc) => _collecteRecolteCard(doc))
                                .toList(),
                      ),
                      _section(
                        title: "SCOOPS",
                        icon: Icons.groups_2_rounded,
                        color: Colors.blue[500]!,
                        isOpen: sectionOpen['SCOOPS']!,
                        onTap: () => setState(() =>
                            sectionOpen['SCOOPS'] = !sectionOpen['SCOOPS']!),
                        children: achatsScoops.isEmpty
                            ? [
                                Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Text("Aucun achat via SCOOPS."))
                              ]
                            : achatsScoops
                                .map((doc) => _collecteAchatHierarchicalCard(
                                    doc, "SCOOPS"))
                                .toList(),
                      ),
                      _section(
                        title: "Individuel",
                        icon: Icons.person_pin_rounded,
                        color: Colors.purple[400]!,
                        isOpen: sectionOpen['Individuel']!,
                        onTap: () => setState(() => sectionOpen['Individuel'] =
                            !sectionOpen['Individuel']!),
                        children: achatsIndividuels.isEmpty
                            ? [
                                Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Text("Aucun achat individuel."))
                              ]
                            : achatsIndividuels
                                .map((doc) => _collecteAchatHierarchicalCard(
                                    doc, "Individuel"))
                                .toList(),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // Tri achats en fonction de la sous-collection présente
  Future<Map<String, List<QueryDocumentSnapshot>>> _triAchats(
      List<QueryDocumentSnapshot> achats) async {
    final achatsScoops = <QueryDocumentSnapshot>[];
    final achatsIndividuels = <QueryDocumentSnapshot>[];
    for (final doc in achats) {
      final scoopsSnap = await doc.reference.collection('SCOOP').limit(1).get();
      final indivSnap =
          await doc.reference.collection('Individuel').limit(1).get();
      if (scoopsSnap.docs.isNotEmpty) {
        achatsScoops.add(doc);
      } else if (indivSnap.docs.isNotEmpty) {
        achatsIndividuels.add(doc);
      }
    }
    return {
      'SCOOPS': achatsScoops,
      'Individuel': achatsIndividuels,
    };
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Color color,
    required bool isOpen,
    required VoidCallback onTap,
    required List<Widget> children,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon, color: color, size: 30),
            title: Text(title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            trailing: Icon(isOpen ? Icons.expand_less : Icons.expand_more,
                color: color),
            onTap: onTap,
          ),
          if (isOpen) Divider(height: 1, color: color.withOpacity(0.3)),
          if (isOpen) Column(children: children),
        ],
      ),
    );
  }

  // Carte Récolte (avec le bouton modifier classique sur toute la card)
  Widget _collecteRecolteCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final date = data['dateCollecte'] is Timestamp
        ? (data['dateCollecte'] as Timestamp).toDate()
        : null;
    final formattedDate = date != null
        ? "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}"
        : "--/--/----";
    return FutureBuilder<QuerySnapshot>(
      future: doc.reference.collection('Récolte').limit(1).get(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Card(
            child: ListTile(
              title: Text("Données non trouvées"),
              subtitle: Text("Impossible de charger les détails."),
            ),
          );
        }
        final sousDoc = snap.data!.docs.first.data() as Map<String, dynamic>;
        return Card(
          color: Colors.white,
          margin: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green[600],
              child: Icon(Icons.eco, color: Colors.white),
            ),
            title:
                Text("Récolte", style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Padding(
              padding: EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Date : $formattedDate"),
                  Text("Récolteur : ${sousDoc['nomRecolteur'] ?? '--'}"),
                  Text("Région : ${sousDoc['region'] ?? '--'}"),
                  Text("Province : ${sousDoc['province'] ?? '--'}"),
                  Text("Commune : ${sousDoc['commune'] ?? '--'}"),
                  Text("Village : ${sousDoc['village'] ?? '--'}"),
                  Text("Quantité : ${sousDoc['quantiteKg'] ?? '--'} kg"),
                  Text("Nb ruches : ${sousDoc['nbRuchesRecoltees'] ?? '--'}"),
                  Text(
                      "Florale : ${(sousDoc['predominanceFlorale'] as List?)?.join(', ') ?? '--'}"),
                  Text("Type produit : ${sousDoc['typeProduit'] ?? '--'}"),
                ],
              ),
            ),
            trailing: _actions(doc, "récolte", [snap.data!.docs.first]),
          ),
        );
      },
    );
  }

  // Carte Achat hiérarchique (SCOOPS/Individuel) avec bouton modifier par produit
  Widget _collecteAchatHierarchicalCard(
      QueryDocumentSnapshot doc, String sectionType) {
    final data = doc.data() as Map<String, dynamic>;
    final date = data['dateCollecte'] is Timestamp
        ? (data['dateCollecte'] as Timestamp).toDate()
        : null;
    final formattedDate = date != null
        ? "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}"
        : "--/--/----";
    final sousCollection = (sectionType == "SCOOPS") ? "SCOOP" : "Individuel";

    return FutureBuilder<QuerySnapshot>(
      future: doc.reference.collection(sousCollection).get(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Card(
            child: ListTile(
              title: Text("Données non trouvées"),
              subtitle: Text("Impossible de charger les détails."),
            ),
          );
        }
        final docSnap = snap.data!.docs.first;
        final docData = docSnap.data() as Map<String, dynamic>;
        final List detailsRaw = (docData['details'] as List?) ?? [];
        final List<Map<String, dynamic>> details = detailsRaw
            .whereType<Map>()
            .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
            .toList();

        final validDetails = details
            .where((item) =>
                item['typeRuche'] != null &&
                item['typeProduit'] != null &&
                (item['typeRuche'].toString().trim() != "" &&
                    item['typeProduit'].toString().trim() != ""))
            .toList();

        if (validDetails.isEmpty) {
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Aucune ruche/produit renseigné pour cet achat.",
                style: TextStyle(color: Colors.red[800]),
              ),
            ),
          );
        }

        final Map<String, List<Map<String, dynamic>>> parRuche = {};
        double montantTotal = 0;
        for (final sd in validDetails) {
          final ruche = sd['typeRuche'] ?? 'Non précisé';
          montantTotal += double.tryParse('${sd['prixTotal'] ?? "0"}') ?? 0;
          parRuche.putIfAbsent(ruche, () => []).add(sd);
        }

        return Card(
          color: Colors.white,
          margin: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  leading: CircleAvatar(
                    backgroundColor: sectionType == "SCOOPS"
                        ? Colors.blue[500]
                        : Colors.purple[400],
                    child: Icon(Icons.shopping_bag, color: Colors.white),
                  ),
                  title: Text(
                    sectionType == "SCOOPS"
                        ? "Achat SCOOPS"
                        : "Achat Individuel",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("Date : $formattedDate"),
                  trailing: _actions(doc, sectionType, [docSnap]),
                ),
                Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (sectionType == "SCOOPS")
                        Text("SCOOPS : ${data['nomSCOOPS'] ?? '--'}",
                            style: TextStyle(fontWeight: FontWeight.w500)),
                      if (sectionType == "Individuel")
                        Text("Producteur : ${data['nomIndividuel'] ?? '--'}",
                            style: TextStyle(fontWeight: FontWeight.w500)),
                      SizedBox(height: 5),
                      ...parRuche.entries.map((entry) {
                        final ruche = entry.key;
                        final produits = entry.value;
                        return Card(
                          color: Colors.amber[50],
                          margin: EdgeInsets.symmetric(vertical: 7),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Ruche : $ruche",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber[900])),
                                ...produits.asMap().entries.map((entryProd) {
                                  final prod = entryProd.value;
                                  final indexProduit = details.indexOf(prod);
                                  return Card(
                                    color: Colors.teal[50],
                                    margin: EdgeInsets.symmetric(
                                        vertical: 5, horizontal: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(7)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                  "Produit : ${prod['typeProduit'] ?? '--'}",
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600)),
                                              Spacer(),
                                              IconButton(
                                                icon: Icon(Icons.edit,
                                                    color: Colors.amber[800],
                                                    size: 22),
                                                tooltip: "Modifier ce produit",
                                                onPressed: () async {
                                                  String? infoId;
                                                  final infoSnap = await doc
                                                      .reference
                                                      .collection(sectionType ==
                                                              "SCOOPS"
                                                          ? "SCOOP"
                                                          : "Individuel")
                                                      .doc(docSnap.id)
                                                      .collection(sectionType ==
                                                              "SCOOPS"
                                                          ? "SCOOP_info"
                                                          : "Individuel_info")
                                                      .limit(1)
                                                      .get();
                                                  if (infoSnap
                                                      .docs.isNotEmpty) {
                                                    infoId =
                                                        infoSnap.docs.first.id;
                                                  }
                                                  if (sectionType == "SCOOPS") {
                                                    Get.to(() =>
                                                        EditAchatSCOOPForm(
                                                          collecteId: doc.id,
                                                          achatDocId:
                                                              docSnap.id,
                                                          indexProduit:
                                                              indexProduit,
                                                          infoId: infoId ?? "",
                                                        ));
                                                  } else {
                                                    Get.to(() =>
                                                        EditAchatIndividuelForm(
                                                          collecteId: doc.id,
                                                          achatDocId:
                                                              docSnap.id,
                                                          indexProduit:
                                                              indexProduit,
                                                          infoId: infoId ?? "",
                                                        ));
                                                  }
                                                },
                                              )
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Text("Quantité acceptée : ",
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w400)),
                                              Text(
                                                  "${prod['quantiteAcceptee'] ?? '--'} ${prod['unite'] ?? ''}"),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Text("Quantité rejetée : ",
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w400)),
                                              Text(
                                                  "${prod['quantiteRejetee'] ?? '--'} ${prod['unite'] ?? ''}"),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Text("Prix unitaire : ",
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w400)),
                                              Text(
                                                  "${prod['prixUnitaire'] ?? '--'} €"),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Text("Prix total : ",
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w400)),
                                              Text(
                                                  "${prod['prixTotal'] ?? '--'} €",
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          Colors.green[700])),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      Divider(),
                      Text(
                        "Montant total : ${montantTotal.toStringAsFixed(2)} €",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.green[800]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Actions (modifier Récolte uniquement), PDF pour tous
  Widget _actions(QueryDocumentSnapshot doc, String sectionType,
      List<QueryDocumentSnapshot> sousDocs) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (sectionType == "récolte")
          IconButton(
            icon: Icon(Icons.edit, color: Colors.amber[800]),
            tooltip: "Modifier",
            onPressed: () {
              String typeForEdit = "récolte";
              Get.to(() => EditCollectePage(
                    collecteId: doc.id,
                    collecteType: typeForEdit,
                  ));
            },
          ),
        IconButton(
          icon: Icon(Icons.picture_as_pdf, color: Colors.red[700]),
          tooltip: "Télécharger reçu",
          onPressed: () async {
            if (sectionType == "récolte") {
              // Récupère le sous-doc de la sous-collec Récolte
              final sousDocsSnap =
                  await doc.reference.collection('Récolte').limit(1).get();
              Map<String, dynamic>? recolteDetails;
              if (sousDocsSnap.docs.isNotEmpty) {
                recolteDetails =
                    sousDocsSnap.docs.first.data() as Map<String, dynamic>;
              }
              await generateAndDownloadRecu(
                sectionType: sectionType,
                data: doc.data() as Map<String, dynamic>,
                recolteDetails: recolteDetails,
                docId: doc.id,
                utilisateurNom:
                    (doc.data() as Map<String, dynamic>)['utilisateurNom'],
              );
            } else {
              final docSnap = sousDocs.first;
              final docData = docSnap.data() as Map<String, dynamic>;
              final List detailsRaw = (docData['details'] as List?) ?? [];
              final List<Map<String, dynamic>> produits = detailsRaw
                  .whereType<Map>()
                  .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
                  .toList();

              Map<String, dynamic>? fournisseur;
              if (["SCOOPS", "Individuel"].contains(sectionType)) {
                final sousDocId = docSnap.id;
                final sousDocRef = doc.reference
                    .collection(
                        sectionType == "SCOOPS" ? "SCOOP" : "Individuel")
                    .doc(sousDocId);
                final infoSnap = await sousDocRef
                    .collection(sectionType == "SCOOPS"
                        ? "SCOOP_info"
                        : "Individuel_info")
                    .limit(1)
                    .get();
                if (infoSnap.docs.isNotEmpty) {
                  fournisseur = infoSnap.docs.first.data();
                }
              }
              await generateAndDownloadRecu(
                sectionType: sectionType,
                data: doc.data() as Map<String, dynamic>,
                produits: produits,
                fournisseur: fournisseur,
                docId: doc.id,
                utilisateurNom:
                    (doc.data() as Map<String, dynamic>)['utilisateurNom'],
              );
            }
          },
        ),
      ],
    );
  }

  // PDF GENERATION
  Future<void> generateAndDownloadRecu({
    required String sectionType,
    required Map<String, dynamic> data,
    List<Map<String, dynamic>> produits = const [],
    Map<String, dynamic>? fournisseur,
    required String docId,
    required String? utilisateurNom,
    Map<String, dynamic>? recolteDetails,
  }) async {
    final pdf = pw.Document();
    final Uint8List logoBytes = await rootBundle
        .load('assets/logo/logo.jpeg')
        .then((byteData) => byteData.buffer.asUint8List());
    final pw.ImageProvider logoImage = pw.MemoryImage(logoBytes);

    pw.Widget infoRow(String label, dynamic value, {bool bold = false}) =>
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
                flex: 2,
                child: pw.Text(label,
                    style: pw.TextStyle(
                        fontWeight:
                            bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
            pw.Expanded(
                flex: 3,
                child: pw.Text(
                    value == null
                        ? '--'
                        : value is DateTime
                            ? "${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}"
                            : value.toString(),
                    style: pw.TextStyle(
                        fontWeight:
                            bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
          ],
        );

    pw.Widget sectionTitle(String title) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 18, bottom: 4),
          child: pw.Text(title,
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16,
                  color: PdfColors.amber800)),
        );
    pw.Widget divider() => pw.Divider(color: PdfColors.amber, thickness: 1);

    final dateCollecte = data['dateCollecte'] is Timestamp
        ? (data['dateCollecte'] as Timestamp).toDate()
        : null;

    double montantTotal = 0;
    produits.forEach((p) {
      montantTotal += double.tryParse('${p['prixTotal'] ?? "0"}') ?? 0;
    });

    pdf.addPage(
      pw.Page(
        margin: pw.EdgeInsets.all(24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Image(
                logoImage,
                width: 100,
                height: 100,
              ),
            ),
            pw.Center(
                child: pw.Text(
              sectionType == "récolte"
                  ? "REÇU DE COLLECTE - RÉCOLTE"
                  : sectionType == "SCOOPS"
                      ? "REÇU DE COLLECTE - ACHAT SCOOPS"
                      : "REÇU DE COLLECTE - ACHAT INDIVIDUEL",
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 22,
                  color: PdfColors.amber700),
            )),
            pw.SizedBox(height: 10),
            divider(),
            sectionTitle("Informations générales"),
            infoRow("ID de la collecte :", docId, bold: true),
            infoRow("Date de collecte :", dateCollecte),
            infoRow("Utilisateur (vendeur) :", utilisateurNom ?? "--"),
            if (sectionType == "récolte")
              infoRow("Type :", "Récolte")
            else if (sectionType == "SCOOPS")
              infoRow("Type :", "Achat SCOOPS")
            else
              infoRow("Type :", "Achat Individuel"),
            divider(),
            if (sectionType == "récolte") ...[
              sectionTitle("Détails de la Récolte"),
              infoRow("Nom du récolteur :", recolteDetails?['nomRecolteur']),
              infoRow("Région :", recolteDetails?['region']),
              infoRow("Province :", recolteDetails?['province']),
              infoRow("Commune :", recolteDetails?['commune']),
              infoRow("Village :", recolteDetails?['village']),
              infoRow("Quantité (kg) :", recolteDetails?['quantiteKg']),
              infoRow("Nb ruches :", recolteDetails?['nbRuchesRecoltees']),
              infoRow(
                  "Florale :",
                  (recolteDetails?['predominanceFlorale'] is List)
                      ? (recolteDetails?['predominanceFlorale'] as List)
                          .join(', ')
                      : recolteDetails?['predominanceFlorale']?.toString()),
              infoRow("Type produit :", recolteDetails?['typeProduit']),
              infoRow(
                  "Date de récolte :",
                  (recolteDetails?['dateRecolte'] is Timestamp)
                      ? (recolteDetails?['dateRecolte'] as Timestamp).toDate()
                      : recolteDetails?['dateRecolte']),
            ],
            if (sectionType == "SCOOPS" || sectionType == "Individuel") ...[
              sectionTitle("Détails de l'Achat (multi-produits possibles)"),
              pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColors.amber50),
                        children: [
                          pw.Padding(
                              padding: pw.EdgeInsets.all(2),
                              child: pw.Text("Produit",
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(2),
                              child: pw.Text("Type ruche",
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(2),
                              child: pw.Text("Quantité acceptée",
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(2),
                              child: pw.Text("Quantité rejetée",
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(2),
                              child: pw.Text("PU (€)",
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(2),
                              child: pw.Text("Total (€)",
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold))),
                        ]),
                    ...produits.map((p) => pw.TableRow(children: [
                          pw.Padding(
                              padding: pw.EdgeInsets.all(2),
                              child:
                                  pw.Text(p['typeProduit']?.toString() ?? "")),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(2),
                              child: pw.Text(p['typeRuche']?.toString() ?? "")),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(2),
                              child: pw.Text(
                                  "${p['quantiteAcceptee'] ?? ""} ${p['unite'] ?? ""}")),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(2),
                              child: pw.Text(
                                  "${p['quantiteRejetee'] ?? ""} ${p['unite'] ?? ""}")),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(2),
                              child:
                                  pw.Text(p['prixUnitaire']?.toString() ?? "")),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(2),
                              child: pw.Text(p['prixTotal']?.toString() ?? "")),
                        ]))
                  ]),
              pw.Padding(
                padding: pw.EdgeInsets.only(top: 10, bottom: 2),
                child: pw.Text(
                    "Montant total : ${montantTotal.toStringAsFixed(2)} €",
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800,
                        fontSize: 15)),
              ),
              divider(),
              pw.Text(
                  sectionType == "SCOOPS"
                      ? "Fournisseur (SCOOPS)"
                      : "Fournisseur (Producteur Individuel)",
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 15,
                      color: PdfColors.amber800)),
              if (fournisseur != null && fournisseur.isNotEmpty)
                pw.Table(
                    columnWidths: {
                      0: pw.FlexColumnWidth(2),
                      1: pw.FlexColumnWidth(3),
                    },
                    border: null,
                    children: [
                      for (final entry in fournisseur.entries)
                        pw.TableRow(children: [
                          pw.Padding(
                              padding: pw.EdgeInsets.symmetric(vertical: 2),
                              child: pw.Text('${entry.key} :',
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.amber800))),
                          pw.Padding(
                              padding: pw.EdgeInsets.symmetric(vertical: 2),
                              child: pw.Text(
                                entry.value == null
                                    ? '--'
                                    : entry.value is DateTime
                                        ? "${entry.value.day.toString().padLeft(2, '0')}/${entry.value.month.toString().padLeft(2, '0')}/${entry.value.year}"
                                        : entry.value.toString(),
                                style: pw.TextStyle(
                                    color: PdfColors.black,
                                    fontWeight: pw.FontWeight.normal),
                              )),
                        ]),
                    ])
              else
                pw.Text("Aucune information fournisseur trouvée.",
                    style: pw.TextStyle(color: PdfColors.red)),
            ],
            pw.Spacer(),
            divider(),
            pw.Center(
                child: pw.Text("Merci pour votre confiance.",
                    style:
                        pw.TextStyle(fontSize: 12, color: PdfColors.grey700))),
          ],
        ),
      ),
    );

    final pdfData = await pdf.save();
    final filename = "recu_$docId.pdf";
    if (kIsWeb) {
      final blob = html.Blob([pdfData], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..target = 'blank'
        ..download = filename;
      html.document.body!.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
    } else {
      await Printing.layoutPdf(
        name: filename,
        onLayout: (format) async => pdfData,
      );
    }
  }
}
