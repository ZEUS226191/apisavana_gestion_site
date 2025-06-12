import 'package:apisavana_gestion/screens/commercialisation/prelevement_form.dart';
import 'package:apisavana_gestion/screens/commercialisation/vente_form.dart';
import 'package:apisavana_gestion/screens/commercialisation/vente_recu.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CommercialisationHomePage extends StatefulWidget {
  const CommercialisationHomePage({super.key});

  @override
  State<CommercialisationHomePage> createState() =>
      _CommercialisationHomePageState();
}

class _CommercialisationHomePageState extends State<CommercialisationHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Tab> myTabs = <Tab>[
    const Tab(icon: Icon(Icons.store), text: "Magazinier"),
    const Tab(icon: Icon(Icons.person), text: "Commercial(e)"),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: myTabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: "Retour au Dashboard",
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Get.offAllNamed('/dashboard'),
        ),
        title: const Text("💰 Commercialisation"),
        backgroundColor: Colors.green[700],
        bottom: TabBar(
          controller: _tabController,
          tabs: myTabs,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          MagazinierPage(onPrelevement: () => _tabController.animateTo(1)),
          CommercialPage(),
        ],
      ),
    );
  }
}

/// MAGAZINIER PAGE
class MagazinierPage extends StatefulWidget {
  final VoidCallback? onPrelevement;
  const MagazinierPage({Key? key, this.onPrelevement}) : super(key: key);

  @override
  State<MagazinierPage> createState() => _MagazinierPageState();
}

class _MagazinierPageState extends State<MagazinierPage> {
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return FutureBuilder<DocumentSnapshot>(
      future: currentUser != null
          ? FirebaseFirestore.instance
              .collection('utilisateurs')
              .doc(currentUser.uid)
              .get()
          : null,
      builder: (context, userSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('conditionnement')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
              return const Center(child: Text("Aucun produit conditionné."));

            final lots = snapshot.data!.docs;
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: lots.length,
              separatorBuilder: (c, i) => const SizedBox(height: 18),
              itemBuilder: (context, i) {
                final lot = lots[i].data() as Map<String, dynamic>;
                final lotId = lots[i].id;

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
                    if (allPrelevSnap.hasData) {
                      for (final pr in allPrelevSnap.data!.docs) {
                        final prData = pr.data() as Map<String, dynamic>;
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
                        nbTotalPots -= (prData['emballages'] as List).fold<int>(
                            0,
                            (prev, emb) =>
                                prev + ((emb['nombre'] ?? 0) as num).toInt());
                      }
                    }
                    final quantiteRestante =
                        quantiteConditionnee - quantitePrelevee;

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('prelevements')
                          .where('lotConditionnementId', isEqualTo: lotId)
                          .snapshots(),
                      builder: (context, prelevSnap) {
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
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.scale,
                                              color: Colors.amber[700],
                                              size: 18),
                                          const SizedBox(width: 6),
                                          Text(
                                              "Conditionné: ${quantiteConditionnee.toStringAsFixed(2)} kg",
                                              style: const TextStyle(
                                                  fontSize: 14)),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(Icons.add_box,
                                              color: Colors.blue, size: 18),
                                          const SizedBox(width: 6),
                                          Text(
                                              "Restant: ${quantiteRestante < 0 ? 0 : quantiteRestante.toStringAsFixed(2)} kg",
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.blue)),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(Icons.format_list_numbered,
                                              color: Colors.brown, size: 18),
                                          const SizedBox(width: 6),
                                          Text(
                                              "Nb total de pots: ${nbTotalPots < 0 ? 0 : nbTotalPots}",
                                              style: const TextStyle(
                                                  fontSize: 14)),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(Icons.attach_money,
                                              color: Colors.green, size: 18),
                                          const SizedBox(width: 6),
                                          Text(
                                              "Prix total: ${prixTotal < 0 ? 0 : prixTotal.toStringAsFixed(0)} FCFA",
                                              style: const TextStyle(
                                                  fontSize: 14)),
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
                                                            fontSize: 13)),
                                                  ],
                                                )),
                                    ],
                                  ),
                                  trailing: ElevatedButton.icon(
                                    icon: const Icon(Icons.add_shopping_cart),
                                    label: const Text("Prélever"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: quantiteRestante > 0
                                          ? Colors.green[700]
                                          : Colors.grey,
                                      foregroundColor: Colors.white,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(30)),
                                    ),
                                    onPressed: quantiteRestante > 0
                                        ? () async {
                                            final result = await Get.to(() =>
                                                PrelevementFormPage(
                                                    lotConditionnement: {
                                                      ...lot,
                                                      "id": lotId
                                                    }));
                                            if (result == true &&
                                                widget.onPrelevement != null)
                                              widget.onPrelevement!();
                                            setState(
                                                () {}); // Rafraîchit la vue
                                          }
                                        : null,
                                  ),
                                ),
                                // Sous-cartes des prélèvements
                                if (prelevSnap.hasData &&
                                    prelevSnap.data!.docs.isNotEmpty)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const Divider(),
                                      ...prelevSnap.data!.docs.map((prDoc) {
                                        final pr = prDoc.data()
                                            as Map<String, dynamic>;
                                        final datePr =
                                            pr['datePrelevement'] != null
                                                ? (pr['datePrelevement']
                                                        as Timestamp)
                                                    .toDate()
                                                : null;
                                        final prId = prDoc.id;
                                        // VENTES: Stream des ventes reliées à ce prélèvement
                                        return StreamBuilder<QuerySnapshot>(
                                          stream: FirebaseFirestore.instance
                                              .collection('ventes')
                                              .doc(pr['commercialId'])
                                              .collection('ventes_effectuees')
                                              .where('prelevementId',
                                                  isEqualTo: prId)
                                              .snapshots(),
                                          builder: (context, ventesSnap) {
                                            double quantitePrelevee =
                                                (pr['quantiteTotale'] ?? 0.0)
                                                    .toDouble();
                                            double montantEstime =
                                                (pr['prixTotalEstime'] ?? 0.0)
                                                    .toDouble();
                                            double quantiteVendue = 0.0;
                                            double montantVendu = 0.0;

                                            Map<String, int>
                                                potsRestantsParType = {};
                                            Map<String, int> potsInitials = {};
                                            if (pr['emballages'] != null) {
                                              for (var emb
                                                  in pr['emballages']) {
                                                potsRestantsParType[
                                                        emb['type']] =
                                                    emb['nombre'];
                                                potsInitials[emb['type']] =
                                                    emb['nombre'];
                                              }
                                            }

                                            if (ventesSnap.hasData) {
                                              for (final vDoc
                                                  in ventesSnap.data!.docs) {
                                                final vente = vDoc.data()
                                                    as Map<String, dynamic>;
                                                quantiteVendue +=
                                                    (vente['quantiteTotale'] ??
                                                            0.0)
                                                        .toDouble();
                                                montantVendu +=
                                                    (vente['montantTotal'] ??
                                                            0.0)
                                                        .toDouble();
                                                if (vente['emballagesVendus'] !=
                                                    null) {
                                                  for (var emb in vente[
                                                      'emballagesVendus']) {
                                                    final t = emb['type'];
                                                    potsRestantsParType[t] =
                                                        (potsRestantsParType[
                                                                    t] ??
                                                                0) -
                                                            ((emb['nombre'] ??
                                                                    0) as num)
                                                                .toInt();
                                                  }
                                                }
                                              }
                                            }
                                            final quantiteRestante =
                                                quantitePrelevee -
                                                    quantiteVendue;
                                            final montantRestant =
                                                montantEstime - montantVendu;

                                            return Card(
                                              color: Colors.orange[50],
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12)),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  ListTile(
                                                    leading: Icon(
                                                        Icons.shopping_bag,
                                                        color:
                                                            Colors.blue[700]),
                                                    title: Text(
                                                      "Prélèvement du ${datePr != null ? "${datePr.day}/${datePr.month}/${datePr.year}" : '?'}",
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ),
                                                    subtitle: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                            "Magazinier: ${pr['magazinierNom'] ?? ''}"),
                                                        Text(
                                                            "Commercial: ${pr['commercialNom'] ?? pr['commercialId'] ?? ''}"),
                                                        Text(
                                                            "Total prélevé: ${pr['quantiteTotale'] ?? '?'} kg"),
                                                        Text(
                                                            "Montant estimé: ${pr['prixTotalEstime'] ?? '?'} FCFA"),
                                                        if (pr['emballages'] !=
                                                            null)
                                                          ...List.generate(
                                                              (pr['emballages']
                                                                      as List)
                                                                  .length, (j) {
                                                            final emb =
                                                                pr['emballages']
                                                                    [j];
                                                            return Text(
                                                                "- ${emb['type']}: ${emb['nombre']} pots x ${emb['contenanceKg']}kg @ ${emb['prixUnitaire']} FCFA",
                                                                style:
                                                                    const TextStyle(
                                                                        fontSize:
                                                                            13));
                                                          }),
                                                        const SizedBox(
                                                            height: 8),
                                                        // Affichage des ventes faites sur ce prélèvement
                                                        if (ventesSnap
                                                                .hasData &&
                                                            ventesSnap
                                                                .data!
                                                                .docs
                                                                .isNotEmpty)
                                                          Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .stretch,
                                                            children: [
                                                              const Divider(),
                                                              ...ventesSnap
                                                                  .data!.docs
                                                                  .map(
                                                                      (venteDoc) {
                                                                final vente = venteDoc
                                                                        .data()
                                                                    as Map<
                                                                        String,
                                                                        dynamic>;
                                                                final dateV = vente[
                                                                            'dateVente'] !=
                                                                        null
                                                                    ? (vente['dateVente']
                                                                            as Timestamp)
                                                                        .toDate()
                                                                    : null;
                                                                return ListTile(
                                                                  leading: const Icon(
                                                                      Icons
                                                                          .point_of_sale,
                                                                      color: Colors
                                                                          .blue),
                                                                  title: Text(
                                                                      "Vente du ${dateV != null ? "${dateV.day}/${dateV.month}/${dateV.year}" : "?"}"),
                                                                  subtitle:
                                                                      Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Text(
                                                                          "Client: ${vente['clientNom'] ?? vente['clientId'] ?? ''}"),
                                                                      Text(
                                                                          "Qté vendue: ${vente['quantiteTotale'] ?? '?'} kg"),
                                                                      Text(
                                                                          "Montant: ${vente['montantTotal'] ?? '?'} FCFA"),
                                                                      if (vente[
                                                                              'emballagesVendus'] !=
                                                                          null)
                                                                        ...List.generate(
                                                                            (vente['emballagesVendus'] as List).length,
                                                                            (k) {
                                                                          final emb =
                                                                              vente['emballagesVendus'][k];
                                                                          return Text(
                                                                              "- ${emb['type']}: ${emb['nombre']} pots",
                                                                              style: const TextStyle(fontSize: 13));
                                                                        }),
                                                                    ],
                                                                  ),
                                                                );
                                                              }).toList(),
                                                            ],
                                                          ),
                                                        // Résumé restant
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(top: 8),
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                  "Restant à vendre: ${quantiteRestante < 0 ? 0 : quantiteRestante.toStringAsFixed(2)} kg"),
                                                              Text(
                                                                  "Montant restant: ${montantRestant < 0 ? 0 : montantRestant.toStringAsFixed(0)} FCFA"),
                                                              ...potsRestantsParType
                                                                  .entries
                                                                  .map((e) => Text(
                                                                      "${e.key}: ${e.value < 0 ? 0 : e.value} pots restants",
                                                                      style: const TextStyle(
                                                                          fontSize:
                                                                              13))),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    // PAS de bouton "Vendre" ici (Magazinier!)
                                                  ),
                                                  // Boutons de reçus prélèvements (Général pour tout le conditionnement)
                                                  if (prelevSnap
                                                          .data!.docs.last ==
                                                      prDoc)
                                                    Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 9,
                                                          horizontal: 15),
                                                      child: Align(
                                                        alignment: Alignment
                                                            .centerRight,
                                                        child: PopupMenuButton<
                                                            String>(
                                                          icon: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: const [
                                                              Icon(Icons
                                                                  .download),
                                                              SizedBox(
                                                                  width: 6),
                                                              Text(
                                                                  "Télécharger reçu de prélèvements"),
                                                            ],
                                                          ),
                                                          itemBuilder:
                                                              (context) => [
                                                            PopupMenuItem(
                                                              value: "all",
                                                              child: const Text(
                                                                  "Tous les prélèvements"),
                                                            ),
                                                            PopupMenuItem(
                                                              value: "last",
                                                              child: const Text(
                                                                  "Dernier prélèvement"),
                                                            ),
                                                          ],
                                                          onSelected: (val) {
                                                            // TODO: Implémenter l'action pour chaque bouton
                                                            if (val == "all") {
                                                              // Télécharger tous les reçus de prélèvements
                                                            } else {
                                                              // Télécharger le dernier reçu de prélèvement
                                                            }
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      }).toList(),
                                    ],
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
      },
    );
  }
}

/// COMMERCIAL PAGE

class CommercialPage extends StatefulWidget {
  const CommercialPage({super.key});

  @override
  State<CommercialPage> createState() => _CommercialPageState();
}

class _CommercialPageState extends State<CommercialPage> {
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final userId = currentUser?.uid;

    if (userId == null) {
      return const Center(child: Text("Utilisateur non identifié !"));
    }

    // Ici, on affiche UNIQUEMENT les prélèvements attribués à ce commercial.
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('prelevements')
          .where('commercialId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Aucun prélèvement attribué."));
        }

        final prelevs = snapshot.data!.docs;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: prelevs.length,
          separatorBuilder: (c, i) => const SizedBox(height: 18),
          itemBuilder: (context, i) {
            final pr = prelevs[i].data() as Map<String, dynamic>;
            final prId = prelevs[i].id;
            final datePr = pr['datePrelevement'] != null
                ? (pr['datePrelevement'] as Timestamp).toDate()
                : null;

            // Pour récupérer des infos sur le lot d'origine (affichage plus complet)
            return FutureBuilder<DocumentSnapshot>(
              future: pr['lotConditionnementId'] != null
                  ? FirebaseFirestore.instance
                      .collection('conditionnement')
                      .doc(pr['lotConditionnementId'])
                      .get()
                  : Future.value(null),
              builder: (context, lotSnap) {
                String lotLabel = pr['lotConditionnementId'] ?? 'Lot inconnu';
                if (lotSnap.hasData && lotSnap.data?.data() != null) {
                  final lotData = lotSnap.data!.data() as Map<String, dynamic>;
                  lotLabel = lotData['lotOrigine'] ?? lotLabel;
                }

                // Calcul des quantités vendues/restantes à partir des ventes
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('ventes')
                      .doc(userId)
                      .collection('ventes_effectuees')
                      .where('prelevementId', isEqualTo: prId)
                      .snapshots(),
                  builder: (context, ventesSnap) {
                    double quantitePrelevee =
                        (pr['quantiteTotale'] ?? 0.0).toDouble();
                    double montantEstime =
                        (pr['prixTotalEstime'] ?? 0.0).toDouble();
                    double quantiteVendue = 0.0;
                    double montantVendu = 0.0;

                    Map<String, int> potsRestantsParType = {};
                    Map<String, int> potsInitials = {};

                    if (pr['emballages'] != null) {
                      for (var emb in pr['emballages']) {
                        potsRestantsParType[emb['type']] = emb['nombre'];
                        potsInitials[emb['type']] = emb['nombre'];
                      }
                    }

                    if (ventesSnap.hasData) {
                      for (final vDoc in ventesSnap.data!.docs) {
                        final vente = vDoc.data() as Map<String, dynamic>;
                        quantiteVendue +=
                            (vente['quantiteTotale'] ?? 0.0).toDouble();
                        montantVendu +=
                            (vente['montantTotal'] ?? 0.0).toDouble();
                        if (vente['emballagesVendus'] != null) {
                          for (var emb in vente['emballagesVendus']) {
                            final t = emb['type'];
                            potsRestantsParType[t] =
                                (potsRestantsParType[t] ?? 0) -
                                    ((emb['nombre'] ?? 0) as num).toInt();
                          }
                        }
                      }
                    }
                    final quantiteRestante = quantitePrelevee - quantiteVendue;
                    final montantRestant = montantEstime - montantVendu;

                    return Card(
                      color: Colors.orange[50],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ListTile(
                            leading: Icon(Icons.shopping_bag,
                                color: Colors.blue[700]),
                            title: Text(
                              "Prélèvement du ${datePr != null ? "${datePr.day}/${datePr.month}/${datePr.year}" : '?'}",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Lot: $lotLabel"),
                                Text(
                                    "Magazinier: ${pr['magazinierNom'] ?? ''}"),
                                Text(
                                    "Total prélevé: ${pr['quantiteTotale'] ?? '?'} kg"),
                                Text(
                                    "Montant estimé: ${pr['prixTotalEstime'] ?? '?'} FCFA"),
                                if (pr['emballages'] != null)
                                  ...List.generate(
                                      (pr['emballages'] as List).length, (j) {
                                    final emb = pr['emballages'][j];
                                    return Text(
                                      "- ${emb['type']}: ${emb['nombre']} pots x ${emb['contenanceKg']}kg @ ${emb['prixUnitaire']} FCFA",
                                      style: const TextStyle(fontSize: 13),
                                    );
                                  }),
                                const SizedBox(height: 8),
                                if (ventesSnap.hasData &&
                                    ventesSnap.data!.docs.isNotEmpty)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const Divider(),
                                      ...ventesSnap.data!.docs.map((venteDoc) {
                                        final vente = venteDoc.data()
                                            as Map<String, dynamic>;
                                        final dateV = vente['dateVente'] != null
                                            ? (vente['dateVente'] as Timestamp)
                                                .toDate()
                                            : null;
                                        return ListTile(
                                          leading: const Icon(
                                              Icons.point_of_sale,
                                              color: Colors.blue),
                                          title: Text(
                                              "Vente du ${dateV != null ? "${dateV.day}/${dateV.month}/${dateV.year}" : "?"}"),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  "Client: ${vente['clientNom'] ?? vente['clientId'] ?? ''}"),
                                              Text(
                                                  "Qté vendue: ${vente['quantiteTotale'] ?? '?'} kg"),
                                              Text(
                                                  "Montant: ${vente['montantTotal'] ?? '?'} FCFA"),
                                              if (vente['emballagesVendus'] !=
                                                  null)
                                                ...List.generate(
                                                  (vente['emballagesVendus']
                                                          as List)
                                                      .length,
                                                  (k) {
                                                    final emb = vente[
                                                        'emballagesVendus'][k];
                                                    return Text(
                                                      "- ${emb['type']}: ${emb['nombre']} pots",
                                                      style: const TextStyle(
                                                          fontSize: 13),
                                                    );
                                                  },
                                                ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ],
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          "Restant à vendre: ${quantiteRestante < 0 ? 0 : quantiteRestante.toStringAsFixed(2)} kg"),
                                      Text(
                                          "Montant restant: ${montantRestant < 0 ? 0 : montantRestant.toStringAsFixed(0)} FCFA"),
                                      ...potsRestantsParType.entries.map(
                                        (e) => Text(
                                          "${e.key}: ${e.value < 0 ? 0 : e.value} pots restants",
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            trailing: quantiteRestante > 0
                                ? ElevatedButton.icon(
                                    icon: const Icon(Icons.point_of_sale),
                                    label: const Text("Vendre"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[700],
                                    ),
                                    onPressed: () async {
                                      await Get.to(
                                          () => VenteFormPage(prelevement: {
                                                ...pr,
                                                "id": prId,
                                              }));
                                    },
                                  )
                                : null,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 9, horizontal: 15),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.assignment_turned_in),
                                  label: const Text(
                                      "Terminer et restituer le reste"),
                                  onPressed: () {
                                    // TODO: Implementer la restitution du reste
                                  },
                                ),
                                PopupMenuButton<String>(
                                  icon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.download),
                                      SizedBox(width: 6),
                                      Text("Télécharger reçu de ventes"),
                                    ],
                                  ),
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: "all",
                                      child: const Text(
                                          "Tous les reçus de ventes"),
                                    ),
                                    PopupMenuItem(
                                      value: "last",
                                      child:
                                          const Text("Dernier reçu de vente"),
                                    ),
                                  ],
                                  onSelected: (val) {
                                    if (val == "all" || val == "last") {
                                      Navigator.of(context)
                                          .push(MaterialPageRoute(
                                        builder: (ctx) => VenteReceiptsPage(
                                          commercialId: userId,
                                          prelevementId: prId,
                                          showLastOnly: val == "last",
                                        ),
                                      ));
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
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
}
