/*Widget _buildMagasinierSimpleDetails(
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
                                    "NOM_MAG_PRINCIPAL", // <-- Remplacer dynamiquement
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
  }*/

/*Widget _buildVenteSection({
    required String title,
    required Color color,
    required List ventes,
    required IconData icon,
    required Color iconColor,
    required bool isMobile,
  }) {
    final cardMaxWidth = isMobile ? 320.0 : 390.0;
    final cardMinWidth = isMobile ? 240.0 : 290.0;

    Widget buildVenteTile(Map<String, dynamic> vente) {
      final dateV = vente['dateVente'] != null
          ? (vente['dateVente'] as Timestamp).toDate()
          : null;
      final client = (vente['clientNom'] ?? vente['clientId'] ?? '').toString();
      final embVendus = vente['emballagesVendus'] ?? [];

      // Pour "Payé: ... • Reste: ..." et badge, utiliser un Wrap au lieu de Row pour éviter overflow
      Widget buildPayBadge() {
        final typeVente = vente['typeVente'] ?? '';
        final montantPaye = vente['montantPaye'] ?? 0;
        final montantRestant = vente['montantRestant'] ?? 0;
        Color badgeColor;
        Color textColor;
        switch (typeVente) {
          case "Comptant":
            badgeColor = Colors.green[100]!;
            textColor = Colors.green[800]!;
            break;
          case "Crédit":
            badgeColor = Colors.orange[100]!;
            textColor = Colors.orange[800]!;
            break;
          case "Recouvrement":
            badgeColor = Colors.blue[100]!;
            textColor = Colors.blue[800]!;
            break;
          default:
            badgeColor = Colors.grey[300]!;
            textColor = Colors.black;
        }
        return Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 2),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: badgeColor,
                ),
                child: Text(
                  typeVente,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                "Payé: $montantPaye FCFA • Reste: $montantRestant FCFA",
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }

      return Container(
        constraints: BoxConstraints(
          maxWidth: cardMaxWidth,
          minWidth: cardMinWidth,
        ),
        margin: const EdgeInsets.only(bottom: 14, right: 12),
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: color.withOpacity(0.13)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_cart, size: 18, color: Colors.blue[600]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Vente du ${dateV != null ? "${dateV.day}/${dateV.month}/${dateV.year}" : "?"}",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Icon(Icons.store, size: 16, color: Colors.purple[200]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Client: $client",
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Icon(Icons.scale, size: 16, color: Colors.teal),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Qté vendue: ${vente['quantiteTotale'] ?? '?'} kg",
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Icon(Icons.attach_money, size: 16, color: Colors.orange),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Montant: ${vente['montantTotal'] ?? '?'} FCFA",
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            buildPayBadge(),
            if (embVendus != null && embVendus is List && embVendus.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(embVendus.length, (k) {
                    final emb = embVendus[k];
                    // Utiliser Wrap pour emballages aussi
                    return Wrap(
                      children: [
                        Icon(icon, color: iconColor, size: 17),
                        const SizedBox(width: 5),
                        Text(
                          "- ${emb['type']}: ${emb['nombre']} pots x ${emb['contenanceKg']}kg @ ${emb['prixUnitaire']} FCFA",
                          style: const TextStyle(fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    );
                  }),
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(
        maxWidth: isMobile ? double.infinity : 1200,
        minWidth: isMobile ? double.infinity : 300,
      ),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 16),
          ),
          const SizedBox(height: 8),
          isMobile
              ? SizedBox(
                  height: 240,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: ventes
                        .map<Widget>((venteDoc) => buildVenteTile(
                            venteDoc.data() as Map<String, dynamic>))
                        .toList(),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ventes
                        .map<Widget>((venteDoc) => buildVenteTile(
                            venteDoc.data() as Map<String, dynamic>))
                        .toList(),
                  ),
                ),
        ],
      ),
    );
  }*/

/*Widget _sousCardCommercial(
      BuildContext context, QueryDocumentSnapshot subPrDoc,
      {required bool isMobile}) {
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
            // ------ AFFICHAGE DES VENTES DU COMMERCIAL ------
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('ventes')
                  .doc(subData['commercialId'])
                  .collection('ventes_effectuees')
                  .where('prelevementId', isEqualTo: subPrDoc.id)
                  .snapshots(),
              builder: (context, ventesSnap) {
                if (!ventesSnap.hasData || ventesSnap.data!.docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 8, top: 7),
                    child: Text("Aucune vente pour ce prélèvement.",
                        style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[700])),
                  );
                }
                final ventes = ventesSnap.data!.docs
                    .map((v) => v.data() as Map<String, dynamic>)
                    .toList();
                final ventesParType = {
                  "Comptant": <Map<String, dynamic>>[],
                  "Crédit": <Map<String, dynamic>>[],
                  "Recouvrement": <Map<String, dynamic>>[],
                };
                for (final v in ventes) {
                  ventesParType[v['typeVente'] ?? 'Comptant']?.add(v);
                }
                Map<String, int> potsVendues = {};
                for (final v in ventes) {
                  final embVendus =
                      v['emballagesVendus'] ?? v['emballages'] ?? [];
                  for (var emb in embVendus) {
                    final t = emb['type'];
                    final n = (emb['nombre'] ?? 0) as int;
                    potsVendues[t] = (potsVendues[t] ?? 0) + n;
                  }
                }
                Map<String, int> potsPreleves = {};
                if (subData['emballages'] != null) {
                  for (var emb in subData['emballages']) {
                    final t = emb['type'];
                    final n = (emb['nombre'] ?? 0) as int;
                    potsPreleves[t] = (potsPreleves[t] ?? 0) + n;
                  }
                }
                Map<String, int> potsRestes = {};
                for (final t in potsPreleves.keys) {
                  potsRestes[t] =
                      (potsPreleves[t] ?? 0) - (potsVendues[t] ?? 0);
                }

                Widget buildVenteTile(Map<String, dynamic> v) {
                  final dateVente = v['dateVente'] != null
                      ? (v['dateVente'] as Timestamp).toDate()
                      : null;
                  final clientId = v['clientId'] ?? '';
                  final quantite = (v['quantiteTotale'] ?? 0).toString();
                  final montantTotal = v['montantTotal'] ?? v['prixTotal'] ?? 0;
                  final montantPaye = v['montantPaye'] ?? 0;
                  final montantRestant = v['montantRestant'] ?? 0;
                  final typeVente = v['typeVente'] ?? '';
                  final embVendus =
                      v['emballagesVendus'] ?? v['emballages'] ?? [];
                  return FutureBuilder<String>(
                    future: clientId != ''
                        ? getClientNomBoutique(clientId)
                        : Future.value(''),
                    builder: (ctx, clientSnap) {
                      final clientNomBoutique = clientSnap.data ?? clientId;
                      return Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 5, horizontal: 1),
                        padding: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.orange[100]!),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.shopping_cart,
                                    size: 18, color: Colors.blue[600]),
                                const SizedBox(width: 5),
                                Text(
                                  "${dateVente != null ? "${dateVente.day}/${dateVente.month}/${dateVente.year}" : "?"}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                if (clientNomBoutique != '') ...[
                                  const SizedBox(width: 8),
                                  Icon(Icons.store,
                                      size: 16, color: Colors.purple[200]),
                                  Text(
                                    "Client : $clientNomBoutique",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500),
                                  )
                                ]
                              ],
                            ),
                            Row(
                              children: [
                                Icon(Icons.scale, size: 16, color: Colors.teal),
                                Text(" ${quantite}kg  ",
                                    style: const TextStyle(fontSize: 13)),
                                Icon(Icons.attach_money,
                                    size: 16, color: Colors.orange),
                                Text(" $montantTotal FCFA",
                                    style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 2.0),
                              child: Row(
                                children: [
                                  if (typeVente.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: typeVente == "Comptant"
                                            ? Colors.green[100]
                                            : typeVente == "Crédit"
                                                ? Colors.orange[100]
                                                : Colors.blue[100],
                                      ),
                                      child: Text(
                                        typeVente,
                                        style: TextStyle(
                                          color: typeVente == "Comptant"
                                              ? Colors.green[800]
                                              : typeVente == "Crédit"
                                                  ? Colors.orange[800]
                                                  : Colors.blue[800],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    "Payé: $montantPaye FCFA • Reste: $montantRestant FCFA",
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            ...embVendus.map<Widget>((emb) => Text(
                                  "- ${emb['type']}: ${emb['nombre']} pots x ${emb['contenanceKg']}kg @ ${emb['prixUnitaire']} FCFA",
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.black87),
                                )),
                          ],
                        ),
                      );
                    },
                  );
                }

                // Responsive : sur mobile, horizontal scroll des ventes par type
                if (isMobile) {
                  return Padding(
                    padding:
                        const EdgeInsets.only(left: 10, right: 8, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Ventes réalisées :",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                                fontSize: 15)),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 200,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (final type in [
                                "Comptant",
                                "Crédit",
                                "Recouvrement"
                              ])
                                if (ventesParType[type]?.isNotEmpty ?? false)
                                  Container(
                                    width:
                                        MediaQuery.of(context).size.width * 0.8,
                                    margin: const EdgeInsets.only(right: 16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4, horizontal: 8),
                                          margin:
                                              const EdgeInsets.only(bottom: 4),
                                          decoration: BoxDecoration(
                                            color: type == "Comptant"
                                                ? Colors.green[50]
                                                : type == "Crédit"
                                                    ? Colors.orange[50]
                                                    : Colors.blue[50],
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            type,
                                            style: TextStyle(
                                              color: type == "Comptant"
                                                  ? Colors.green[800]
                                                  : type == "Crédit"
                                                      ? Colors.orange[800]
                                                      : Colors.blue[800],
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                        ...ventesParType[type]!
                                            .map<Widget>(buildVenteTile)
                                            .toList()
                                      ],
                                    ),
                                  ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text("Restes :",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red)),
                        ...potsRestes.entries.map((e) => Text(
                              "${e.key}: ${e.value < 0 ? 0 : e.value} pots",
                              style: const TextStyle(fontSize: 13),
                            )),
                        if (demandeTerminee && approuveParMag)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.green[300],
                                  borderRadius: BorderRadius.circular(9)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
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
                          ),
                        if (restesApresVente.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(9),
                                  border:
                                      Border.all(color: Colors.green[200]!)),
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
                                        Text(
                                            "${restesKg.toStringAsFixed(2)} kg",
                                            style: TextStyle(
                                                color: Colors.green[900],
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                    ...restesApresVente.entries.map((e) => Text(
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
                  );
                }
                // Desktop: groupé horizontalement
                return Padding(
                  padding: const EdgeInsets.only(left: 10, right: 8, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Ventes réalisées :",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                              fontSize: 15)),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final type in [
                            "Comptant",
                            "Crédit",
                            "Recouvrement"
                          ])
                            if (ventesParType[type]?.isNotEmpty ?? false)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4, horizontal: 8),
                                      margin: const EdgeInsets.only(bottom: 4),
                                      decoration: BoxDecoration(
                                        color: type == "Comptant"
                                            ? Colors.green[50]
                                            : type == "Crédit"
                                                ? Colors.orange[50]
                                                : Colors.blue[50],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        type,
                                        style: TextStyle(
                                          color: type == "Comptant"
                                              ? Colors.green[800]
                                              : type == "Crédit"
                                                  ? Colors.orange[800]
                                                  : Colors.blue[800],
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    ...ventesParType[type]!
                                        .map<Widget>(buildVenteTile)
                                        .toList()
                                  ],
                                ),
                              )
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text("Restes :",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.red)),
                      ...potsRestes.entries.map((e) => Text(
                            "${e.key}: ${e.value < 0 ? 0 : e.value} pots",
                            style: const TextStyle(fontSize: 13),
                          )),
                      if (demandeTerminee && approuveParMag)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.green[300],
                                borderRadius: BorderRadius.circular(9)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
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
                        ),
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
                );
              },
            ),
          ],
        ),
      ),
    );
  }*/

// ----------- SOUS-CARTES VENTES -----------
/*Widget _buildSousVentes(String prelevementId, dynamic commercialId) {
    if (commercialId == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ventes')
          .doc(commercialId)
          .collection('ventes_effectuees')
          .where('prelevementId', isEqualTo: prelevementId)
          .snapshots(),
      builder: (context, ventesSnap) {
        if (!ventesSnap.hasData || ventesSnap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final docs = ventesSnap.data!.docs;
        final venteComptant =
            docs.where((d) => d['typeVente'] == 'Comptant').toList();
        final venteCredit =
            docs.where((d) => d['typeVente'] == 'Crédit').toList();
        final venteRecouvrement =
            docs.where((d) => d['typeVente'] == 'Recouvrement').toList();
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (venteComptant.isNotEmpty)
                _buildVenteSection(
                    title: "VENTES COMPTANT",
                    color: Colors.green,
                    ventes: venteComptant,
                    icon: Icons.point_of_sale,
                    iconColor: Colors.green),
              if (venteCredit.isNotEmpty)
                _buildVenteSection(
                    title: "VENTES CRÉDIT",
                    color: Colors.orange,
                    ventes: venteCredit,
                    icon: Icons.point_of_sale,
                    iconColor: Colors.orange),
              if (venteRecouvrement.isNotEmpty)
                _buildVenteSection(
                    title: "VENTES RECOUVREMENT",
                    color: Colors.blue,
                    ventes: venteRecouvrement,
                    icon: Icons.point_of_sale,
                    iconColor: Colors.blue),
            ]
                .map((w) => Padding(
                    padding: const EdgeInsets.only(right: 22), child: w))
                .toList(),
          ),
        );
      },
    );
  }*/
