import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

String? formatFirestoreDate(dynamic d) {
  if (d == null) return null;
  if (d is DateTime) return "${d.day}/${d.month}/${d.year}";
  if (d is Timestamp)
    return "${d.toDate().day}/${d.toDate().month}/${d.toDate().year}";
  return d.toString();
}

class TelechargerRapportBouton extends StatelessWidget {
  final Map<String, dynamic> prelevement;
  final Map<String, dynamic> lot;

  const TelechargerRapportBouton({
    super.key,
    required this.prelevement,
    required this.lot,
  });

  Future<List<Map<String, dynamic>>> _fetchPrelevementsCommerciauxForMagSimple(
      String lotId, String magSimpleId) async {
    final snap = await FirebaseFirestore.instance
        .collection('prelevements')
        .where('lotConditionnementId', isEqualTo: lotId)
        .where('magazinierId', isEqualTo: magSimpleId)
        .where('typePrelevement', isEqualTo: 'commercial')
        .get();
    return snap.docs.map((d) {
      var data = d.data() as Map<String, dynamic>;
      data['id'] = d.id;
      return data;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchVentesCommerciales(
      String commercialId, String prelevementId) async {
    final snap = await FirebaseFirestore.instance
        .collection('ventes')
        .doc(commercialId)
        .collection('ventes_effectuees')
        .where('prelevementId', isEqualTo: prelevementId)
        .get();
    return snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
  }

  pw.Widget buildSectionTitle(String text, PdfColor color, pw.Font font,
      {double size = 17}) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4, top: 12),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontWeight: pw.FontWeight.bold,
          fontSize: size,
          color: color,
        ),
      ),
    );
  }

  pw.Widget buildKeyValue(String label, String value, pw.Font font,
      {PdfColor keyColor = PdfColors.blueGrey800,
      PdfColor valueColor = PdfColors.black}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 170,
          child: pw.Text(
            label,
            style: pw.TextStyle(
                font: font,
                color: keyColor,
                fontWeight: pw.FontWeight.bold,
                fontSize: 11.5),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(font: font, color: valueColor, fontSize: 11.5),
          ),
        ),
      ],
    );
  }

  pw.Widget buildTableHeader(List<String> headers, PdfColor bg, pw.Font font) {
    return pw.Container(
      color: bg,
      child: pw.Row(
        children: headers
            .map((h) => pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 2, horizontal: 3),
                    child: pw.Text(h,
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            font: font,
                            fontSize: 11,
                            color: PdfColors.blueGrey800)),
                  ),
                ))
            .toList(),
      ),
    );
  }

  pw.Widget buildTableRow(List<String> cells, pw.Font font, {PdfColor? color}) {
    return pw.Container(
      color: color ?? PdfColors.white,
      child: pw.Row(
        children: cells
            .map((c) => pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 2, horizontal: 3),
                    child: pw.Text(c,
                        style: pw.TextStyle(font: font, fontSize: 11)),
                  ),
                ))
            .toList(),
      ),
    );
  }

  pw.Widget buildDivider() =>
      pw.Divider(height: 14, thickness: 0.6, color: PdfColors.blueGrey200);

  Future<void> _generateAndDownloadPdf(BuildContext context) async {
    final pdf = pw.Document();
    final ttf =
        pw.Font.ttf(await rootBundle.load('assets/fonts/OpenSans-Regular.ttf'));
    final ttfBold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/OpenSans-Bold.ttf'));

    final lotId =
        lot['id'] ?? lot['lotConditionnementId'] ?? lot['lotId'] ?? "";
    final magSimpleId = prelevement['magasinierId'] ??
        prelevement['magasinierDestId'] ??
        prelevement['magasinierNom'] ??
        "";

    // --- PAGE 1 - EN-TÊTE & LOT ---
    pdf.addPage(
      pw.Page(
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(35),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(8),
                color: PdfColors.blue50,
                border: pw.Border.all(color: PdfColors.blue200, width: 1.2),
              ),
              padding: const pw.EdgeInsets.all(14),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('RAPPORT DE TRAÇABILITÉ',
                            style: pw.TextStyle(
                                font: ttfBold,
                                fontSize: 22,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue800)),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          "Lot : ${lot['lotOrigine'] ?? ''}",
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              font: ttfBold,
                              fontSize: 13,
                              color: PdfColors.blueGrey700),
                        ),
                      ]),
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("Date de génération :",
                            style: pw.TextStyle(
                                font: ttf,
                                fontSize: 10,
                                color: PdfColors.blueGrey600)),
                        pw.Text(formatFirestoreDate(DateTime.now()) ?? "",
                            style: pw.TextStyle(
                                font: ttf,
                                fontSize: 10,
                                color: PdfColors.blueGrey800)),
                      ]),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            buildSectionTitle(
                'Informations sur le Lot', PdfColors.blue700, ttfBold),
            buildDivider(),
            buildKeyValue("Date conditionnement :",
                formatFirestoreDate(lot['dateConditionnement']) ?? "-", ttf),
            buildKeyValue("Quantité conditionnée :",
                "${lot['quantiteConditionnee']} kg", ttf),
            buildKeyValue("Nombre de pots :", "${lot['nbTotalPots']}", ttf),
            buildKeyValue("Prix total :", "${lot['prixTotal']} FCFA", ttf),
            pw.SizedBox(height: 7),
            pw.Text('Emballages :',
                style: pw.TextStyle(font: ttfBold, fontSize: 12)),
            pw.SizedBox(height: 2),
            if (lot['emballages'] != null)
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blue100),
                  borderRadius: pw.BorderRadius.circular(5),
                  color: PdfColors.blue50,
                ),
                child: pw.Column(
                  children: [
                    buildTableHeader(["Type", "Qté", "Contenance (kg)"],
                        PdfColors.blue100, ttfBold),
                    ...List.generate(
                      (lot['emballages'] as List).length > 10
                          ? 10
                          : (lot['emballages'] as List).length,
                      (i) {
                        var emb = lot['emballages'][i];
                        return buildTableRow([
                          emb['type'].toString(),
                          emb['nombre'].toString(),
                          "${emb['contenanceKg']}",
                        ], ttf,
                            color: i % 2 == 0
                                ? PdfColors.white
                                : PdfColors.blue50);
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    // --- PAGE 2 - PRÉLÈVEMENT MAGASINIER SIMPLE ---
    pdf.addPage(
      pw.Page(
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(35),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            buildSectionTitle(
                'Prélèvement Magasinier Simple', PdfColors.orange700, ttfBold),
            buildDivider(),
            buildKeyValue("Magasinier Simple :",
                "${prelevement['magasinierDestNom'] ?? ''}", ttf),
            buildKeyValue(
                "Date prélèvement :",
                formatFirestoreDate(prelevement['datePrelevement']) ?? "-",
                ttf),
            buildKeyValue("Quantité totale :",
                "${prelevement['quantiteTotale']} kg", ttf),
            buildKeyValue("Valeur estimée :",
                "${prelevement['prixTotalEstime']} FCFA", ttf),
            pw.SizedBox(height: 7),
            pw.Text('Emballages :',
                style: pw.TextStyle(font: ttfBold, fontSize: 12)),
            pw.SizedBox(height: 2),
            if (prelevement['emballages'] != null)
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.orange100),
                  borderRadius: pw.BorderRadius.circular(5),
                  color: PdfColors.orange50,
                ),
                child: pw.Column(
                  children: [
                    buildTableHeader([
                      "Type",
                      "Qté",
                      "Contenance (kg)",
                      "Prix unitaire FCFA"
                    ], PdfColors.orange100, ttfBold),
                    ...List.generate(
                      (prelevement['emballages'] as List).length > 10
                          ? 10
                          : (prelevement['emballages'] as List).length,
                      (i) {
                        var emb = prelevement['emballages'][i];
                        return buildTableRow([
                          emb['type'].toString(),
                          emb['nombre'].toString(),
                          "${emb['contenanceKg']}",
                          "${emb['prixUnitaire']}"
                        ], ttf,
                            color: i % 2 == 0
                                ? PdfColors.white
                                : PdfColors.orange50);
                      },
                    ),
                  ],
                ),
              ),
            pw.SizedBox(height: 8),
            pw.Text('Restes cumulés réstitués :',
                style: pw.TextStyle(font: ttfBold, fontSize: 12)),
            pw.SizedBox(height: 2),
            if (prelevement['restesApresVenteCommerciaux'] != null &&
                (prelevement['restesApresVenteCommerciaux'] as Map).isNotEmpty)
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.green100),
                  borderRadius: pw.BorderRadius.circular(5),
                  color: PdfColors.green50,
                ),
                child: pw.Column(
                  children: [
                    buildTableHeader(
                        ["Type", "Restes (pots)"], PdfColors.green100, ttfBold),
                    ...((prelevement['restesApresVenteCommerciaux']
                            as Map<String, dynamic>)
                        .entries
                        .take(10)
                        .map((e) => buildTableRow(
                              [e.key, e.value.toString()],
                              ttf,
                              color: PdfColors.green50,
                            )))
                  ],
                ),
              )
            else
              pw.Text("Aucun reste signalé.", style: pw.TextStyle(font: ttf)),
          ],
        ),
      ),
    );

    // --- PAGES PRÉLÈVEMENTS COMMERCIAUX ---
    final prelevementsCommerciaux =
        await _fetchPrelevementsCommerciauxForMagSimple(lotId, magSimpleId);
    int pageC = 1;
    for (final pc in prelevementsCommerciaux.take(5)) {
      final ventes = await _fetchVentesCommerciales(
          pc['commercialId'], pc['id'] ?? pc['prelevementId'] ?? "");
      pdf.addPage(
        pw.Page(
          theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(35),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildSectionTitle("Prélèvement Commercial #$pageC",
                  PdfColors.purple700, ttfBold,
                  size: 16),
              buildDivider(),
              buildKeyValue("Commercial :",
                  "${pc['commercialNom'] ?? pc['commercialId'] ?? ''}", ttf),
              buildKeyValue("Date prélèvement :",
                  formatFirestoreDate(pc['datePrelevement']) ?? "-", ttf),
              buildKeyValue("Quantité :", "${pc['quantiteTotale']} kg", ttf),
              buildKeyValue("Valeur :", "${pc['prixTotalEstime']} FCFA", ttf),
              pw.SizedBox(height: 7),
              pw.Text("Emballages :",
                  style: pw.TextStyle(font: ttfBold, fontSize: 12)),
              pw.SizedBox(height: 2),
              if (pc['emballages'] != null)
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.purple100),
                    borderRadius: pw.BorderRadius.circular(5),
                    color: PdfColors.purple50,
                  ),
                  child: pw.Column(
                    children: [
                      buildTableHeader([
                        "Type",
                        "Qté",
                        "Contenance (kg)",
                        "Prix unitaire FCFA"
                      ], PdfColors.purple100, ttfBold),
                      ...List.generate(
                        (pc['emballages'] as List).length > 10
                            ? 10
                            : (pc['emballages'] as List).length,
                        (i) {
                          var emb = pc['emballages'][i];
                          return buildTableRow([
                            emb['type'].toString(),
                            emb['nombre'].toString(),
                            "${emb['contenanceKg']}",
                            "${emb['prixUnitaire']}"
                          ], ttf,
                              color: i % 2 == 0
                                  ? PdfColors.white
                                  : PdfColors.purple50);
                        },
                      ),
                    ],
                  ),
                ),
              pw.SizedBox(height: 8),
              pw.Text('Ventes réalisées :',
                  style: pw.TextStyle(font: ttfBold, fontSize: 12)),
              if (ventes.isEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Text("Aucune vente.",
                      style: pw.TextStyle(color: PdfColors.red800, font: ttf)),
                ),
              ...ventes.take(10).map((vente) => pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 3, left: 5),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      borderRadius: pw.BorderRadius.circular(4),
                      border: pw.Border.all(color: PdfColors.blue100),
                    ),
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text("Date : ",
                                style:
                                    pw.TextStyle(font: ttfBold, fontSize: 11)),
                            pw.Text(
                                "${formatFirestoreDate(vente['dateVente']) ?? '-'}",
                                style: pw.TextStyle(font: ttf)),
                          ],
                        ),
                        pw.Row(
                          children: [
                            pw.Text("Client : ",
                                style:
                                    pw.TextStyle(font: ttfBold, fontSize: 11)),
                            pw.Text(
                                "${vente['clientNom'] ?? vente['clientId'] ?? ''}",
                                style: pw.TextStyle(font: ttf)),
                          ],
                        ),
                        pw.Row(
                          children: [
                            pw.Text("Type : ",
                                style:
                                    pw.TextStyle(font: ttfBold, fontSize: 11)),
                            pw.Text("${vente['typeVente'] ?? '-'}",
                                style: pw.TextStyle(font: ttf)),
                          ],
                        ),
                        pw.Row(
                          children: [
                            pw.Text("Qté vendue : ",
                                style:
                                    pw.TextStyle(font: ttfBold, fontSize: 11)),
                            pw.Text("${vente['quantiteTotale'] ?? '-'} kg",
                                style: pw.TextStyle(font: ttf)),
                          ],
                        ),
                        pw.Row(
                          children: [
                            pw.Text("Montant : ",
                                style:
                                    pw.TextStyle(font: ttfBold, fontSize: 11)),
                            pw.Text(
                                "${vente['montantTotal'] ?? vente['prixTotal'] ?? '-'} FCFA",
                                style: pw.TextStyle(font: ttf)),
                          ],
                        ),
                      ],
                    ),
                  )),
              if (pc['restesApresVenteCommercial'] != null &&
                  (pc['restesApresVenteCommercial'] as Map).isNotEmpty)
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 4),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.green100),
                    borderRadius: pw.BorderRadius.circular(5),
                    color: PdfColors.green50,
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      buildTableHeader(["Type", "Restes après vente (pots)"],
                          PdfColors.green100, ttfBold),
                      ...((pc['restesApresVenteCommercial']
                              as Map<String, dynamic>)
                          .entries
                          .take(10)
                          .map((e) => buildTableRow(
                                [e.key, e.value.toString()],
                                ttf,
                                color: PdfColors.green50,
                              )))
                    ],
                  ),
                ),
              pw.Spacer(),
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  "Page ${pageC + 2}",
                  style: pw.TextStyle(
                      font: ttf, fontSize: 10, color: PdfColors.blueGrey600),
                ),
              )
            ],
          ),
        ),
      );
      pageC++;
    }

    await Printing.sharePdf(
        bytes: await pdf.save(), filename: 'rapport_restitution.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.download),
      label: const Text("Télécharger le rapport"),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        minimumSize: const Size(120, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () => _generateAndDownloadPdf(context),
    );
  }
}
