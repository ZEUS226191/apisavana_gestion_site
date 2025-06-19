import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class RapportGlobalPage extends StatelessWidget {
  final List<Map<String, dynamic>> lotsData;

  const RapportGlobalPage({Key? key, required this.lotsData}) : super(key: key);

  Future<void> _generateAndDownloadPdf(BuildContext context) async {
    final pdf = pw.Document();
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.symmetric(horizontal: 25, vertical: 20),
          theme: pw.ThemeData.withFont(
            base: baseFont,
            bold: boldFont,
          ),
        ),
        build: (pw.Context context) {
          return [
            pw.Text('RAPPORT GLOBAL',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 18,
                    color: PdfColors.blue800)),
            pw.SizedBox(height: 10),
            ...lotsData.map((lot) {
              final prelevements =
                  lot['prelevements'] as List<Map<String, dynamic>>? ?? [];
              final ventes = lot['ventes'] as List<Map<String, dynamic>>? ?? [];
              return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Lot : ${lot['lotOrigine'] ?? lot['id']}",
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.Text(
                        "Date conditionnement : ${lot['dateConditionnement'] ?? '-'}"),
                    pw.Text(
                        "Quantité conditionnée : ${lot['quantiteConditionnee'] ?? ''} kg"),
                    pw.Text("Nombre de pots : ${lot['nbTotalPots'] ?? ''}"),
                    pw.Text("Prix total : ${lot['prixTotal'] ?? ''} FCFA"),
                    pw.SizedBox(height: 8),
                    pw.Text("Prélèvements :",
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                            color: PdfColors.orange)),
                    if (prelevements.isEmpty)
                      pw.Text("Aucun prélèvement pour ce lot."),
                    ...prelevements.map((pr) => pw.Text(
                        "- ${pr['typePrelevement']} | ${pr['quantiteTotale']} kg | ${pr['prixTotalEstime']} FCFA")),
                    pw.SizedBox(height: 8),
                    pw.Text("Ventes :",
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                            color: PdfColors.purple)),
                    if (ventes.isEmpty) pw.Text("Aucune vente liée à ce lot."),
                    ...ventes.map((vente) => pw.Text(
                        "- ${vente['typeVente'] ?? ''} | ${vente['quantiteTotale'] ?? ''} kg | ${vente['montantTotal'] ?? vente['prixTotal'] ?? ''} FCFA")),
                    pw.Divider(),
                  ]);
            }),
          ];
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'rapport_global.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Rapport Global PDF")),
      body: Center(
        child: ElevatedButton.icon(
          icon: Icon(Icons.picture_as_pdf),
          label: Text("Télécharger le rapport"),
          onPressed: () => _generateAndDownloadPdf(context),
        ),
      ),
    );
  }
}
