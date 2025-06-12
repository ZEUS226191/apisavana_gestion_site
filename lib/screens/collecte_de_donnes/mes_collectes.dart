// Pour web only
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

// Helper pour icônes et couleurs selon type
IconData collecteIcon(String type) {
  switch (type) {
    case 'récolte':
      return Icons.eco_rounded;
    case 'achat':
      return Icons.shopping_bag_rounded;
    default:
      return Icons.help_outline;
  }
}

Color collecteColor(String type) {
  switch (type) {
    case 'récolte':
      return Colors.green[600]!;
    case 'SCOOPS':
      return Colors.blue[500]!;
    case 'Individuel':
      return Colors.purple[400]!;
    default:
      return Colors.grey[400]!;
  }
}

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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text("Mes collectes")),
        body: Center(child: Text("Non connecté.")),
      );
    }
    Future<Map<String, List<QueryDocumentSnapshot>>> fetchTriAchatDocs(
        List<QueryDocumentSnapshot> docs) async {
      final achatsScoops = <QueryDocumentSnapshot>[];
      final achatsIndividuels = <QueryDocumentSnapshot>[];
      for (final doc
          in docs.where((doc) => (doc.data() as Map)['type'] == 'achat')) {
        final scoopsSnap =
            await doc.reference.collection('SCOOP').limit(1).get();
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
        body: FutureBuilder<QuerySnapshot>(
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
            final docs = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['utilisateurId'] == user.uid;
            }).toList();
            final recoltes = docs
                .where((doc) => (doc.data() as Map)['type'] == 'récolte')
                .toList();

            // <<<<<<<< SECTION AJOUTEE POUR LE VRAI TRI DES ACHATS >>>>>>>>
            return FutureBuilder<Map<String, List<QueryDocumentSnapshot>>>(
                future: () async {
              final achatsScoops = <QueryDocumentSnapshot>[];
              final achatsIndividuels = <QueryDocumentSnapshot>[];
              for (final doc in docs
                  .where((doc) => (doc.data() as Map)['type'] == 'achat')) {
                final scoopsSnap =
                    await doc.reference.collection('SCOOP').limit(1).get();
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
            }(), builder: (context, achatsSnap) {
              if (!achatsSnap.hasData) {
                return Center(child: CircularProgressIndicator());
              }
              final achatsScoops = achatsSnap.data!['SCOOPS']!;
              final achatsIndividuels = achatsSnap.data!['Individuel']!;
              return ListView(
                padding: EdgeInsets.all(18),
                children: [
                  // Header Dashboard stylé
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    color: Colors.amber[50],
                    elevation: 2,
                    margin: EdgeInsets.only(bottom: 18),
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 18, horizontal: 22),
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
                                    "Bienvenue, ${user.displayName ?? user.email ?? user.uid}",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18)),
                                SizedBox(height: 8),
                                Text(
                                  "Total : ${docs.length} collectes",
                                  style: TextStyle(
                                      color: Colors.amber[900], fontSize: 16),
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

                  // Accordion section Récolte
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
                            .map((doc) => _collecteCard(doc, 'récolte'))
                            .toList(),
                  ),

                  // Accordion section SCOOPS
                  _section(
                    title: "SCOOPS",
                    icon: Icons.groups_2_rounded,
                    color: Colors.blue[500]!,
                    isOpen: sectionOpen['SCOOPS']!,
                    onTap: () => setState(
                        () => sectionOpen['SCOOPS'] = !sectionOpen['SCOOPS']!),
                    children: achatsScoops.isEmpty
                        ? [
                            Padding(
                                padding: EdgeInsets.all(8),
                                child: Text("Aucun achat via SCOOPS."))
                          ]
                        : achatsScoops
                            .map((doc) => _collecteCard(doc, 'SCOOPS'))
                            .toList(),
                  ),

                  // Accordion section Individuel
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
                            .map((doc) => _collecteCard(doc, 'Individuel'))
                            .toList(),
                  ),
                ],
              );
            });
          },
        ));
  }

  // Widget section accordéon stylée
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
          if (isOpen)
            Column(
              children: children,
            ),
        ],
      ),
    );
  }

  // Carte stylée pour chaque collecte
  Widget _collecteCard(QueryDocumentSnapshot doc, String sectionType) {
    final data = doc.data() as Map<String, dynamic>;
    final date = data['dateCollecte'] is Timestamp
        ? (data['dateCollecte'] as Timestamp).toDate()
        : null;
    final formattedDate = date != null
        ? "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}"
        : "--/--/----";

    // Récupérer la sous-collection selon le type
    String sousCollection;
    if (sectionType == "récolte")
      sousCollection = 'Récolte';
    else if (sectionType == "SCOOPS")
      sousCollection = 'SCOOP';
    else
      sousCollection = 'Individuel';

    return FutureBuilder<QuerySnapshot>(
      future: doc.reference.collection(sousCollection).limit(1).get(),
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

        // Pour achat, il faut aussi aller chercher les infos fournisseur si besoin
        String? fournisseurName;
        if (sectionType == "SCOOPS") {
          // Ajoute ici un autre FutureBuilder si tu veux le nom SCOOPS
        }
        if (sectionType == "Individuel") {
          // Ajoute ici un autre FutureBuilder si tu veux le nom producteur
        }

        return Card(
          color: Colors.white,
          margin: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: collecteColor(sectionType),
              child: Icon(
                  collecteIcon(sectionType == "récolte" ? "récolte" : "achat"),
                  color: Colors.white),
            ),
            title: Text(
              sectionType == "récolte"
                  ? "Récolte"
                  : sectionType == "SCOOPS"
                      ? "Achat SCOOPS"
                      : "Achat Individuel",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Date : $formattedDate", style: TextStyle(fontSize: 14)),
                if (sectionType == "récolte")
                  Text("Récolteur : ${sousDoc['nomRecolteur'] ?? '--'}"),
                if (sectionType == "récolte")
                  Text(
                      "Quantité : ${sousDoc['quantiteKg']?.toString() ?? '--'} kg"),
                if (sectionType == "récolte")
                  Text("Florale : ${sousDoc['predominanceFlorale'] ?? '--'}"),
                if (sectionType == "SCOOPS")
                  Text(
                      "Quantité : ${sousDoc['quantite']?.toString() ?? '--'} ${sousDoc['unite'] ?? ''}"),
                if (sectionType == "SCOOPS")
                  Text("Type produit : ${sousDoc['typeProduit'] ?? '--'}"),
                if (sectionType == "Individuel")
                  Text(
                      "Quantité : ${sousDoc['quantite']?.toString() ?? '--'} ${sousDoc['unite'] ?? ''}"),
                if (sectionType == "Individuel")
                  Text("Type produit : ${sousDoc['typeProduit'] ?? '--'}"),
                // etc.
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.amber[800]),
                  tooltip: "Modifier",
                  onPressed: () {
                    String typeForEdit =
                        sectionType == "récolte" ? "récolte" : "achat";
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
                    Map<String, dynamic>? fournisseur;
                    String? fournisseurTitre;
                    // On récupère d'abord l'ID du doc sous-collection (ex: achatId)
                    final sousDocId = snap.data!.docs.first.id;
                    final sousDocRef = doc.reference
                        .collection(
                            sectionType == "SCOOPS" ? "SCOOP" : "Individuel")
                        .doc(sousDocId);
                    // Puis on va chercher le fournisseur
                    final infoSnap = await sousDocRef
                        .collection(sectionType == "SCOOPS"
                            ? "SCOOP_info"
                            : "Individuel_info")
                        .limit(1)
                        .get();
                    if (infoSnap.docs.isNotEmpty) {
                      fournisseur = infoSnap.docs.first.data();
                      fournisseurTitre = sectionType == "SCOOPS"
                          ? "Fournisseur (SCOOPS)"
                          : "Fournisseur (Producteur Individuel)";
                    }
                    await generateAndDownloadRecu(
                      sectionType: sectionType,
                      data: doc.data() as Map<String, dynamic>,
                      sousDoc: sousDoc,
                      fournisseur: fournisseur,
                      docId: doc.id,
                      utilisateurNom: (doc.data()
                          as Map<String, dynamic>)['utilisateurNom'],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper pour une ligne d'info à 2 colonnes pour sections "fournisseur"
  pw.Widget infoRow2(String label, dynamic value, {bool bold = false}) =>
      pw.Padding(
        padding: pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
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
        ),
      );

// Helper pour titre de section Fournisseur
  pw.Widget fournisseurSectionTitle(String title) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 18, bottom: 4),
        child: pw.Text(title,
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 16,
                color: PdfColors.amber800)),
      );

  Future<void> generateAndDownloadRecu({
    required String sectionType,
    required Map<String, dynamic> data,
    required Map<String, dynamic> sousDoc,
    Map<String, dynamic>? fournisseur, // null si pas de fournisseur
    required String docId,
    required String? utilisateurNom,
  }) async {
    final pdf = pw.Document();

    // --- AJOUT LOGO ---
    final Uint8List logoBytes = await rootBundle
        .load('assets/logo/logo.jpeg')
        .then((byteData) => byteData.buffer.asUint8List());
    final pw.ImageProvider logoImage = pw.MemoryImage(logoBytes);

    // Helper pour une ligne d'info générale (informations générales + détails de la récolte/d'achat)
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

    // ----------- PAGE -----------
    pdf.addPage(
      pw.Page(
        margin: pw.EdgeInsets.all(24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // LOGO EN HAUT
            pw.Center(
              child: pw.Image(
                logoImage,
                width: 100, // adapte la taille si besoin
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
              infoRow("Nom du récolteur :", sousDoc['nomRecolteur']),
              infoRow("Région :", sousDoc['region']),
              infoRow("Province :", sousDoc['province']),
              infoRow("Village :", sousDoc['village']),
              infoRow("Quantité (kg) :", sousDoc['quantiteKg']),
              infoRow("Prédominance florale :", sousDoc['predominanceFlorale']),
              infoRow(
                  "Date de récolte :",
                  sousDoc['dateRecolte'] is Timestamp
                      ? (sousDoc['dateRecolte'] as Timestamp).toDate()
                      : sousDoc['dateRecolte']),
            ],
            if (sectionType == "SCOOPS" || sectionType == "Individuel") ...[
              sectionTitle("Détails de l'Achat"),
              infoRow("Quantité :", sousDoc['quantite']),
              infoRow("Unité :", sousDoc['unite']),
              infoRow("Type de produit :", sousDoc['typeProduit']),
              infoRow("Type de ruche :", sousDoc['typeRuche']),
              infoRow("Prix unitaire :", sousDoc['prixUnitaire']),
              infoRow("Prix total :", sousDoc['prixTotal']),
              infoRow(
                  "Date d'achat :",
                  sousDoc['dateAchat'] is Timestamp
                      ? (sousDoc['dateAchat'] as Timestamp).toDate()
                      : sousDoc['dateAchat']),
              divider(),
              // Section Fournisseur bien visible
              fournisseurSectionTitle(sectionType == "SCOOPS"
                  ? "Fournisseur (SCOOPS)"
                  : "Fournisseur (Producteur Individuel)"),
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

  Future<void> downloadPdf(pw.Document pdf, String filename) async {
    final pdfData = await pdf.save();
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
