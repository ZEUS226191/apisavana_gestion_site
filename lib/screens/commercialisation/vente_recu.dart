// Pour le téléchargement web
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class VenteReceiptsPage extends StatelessWidget {
  final String commercialId;
  final String prelevementId;
  final bool showLastOnly;

  const VenteReceiptsPage({
    Key? key,
    required this.commercialId,
    required this.prelevementId,
    this.showLastOnly = false,
  }) : super(key: key);

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchVentesManually(
      String commercialId, String prelevementId) async {
    final snap = await FirebaseFirestore.instance
        .collection('ventes')
        .doc(commercialId)
        .collection('ventes_effectuees')
        .get();

    final filtered = snap.docs
        .where((doc) => doc['prelevementId'] == prelevementId)
        .toList();

    filtered.sort((a, b) {
      final aDate = a['createdAt'] is Timestamp
          ? (a['createdAt'] as Timestamp).toDate()
          : DateTime(1970);
      final bDate = b['createdAt'] is Timestamp
          ? (b['createdAt'] as Timestamp).toDate()
          : DateTime(1970);
      return bDate.compareTo(aDate);
    });

    return filtered;
  }

  /// Récupère les noms du commercial et du client à partir de leur ID
  Future<Map<String, String>> getNames(
      String commercialId, String clientId) async {
    String commercialNom = commercialId;
    String clientNom = clientId;

    // Commercial
    try {
      final commercialSnap = await FirebaseFirestore.instance
          .collection('utilisateurs')
          .doc(commercialId)
          .get();
      if (commercialSnap.exists) {
        final d = commercialSnap.data();
        if (d != null) {
          commercialNom = d['nom'] ?? d['prenom'] ?? commercialId;
          if (d['prenom'] != null) {
            commercialNom = "${d['prenom']} ${d['nom'] ?? ''}".trim();
          }
        }
      }
    } catch (_) {}

    // Client
    try {
      final clientSnap = await FirebaseFirestore.instance
          .collection('clients')
          .doc(clientId)
          .get();
      if (clientSnap.exists) {
        final d = clientSnap.data();
        if (d != null) {
          clientNom = d['nomBoutique'] ?? d['nomGerant'] ?? clientId;
        }
      }
    } catch (_) {}

    return {
      'commercial': commercialNom,
      'client': clientNom,
    };
  }

  Future<Uint8List> _buildPdf(
    Map<String, dynamic> vente, {
    Uint8List? logoBytes,
    String? commercialNom,
    String? clientNom,
  }) async {
    final pdf = pw.Document();

    final date = vente['dateVente'] != null
        ? (vente['dateVente'] as Timestamp).toDate()
        : null;
    final emb = vente['emballagesVendus'] as List<dynamic>? ?? [];
    final quantiteTotale = vente['quantiteTotale']?.toStringAsFixed(2) ?? '?';
    final montantTotal = vente['montantTotal']?.toStringAsFixed(0) ?? '?';
    final typeVente = vente['typeVente'] ?? '';
    final montantPaye = vente['montantPaye']?.toStringAsFixed(0);
    final montantRestant = vente['montantRestant']?.toStringAsFixed(0);

    final dateString =
        date != null ? DateFormat('dd/MM/yyyy HH:mm').format(date) : '';

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logoBytes != null)
              pw.Center(
                child: pw.Image(
                  pw.MemoryImage(logoBytes),
                  height: 80,
                  fit: pw.BoxFit.contain,
                ),
              ),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                "REÇU DE VENTE",
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 20,
                  color: PdfColors.blue800,
                ),
              ),
            ),
            pw.Divider(),
            pw.SizedBox(height: 8),
            if (dateString.isNotEmpty) pw.Text("Date : $dateString"),
            if (clientNom != null) pw.Text("Client : $clientNom"),
            if (commercialNom != null) pw.Text("Commercial : $commercialNom"),
            pw.Text("Type de vente : $typeVente"),
            pw.Text("Quantité totale : $quantiteTotale kg"),
            pw.Text("Montant total : $montantTotal FCFA"),
            pw.SizedBox(height: 8),
            pw.Text(
              "Détail produits :",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 2),
            if (emb.isNotEmpty)
              ...emb.map((e) => pw.Text(
                    "- ${e['type']}: ${e['nombre']} pot(s) x ${e['contenanceKg']}kg @ ${e['prixUnitaire']} FCFA",
                  )),
            pw.SizedBox(height: 8),
            if (montantPaye != null)
              pw.Text("Montant payé : $montantPaye FCFA"),
            if (montantRestant != null)
              pw.Text("Montant restant : $montantRestant FCFA"),
            pw.SizedBox(height: 18),
            pw.Divider(),
            pw.Center(
                child: pw.Text("Merci de votre confiance !",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> _loadLogoBytes() async {
    final bytes = await rootBundle.load('assets/logo/logo.jpeg');
    return bytes.buffer.asUint8List();
  }

  void _handleDownload(
      BuildContext context, Map<String, dynamic> vente, String docId) async {
    final logoBytes = await _loadLogoBytes();
    final clientId = vente['clientId'] ?? '';
    final Map<String, String> names = await getNames(commercialId, clientId);

    final pdfBytes = await _buildPdf(
      vente,
      logoBytes: logoBytes,
      commercialNom: names['commercial'],
      clientNom: names['client'],
    );

    final filename = "recu_$docId.pdf";
    if (kIsWeb) {
      final blob = html.Blob([pdfBytes], 'application/pdf');
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
        onLayout: (_) async => pdfBytes,
        name: filename,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(showLastOnly ? "Dernier reçu de vente" : "Reçus de ventes"),
        backgroundColor: Colors.blue[700],
      ),
      body: FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        future: fetchVentesManually(commercialId, prelevementId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Aucun reçu disponible."));
          }

          final docs = snapshot.data!;
          final ventesDocs = showLastOnly ? [docs.first] : docs;

          return ListView.separated(
            padding: const EdgeInsets.all(18),
            separatorBuilder: (_, __) => const Divider(),
            itemCount: ventesDocs.length,
            itemBuilder: (context, i) {
              final venteDoc = ventesDocs[i];
              final vente = venteDoc.data();
              final docId = venteDoc.id;
              final date = vente['dateVente'] != null
                  ? (vente['dateVente'] as Timestamp).toDate()
                  : null;
              final emb = vente['emballagesVendus'] as List<dynamic>? ?? [];
              final clientId = vente['clientId'] ?? '';

              return FutureBuilder<Map<String, String>>(
                future: getNames(commercialId, clientId),
                builder: (context, namesSnap) {
                  final clientNom = namesSnap.data?['client'] ?? clientId;
                  final commercialNom =
                      namesSnap.data?['commercial'] ?? commercialId;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "Reçu de vente",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                      color: Colors.blue[800]),
                                ),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[700],
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.download),
                                label: const Text("Télécharger"),
                                onPressed: () =>
                                    _handleDownload(context, vente, docId),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (date != null)
                            Text(
                                "Date: ${DateFormat('dd/MM/yyyy HH:mm').format(date)}"),
                          Text("Client: $clientNom"),
                          Text("Commercial: $commercialNom"),
                          Text(
                              "Quantité totale: ${vente['quantiteTotale']?.toStringAsFixed(2) ?? '?'} kg"),
                          Text(
                              "Montant total: ${vente['montantTotal']?.toStringAsFixed(0) ?? '?'} FCFA"),
                          Text("Type de vente: ${vente['typeVente'] ?? ''}"),
                          const SizedBox(height: 6),
                          if (emb.isNotEmpty)
                            ...emb.map((e) => Text(
                                "- ${e['type']}: ${e['nombre']} pot(s) x ${e['contenanceKg']}kg @ ${e['prixUnitaire']} FCFA")),
                          const SizedBox(height: 8),
                          if (vente['montantPaye'] != null)
                            Text(
                                "Montant payé: ${vente['montantPaye']?.toStringAsFixed(0)} FCFA"),
                          if (vente['montantRestant'] != null)
                            Text(
                                "Montant restant: ${vente['montantRestant']?.toStringAsFixed(0)} FCFA"),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
