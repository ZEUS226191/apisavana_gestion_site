import 'package:apisavana_gestion/screens/commercialisation/prelevement_form.dart';
import 'package:apisavana_gestion/screens/commercialisation/prelevement_magazinier.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MagasinierPrincipalView extends StatefulWidget {
  final VoidCallback? onPrelevement;
  const MagasinierPrincipalView({super.key, this.onPrelevement});

  @override
  State<MagasinierPrincipalView> createState() =>
      _MagasinierPrincipalViewState();
}

class _MagasinierPrincipalViewState extends State<MagasinierPrincipalView> {
  // Pour mémoriser la sélection du mag simple par lot
  Map<String, String?> selectedMagasinierSimpleByLot = {};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance.collection('conditionnement').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          debugPrint("Aucun lot conditionné trouvé !");
          return const Center(child: Text("Aucun produit conditionné."));
        }

        final lots = snapshot.data!.docs;
        debugPrint("Nombre de lots conditionnés récupérés : ${lots.length}");

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 700;
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: lots.length,
              separatorBuilder: (c, i) => const SizedBox(height: 18),
              itemBuilder: (context, i) {
                final lot = lots[i].data() as Map<String, dynamic>;
                final lotId = lots[i].id;
                debugPrint(
                    "Traitement du lot $lotId (${lot['lotOrigine'] ?? ''})");

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('prelevements')
                      .where('lotConditionnementId', isEqualTo: lotId)
                      .snapshots(),
                  builder: (context, allPrelevSnap) {
                    double quantiteConditionnee =
                        (lot['quantiteConditionnee'] ?? 0.0).toDouble();
                    double quantitePrelevee = 0.0;
                    int nbTotalPots = (lot['nbTotalPots'] ?? 0) as int;
                    double prixTotal = (lot['prixTotal'] ?? 0.0).toDouble();

                    Map<String, int> potsRestantsParType = {};
                    Map<String, int> potsInitials = {};
                    if (lot['emballages'] != null) {
                      for (var emb in lot['emballages']) {
                        potsRestantsParType[emb['type']] = emb['nombre'];
                        potsInitials[emb['type']] = emb['nombre'];
                      }
                    }

                    // Listes pour organisation
                    List<QueryDocumentSnapshot> prelevementsMagasiniersSimples =
                        [];
                    Map<String, List<QueryDocumentSnapshot>>
                        prelevementsCommerciauxByMagSimple = {};

                    // Pour la gestion de la validation mag simple → mag principal
                    Map<String, dynamic> prelevSimpleRestitData = {};

                    if (allPrelevSnap.hasData) {
                      debugPrint(
                          "Nombre de prélèvements pour lot $lotId : ${allPrelevSnap.data!.docs.length}");
                      for (final pr in allPrelevSnap.data!.docs) {
                        final prData = pr.data() as Map<String, dynamic>;
                        final isVersMagasinierSimple =
                            (prData['magasinierDestId'] ?? '')
                                    .toString()
                                    .isNotEmpty &&
                                prData['typePrelevement'] == 'magasinier';
                        final isVersCommercialDirect =
                            (prData['magasinierDestId'] == null ||
                                    (prData['magasinierDestId'] ?? '')
                                        .toString()
                                        .isEmpty) &&
                                (prData['magazinierId'] == null ||
                                    (prData['magazinierId'] ?? '')
                                        .toString()
                                        .isEmpty) &&
                                prData['typePrelevement'] == 'commercial';

                        if (isVersMagasinierSimple || isVersCommercialDirect) {
                          quantitePrelevee +=
                              (prData['quantiteTotale'] ?? 0.0).toDouble();
                          prixTotal -=
                              (prData['prixTotalEstime'] ?? 0.0).toDouble();
                          if (prData['emballages'] != null) {
                            for (var emb in prData['emballages']) {
                              final t = emb['type'];
                              potsRestantsParType[t] =
                                  (potsRestantsParType[t] ?? 0) -
                                      ((emb['nombre'] ?? 0) as num).toInt();
                            }
                          }
                          nbTotalPots -= (prData['emballages'] as List)
                              .fold<int>(
                                  0,
                                  (prev, emb) =>
                                      prev +
                                      ((emb['nombre'] ?? 0) as num).toInt());
                        }

                        // Prélèvements vers magasinier simple (parent)
                        if ((prData['magasinierDestId'] ?? '')
                                .toString()
                                .isNotEmpty &&
                            prData['typePrelevement'] == 'magasinier') {
                          prelevementsMagasiniersSimples.add(pr);
                        }

                        // Prélèvements à des commerciaux faits par mag simple (enfant)
                        if ((prData['magazinierId'] ?? '').toString().isNotEmpty &&
                            (prData['commercialId'] ?? '')
                                .toString()
                                .isNotEmpty &&
                            prData['typePrelevement'] == 'commercial') {
                          final magSimpleId =
                              (prData['magazinierId'] ?? '').toString().trim();
                          prelevementsCommerciauxByMagSimple.putIfAbsent(
                              magSimpleId, () => []);
                          prelevementsCommerciauxByMagSimple[magSimpleId]!
                              .add(pr);
                        }
                      }
                    }

                    // 1. Récupère la liste unique des magasiniers simples ayant un prélèvement sur ce lot
                    final magSimplesForLot = prelevementsMagasiniersSimples
                        .map((prDoc) => {
                              "id": (prDoc.data() as Map<String, dynamic>)[
                                      'magasinierDestId'] ??
                                  "",
                              "nom": (prDoc.data() as Map<String, dynamic>)[
                                      'magasinierDestNom'] ??
                                  "",
                            })
                        .where((m) => m['id'].toString().isNotEmpty)
                        .toSet()
                        .toList();

                    // Mémorisation de la sélection (persistant par lot)
                    selectedMagasinierSimpleByLot.putIfAbsent(
                      lotId,
                      () => magSimplesForLot.isNotEmpty
                          ? magSimplesForLot.first['id']
                          : null,
                    );

                    // Sélectionné courant
                    String? selectedMagSimpleId =
                        selectedMagasinierSimpleByLot[lotId];

                    // --- PATCH ici : gestion validation mag simple → principal ---
                    bool demandeRestitutionMagasinier = false;
                    bool restitutionValideePrincipal = false;
                    String nomMagSimple = '';
                    QueryDocumentSnapshot? selectedPrDoc;

                    if (selectedMagSimpleId != null) {
                      selectedPrDoc =
                          prelevementsMagasiniersSimples.firstWhereOrNull(
                        (pr) =>
                            (pr.data()
                                as Map<String, dynamic>)['magasinierDestId'] ==
                            selectedMagSimpleId,
                      );
                      if (selectedPrDoc != null) {
                        prelevSimpleRestitData =
                            selectedPrDoc.data() as Map<String, dynamic>;
                        demandeRestitutionMagasinier = prelevSimpleRestitData[
                                'demandeRestitutionMagasinier'] ==
                            true;
                        restitutionValideePrincipal = prelevSimpleRestitData[
                                'magasinierPrincipalApprobationRestitution'] ==
                            true;
                        nomMagSimple =
                            prelevSimpleRestitData['magasinierDestNom'] ?? '';
                      }
                    }

                    return Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                      elevation: 5,
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.green[50],
                                child: Icon(Icons.inventory_2_rounded,
                                    size: 35, color: Colors.green[800]),
                              ),
                              title: Text(
                                "Lot: ${lot['lotOrigine'] ?? lotId}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.scale,
                                          color: Colors.amber[700], size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Conditionné: ${quantiteConditionnee.toStringAsFixed(2)} kg",
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Icon(Icons.add_box,
                                          color: Colors.blue, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Restant: ${(quantiteConditionnee - quantitePrelevee) < 0 ? 0 : (quantiteConditionnee - quantitePrelevee).toStringAsFixed(2)} kg",
                                        style: const TextStyle(
                                            fontSize: 14, color: Colors.blue),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Icon(Icons.format_list_numbered,
                                          color: Colors.brown, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                          "Nb total de pots: ${nbTotalPots < 0 ? 0 : nbTotalPots}",
                                          style: const TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Icon(Icons.attach_money,
                                          color: Colors.green, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Prix total: ${prixTotal < 0 ? 0 : prixTotal.toStringAsFixed(0)} FCFA",
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  if (potsRestantsParType.isNotEmpty)
                                    ...potsRestantsParType.entries
                                        .map((e) => Row(
                                              children: [
                                                Icon(Icons.local_mall,
                                                    color: Colors.amber,
                                                    size: 16),
                                                const SizedBox(width: 6),
                                                Text(
                                                  "${e.key}: ${e.value < 0 ? 0 : e.value} pots (${potsInitials[e.key] ?? 0} init.)",
                                                  style: const TextStyle(
                                                      fontSize: 13),
                                                ),
                                              ],
                                            )),
                                ],
                              ),
                              trailing: (quantiteConditionnee -
                                          quantitePrelevee) >
                                      0
                                  ? ElevatedButton.icon(
                                      icon: const Icon(Icons.add_shopping_cart),
                                      label: const Text("Prélever"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: (quantiteConditionnee -
                                                    quantitePrelevee) >
                                                0
                                            ? Colors.green[700]
                                            : Colors.grey,
                                        foregroundColor: Colors.white,
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(30)),
                                      ),
                                      onPressed: () async {
                                        final res =
                                            await showModalBottomSheet<String>(
                                          context: context,
                                          builder: (ctx) => SafeArea(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ListTile(
                                                  leading: Icon(Icons.people,
                                                      color: Colors.green),
                                                  title:
                                                      Text("À un commercial"),
                                                  onTap: () => Navigator.pop(
                                                      ctx, 'commercial'),
                                                ),
                                                ListTile(
                                                  leading: Icon(Icons.store,
                                                      color: Colors.brown),
                                                  title:
                                                      Text("À un magasinier"),
                                                  onTap: () => Navigator.pop(
                                                      ctx, 'magasinier'),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                        if (res == 'commercial') {
                                          final result = await Get.to(() =>
                                              PrelevementFormPage(
                                                  lotConditionnement: {
                                                    ...lot,
                                                    "id": lotId
                                                  }));
                                          if (result == true &&
                                              widget.onPrelevement != null)
                                            widget.onPrelevement!();
                                          (context as Element).markNeedsBuild();
                                        } else if (res == 'magasinier') {
                                          final result = await Get.to(() =>
                                              PrelevementMagasinierFormPage(
                                                  lotConditionnement: {
                                                    ...lot,
                                                    "id": lotId
                                                  }));
                                          if (result == true &&
                                              widget.onPrelevement != null)
                                            widget.onPrelevement!();
                                          (context as Element).markNeedsBuild();
                                        }
                                      },
                                    )
                                  : null,
                            ),
                            // ----------- SELECTEUR MAGASINIER SIMPLE + INFOS DÉTAILLÉES -----------
                            if (magSimplesForLot.isNotEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    const Text("Magasinier simple : ",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    DropdownButton<String>(
                                      value: selectedMagSimpleId,
                                      items: magSimplesForLot
                                          .map((m) => DropdownMenuItem(
                                              value: m['id'],
                                              child: Text(m['nom'])))
                                          .toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          selectedMagasinierSimpleByLot[lotId] =
                                              val;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            if (selectedPrDoc != null)
                              _buildMagasinierSimpleDetails(
                                context,
                                selectedPrDoc,
                                prelevementsCommerciauxByMagSimple,
                                lot,
                                lotId,
                                isMobile,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMagasinierSimpleDetails(
    BuildContext context,
    QueryDocumentSnapshot prDoc,
    Map<String, List<QueryDocumentSnapshot>> prelevementsCommerciauxByMagSimple,
    Map<String, dynamic> lot,
    String lotId,
    bool isMobile,
  ) {
    final prData = prDoc.data() as Map<String, dynamic>;
    final datePr = prData['datePrelevement'] != null
        ? (prData['datePrelevement'] as Timestamp).toDate()
        : null;
    final magSimpleId = (prData['magasinierDestId'] ?? '').toString().trim();
    final prId = prDoc.id;
    final bool demandeTerminee = prData['demandeRestitution'] == true;
    final bool approuveParMag =
        prData['magazinierApprobationRestitution'] == true;
    final String? nomMagApprobateur = prData['magazinierApprobateurNom'];
    final sousPrelevs = prelevementsCommerciauxByMagSimple[magSimpleId] ?? [];

    // ----------- RESTES CUMULES DE TOUTES LES RESTITUTIONS ----------
    Map<String, int> restesCumulCommerciaux = {};
    double restesKgTotal = 0.0;
    for (final subPrDoc in sousPrelevs) {
      final subData = subPrDoc.data() as Map<String, dynamic>;
      if (subData['restesApresVenteCommercial'] != null) {
        final m =
            Map<String, dynamic>.from(subData['restesApresVenteCommercial']);
        m.forEach((k, v) {
          restesCumulCommerciaux[k] =
              (restesCumulCommerciaux[k] ?? 0) + (v as int);
        });
      }
    }
    if (prData['emballages'] != null) {
      for (var emb in prData['emballages']) {
        if (restesCumulCommerciaux.containsKey(emb['type'])) {
          restesKgTotal += (restesCumulCommerciaux[emb['type']] ?? 0) *
              (emb['contenanceKg'] ?? 0.0);
        }
      }
    }

    final bool demandeRestitutionMagasinier =
        prData['demandeRestitutionMagasinier'] == true;
    final bool restitutionValideePrincipal =
        prData['magasinierPrincipalApprobationRestitution'] == true;
    final String? nomMagPrincipal = prData['magasinierPrincipalApprobateurNom'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Card(
          color: Colors.orange[50],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  leading: Icon(Icons.shopping_bag, color: Colors.blue[700]),
                  title: Text(
                    "Prélèvement mag simple du ${datePr != null ? "${datePr.day}/${datePr.month}/${datePr.year}" : '?'}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          "Magasinier destinataire: ${prData['magasinierDestNom'] ?? ''}"),
                      Text(
                          "Quantité: ${prData['quantiteTotale'] ?? '?'} kg, Valeur: ${prData['prixTotalEstime'] ?? '?'} FCFA"),
                      if (prData['emballages'] != null)
                        ...List.generate((prData['emballages'] as List).length,
                            (j) {
                          final emb = prData['emballages'][j];
                          return Text(
                            "- ${emb['type']}: ${emb['nombre']} pots x ${emb['contenanceKg']}kg @ ${emb['prixUnitaire']} FCFA",
                            style: const TextStyle(fontSize: 13),
                          );
                        }),
                      if (restesCumulCommerciaux.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 7, bottom: 2),
                          child: Container(
                            decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: Colors.green[200]!)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8.0, horizontal: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.undo,
                                          color: Colors.green[700], size: 20),
                                      const SizedBox(width: 7),
                                      Text("Restes cumulés réstitués :",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green[800])),
                                      const SizedBox(width: 7),
                                      Text(
                                          "${restesKgTotal.toStringAsFixed(2)} kg",
                                          style: TextStyle(
                                              color: Colors.green[900],
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  ...restesCumulCommerciaux.entries.map((e) =>
                                      Text(
                                          "${e.key}: ${e.value} pots",
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.green))),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (sousPrelevs.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 8.0, top: 8, bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "Prélèvements commerciaux réalisés par ce magasinier simple :",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange),
                        ),
                        ...sousPrelevs.map((subPrDoc) =>
                            _buildSousPrelevementCommercial(
                                subPrDoc, isMobile)),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 7.0, horizontal: 6.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (demandeRestitutionMagasinier &&
                          !restitutionValideePrincipal)
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.verified),
                            label: const Text(
                                "Valider retour de ce magasinier simple"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                              minimumSize: Size(isMobile ? 130 : 200, 40),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('prelevements')
                                  .doc(prDoc.id)
                                  .update({
                                'magasinierPrincipalApprobationRestitution':
                                    true,
                                'magasinierPrincipalApprobateurNom':
                                    "NOM_MAG_PRINCIPAL", // <- Remplacer dynamiquement
                                'dateApprobationRestitutionMagasinier':
                                    FieldValue.serverTimestamp(),
                              });
                              Get.snackbar("Succès", "Retour validé !");
                              (context as Element).markNeedsBuild();
                            },
                          ),
                        ),
                      if (restitutionValideePrincipal)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                                color: Colors.green[200],
                                borderRadius: BorderRadius.circular(16)),
                            child: Center(
                              child: Text(
                                "Restitution validée par le principal"
                                "${nomMagPrincipal != null && nomMagPrincipal.isNotEmpty ? " : $nomMagPrincipal" : ""}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TelechargerRapportBouton(
                          prelevement: prData,
                          lot: {...lot, 'id': lotId},
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSousPrelevementCommercial(
      QueryDocumentSnapshot subPrDoc, bool isMobile) {
    final subData = subPrDoc.data() as Map<String, dynamic>;
    final subDate = subData['datePrelevement'] != null
        ? (subData['datePrelevement'] as Timestamp).toDate()
        : null;
    final bool demandeTerminee = subData['demandeRestitution'] == true;
    final bool approuveParMag =
        subData['magazinierApprobationRestitution'] == true;
    Map<String, int> restesApresVente = {};
    double restesKg = 0.0;
    if (subData['restesApresVenteCommercial'] != null) {
      final m =
          Map<String, dynamic>.from(subData['restesApresVenteCommercial']);
      m.forEach((k, v) => restesApresVente[k] = (v as int));
      if (subData['emballages'] != null) {
        for (var emb in subData['emballages']) {
          if (restesApresVente.containsKey(emb['type'])) {
            restesKg += (restesApresVente[emb['type']] ?? 0) *
                (emb['contenanceKg'] ?? 0.0);
          }
        }
      }
    }
    return Card(
      color: Colors.orange[100],
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.orange[700]),
                const SizedBox(width: 6),
                Text(
                  "Commercial: ${subData['commercialNom'] ?? subData['commercialId'] ?? ''}",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                if (demandeTerminee && approuveParMag)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.green[300],
                        borderRadius: BorderRadius.circular(9)),
                    child: Row(
                      children: [
                        Icon(Icons.verified,
                            size: 16, color: Colors.green[900]),
                        const SizedBox(width: 4),
                        const Text("Restitution validée",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green))
                      ],
                    ),
                  ),
              ],
            ),
            Text(
                "Prélèvement du ${subDate != null ? "${subDate.day}/${subDate.month}/${subDate.year}" : '?'}"),
            Text("Quantité: ${subData['quantiteTotale']} kg"),
            Text("Valeur: ${subData['prixTotalEstime']} FCFA"),
            if (subData['emballages'] != null)
              ...List.generate((subData['emballages'] as List).length, (j) {
                final emb = subData['emballages'][j];
                return Text(
                    "- ${emb['type']}: ${emb['nombre']} pots x ${emb['contenanceKg']}kg @ ${emb['prixUnitaire']} FCFA",
                    style: const TextStyle(fontSize: 13));
              }),
            if (restesApresVente.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Colors.green[200]!)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.undo,
                                color: Colors.green[700], size: 20),
                            const SizedBox(width: 7),
                            Text("Restes réstitués :",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[800])),
                            const SizedBox(width: 7),
                            Text("${restesKg.toStringAsFixed(2)} kg",
                                style: TextStyle(
                                    color: Colors.green[900],
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        ...restesApresVente.entries.map((e) => Text(
                            "${e.key}: ${e.value} pots",
                            style: const TextStyle(
                                fontSize: 13, color: Colors.green))),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
