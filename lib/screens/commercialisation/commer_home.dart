import 'package:apisavana_gestion/screens/commercialisation/prelevement_form.dart';
import 'package:apisavana_gestion/screens/commercialisation/prelevement_magazinier.dart';
import 'package:apisavana_gestion/screens/commercialisation/vente_form.dart';
import 'package:apisavana_gestion/screens/commercialisation/vente_recu.dart';
import 'package:apisavana_gestion/screens/commercialisation/widgets/rapport.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart'; // Ajoute cette ligne
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

// Il te faut ces helpers/extension pour `.firstWhereOrNull` etc.
// Ajoute si tu ne les as pas :
extension IterableExt<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

class CommercialisationHomePage extends StatefulWidget {
  const CommercialisationHomePage({super.key});

  @override
  State<CommercialisationHomePage> createState() =>
      _CommercialisationHomePageState();
}

class _CommercialisationHomePageState extends State<CommercialisationHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<Tab> myTabs;

  String? _userRole;

  @override
  void initState() {
    super.initState();
    myTabs = [
      const Tab(icon: Icon(Icons.store), text: "Magazinier"),
      const Tab(icon: Icon(Icons.person), text: "Commercial(e)"),
      const Tab(icon: Icon(Icons.attach_money), text: "Caissier"),
      const Tab(
          icon: Icon(Icons.admin_panel_settings),
          text: "Gestionnaire Commercial"),
    ];
    _tabController = TabController(length: myTabs.length, vsync: this);
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userDoc = await FirebaseFirestore.instance
        .collection('utilisateurs')
        .doc(user.uid)
        .get();
    final data = userDoc.data() ?? {};
    setState(() {
      _userRole = data['role'];
    });
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
          CaissierPage(),
          GestionnaireCommercialPage(),
        ],
      ),
    );
  }
}

class MagazinierPage extends StatefulWidget {
  final VoidCallback? onPrelevement;
  const MagazinierPage({super.key, this.onPrelevement});

  @override
  State<MagazinierPage> createState() => _MagazinierPageState();
}

class _MagazinierPageState extends State<MagazinierPage> {
  String? userNom;
  String? userRole;
  String? typeMag;
  String? localiteMag;
  String? userId;

  @override
  void initState() {
    super.initState();
    _loadUserInfos();
  }

  Future<void> _loadUserInfos() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('utilisateurs')
          .doc(currentUser.uid)
          .get();
      final data = userDoc.data() ?? {};
      setState(() {
        userId = currentUser.uid;
        userNom = data['nom']?.toString();
        userRole = data['role']?.toString();
        final magField = data['magazinier'] as Map<String, dynamic>?;
        typeMag = magField?['type']?.toString();
        localiteMag = magField?['localite']?.toString();
      });
    }
  }

  Future<void> approuverRestitutionAutomatique({
    required String prelevementId,
    required Map<String, dynamic> prelevement,
    required List ventes,
  }) async {
    List emballages = prelevement['emballages'] ?? [];
    List<Map<String, dynamic>> potsRestants = [];
    double quantiteRestanteKg = 0;
    double montantRestant = 0;

    Map<String, int> potsVendus = {};
    for (var emb in emballages) {
      potsVendus[emb['type']] = 0;
    }
    for (var venteDoc in ventes) {
      final vente = venteDoc.data() as Map<String, dynamic>;
      if (vente['emballagesVendus'] != null) {
        for (final emb in vente['emballagesVendus']) {
          potsVendus[emb['type']] =
              (potsVendus[emb['type']] ?? 0) + (emb['nombre'] ?? 0) as int;
        }
      }
    }

    for (var emb in emballages) {
      int potsRest = (emb['nombre'] ?? 0) - (potsVendus[emb['type']] ?? 0);
      if (potsRest > 0) {
        potsRestants.add({
          ...emb,
          'nombre': potsRest,
        });
        quantiteRestanteKg += potsRest * (emb['contenanceKg'] ?? 0.0);
        montantRestant += potsRest * (emb['prixUnitaire'] ?? 0.0);
      }
    }

    await FirebaseFirestore.instance
        .collection('prelevements')
        .doc(prelevementId)
        .update({
      'magazinierApprobationRestitution': true,
      'magazinierApprobateurNom': userNom ?? '',
      'dateApprobationRestitution': FieldValue.serverTimestamp(),
      'emballagesRestitues': potsRestants,
      'quantiteRestituee': quantiteRestanteKg,
      'montantRestitue': montantRestant,
      'restitutionAutomatique': true,
    });
  }

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
        if (userSnap.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!userSnap.hasData || userSnap.data == null) {
          // Pas de données utilisateur
          return Center(child: Text("Utilisateur non trouvé"));
        }

        final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
        final nomUser = userData['nom'] as String?;
        final magField = userData['magazinier'] as Map<String, dynamic>?;
        final typeMag = magField?['type']?.toString()?.toLowerCase().trim();
        final userId = currentUser?.uid;

        // Autorisation stricte par rôle exact
        if (typeMag == 'simple') {
          return magasinierSimpleView(userId!, nomUser ?? "");
        } else if (typeMag == 'principale') {
          return magasinierPrincipalView();
        } else {
          // Tout autre type d'utilisateur : accès refusé
          return Center(
              child: Text(
                  "Accès refusé : vous n'êtes pas un magasinier autorisé."));
        }
      },
    );
  }

  // ----------- MAGASINIER SIMPLE VIEW -----------
  // Helper pour récupérer le nom du mag principal (à adapter selon ta structure user)
  Future<String> getNomMagPrincipal() async {
    // TODO: Ajoute la vraie logique de récupération, ici un exemple statique :
    return "MAGAZINIER PRINCIPAL";
  }

// Helper pour récupérer le nom de boutique du client à partir de son id (cache local simple)
  final Map<String, String> _clientNameCache = {};
  Future<String> getClientNomBoutique(String clientId) async {
    if (_clientNameCache.containsKey(clientId))
      return _clientNameCache[clientId]!;
    final snap = await FirebaseFirestore.instance
        .collection('clients')
        .doc(clientId)
        .get();
    final nom = (snap.data() ?? {})['nomBoutique'] ?? clientId;
    _clientNameCache[clientId] = nom;
    return nom;
  }

  // Helper pour récupérer le nom du magasinier principal
  Widget magasinierSimpleView(
    String userId,
    String nomUser, {
    VoidCallback? onPrelevement,
  }) {
    final ValueNotifier<Map<String, String?>> expandedCommercialSelectorByLot =
        ValueNotifier({});

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance.collection('conditionnement').snapshots(),
      builder: (context, lotsSnap) {
        if (!lotsSnap.hasData || lotsSnap.data!.docs.isEmpty) {
          return const Center(child: Text("Aucun lot reçu."));
        }
        final lots = lotsSnap.data!.docs;
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
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('prelevements')
                      .where('lotConditionnementId', isEqualTo: lotId)
                      .snapshots(),
                  builder: (context, allPrelevSnap) {
                    if (!allPrelevSnap.hasData) return const SizedBox.shrink();
                    final prelevements = allPrelevSnap.data!.docs;

                    // Prélèvements reçus par ce magasinier simple sur ce lot
                    final prelevementsRecus = prelevements.where((prDoc) {
                      final d = prDoc.data() as Map<String, dynamic>;
                      return d['typePrelevement'] == 'magasinier' &&
                          d['magasinierDestId'] == userId;
                    }).toList();
                    if (prelevementsRecus.isEmpty)
                      return const SizedBox.shrink();

                    // Stock reçu
                    double quantiteRecu = 0.0;
                    Map<String, int> potsRecusParType = {};
                    String prelevRecusDocId = '';
                    Map<String, dynamic> prelevRecusData = {};
                    for (final prDoc in prelevementsRecus) {
                      final d = prDoc.data() as Map<String, dynamic>;
                      quantiteRecu += (d['quantiteTotale'] ?? 0.0).toDouble();
                      if (d['emballages'] != null) {
                        for (var emb in d['emballages']) {
                          final t = emb['type'];
                          final n = (emb['nombre'] ?? 0) as int;
                          potsRecusParType[t] = (potsRecusParType[t] ?? 0) + n;
                        }
                      }
                      prelevRecusDocId = prDoc.id;
                      prelevRecusData = d;
                    }

                    // Prélèvements faits à des commerciaux
                    final prelevementsCommerciaux = prelevements.where((prDoc) {
                      final d = prDoc.data() as Map<String, dynamic>;
                      return d['typePrelevement'] == 'commercial' &&
                          d['magazinierId'] == userId;
                    }).toList();

                    double quantitePrelevee = 0.0;
                    Map<String, int> potsPrelevesParType = {};
                    for (final prDoc in prelevementsCommerciaux) {
                      final d = prDoc.data() as Map<String, dynamic>;
                      quantitePrelevee +=
                          (d['quantiteTotale'] ?? 0.0).toDouble();
                      if (d['emballages'] != null) {
                        for (var emb in d['emballages']) {
                          final t = emb['type'];
                          final n = (emb['nombre'] ?? 0) as int;
                          potsPrelevesParType[t] =
                              (potsPrelevesParType[t] ?? 0) + n;
                        }
                      }
                    }

                    // === CUMUL DES RESTES COMMERCIAUX VALIDÉS ===
                    Map<String, int> totalRestesParType = {};
                    double totalRestesKg = 0.0;
                    for (final prDoc in prelevementsCommerciaux) {
                      final d = prDoc.data() as Map<String, dynamic>;
                      if (d['magazinierApprobationRestitution'] == true &&
                          d['demandeRestitution'] == true &&
                          d['restesApresVenteCommercial'] != null) {
                        final restes = Map<String, dynamic>.from(
                            d['restesApresVenteCommercial']);
                        restes.forEach((k, v) {
                          totalRestesParType[k] =
                              (totalRestesParType[k] ?? 0) + (v as int);
                        });
                        if (d['emballages'] != null) {
                          for (var emb in d['emballages']) {
                            final type = emb['type'];
                            final contenance =
                                (emb['contenanceKg'] ?? 0.0).toDouble();
                            if (restes.containsKey(type)) {
                              totalRestesKg += (restes[type] ?? 0) * contenance;
                            }
                          }
                        }
                      }
                    }

                    // --- MAJ Firestore des champs restesApresVenteCommerciaux et restantApresVenteCommerciauxKg (doc mag simple) ---
                    bool needsUpdate = false;
                    Map<String, int> dbRestes = Map<String, int>.from(
                        prelevRecusData['restesApresVenteCommerciaux'] ?? {});
                    totalRestesParType.forEach((k, v) {
                      final current = dbRestes[k] ?? 0;
                      if (v != current) {
                        dbRestes[k] = v;
                        needsUpdate = true;
                      }
                    });
                    double dbRestesKg =
                        (prelevRecusData['restantApresVenteCommerciauxKg'] ??
                                0.0)
                            .toDouble();
                    if ((totalRestesKg - dbRestesKg).abs() > 0.01) {
                      dbRestesKg = totalRestesKg;
                      needsUpdate = true;
                    }
                    if (needsUpdate && prelevRecusDocId.isNotEmpty) {
                      FirebaseFirestore.instance
                          .collection('prelevements')
                          .doc(prelevRecusDocId)
                          .update({
                        'restesApresVenteCommerciaux': dbRestes,
                        'restantApresVenteCommerciauxKg': dbRestesKg,
                      });
                    }
                    final restesApresVentesCommerciaux = dbRestes;
                    final restesKgApresVentesCommerciaux = dbRestesKg;

                    // Quantité restante (inclut le cumul des restes)
                    double quantiteRestanteNormal =
                        quantiteRecu - quantitePrelevee;
                    double quantiteRestante =
                        quantiteRestanteNormal + restesKgApresVentesCommerciaux;

                    // Cumul des pots par type (ajoute aussi les restes commerciaux validés)
                    Map<String, int> potsRestantsParType = {};
                    for (final t in potsRecusParType.keys) {
                      final resteNormal = (potsRecusParType[t] ?? 0) -
                          (potsPrelevesParType[t] ?? 0);
                      final resteComm = restesApresVentesCommerciaux[t] ?? 0;
                      potsRestantsParType[t] = resteNormal + resteComm;
                    }
                    for (final t in restesApresVentesCommerciaux.keys) {
                      if (!potsRestantsParType.containsKey(t)) {
                        potsRestantsParType[t] =
                            restesApresVentesCommerciaux[t]!;
                      }
                    }

                    // Sélecteur commercial par lot
                    final commerciauxForLot = prelevementsCommerciaux
                        .map((prDoc) => {
                              "id": (prDoc.data() as Map<String, dynamic>)[
                                      'commercialId'] ??
                                  "",
                              "nom": (prDoc.data() as Map<String, dynamic>)[
                                      'commercialNom'] ??
                                  "",
                            })
                        .where((c) => c['id'].toString().isNotEmpty)
                        .toSet()
                        .toList();

                    if (!expandedCommercialSelectorByLot.value
                        .containsKey(lotId)) {
                      expandedCommercialSelectorByLot.value = {
                        ...expandedCommercialSelectorByLot.value,
                        lotId: null,
                      };
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
                            // HEADER avec bouton Prélever
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Lot: ${lot['lotOrigine'] ?? lotId}",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.scale,
                                              color: Colors.amber[700],
                                              size: 18),
                                          const SizedBox(width: 6),
                                          Text("Quantité reçue : ",
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600)),
                                          Text(
                                              "${quantiteRecu.toStringAsFixed(2)} kg",
                                              style: const TextStyle(
                                                  fontSize: 15)),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(Icons.add_box,
                                              color: Colors.blue, size: 18),
                                          const SizedBox(width: 6),
                                          Text("Restant : ",
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600)),
                                          Text(
                                              "${quantiteRestante < 0 ? 0 : quantiteRestante.toStringAsFixed(2)} kg",
                                              style: const TextStyle(
                                                  fontSize: 15,
                                                  color: Colors.blue)),
                                        ],
                                      ),
                                      if (potsRestantsParType.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Wrap(
                                            spacing: 12,
                                            children: potsRestantsParType.keys
                                                .map((t) {
                                              return Chip(
                                                label: Text(
                                                  "$t: ${potsRestantsParType[t]! < 0 ? 0 : potsRestantsParType[t]} / ${potsRecusParType[t] ?? potsRestantsParType[t]} pots",
                                                  style: const TextStyle(
                                                      fontSize: 13),
                                                ),
                                                backgroundColor:
                                                    Colors.amber[50],
                                                avatar: const Icon(
                                                    Icons.local_mall,
                                                    size: 18,
                                                    color: Colors.amber),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      if (restesApresVentesCommerciaux
                                          .isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 6),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.green[50],
                                              border: Border.all(
                                                  color: Colors.green[100]!),
                                              borderRadius:
                                                  BorderRadius.circular(9),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 7.0,
                                                      horizontal: 10),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(Icons.undo,
                                                          color:
                                                              Colors.green[700],
                                                          size: 20),
                                                      const SizedBox(width: 7),
                                                      Text(
                                                        "Restes cumulés des commerciaux :",
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors
                                                                .green[800]),
                                                      ),
                                                      const SizedBox(width: 7),
                                                      Text(
                                                        "${restesKgApresVentesCommerciaux.toStringAsFixed(2)} kg",
                                                        style: TextStyle(
                                                            color: Colors
                                                                .green[900],
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600),
                                                      ),
                                                    ],
                                                  ),
                                                  ...restesApresVentesCommerciaux
                                                      .entries
                                                      .map((e) => Text(
                                                            "${e.key}: ${e.value} pots",
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                    color: Colors
                                                                        .green),
                                                          )),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // RIGHT: BOUTON PRELEVER
                                if (quantiteRestante > 0)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(left: 10, top: 2),
                                    child: ElevatedButton.icon(
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
                                      onPressed: () async {
                                        final result = await Get.to(
                                          () => PrelevementFormPage(
                                            lotConditionnement: {
                                              ...lot,
                                              "id": lotId,
                                            },
                                          ),
                                        );
                                        if (result == true &&
                                            onPrelevement != null) {
                                          onPrelevement!();
                                        }
                                      },
                                    ),
                                  ),
                              ],
                            ),
                            // ----------- SELECTEUR COMMERCIAL DEROULEUR -----------
                            if (commerciauxForLot.isNotEmpty)
                              ValueListenableBuilder<Map<String, String?>>(
                                valueListenable:
                                    expandedCommercialSelectorByLot,
                                builder: (context, selections, _) {
                                  final expandedId = selections[lotId];
                                  return Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2),
                                        child: Row(
                                          children: [
                                            Icon(Icons.people,
                                                color: Colors.green, size: 19),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: DropdownButtonFormField<
                                                  String>(
                                                value: expandedId,
                                                hint: const Text(
                                                    "Afficher un prélèvement commercial..."),
                                                items: commerciauxForLot
                                                    .map((c) =>
                                                        DropdownMenuItem<
                                                            String>(
                                                          value:
                                                              c['id'] as String,
                                                          child: Text(c['nom']
                                                              as String),
                                                        ))
                                                    .toList(),
                                                onChanged: (val) {
                                                  expandedCommercialSelectorByLot
                                                      .value = {
                                                    lotId: expandedId == val
                                                        ? null
                                                        : val,
                                                  };
                                                },
                                                isExpanded: true,
                                                icon: expandedId != null
                                                    ? Icon(Icons.arrow_drop_up)
                                                    : Icon(
                                                        Icons.arrow_drop_down),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (expandedId != null)
                                        Builder(builder: (context) {
                                          final matching =
                                              prelevementsCommerciaux
                                                  .where(
                                                    (pr) =>
                                                        (pr.data() as Map<
                                                                String,
                                                                dynamic>)[
                                                            'commercialId'] ==
                                                        expandedId,
                                                  )
                                                  .toList();
                                          final selectedPrDoc =
                                              matching.isNotEmpty
                                                  ? matching.first
                                                  : null;

                                          if (selectedPrDoc != null) {
                                            // Affiche les détails commerciaux et le bouton de validation (intégré)
                                            return _buildCommercialDetailsSimple(
                                              context,
                                              selectedPrDoc,
                                              isMobile,
                                              nomMagasinier: nomUser,
                                              onPrelevement: onPrelevement,
                                            );
                                          }
                                          return const SizedBox();
                                        }),
                                    ],
                                  );
                                },
                              ),
                            // --- BOUTON RENDRE COMPTE ---
                            FutureBuilder<String>(
                              future: getNomMagPrincipal(),
                              builder: (context, principalSnap) {
                                bool tousRestitues = false;
                                if (prelevementsCommerciaux.isNotEmpty) {
                                  tousRestitues =
                                      prelevementsCommerciaux.every((prDoc) {
                                    final d =
                                        prDoc.data() as Map<String, dynamic>;
                                    return d['demandeRestitution'] == true &&
                                        d['magazinierApprobationRestitution'] ==
                                            true;
                                  });
                                }
                                bool demandeRestitutionEnCours =
                                    prelevRecusData[
                                            'demandeRestitutionMagasinier'] ==
                                        true;
                                bool restitutionValideePrincipal = prelevRecusData[
                                        'magasinierPrincipalApprobationRestitution'] ==
                                    true;

                                if (tousRestitues &&
                                    principalSnap.hasData &&
                                    !demandeRestitutionEnCours &&
                                    !restitutionValideePrincipal) {
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                        top: 14.0,
                                        left: 10,
                                        right: 10,
                                        bottom: 4),
                                    child: ElevatedButton.icon(
                                      icon: const Icon(
                                          Icons.assignment_turned_in),
                                      label: Text(
                                          'Rendre compte au "${principalSnap.data!}"'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue[700],
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(200, 45),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(13),
                                        ),
                                      ),
                                      onPressed: () async {
                                        final prelevRecusSnap =
                                            await FirebaseFirestore.instance
                                                .collection('prelevements')
                                                .where('lotConditionnementId',
                                                    isEqualTo: lotId)
                                                .where('typePrelevement',
                                                    isEqualTo: 'magasinier')
                                                .where('magasinierDestId',
                                                    isEqualTo: userId)
                                                .get();

                                        if (prelevRecusSnap.docs.isNotEmpty) {
                                          final docRef = prelevRecusSnap
                                              .docs.first.reference;
                                          await docRef.update({
                                            'demandeRestitutionMagasinier':
                                                true,
                                            'dateDemandeRestitutionMagasinier':
                                                FieldValue.serverTimestamp(),
                                          });
                                          Get.snackbar("Demande envoyée",
                                              "La demande de restitution a été transmise au magasinier principal.");
                                          if (onPrelevement != null)
                                            onPrelevement!();
                                        }
                                      },
                                    ),
                                  );
                                } else if (demandeRestitutionEnCours &&
                                    !restitutionValideePrincipal) {
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                        top: 14,
                                        left: 10,
                                        right: 10,
                                        bottom: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8, horizontal: 18),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[100],
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                      child: const Text(
                                        "En attente de validation du magasinier principal...",
                                        style: TextStyle(
                                            color: Colors.orange,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  );
                                } else if (restitutionValideePrincipal) {
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                        top: 14,
                                        left: 10,
                                        right: 10,
                                        bottom: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8, horizontal: 18),
                                      decoration: BoxDecoration(
                                        color: Colors.green[100],
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                      child: const Text(
                                        "Restitution validée par le magasinier principal",
                                        style: TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
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

// NO MORE: _buildValiderRestitutionCommercialButton

  Widget _buildCommercialDetailsSimple(
    BuildContext context,
    QueryDocumentSnapshot prDoc,
    bool isMobile, {
    required String nomMagasinier,
    VoidCallback? onPrelevement,
  }) {
    final d = prDoc.data() as Map<String, dynamic>;
    final datePr = d['datePrelevement'] != null
        ? (d['datePrelevement'] as Timestamp).toDate()
        : null;
    final prelevementId = prDoc.id;
    final commercialId = d['commercialId'];
    final demandeRestitution = d['demandeRestitution'] == true;
    final restitutionApprouvee = d['magazinierApprobationRestitution'] == true;

    return Card(
      color: Colors.orange[50],
      margin: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Infos principales du prélèvement ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_pin,
                              color: Colors.orange, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            "Commercial : ",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Flexible(
                            child: Text(
                              "${d['commercialNom'] ?? d['commercialId'] ?? ''}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepOrange),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              color: Colors.brown, size: 17),
                          const SizedBox(width: 4),
                          Text(
                            "Prélèvement du : ",
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            datePr != null
                                ? "${datePr.day}/${datePr.month}/${datePr.year}"
                                : '?',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.scale, color: Colors.teal, size: 18),
                          const SizedBox(width: 4),
                          Text("Quantité : ${d['quantiteTotale']} kg",
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.attach_money,
                              color: Colors.orange, size: 18),
                          const SizedBox(width: 4),
                          Text("Valeur : ${d['prixTotalEstime']} FCFA",
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10.0, top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Détail emballages :",
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.brown)),
                        ...((d['emballages'] ?? []) as List).map((emb) => Text(
                              "- ${emb['type']}: ${emb['nombre']} pots x ${emb['contenanceKg']}kg @ ${emb['prixUnitaire']} FCFA",
                              style: const TextStyle(fontSize: 12),
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // --- SOUS SECTION VENTES DU COMMERCIAL (responsive) ---
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('ventes')
                  .doc(commercialId)
                  .collection('ventes_effectuees')
                  .where('prelevementId', isEqualTo: prelevementId)
                  .snapshots(),
              builder: (context, ventesSnap) {
                if (!ventesSnap.hasData || ventesSnap.data!.docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 10, bottom: 8),
                    child: Text("Aucune vente enregistrée pour ce prélèvement.",
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
                if (d['emballages'] != null) {
                  for (var emb in d['emballages']) {
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
                      return Container(
                        constraints: BoxConstraints(
                          maxWidth: isMobile ? 320.0 : 390.0,
                          minWidth: isMobile ? 200.0 : 290.0,
                        ),
                        margin: const EdgeInsets.only(bottom: 14, right: 12),
                        padding: const EdgeInsets.symmetric(
                            vertical: 7, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border:
                              Border.all(color: badgeColor.withOpacity(0.13)),
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
                                Flexible(
                                  child: Text(
                                    dateVente != null
                                        ? "${dateVente.day}/${dateVente.month}/${dateVente.year}"
                                        : "?",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (clientNomBoutique != '') ...[
                                  const SizedBox(width: 6),
                                  Icon(Icons.store,
                                      size: 15, color: Colors.purple[200]),
                                  Flexible(
                                    child: Text(
                                      "Client : $clientNomBoutique",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Row(
                              children: [
                                Icon(Icons.scale, size: 16, color: Colors.teal),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    "$quantite kg",
                                    style: const TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(Icons.attach_money,
                                    size: 16, color: Colors.orange),
                                Flexible(
                                  child: Text(
                                    " $montantTotal FCFA",
                                    style: const TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 2, bottom: 2),
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
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
                            ),
                            ...embVendus.map<Widget>((emb) => Wrap(
                                  children: [
                                    Text(
                                      "- ${emb['type']}: ${emb['nombre']} pots x ${emb['contenanceKg']}kg @ ${emb['prixUnitaire']} FCFA",
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.black87),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                )),
                          ],
                        ),
                      );
                    },
                  );
                }

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
                          height: 220,
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
                                    width: 270,
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
                                            .map<Widget>(
                                                (v) => buildVenteTile(v))
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
                      ],
                    ),
                  );
                }
                // Desktop
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
                                        .map<Widget>((v) => buildVenteTile(v))
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
                    ],
                  ),
                );
              },
            ),
            // --- SECTION RESTITUTION et VALIDATION ---
            Padding(
              padding:
                  const EdgeInsets.only(left: 10, right: 8, bottom: 8, top: 4),
              child: Row(
                children: [
                  if (demandeRestitution && !restitutionApprouvee) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: Colors.orange[200],
                          borderRadius: BorderRadius.circular(10)),
                      child: const Text(
                        "En attente de validation de la restitution...",
                        style: TextStyle(
                            color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.verified),
                      label: Text(
                          "Valider la restitution de ${d['commercialNom'] ?? d['commercialId']}"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        // 1. Récupère toutes les ventes pour ce commercial/prélèvement
                        final ventesSnap = await FirebaseFirestore.instance
                            .collection('ventes')
                            .doc(commercialId)
                            .collection('ventes_effectuees')
                            .where('prelevementId', isEqualTo: prelevementId)
                            .get();
                        final ventes =
                            ventesSnap.docs.map((v) => v.data()).toList();

                        // 2. Calcul des pots vendus par type
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

                        // 3. Calcul des restes par type
                        Map<String, int> restesParType = {};
                        double restesKg = 0.0;
                        if (d['emballages'] != null) {
                          for (var emb in d['emballages']) {
                            final type = emb['type'];
                            final nInit = (emb['nombre'] ?? 0) as int;
                            final vendu = potsVendues[type] ?? 0;
                            final reste = nInit - vendu;
                            restesParType[type] = reste;
                            final contenance =
                                (emb['contenanceKg'] ?? 0.0).toDouble();
                            restesKg += reste * contenance;
                          }
                        }

                        await FirebaseFirestore.instance
                            .collection('prelevements')
                            .doc(prDoc.id)
                            .update({
                          'magazinierApprobationRestitution': true,
                          'magazinierApprobateurNom': nomMagasinier,
                          'dateApprobationRestitution':
                              FieldValue.serverTimestamp(),
                          'restesApresVenteCommercial': restesParType,
                          'restantApresVenteCommercialKg': restesKg,
                        });
                        if (onPrelevement != null) onPrelevement();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                "Restitution du commercial validée avec succès !"),
                            backgroundColor: Colors.green[700],
                          ),
                        );
                      },
                    ),
                  ],
                  if (restitutionApprouvee)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: Colors.green[200],
                          borderRadius: BorderRadius.circular(10)),
                      child: const Text(
                        "Restitution validée",
                        style: TextStyle(
                            color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget magasinierPrincipalView({VoidCallback? onPrelevement}) {
    final ValueNotifier<Map<String, dynamic>> expandedSelectorByLot =
        ValueNotifier({});
    final ValueNotifier<Map<String, String?>> expandedCommercialByMagSimple =
        ValueNotifier({});

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance.collection('conditionnement').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Aucun produit conditionné."));
        }

        final lots = snapshot.data!.docs;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 700;
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: lots.length,
              separatorBuilder: (c, i) => const SizedBox(height: 18),
              itemBuilder: (context, i) {
                final lotDoc = lots[i];
                final lot = lotDoc.data() as Map<String, dynamic>;
                final lotId = lotDoc.id;

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

                    List<QueryDocumentSnapshot> prelevementsMagasiniersSimples =
                        [];
                    List<QueryDocumentSnapshot> prelevementsCommerciauxDirects =
                        [];
                    Map<String, List<QueryDocumentSnapshot>>
                        prelevementsCommerciauxByMagSimple = {};

                    // NEW : Pour cumul des restes mag simple validés (pour affichage et calcul)
                    Map<String, int> restesCumulesParType = {};
                    double restesCumulesKg = 0.0;

                    if (allPrelevSnap.hasData) {
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

                        // -- Prélèvements vers magasinier simple (parent)
                        if ((prData['magasinierDestId'] ?? '')
                                .toString()
                                .isNotEmpty &&
                            prData['typePrelevement'] == 'magasinier') {
                          prelevementsMagasiniersSimples.add(pr);
                        }

                        // -- Prélèvements à des commerciaux faits par mag principal (direct, parent)
                        if (((prData['magasinierDestId'] == null ||
                                (prData['magasinierDestId'] ?? '')
                                    .toString()
                                    .isEmpty) &&
                            (prData['typePrelevement'] == 'commercial') &&
                            ((prData['magazinierId'] == null ||
                                (prData['magazinierId'] ?? '')
                                    .toString()
                                    .isEmpty)))) {
                          prelevementsCommerciauxDirects.add(pr);
                        }

                        // -- Prélèvements à des commerciaux faits par mag simple (enfant)
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

                        // -- CUMUL RESTES MAG SIMPLE (déjà validés et restitués)
                        if (prData['typePrelevement'] == 'magasinier' &&
                            prData['magasinierPrincipalApprobationRestitution'] ==
                                true &&
                            prData['restesApresVenteCommerciaux'] != null) {
                          final restesMap = Map<String, dynamic>.from(
                              prData['restesApresVenteCommerciaux']);
                          // On cumule tous les types
                          restesMap.forEach((k, v) {
                            restesCumulesParType[k] =
                                (restesCumulesParType[k] ?? 0) + (v as int);
                          });
                          // Affichage du total kg
                          if (prData['emballages'] != null) {
                            for (var emb in prData['emballages']) {
                              final type = emb['type'];
                              final contenance =
                                  (emb['contenanceKg'] ?? 0.0).toDouble();
                              if (restesMap.containsKey(type)) {
                                restesCumulesKg +=
                                    (restesMap[type] ?? 0) * contenance;
                              }
                            }
                          }
                        }
                      }
                    }

                    // -- Pour l'affichage et le calcul du "Restant", on ajoute les restes cumules
                    // (ne touche PAS à la quantité conditionnée ni aux initials)
                    double quantiteRestanteNormal =
                        quantiteConditionnee - quantitePrelevee;
                    double quantiteRestante =
                        quantiteRestanteNormal + restesCumulesKg;

                    // -- Pour l'affichage du nombre de pots restants (par type), on ajoute les restes cumulés
                    Map<String, int> potsRestantsAvecRestes =
                        Map.from(potsRestantsParType);
                    restesCumulesParType.forEach((k, v) {
                      potsRestantsAvecRestes[k] =
                          (potsRestantsAvecRestes[k] ?? 0) + v;
                    });

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

                    final commerciauxForLot = prelevementsCommerciauxDirects
                        .map((prDoc) => {
                              "id": (prDoc.data() as Map<String, dynamic>)[
                                      'commercialId'] ??
                                  "",
                              "nom": (prDoc.data() as Map<String, dynamic>)[
                                      'commercialNom'] ??
                                  "",
                            })
                        .where((c) => c['id'].toString().isNotEmpty)
                        .toSet()
                        .toList();

                    if (!expandedSelectorByLot.value.containsKey(lotId)) {
                      expandedSelectorByLot.value = {
                        ...expandedSelectorByLot.value,
                        lotId: null,
                      };
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
                                        "Restant: ${quantiteRestante < 0 ? 0 : quantiteRestante.toStringAsFixed(2)} kg",
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
                                          style: const TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  if (potsRestantsAvecRestes.isNotEmpty)
                                    ...potsRestantsAvecRestes.entries
                                        .map((e) => Row(
                                              children: [
                                                Icon(Icons.local_mall,
                                                    color: Colors.amber,
                                                    size: 16),
                                                const SizedBox(width: 6),
                                                Text(
                                                  "${e.key}: ${e.value < 0 ? 0 : e.value} pots"
                                                  " (${potsInitials[e.key] ?? 0} init.)",
                                                  style: const TextStyle(
                                                      fontSize: 13),
                                                ),
                                              ],
                                            )),
                                  // Affichage des restes cumulés (bandeau vert)
                                  if (restesCumulesParType.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          top: 10, bottom: 8),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.green[50],
                                          border: Border.all(
                                              color: Colors.green[100]!),
                                          borderRadius:
                                              BorderRadius.circular(9),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12.0, horizontal: 14),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.undo,
                                                      color: Colors.green[700],
                                                      size: 20),
                                                  const SizedBox(width: 7),
                                                  Text(
                                                    "Restes cumulés restitués : ",
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            Colors.green[800]),
                                                  ),
                                                  const SizedBox(width: 7),
                                                  Text(
                                                    "${restesCumulesKg.toStringAsFixed(2)} kg",
                                                    style: TextStyle(
                                                        color:
                                                            Colors.green[900],
                                                        fontWeight:
                                                            FontWeight.w600),
                                                  ),
                                                ],
                                              ),
                                              ...restesCumulesParType.entries
                                                  .map((e) => Text(
                                                        "${e.key}: ${e.value} pots",
                                                        style: const TextStyle(
                                                            fontSize: 13,
                                                            color:
                                                                Colors.green),
                                                      )),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: (quantiteRestante > 0)
                                  ? ElevatedButton.icon(
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
                                              onPrelevement != null)
                                            onPrelevement!();
                                          (context as Element).markNeedsBuild();
                                        } else if (res == 'magasinier') {
                                          final result = await Get.to(() =>
                                              PrelevementMagasinierFormPage(
                                                  lotConditionnement: {
                                                    ...lot,
                                                    "id": lotId
                                                  }));
                                          if (result == true &&
                                              onPrelevement != null)
                                            onPrelevement!();
                                          (context as Element).markNeedsBuild();
                                        }
                                      },
                                    )
                                  : null,
                            ),
                            ValueListenableBuilder<Map<String, dynamic>>(
                              valueListenable: expandedSelectorByLot,
                              builder: (context, selections, _) {
                                final expanded = selections[lotId];
                                final expandedType =
                                    expanded is Map ? expanded['type'] : null;
                                final expandedId =
                                    expanded is Map ? expanded['id'] : null;

                                return Column(
                                  children: [
                                    if (magSimplesForLot.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2),
                                        child: Row(
                                          children: [
                                            Icon(Icons.store,
                                                color: Colors.brown, size: 19),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: DropdownButtonFormField<
                                                  String>(
                                                value:
                                                    expandedType == 'magasinier'
                                                        ? expandedId as String?
                                                        : null,
                                                hint: const Text(
                                                    "Afficher un magasinier simple..."),
                                                items: magSimplesForLot
                                                    .map((m) =>
                                                        DropdownMenuItem<
                                                            String>(
                                                          value:
                                                              m['id'] as String,
                                                          child: Text(m['nom']
                                                              as String),
                                                        ))
                                                    .toList(),
                                                onChanged: (val) {
                                                  expandedSelectorByLot.value =
                                                      {
                                                    lotId: expandedType ==
                                                                'magasinier' &&
                                                            expandedId == val
                                                        ? null
                                                        : {
                                                            'type':
                                                                'magasinier',
                                                            'id': val
                                                          }
                                                  };
                                                },
                                                isExpanded: true,
                                                icon: expandedType ==
                                                        'magasinier'
                                                    ? Icon(Icons.arrow_drop_up)
                                                    : Icon(
                                                        Icons.arrow_drop_down),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (commerciauxForLot.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2),
                                        child: Row(
                                          children: [
                                            Icon(Icons.people,
                                                color: Colors.green, size: 19),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: DropdownButtonFormField<
                                                  String>(
                                                value:
                                                    expandedType == 'commercial'
                                                        ? expandedId as String?
                                                        : null,
                                                hint: const Text(
                                                    "Afficher un prélèvement commercial..."),
                                                items: commerciauxForLot
                                                    .map((c) =>
                                                        DropdownMenuItem<
                                                            String>(
                                                          value:
                                                              c['id'] as String,
                                                          child: Text(c['nom']
                                                              as String),
                                                        ))
                                                    .toList(),
                                                onChanged: (val) {
                                                  expandedSelectorByLot.value =
                                                      {
                                                    lotId: expandedType ==
                                                                'commercial' &&
                                                            expandedId == val
                                                        ? null
                                                        : {
                                                            'type':
                                                                'commercial',
                                                            'id': val
                                                          }
                                                  };
                                                },
                                                isExpanded: true,
                                                icon: expandedType ==
                                                        'commercial'
                                                    ? Icon(Icons.arrow_drop_up)
                                                    : Icon(
                                                        Icons.arrow_drop_down),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (expandedType == 'magasinier' &&
                                        expandedId != null)
                                      Builder(builder: (context) {
                                        final selectedPrDoc =
                                            prelevementsMagasiniersSimples
                                                .firstWhereOrNull(
                                          (pr) =>
                                              (pr.data()
                                                      as Map<String, dynamic>)[
                                                  'magasinierDestId'] ==
                                              expandedId,
                                        );
                                        if (selectedPrDoc != null) {
                                          final magSimpleId =
                                              expandedId as String;
                                          final sousPrelevs =
                                              prelevementsCommerciauxByMagSimple[
                                                      magSimpleId] ??
                                                  [];
                                          final commerciauxOfMagSimple =
                                              sousPrelevs
                                                  .map((prDoc) => {
                                                        "id": (prDoc.data()
                                                                    as Map<
                                                                        String,
                                                                        dynamic>)[
                                                                'commercialId'] ??
                                                            "",
                                                        "nom": (prDoc.data()
                                                                    as Map<
                                                                        String,
                                                                        dynamic>)[
                                                                'commercialNom'] ??
                                                            "",
                                                      })
                                                  .where((c) => c['id']
                                                      .toString()
                                                      .isNotEmpty)
                                                  .toSet()
                                                  .toList();
                                          final magKey = "$lotId-$magSimpleId";
                                          if (!expandedCommercialByMagSimple
                                              .value
                                              .containsKey(magKey)) {
                                            expandedCommercialByMagSimple
                                                .value = {
                                              ...expandedCommercialByMagSimple
                                                  .value,
                                              magKey: null,
                                            };
                                          }
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              _buildMagasinierSimpleDetails(
                                                context,
                                                selectedPrDoc,
                                                sousPrelevs,
                                                lot,
                                                lotId,
                                                isMobile,
                                                bottomExtrasBuilder: (
                                                  demandeRestitutionMagasinier,
                                                  restitutionValideePrincipal,
                                                  nomMagPrincipal,
                                                  prData,
                                                ) {
                                                  // Boutons et rapport EN BAS UNIQUEMENT
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 18.0),
                                                    child: Row(
                                                      children: [
                                                        if (demandeRestitutionMagasinier &&
                                                            !restitutionValideePrincipal)
                                                          Expanded(
                                                            child:
                                                                ElevatedButton
                                                                    .icon(
                                                              icon: const Icon(
                                                                  Icons
                                                                      .verified),
                                                              label: const Text(
                                                                  "Valider retour de ce magasinier simple"),
                                                              style:
                                                                  ElevatedButton
                                                                      .styleFrom(
                                                                backgroundColor:
                                                                    Colors.green[
                                                                        700],
                                                                foregroundColor:
                                                                    Colors
                                                                        .white,
                                                                minimumSize: Size(
                                                                    isMobile
                                                                        ? 130
                                                                        : 200,
                                                                    40),
                                                                shape: RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            10)),
                                                              ),
                                                              onPressed:
                                                                  () async {
                                                                await FirebaseFirestore
                                                                    .instance
                                                                    .collection(
                                                                        'prelevements')
                                                                    .doc(
                                                                        selectedPrDoc
                                                                            .id)
                                                                    .update({
                                                                  'magasinierPrincipalApprobationRestitution':
                                                                      true,
                                                                  'magasinierPrincipalApprobateurNom':
                                                                      "NOM_MAG_PRINCIPAL", // <-- Remplacer dynamiquement
                                                                  'dateApprobationRestitutionMagasinier':
                                                                      FieldValue
                                                                          .serverTimestamp(),
                                                                });
                                                                Get.snackbar(
                                                                    "Succès",
                                                                    "Retour validé !");
                                                                (context
                                                                        as Element)
                                                                    .markNeedsBuild();
                                                              },
                                                            ),
                                                          ),
                                                        if (restitutionValideePrincipal)
                                                          Expanded(
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          10,
                                                                      vertical:
                                                                          7),
                                                              decoration: BoxDecoration(
                                                                  color: Colors
                                                                          .green[
                                                                      200],
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              16)),
                                                              child: Center(
                                                                child: Text(
                                                                  "Restitution validée par le principal"
                                                                  "${nomMagPrincipal != null && nomMagPrincipal.isNotEmpty ? " : $nomMagPrincipal" : ""}",
                                                                  style: const TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color: Colors
                                                                          .green),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        const SizedBox(
                                                            width: 10),
                                                        // BOUTON RAPPORT
                                                        Expanded(
                                                          child: demandeRestitutionMagasinier
                                                              ? TelechargerRapportBouton(
                                                                  prelevement:
                                                                      prData,
                                                                  lot: {
                                                                    ...lot,
                                                                    'id': lotId
                                                                  },
                                                                )
                                                              : AbsorbPointer(
                                                                  absorbing:
                                                                      true,
                                                                  child:
                                                                      Opacity(
                                                                    opacity:
                                                                        0.5,
                                                                    child:
                                                                        TelechargerRapportBouton(
                                                                      prelevement:
                                                                          prData,
                                                                      lot: {
                                                                        ...lot,
                                                                        'id':
                                                                            lotId
                                                                      },
                                                                    ),
                                                                  ),
                                                                ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                              SizedBox(height: 10),
                                              if (commerciauxOfMagSimple
                                                  .isNotEmpty)
                                                ValueListenableBuilder<
                                                    Map<String, String?>>(
                                                  valueListenable:
                                                      expandedCommercialByMagSimple,
                                                  builder: (context,
                                                      comSelections, _) {
                                                    final expandedCommercialId =
                                                        comSelections[magKey];
                                                    return Column(
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical: 2),
                                                          child: Row(
                                                            children: [
                                                              Icon(Icons.person,
                                                                  color: Colors
                                                                      .blue,
                                                                  size: 19),
                                                              const SizedBox(
                                                                  width: 4),
                                                              Expanded(
                                                                child:
                                                                    DropdownButtonFormField<
                                                                        String>(
                                                                  value:
                                                                      expandedCommercialId,
                                                                  hint: const Text(
                                                                      "Afficher un commercial..."),
                                                                  items: commerciauxOfMagSimple
                                                                      .map((c) => DropdownMenuItem<String>(
                                                                            value:
                                                                                c['id'] as String,
                                                                            child:
                                                                                Text(c['nom'] as String),
                                                                          ))
                                                                      .toList(),
                                                                  onChanged:
                                                                      (val) {
                                                                    expandedCommercialByMagSimple
                                                                        .value = {
                                                                      ...expandedCommercialByMagSimple
                                                                          .value,
                                                                      magKey: expandedCommercialId ==
                                                                              val
                                                                          ? null
                                                                          : val,
                                                                    };
                                                                  },
                                                                  isExpanded:
                                                                      true,
                                                                  icon: expandedCommercialId !=
                                                                          null
                                                                      ? Icon(Icons
                                                                          .arrow_drop_up)
                                                                      : Icon(Icons
                                                                          .arrow_drop_down),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        if (expandedCommercialId !=
                                                            null)
                                                          Builder(builder:
                                                              (context) {
                                                            final subPrDoc =
                                                                sousPrelevs
                                                                    .firstWhereOrNull(
                                                              (pr) =>
                                                                  (pr.data() as Map<
                                                                          String,
                                                                          dynamic>)[
                                                                      'commercialId'] ==
                                                                  expandedCommercialId,
                                                            );
                                                            if (subPrDoc !=
                                                                null) {
                                                              return _buildSousPrelevementCommercialWithVentes(
                                                                  context,
                                                                  subPrDoc,
                                                                  isMobile);
                                                            }
                                                            return const SizedBox();
                                                          }),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              SizedBox(height: 10),
                                            ],
                                          );
                                        }
                                        return const SizedBox();
                                      }),
                                    if (expandedType == 'commercial' &&
                                        expandedId != null)
                                      Builder(builder: (context) {
                                        final selectedPrDoc =
                                            prelevementsCommerciauxDirects
                                                .firstWhereOrNull(
                                          (pr) =>
                                              (pr.data() as Map<String,
                                                  dynamic>)['commercialId'] ==
                                              expandedId,
                                        );
                                        if (selectedPrDoc != null) {
                                          return _buildCommercialDirectDetailsWithVentes(
                                            context,
                                            selectedPrDoc,
                                            lot,
                                            lotId,
                                            isMobile,
                                          );
                                        }
                                        return const SizedBox();
                                      }),
                                  ],
                                );
                              },
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

// --- Détail magasinier simple : résumé (sans les commerciaux enfants) ---
  Widget _buildMagasinierSimpleDetails(
      BuildContext context,
      QueryDocumentSnapshot prDoc,
      List<QueryDocumentSnapshot> sousPrelevs,
      Map<String, dynamic> lot,
      String lotId,
      bool isMobile,
      {Widget Function(bool, bool, String?, Map<String, dynamic>)?
          bottomExtrasBuilder}) {
    final prData = prDoc.data() as Map<String, dynamic>;
    final datePr = prData['datePrelevement'] != null
        ? (prData['datePrelevement'] as Timestamp).toDate()
        : null;

    // ---- CALCUL RESTES CUMULES ---
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
                ...List.generate((prData['emballages'] as List).length, (j) {
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
                              Text("${restesKgTotal.toStringAsFixed(2)} kg",
                                  style: TextStyle(
                                      color: Colors.green[900],
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                          ...restesCumulCommerciaux.entries.map((e) => Text(
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
        if (bottomExtrasBuilder != null) const SizedBox(height: 14),
        // Les éléments en bas de la carte (boutons) ici !
        if (bottomExtrasBuilder != null)
          bottomExtrasBuilder(
            demandeRestitutionMagasinier,
            restitutionValideePrincipal,
            nomMagPrincipal,
            prData,
          ),
      ],
    );
  }

// --- Détail commercial direct (mag principal -> commercial) AVEC VENTES PAR TYPE ---
  Widget _buildCommercialDirectDetailsWithVentes(
    BuildContext context,
    QueryDocumentSnapshot prDoc,
    Map<String, dynamic> lot,
    String lotId,
    bool isMobile,
  ) {
    final prData = prDoc.data() as Map<String, dynamic>;
    final datePr = prData['datePrelevement'] != null
        ? (prData['datePrelevement'] as Timestamp).toDate()
        : null;
    final String commercialId = prData['commercialId'] ?? "";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Card(
          color: Colors.green[50],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  leading: Icon(Icons.person, color: Colors.green[700]),
                  title: Text(
                    "Prélèvement commercial direct du ${datePr != null ? "${datePr.day}/${datePr.month}/${datePr.year}" : '?'}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          "Commercial: ${prData['commercialNom'] ?? prData['commercialId'] ?? ''}"),
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
                    ],
                  ),
                ),
                _buildDetailVentesCommercial(
                  context: context,
                  commercialId: commercialId,
                  prelevementId: prDoc.id,
                  isMobile: isMobile,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 18.0),
                  child: TelechargerRapportBouton(
                    prelevement: prData,
                    lot: {...lot, 'id': lotId},
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

// --- Détail ventes pour un commercial/prélèvement donné ---
  Widget _buildDetailVentesCommercial({
    required BuildContext context,
    required String commercialId,
    required String prelevementId,
    required bool isMobile,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ventes')
          .doc(commercialId)
          .collection('ventes_effectuees')
          .where('prelevementId', isEqualTo: prelevementId)
          .snapshots(),
      builder: (context, ventesSnap) {
        if (!ventesSnap.hasData || ventesSnap.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(left: 8, top: 7),
            child: Text("Aucune vente pour ce prélèvement.",
                style: TextStyle(
                    fontStyle: FontStyle.italic, color: Colors.grey[700])),
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

        Widget buildVenteTile(Map<String, dynamic> v, bool isMobile) {
          final dateVente = v['dateVente'] != null
              ? (v['dateVente'] as Timestamp).toDate()
              : null;
          final clientNomBoutique = v['clientNom'] ?? v['clientId'] ?? '';
          final quantite = (v['quantiteTotale'] ?? 0).toString();
          final montantTotal = v['montantTotal'] ?? v['prixTotal'] ?? 0;
          final montantPaye = v['montantPaye'] ?? 0;
          final montantRestant = v['montantRestant'] ?? 0;
          final typeVente = v['typeVente'] ?? '';
          final embVendus = v['emballagesVendus'] ?? v['emballages'] ?? [];

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

          return Container(
            constraints: BoxConstraints(
              maxWidth: isMobile ? 320.0 : 390.0,
              minWidth: isMobile ? 200.0 : 290.0,
            ),
            margin: const EdgeInsets.only(bottom: 14, right: 12),
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: badgeColor.withOpacity(0.13)),
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
                    Flexible(
                      child: Text(
                        dateVente != null
                            ? "${dateVente.day}/${dateVente.month}/${dateVente.year}"
                            : "?",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (clientNomBoutique != '') ...[
                      const SizedBox(width: 6),
                      Icon(Icons.store, size: 15, color: Colors.purple[200]),
                      Flexible(
                        child: Text(
                          "Client : $clientNomBoutique",
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.scale, size: 16, color: Colors.teal),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        "$quantite kg",
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.attach_money, size: 16, color: Colors.orange),
                    Flexible(
                      child: Text(
                        " $montantTotal FCFA",
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 2),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
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
                ),
                ...embVendus.map<Widget>((emb) => Wrap(
                      children: [
                        Text(
                          "- ${emb['type']}: ${emb['nombre']} pots x ${emb['contenanceKg']}kg @ ${emb['prixUnitaire']} FCFA",
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black87),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    )),
              ],
            ),
          );
        }

        if (isMobile) {
          return Padding(
            padding: const EdgeInsets.only(left: 2, right: 2, bottom: 8),
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
                  height: 250,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final type in ["Comptant", "Crédit", "Recouvrement"])
                        if (ventesParType[type]?.isNotEmpty ?? false)
                          Container(
                            width: 280,
                            margin: const EdgeInsets.only(right: 18),
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
                                    .map<Widget>((vente) =>
                                        buildVenteTile(vente, isMobile))
                                    .toList()
                              ],
                            ),
                          )
                    ],
                  ),
                ),
              ],
            ),
          );
        }
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
                  for (final type in ["Comptant", "Crédit", "Recouvrement"])
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
                                .map<Widget>(
                                    (vente) => buildVenteTile(vente, isMobile))
                                .toList()
                          ],
                        ),
                      )
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSousPrelevementCommercialWithVentes(
      BuildContext context, QueryDocumentSnapshot subPrDoc, bool isMobile) {
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
            _buildDetailVentesCommercial(
                context: context,
                commercialId: subData['commercialId'],
                prelevementId: subPrDoc.id,
                isMobile: isMobile),
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

                    List<QueryDocumentSnapshot> ventesDocs =
                        ventesSnap.data?.docs.toList() ?? [];
                    List venteComptant = [];
                    List venteCredit = [];
                    List venteRecouvrement = [];
                    for (var vd in ventesDocs) {
                      final v = vd.data() as Map<String, dynamic>;
                      if (v['typeVente'] == "Comptant") {
                        venteComptant.add(vd);
                      } else if (v['typeVente'] == "Crédit") {
                        venteCredit.add(vd);
                      } else if (v['typeVente'] == "Recouvrement") {
                        venteRecouvrement.add(vd);
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

                    final bool demandeTerminee =
                        pr['demandeRestitution'] == true;
                    final bool approuveParMag =
                        pr['magazinierApprobationRestitution'] == true;
                    final String? nomMagApprobateur =
                        pr['magazinierApprobateurNom'];

                    // --- Nouvelle logique : vérifie la validation du caissier dynamiquement
                    Widget buildValidCaissierWidget() {
                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('transactions_caissier')
                            .where('prelevementId', isEqualTo: prId)
                            .snapshots(),
                        builder: (context, txnSnap) {
                          bool toutValide = false;
                          if (txnSnap.hasData &&
                              txnSnap.data!.docs.isNotEmpty) {
                            toutValide = txnSnap.data!.docs.every((doc) =>
                                doc['transfertValideParCaissier'] == true);
                          }
                          if (approuveParMag && !toutValide) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                  color: Colors.orange[200],
                                  borderRadius: BorderRadius.circular(16)),
                              child: const Text(
                                  "En attente de validation du caissier !!",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange)),
                            );
                          } else if (approuveParMag && toutValide) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                  color: Colors.green[200],
                                  borderRadius: BorderRadius.circular(16)),
                              child: const Text(
                                "Validé par le caissier !",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      );
                    }

                    return Card(
                      color: Colors.orange[50],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.shopping_bag,
                                  color: Colors.blue[700]),
                              title: Text(
                                "Prélèvement du ${datePr != null ? "${datePr.day}/${datePr.month}/${datePr.year}" : '?'}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
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
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (venteComptant.isNotEmpty)
                                            _buildVenteSection(
                                              title: "VENTES COMPTANT",
                                              color: Colors.green,
                                              ventes: venteComptant,
                                              icon: Icons.point_of_sale,
                                              iconColor: Colors.green,
                                            ),
                                          if (venteCredit.isNotEmpty)
                                            _buildVenteSection(
                                              title: "VENTES CRÉDIT",
                                              color: Colors.orange,
                                              ventes: venteCredit,
                                              icon: Icons.point_of_sale,
                                              iconColor: Colors.orange,
                                            ),
                                          if (venteRecouvrement.isNotEmpty)
                                            _buildVenteSection(
                                              title: "VENTES RECOUVREMENT",
                                              color: Colors.blue,
                                              ventes: venteRecouvrement,
                                              icon: Icons.point_of_sale,
                                              iconColor: Colors.blue,
                                            ),
                                        ]
                                            .map((w) => Padding(
                                                padding: const EdgeInsets.only(
                                                    right: 22),
                                                child: w))
                                            .toList(),
                                      ),
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
                                            style:
                                                const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                        const SizedBox(height: 7),
                                        if (demandeTerminee && !approuveParMag)
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 5),
                                                decoration: BoxDecoration(
                                                    color: Colors.orange[200],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16)),
                                                child: const Text(
                                                    "En demande d'approbation",
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.orange)),
                                              ),
                                            ],
                                          ),
                                        if (approuveParMag)
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 5),
                                                decoration: BoxDecoration(
                                                    color: Colors.green[200],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16)),
                                                child: Text(
                                                  "Approuvé par le Magazinier : ${nomMagApprobateur ?? ''}",
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.green),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              buildValidCaissierWidget(),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!demandeTerminee)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.shopping_cart),
                                      label: const Text("Vendre"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: quantiteRestante > 0
                                            ? Colors.blue[700]
                                            : Colors.grey,
                                      ),
                                      onPressed: quantiteRestante > 0
                                          ? () async {
                                              final result = await Get.to(
                                                  () => VenteFormPage(
                                                        prelevement: {
                                                          ...pr,
                                                          "id": prId,
                                                          "emballages":
                                                              pr['emballages'] ??
                                                                  [],
                                                        },
                                                      ));
                                              if (result == true)
                                                setState(() {});
                                            }
                                          : null,
                                    ),
                                    const SizedBox(width: 16),
                                    ElevatedButton.icon(
                                      icon: const Icon(
                                          Icons.assignment_turned_in),
                                      label: const Text(
                                          "Terminer et restituer le reste"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red[700],
                                      ),
                                      onPressed: () async {
                                        await FirebaseFirestore.instance
                                            .collection('prelevements')
                                            .doc(prId)
                                            .update({
                                          'demandeRestitution': true,
                                          'dateDemandeRestitution':
                                              FieldValue.serverTimestamp(),
                                        });
                                        setState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 9, horizontal: 15),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
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

  Widget _buildVenteSection({
    required String title,
    required Color color,
    required List ventes,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 340, minWidth: 260),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 16)),
          const SizedBox(height: 6),
          ...ventes.map<Widget>((venteDoc) {
            final vente = venteDoc.data() as Map<String, dynamic>;
            final dateV = vente['dateVente'] != null
                ? (vente['dateVente'] as Timestamp).toDate()
                : null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Vente du ${dateV != null ? "${dateV.day}/${dateV.month}/${dateV.year}" : "?"}",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                      "Client: ${vente['clientNom'] ?? vente['clientId'] ?? ''}"),
                  Text("Qté vendue: ${vente['quantiteTotale'] ?? '?'} kg"),
                  Text("Montant: ${vente['montantTotal'] ?? '?'} FCFA"),
                  if (vente['emballagesVendus'] != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(
                          (vente['emballagesVendus'] as List).length, (k) {
                        final emb = vente['emballagesVendus'][k];
                        return Row(
                          children: [
                            Icon(icon, color: iconColor, size: 19),
                            const SizedBox(width: 5),
                            Text(
                              "- ${emb['type']}: ${emb['nombre']} pots",
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        );
                      }),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// CAISSIER PAGE
class CaissierPage extends StatefulWidget {
  const CaissierPage({super.key});

  @override
  State<CaissierPage> createState() => _CaissierPageState();
}

class _CaissierPageState extends State<CaissierPage> {
  // Un seul commercial ouvert à la fois
  String? expandedCommercialId;

  Future<Map<String, dynamic>?> fetchCommercialInfo(String commercialId) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('utilisateurs')
        .doc(commercialId)
        .get();
    return userDoc.data() as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> fetchClientInfo(String clientId) async {
    if (clientId.isEmpty) return null;
    final clientDoc = await FirebaseFirestore.instance
        .collection('clients')
        .doc(clientId)
        .get();
    return clientDoc.data() as Map<String, dynamic>?;
  }

  void callPhoneNumber(String phone, BuildContext context) async {
    final Uri url = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'appeler ce numéro.')),
      );
    }
  }

  Future<void> showCreditPaymentDialog({
    required BuildContext context,
    required QueryDocumentSnapshot venteDoc,
    required int montantRestant,
    required int montantPaye,
    required int montantTotal,
    required String typeVente,
  }) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    int montantSaisi = 0;

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
              "Solder le ${typeVente == "Crédit" ? "crédit" : "recouvrement"}"),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: "Montant versé",
                suffixText: "FCFA",
              ),
              keyboardType: TextInputType.number,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return "Saisir un montant";
                }
                final intVal = int.tryParse(val.trim());
                if (intVal == null || intVal <= 0) {
                  return "Montant invalide";
                }
                if (intVal > montantRestant) {
                  return "Montant trop élevé";
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                montantSaisi = int.parse(controller.text.trim());
                final nouveauMontantPaye = montantPaye + montantSaisi;
                final nouveauMontantRestant = montantTotal - nouveauMontantPaye;
                final updates = <String, dynamic>{
                  'montantPaye': nouveauMontantPaye,
                  'montantRestant':
                      nouveauMontantRestant > 0 ? nouveauMontantRestant : 0,
                  'etatCredit':
                      nouveauMontantRestant <= 0 ? 'remboursé' : 'partiel',
                };
                if (nouveauMontantRestant <= 0) {
                  updates['creditRembourseParCaissier'] = true;
                  updates['dateCreditRembourseParCaissier'] =
                      FieldValue.serverTimestamp();
                }
                await venteDoc.reference.update(updates);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(nouveauMontantRestant <= 0
                      ? "Le crédit a été totalement remboursé !"
                      : "Paiement crédit enregistré."),
                ));
                setState(() {});
              },
              child: const Text("Valider paiement"),
            ),
          ],
        );
      },
    );
  }

  bool hasAllCreditsCleared(List<QueryDocumentSnapshot> docs, String? type) {
    for (final doc in docs) {
      final vente = doc.data() as Map<String, dynamic>;
      final venteType = vente['typeVente']?.toString() ?? 'Comptant';
      if ((venteType == "Crédit" || venteType == "Recouvrement") &&
          (type == null || venteType == type)) {
        final montantRestant = (vente['montantRestant'] ?? 0) as int;
        if (montantRestant > 0) return false;
      }
    }
    return true;
  }

  bool allTransactionsValidated(
      List<QueryDocumentSnapshot> docs, String? type) {
    for (final doc in docs) {
      final vente = doc.data() as Map<String, dynamic>;
      final venteType = vente['typeVente']?.toString() ?? 'Comptant';
      if (type == null || venteType == type) {
        if (vente['transfertValideParCaissier'] != true) return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions_caissier')
          .orderBy('dateTransfertCaissier', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Aucune transaction à valider."));
        }

        // Regroupement par commercialId
        Map<String, List<QueryDocumentSnapshot>> ventesParCommercial = {};
        for (final doc in snapshot.data!.docs) {
          final vente = doc.data() as Map<String, dynamic>;
          final vendeur = vente['commercialId'] ?? 'Inconnu';
          ventesParCommercial.putIfAbsent(vendeur, () => []).add(doc);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: ventesParCommercial.entries.map((entry) {
            final vendeurId = entry.key;
            final docs = entry.value;
            // Détecter les types de vente existants pour ce commercial
            final Set<String> typesVente = docs
                .map((venteDoc) =>
                    (venteDoc.data() as Map<String, dynamic>)['typeVente']
                        ?.toString() ??
                    'Comptant')
                .toSet();

            final ValueNotifier<String?> selectedTypeVente =
                ValueNotifier(typesVente.isNotEmpty ? typesVente.first : null);

            return FutureBuilder<Map<String, dynamic>?>(
              future: fetchCommercialInfo(vendeurId),
              builder: (context, userSnap) {
                final userData = userSnap.data;
                final isExpanded = expandedCommercialId == vendeurId;
                return Card(
                  elevation: 5,
                  margin: const EdgeInsets.only(bottom: 25),
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ExpansionTile(
                    key: ValueKey(vendeurId),
                    initiallyExpanded: isExpanded,
                    onExpansionChanged: (expanded) {
                      setState(() {
                        expandedCommercialId = expanded ? vendeurId : null;
                      });
                    },
                    tilePadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    childrenPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    title: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.blue[50],
                          child: Icon(Icons.person,
                              color: Colors.blue[900], size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Commercial: ${userData?['magazinier']?['nom'] ?? userData?['nom'] ?? vendeurId}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              if (userData != null)
                                Row(
                                  children: [
                                    Icon(Icons.email,
                                        size: 15, color: Colors.grey[700]),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        "${userData['email'] ?? ''}",
                                        style: const TextStyle(fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              if (userData != null)
                                Row(
                                  children: [
                                    Icon(Icons.location_on,
                                        size: 15, color: Colors.grey[700]),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        "${userData['magazinier']?['localite'] ?? ''}",
                                        style: const TextStyle(fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    children: [
                      // Selecteur type de vente s'il y en a plus d'un type
                      if (typesVente.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 4, right: 4, bottom: 18, top: 7),
                          child: Row(
                            children: [
                              Icon(Icons.filter_alt, color: Colors.purple[400]),
                              const SizedBox(width: 8),
                              const Text(
                                "Type de vente : ",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ValueListenableBuilder<String?>(
                                  valueListenable: selectedTypeVente,
                                  builder: (context, typeSelected, _) {
                                    return DropdownButton<String>(
                                      value: typeSelected,
                                      isExpanded: true,
                                      items: typesVente
                                          .map((t) => DropdownMenuItem<String>(
                                                value: t,
                                                child: Text(
                                                  t,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500),
                                                ),
                                              ))
                                          .toList(),
                                      onChanged: (val) =>
                                          selectedTypeVente.value = val,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ValueListenableBuilder<String?>(
                        valueListenable: selectedTypeVente,
                        builder: (context, selectedType, _) {
                          final filteredDocs = docs
                              .where((venteDoc) =>
                                  ((venteDoc.data() as Map<String, dynamic>)[
                                              'typeVente']
                                          ?.toString() ??
                                      'Comptant') ==
                                  (selectedType ?? 'Comptant'))
                              .toList();

                          // Vérifie si tous les crédits/recouvrements sont soldés pour activer le bouton général Valider
                          final allCreditsCleared =
                              hasAllCreditsCleared(filteredDocs, selectedType);

                          // Vérifie si toutes les transactions sont validées pour ce type
                          final allValidated = allTransactionsValidated(
                              filteredDocs, selectedType);

                          if (filteredDocs.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(18.0),
                              child: Text(
                                "Aucune vente pour ce type.",
                                style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey),
                              ),
                            );
                          }
                          return Column(
                            children: [
                              ...filteredDocs.map((venteDoc) {
                                final vente =
                                    venteDoc.data() as Map<String, dynamic>;
                                final clientId = vente['clientId'] ?? '';
                                final dateV = vente['dateVente'] != null
                                    ? (vente['dateVente'] as Timestamp).toDate()
                                    : null;
                                final montant = vente['montantTotal'] ?? 0;
                                final montantPaye = vente['montantPaye'] ?? 0;
                                final montantRestant =
                                    vente['montantRestant'] ?? 0;
                                final typeVente =
                                    vente['typeVente']?.toString() ?? '';
                                final approuve =
                                    vente['transfertValideParCaissier'] == true;
                                final prelevId = vente['prelevementId'] ?? '?';
                                final emballages =
                                    vente['emballagesVendus'] as List?;
                                final detailsEmballage = emballages != null
                                    ? emballages
                                        .map((e) =>
                                            "- ${e['type']}: ${e['nombre']} pots")
                                        .join("\n")
                                    : "";

                                return FutureBuilder<Map<String, dynamic>?>(
                                  future: fetchClientInfo(clientId),
                                  builder: (context, clientSnap) {
                                    final clientData = clientSnap.data;
                                    final boutique =
                                        clientData?['nomBoutique'] ??
                                            vente['nomBoutique'] ??
                                            '';
                                    final clientName =
                                        clientData?['nomGerant'] ??
                                            vente['clientNom'] ??
                                            vente['clientId'] ??
                                            '';
                                    final clientTel =
                                        clientData?['telephone1'] ??
                                            vente['clientTel'] ??
                                            '';
                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 8, horizontal: 5),
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16)),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10, horizontal: 10),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  approuve
                                                      ? Icons.verified
                                                      : Icons.pending_actions,
                                                  color: approuve
                                                      ? Colors.green
                                                      : Colors.orange,
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  "${typeVente.toString().toUpperCase()}",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: approuve
                                                        ? Colors.green[700]
                                                        : Colors.orange[700],
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                const Spacer(),
                                                if (approuve)
                                                  Chip(
                                                    label: Text(
                                                        vente['etatCredit'] ==
                                                                'remboursé'
                                                            ? "Crédit remboursé"
                                                            : vente['etatCredit'] ==
                                                                        'partiel' &&
                                                                    (typeVente ==
                                                                            "Crédit" ||
                                                                        typeVente ==
                                                                            "Recouvrement")
                                                                ? "Partiellement remboursé"
                                                                : "Validé",
                                                        style: const TextStyle(
                                                            color:
                                                                Colors.white)),
                                                    backgroundColor: vente[
                                                                'etatCredit'] ==
                                                            'remboursé'
                                                        ? Colors.green
                                                        : vente['etatCredit'] ==
                                                                'partiel'
                                                            ? Colors.orange
                                                            : Colors.green[700],
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 16,
                                              runSpacing: 6,
                                              children: [
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.storefront,
                                                        color: Colors.blue[800],
                                                        size: 18),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      "Boutique: ",
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w500),
                                                    ),
                                                    Text(
                                                      boutique.isNotEmpty
                                                          ? boutique
                                                          : "-",
                                                      style: const TextStyle(
                                                          fontStyle:
                                                              FontStyle.italic),
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.person_outline,
                                                        color: Colors.teal[800],
                                                        size: 18),
                                                    const SizedBox(width: 3),
                                                    const Text("Client: "),
                                                    Text(
                                                      clientName,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w500),
                                                    ),
                                                  ],
                                                ),
                                                if (clientTel
                                                    .toString()
                                                    .isNotEmpty)
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.phone,
                                                          color:
                                                              Colors.green[800],
                                                          size: 18),
                                                      const SizedBox(width: 3),
                                                      Text(clientTel),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 7),
                                            Row(
                                              children: [
                                                Icon(Icons.date_range,
                                                    size: 16,
                                                    color: Colors.grey),
                                                const SizedBox(width: 4),
                                                Text(
                                                    "Date: ${dateV != null ? "${dateV.day}/${dateV.month}/${dateV.year}" : "?"}"),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                Icon(Icons.price_change,
                                                    size: 16,
                                                    color: Colors.orange[300]),
                                                const SizedBox(width: 4),
                                                Text("Montant total: "),
                                                Text("$montant FCFA",
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                Icon(Icons.check_circle,
                                                    size: 16,
                                                    color: Colors.green[300]),
                                                const SizedBox(width: 4),
                                                Text("Montant payé: "),
                                                Text("$montantPaye FCFA",
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                Icon(Icons.cancel,
                                                    size: 16,
                                                    color: Colors.red[200]),
                                                const SizedBox(width: 4),
                                                Text("Montant restant: "),
                                                Text("$montantRestant FCFA",
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                Icon(Icons.assignment,
                                                    size: 16,
                                                    color:
                                                        Colors.deepPurple[200]),
                                                const SizedBox(width: 4),
                                                Text("Prélèvement: $prelevId"),
                                              ],
                                            ),
                                            if (detailsEmballage.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 4.0, bottom: 2),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(Icons.local_mall,
                                                        size: 17,
                                                        color:
                                                            Colors.amber[800]),
                                                    const SizedBox(width: 4),
                                                    Flexible(
                                                        child: Text(
                                                            "Emballages:\n$detailsEmballage")),
                                                  ],
                                                ),
                                              ),
                                            if (vente['note'] != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 2.0),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.note,
                                                        size: 15,
                                                        color:
                                                            Colors.grey[700]),
                                                    const SizedBox(width: 3),
                                                    Flexible(
                                                        child: Text(
                                                            "Note: ${vente['note']}")),
                                                  ],
                                                ),
                                              ),
                                            if (vente['nomMagazinier'] != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 2.0),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.store,
                                                        size: 15,
                                                        color:
                                                            Colors.brown[700]),
                                                    const SizedBox(width: 3),
                                                    Flexible(
                                                        child: Text(
                                                            "Magasinier: ${vente['nomMagazinier']}")),
                                                  ],
                                                ),
                                              ),
                                            if (vente[
                                                    'dateTransfertCaissier'] !=
                                                null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 2.0),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.compare_arrows,
                                                        size: 15,
                                                        color: Colors.blueGrey),
                                                    const SizedBox(width: 3),
                                                    Flexible(
                                                      child: Text(
                                                        "Transféré au caissier le: ${vente['dateTransfertCaissier'] is Timestamp ? (vente['dateTransfertCaissier'] as Timestamp).toDate().toString() : vente['dateTransfertCaissier'].toString()}",
                                                        style: const TextStyle(
                                                            fontSize: 12,
                                                            color: Colors
                                                                .blueGrey),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            const SizedBox(height: 10),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                if (clientTel
                                                    .toString()
                                                    .isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            right: 10),
                                                    child: ElevatedButton.icon(
                                                      icon: const Icon(
                                                          Icons.call),
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            Colors.green[700],
                                                        foregroundColor:
                                                            Colors.white,
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                        ),
                                                        elevation: 0,
                                                      ),
                                                      onPressed: () =>
                                                          callPhoneNumber(
                                                              clientTel
                                                                  .toString(),
                                                              context),
                                                      label: const Text(
                                                          "Appeler client"),
                                                    ),
                                                  ),
                                                // BOUTON VALIDER/SOLDER CREDIT
                                                if ((typeVente == "Crédit" ||
                                                        typeVente ==
                                                            "Recouvrement") &&
                                                    montantRestant > 0)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 6),
                                                    child: ElevatedButton.icon(
                                                      icon: const Icon(
                                                          Icons.attach_money),
                                                      label: Text(typeVente ==
                                                              "Crédit"
                                                          ? "Solder le crédit"
                                                          : "Solder le recouvrement"),
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            Colors.orange[700],
                                                        foregroundColor:
                                                            Colors.white,
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                        ),
                                                        elevation: 0,
                                                      ),
                                                      onPressed: () =>
                                                          showCreditPaymentDialog(
                                                        context: context,
                                                        venteDoc: venteDoc,
                                                        montantRestant:
                                                            montantRestant,
                                                        montantPaye:
                                                            montantPaye,
                                                        montantTotal: montant,
                                                        typeVente: typeVente,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }),
                              // BOUTON GENERAL VALIDER : Affiché seulement si toutes les transactions sont validables
                              if (allCreditsCleared && !allValidated)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      top: 18.0, bottom: 14),
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.verified),
                                      label: const Text(
                                          "Valider toutes les transactions"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue[700],
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        elevation: 2,
                                        minimumSize: const Size(220, 48),
                                      ),
                                      onPressed: () async {
                                        // Valide toutes les transactions du type sélectionné
                                        for (final venteDoc in filteredDocs) {
                                          await venteDoc.reference.update({
                                            'transfertValideParCaissier': true,
                                          });
                                        }
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    "Toutes les transactions ont été validées.")));
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                ),
                              if (!allCreditsCleared)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 10, bottom: 8),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline,
                                          color: Colors.orange[700]),
                                      const SizedBox(width: 7),
                                      const Text(
                                        "Veuillez solder tous les crédits/recouvrements avant validation.",
                                        style: TextStyle(
                                            color: Colors.orange,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }
}

class GestionnaireCommercialPage extends StatefulWidget {
  const GestionnaireCommercialPage({super.key});
  @override
  State<GestionnaireCommercialPage> createState() =>
      _GestionnaireCommercialPageState();
}

class _GestionnaireCommercialPageState
    extends State<GestionnaireCommercialPage> {
  String selectedSection = "Ventes";
  String? selectedClient;
  String? selectedCommercial;
  String? selectedTypeProduit;
  String? selectedLocalite;
  DateTimeRange? selectedPeriode;
  String? selectedCollecteType;
  String? selectedStockLocalite;
  String? selectedStockMagasin;

  Map<String, String> clientsMap = {};
  Map<String, String> commerciauxMap = {};

  // Pour l'export PDF, stocker la dernière liste filtrée affichée
  List<Map<String, dynamic>> _latestVentesFiltered = [];
  List<Map<String, dynamic>> _latestCollectesFiltered = [];
  List<Map<String, dynamic>> _latestStockFiltered = [];

  Future<List<String>> fetchClients() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('clients').get();
      clientsMap = {
        for (var d in snap.docs)
          d.id: d.data()['nomBoutique'] ?? d.data()['nomGerant'] ?? d.id
      };
      return clientsMap.values.toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<String>> fetchCommerciaux() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('utilisateurs')
          .where('role', isEqualTo: 'commercial')
          .get();
      commerciauxMap = {};
      for (var d in snap.docs) {
        final nom = d.data()['nom'] ?? d.id;
        commerciauxMap[d.id] = nom;
        final uid = d.data()['uid'];
        if (uid != null && uid != d.id) {
          commerciauxMap[uid] = nom;
        }
      }
      return commerciauxMap.values.toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<String>> fetchTypesProduit() async {
    try {
      final snap =
          await FirebaseFirestore.instance.collection('conditionnement').get();
      final types = <String>{};
      for (var doc in snap.docs) {
        final emballages = (doc.data()['emballages'] as List?) ?? [];
        for (final emb in emballages) {
          types.add(emb['type'] ?? '');
        }
      }
      return types.where((e) => e.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<String>> fetchLocalites() async {
    try {
      final snap =
          await FirebaseFirestore.instance.collection('utilisateurs').get();
      final localites = <String>{};
      for (var doc in snap.docs) {
        final loc = doc.data()['localite'];
        if (loc != null && loc.toString().isNotEmpty) localites.add(loc);
      }
      return localites.toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<String>> fetchMagasins() async {
    try {
      final snap =
          await FirebaseFirestore.instance.collection('magasins').get();
      return snap.docs
          .map((e) => e.data()['nom'] ?? e.id)
          .cast<String>()
          .toList();
    } catch (e) {
      return [];
    }
  }

  Widget periodePicker() {
    return OutlinedButton.icon(
      icon: const Icon(Icons.date_range),
      label: Text(selectedPeriode == null
          ? "Période"
          : "${DateFormat('dd/MM/yyyy').format(selectedPeriode!.start)} - "
              "${DateFormat('dd/MM/yyyy').format(selectedPeriode!.end)}"),
      onPressed: () async {
        try {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(const Duration(days: 2)),
            initialDateRange: selectedPeriode,
          );
          if (picked != null) setState(() => selectedPeriode = picked);
        } catch (_) {}
      },
    );
  }

  Future<void> exportPDF(
      List<Map<String, dynamic>>? data, String section) async {
    try {
      List<Map<String, dynamic>> exportData = data ?? [];
      if ((section == "Ventes" || section == "Crédits") &&
          _latestVentesFiltered.isNotEmpty) {
        exportData = _latestVentesFiltered;
      }
      if (section == "Collectes" && _latestCollectesFiltered.isNotEmpty) {
        exportData = _latestCollectesFiltered;
      }
      if (section == "Stock" && _latestStockFiltered.isNotEmpty) {
        exportData = _latestStockFiltered;
      }
      if (exportData.isEmpty) {
        final pdf = pw.Document();
        pdf.addPage(pw.Page(
          build: (context) => pw.Center(child: pw.Text('Aucune donnée')),
        ));
        await Printing.layoutPdf(onLayout: (format) async => pdf.save());
        return;
      }

      List<String> columns;
      List<List<String>> rows;

      if (section == "Ventes" || section == "Crédits") {
        columns = [
          "Date",
          "Client",
          "Commercial",
          "Type vente",
          "Montant total",
        ];
        rows = exportData.map((v) {
          final dateV = v['dateVente'] is Timestamp
              ? DateFormat('dd/MM/yyyy')
                  .format((v['dateVente'] as Timestamp).toDate())
              : "";
          String? commId = v['commercialId']?.toString();
          String? commNom = v['commercialNom']?.toString();
          String displayComm = commerciauxMap[commId] ?? commNom ?? "";
          String displayClient =
              clientsMap[v['clientId']] ?? v['clientNom'] ?? "";
          return [
            dateV,
            displayClient,
            displayComm,
            v['typeVente'] ?? "",
            "${v['montantTotal'] ?? ""}"
          ]
              .map((e) => e.toString())
              .toList(); // <-- Cette ligne rend la liste typée String
        }).toList();
      } else if (section == "Collectes") {
        columns = [
          "Date",
          "Type",
          "Producteur/SCOOPS",
          "Produit",
          "Qté",
          "Localité"
        ];
        rows = exportData.map((l) {
          final dateC = l['dateCollecte'] is Timestamp
              ? DateFormat('dd/MM/yyyy')
                  .format((l['dateCollecte'] as Timestamp).toDate())
              : "";
          return [
            dateC,
            "${l['typeCol'] ?? l['type'] ?? ""}",
            "${l['nomProducteur'] ?? ""}",
            "${l['typeProduit'] ?? ""}",
            "${l['quantiteAcceptee'] ?? l['quantiteFiltree'] ?? l['quantite'] ?? ""}",
            "${l['localiteCol'] ?? ""}"
          ];
        }).toList();
      } else if (section == "Stock") {
        columns = [
          "Date",
          "Lot origine",
          "Florale",
          "Nb total pots",
          "Qté conditionnée",
          "Qté reçue",
          "Qté restante",
        ];
        rows = exportData.map((lot) {
          final dateC = lot['date'] is Timestamp
              ? DateFormat('dd/MM/yyyy')
                  .format((lot['date'] as Timestamp).toDate())
              : "";
          return [
            dateC,
            "${lot['lotOrigine'] ?? ""}",
            "${lot['predominanceFlorale'] ?? ""}",
            "${lot['nbTotalPots'] ?? ""}",
            "${lot['quantiteConditionnee'] ?? ""}",
            "${lot['quantiteRecue'] ?? ""}",
            "${lot['quantiteRestante'] ?? ""}",
          ];
        }).toList();
      } else {
        columns = [];
        rows = [];
      }

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "Export $section",
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 22),
              ),
              pw.SizedBox(height: 14),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey300),
                    children: columns
                        .map((h) => pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(h,
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold)),
                            ))
                        .toList(),
                  ),
                  ...rows.asMap().entries.map((entry) {
                    final index = entry.key;
                    final row = entry.value;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                          color: index.isEven
                              ? PdfColors.white
                              : PdfColors.grey100),
                      children: row
                          .map((cell) => pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(cell),
                              ))
                          .toList(),
                    );
                  }),
                ],
              )
            ],
          ),
        ),
      );
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur export PDF: $e")),
        );
      }
    }
  }

  void showDetailsDialog(BuildContext context, Map<String, dynamic> data,
      {String? title}) {
    String formatValue(dynamic value, {String? key}) {
      if (key != null && key.toLowerCase().contains('client')) {
        return clientsMap[value] ?? value?.toString() ?? '';
      }
      if (key != null && key.toLowerCase().contains('commercial')) {
        return commerciauxMap[value] ?? value?.toString() ?? '';
      }
      if (value is Timestamp) {
        return DateFormat('dd/MM/yyyy HH:mm').format(value.toDate());
      }
      if (value is DateTime) {
        return DateFormat('dd/MM/yyyy HH:mm').format(value);
      }
      if (value is Map) {
        return value.entries
            .map((e) => "${e.key}: ${formatValue(e.value, key: e.key)}")
            .join(", ");
      }
      if (value is List) {
        if (value.isEmpty) return "(vide)";
        if (value[0] is Map) {
          return value
              .map((item) => value.length > 1
                  ? "\n- ${formatValue(item)}"
                  : formatValue(item))
              .join("");
        }
        return value.join(", ");
      }
      return value?.toString() ?? "";
    }

    List<Widget> buildDetails(Map<String, dynamic> details) {
      final infos = <TableRow>[];
      final autres = <TableRow>[];
      final listes = <Widget>[];

      details.forEach((key, value) {
        final labelStyle = TextStyle(
            fontWeight: FontWeight.w600, color: Colors.deepPurple[700]);
        if (key.toLowerCase().contains('nom') ||
            key.toLowerCase().contains('type') ||
            key.toLowerCase().contains('produit') ||
            key.toLowerCase().contains('client') ||
            key.toLowerCase().contains('commercial')) {
          infos.add(TableRow(children: [
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(key, style: labelStyle)),
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(formatValue(value, key: key))),
          ]));
        } else if (value is List && value.isNotEmpty && value[0] is Map) {
          listes.add(Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 2),
            child: Text("$key :",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.deepPurple)),
          ));
          for (var i = 0; i < value.length; i++) {
            final map = value[i] as Map;
            listes.add(
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.deepPurple.shade100),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Table(
                    columnWidths: const {
                      0: IntrinsicColumnWidth(),
                      1: FlexColumnWidth(),
                    },
                    children: map.entries
                        .map<TableRow>((entry) => TableRow(
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  child: Text("${entry.key}",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w500)),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                      formatValue(entry.value, key: entry.key)),
                                ),
                              ],
                            ))
                        .toList(),
                  ),
                ),
              ),
            );
          }
        } else {
          autres.add(TableRow(children: [
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(key, style: labelStyle)),
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(formatValue(value, key: key))),
          ]));
        }
      });

      return [
        if (infos.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text("Informations principales",
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple)),
          ),
          Table(
            columnWidths: const {
              0: IntrinsicColumnWidth(),
              1: FlexColumnWidth()
            },
            children: infos,
          ),
        ],
        if (autres.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text("Autres champs",
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800])),
          ),
          Table(
            columnWidths: const {
              0: IntrinsicColumnWidth(),
              1: FlexColumnWidth()
            },
            children: autres,
          ),
        ],
        if (listes.isNotEmpty) ...listes,
        const SizedBox(height: 10),
      ];
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(Icons.info, color: Colors.deepPurple[300]),
            const SizedBox(width: 8),
            Text(title ?? "Détails",
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: buildDetails(data),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Fermer")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([
        fetchClients(),
        fetchCommerciaux(),
        fetchTypesProduit(),
        fetchLocalites(),
        fetchMagasins(),
      ]),
      builder: (context, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final clients = snap.data![0] as List<String>;
        final commerciaux = snap.data![1] as List<String>;
        final produits = snap.data![2] as List<String>;
        final localites = snap.data![3] as List<String>;
        final magasins = snap.data![4] as List<String>;

        // Filtres responsifs (Wrap = mobile friendly)
        List<Widget> filterWidgets = [];
        if (selectedSection == "Ventes" || selectedSection == "Crédits") {
          filterWidgets.addAll([
            SizedBox(
              width: 220,
              child: DropdownButton<String?>(
                value: selectedClient,
                hint: const Text("Client"),
                isExpanded: true,
                items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text("Tous"))
                    ] +
                    clients
                        .map((c) =>
                            DropdownMenuItem<String?>(value: c, child: Text(c)))
                        .toList(),
                onChanged: (v) => setState(() => selectedClient = v),
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButton<String?>(
                value: selectedCommercial,
                hint: const Text("Commercial"),
                isExpanded: true,
                items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text("Tous"))
                    ] +
                    commerciaux
                        .map((c) =>
                            DropdownMenuItem<String?>(value: c, child: Text(c)))
                        .toList(),
                onChanged: (v) => setState(() => selectedCommercial = v),
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButton<String?>(
                value: selectedTypeProduit,
                hint: const Text("Type produit"),
                isExpanded: true,
                items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text("Tous"))
                    ] +
                    produits
                        .map((t) =>
                            DropdownMenuItem<String?>(value: t, child: Text(t)))
                        .toList(),
                onChanged: (v) => setState(() => selectedTypeProduit = v),
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButton<String?>(
                value: selectedLocalite,
                hint: const Text("Localité"),
                isExpanded: true,
                items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text("Toutes"))
                    ] +
                    localites
                        .map((l) =>
                            DropdownMenuItem<String?>(value: l, child: Text(l)))
                        .toList(),
                onChanged: (v) => setState(() => selectedLocalite = v),
              ),
            ),
            periodePicker(),
          ]);
        }
        if (selectedSection == "Collectes") {
          filterWidgets.addAll([
            SizedBox(
              width: 220,
              child: DropdownButton<String?>(
                value: selectedCollecteType,
                hint: const Text("Type collecte"),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text("Tous")),
                  const DropdownMenuItem<String?>(
                      value: "achat", child: Text("Achat")),
                  const DropdownMenuItem<String?>(
                      value: "récolte", child: Text("Récolte")),
                  const DropdownMenuItem<String?>(
                      value: "SCOOPS", child: Text("SCOOPS")),
                  const DropdownMenuItem<String?>(
                      value: "Individuel", child: Text("Individuel")),
                ],
                onChanged: (v) => setState(() => selectedCollecteType = v),
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButton<String?>(
                value: selectedLocalite,
                hint: const Text("Localité"),
                isExpanded: true,
                items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text("Toutes"))
                    ] +
                    localites
                        .map((l) =>
                            DropdownMenuItem<String?>(value: l, child: Text(l)))
                        .toList(),
                onChanged: (v) => setState(() => selectedLocalite = v),
              ),
            ),
          ]);
        }
        if (selectedSection == "Stock") {
          filterWidgets.addAll([
            SizedBox(
              width: 220,
              child: DropdownButton<String?>(
                value: selectedStockLocalite,
                hint: const Text("Localité"),
                isExpanded: true,
                items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text("Toutes"))
                    ] +
                    localites
                        .map((l) =>
                            DropdownMenuItem<String?>(value: l, child: Text(l)))
                        .toList(),
                onChanged: (v) => setState(() => selectedStockLocalite = v),
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButton<String?>(
                value: selectedStockMagasin,
                hint: const Text("Magasin"),
                isExpanded: true,
                items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text("Tous"))
                    ] +
                    magasins
                        .map((m) =>
                            DropdownMenuItem<String?>(value: m, child: Text(m)))
                        .toList(),
                onChanged: (v) => setState(() => selectedStockMagasin = v),
              ),
            ),
          ]);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1300),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Tableau de bord Gestionnaire Commercial",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ChoiceChip(
                      label: const Text("Ventes"),
                      selected: selectedSection == "Ventes",
                      onSelected: (_) =>
                          setState(() => selectedSection = "Ventes"),
                    ),
                    ChoiceChip(
                      label: const Text("Crédits en cours"),
                      selected: selectedSection == "Crédits",
                      onSelected: (_) =>
                          setState(() => selectedSection = "Crédits"),
                    ),
                    ChoiceChip(
                      label: const Text("Collectes"),
                      selected: selectedSection == "Collectes",
                      onSelected: (_) =>
                          setState(() => selectedSection = "Collectes"),
                    ),
                    ChoiceChip(
                      label: const Text("Stock"),
                      selected: selectedSection == "Stock",
                      onSelected: (_) =>
                          setState(() => selectedSection = "Stock"),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: filterWidgets,
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (selectedSection == "Ventes" ||
                        selectedSection == "Crédits") {
                      await exportPDF(_latestVentesFiltered, selectedSection);
                    } else if (selectedSection == "Stock") {
                      await exportPDF(_latestStockFiltered, selectedSection);
                    } else if (selectedSection == "Collectes") {
                      await exportPDF(
                          _latestCollectesFiltered, selectedSection);
                    }
                  },
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text("Exporter PDF"),
                ),
                const SizedBox(height: 16),
                if (selectedSection == "Ventes")
                  buildVentesTable(context, showOnlyCredits: false),
                if (selectedSection == "Crédits")
                  buildVentesTable(context, showOnlyCredits: true),
                if (selectedSection == "Collectes")
                  buildCollectesTable(context),
                if (selectedSection == "Stock") buildStockTable(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildVentesTable(BuildContext context,
      {required bool showOnlyCredits}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('ventes_effectuees')
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError)
          return Center(child: Text('Erreur Firestore: ${snap.error}'));
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final ventes = snap.data!.docs
            .map((e) => e.data() as Map<String, dynamic>)
            .toList();
        List<Map<String, dynamic>> filtered = ventes;
        if (showOnlyCredits) {
          filtered = filtered
              .where((v) =>
                  v['typeVente'] == "Crédit" ||
                  v['typeVente'] == "Recouvrement")
              .toList();
        }
        if (selectedClient != null) {
          filtered = filtered
              .where((v) =>
                  (clientsMap[v['clientId']] ?? v['clientNom'] ?? "") ==
                  selectedClient)
              .toList();
        }
        if (selectedCommercial != null) {
          filtered = filtered.where((v) {
            String? commId = v['commercialId']?.toString();
            String? commNom = v['commercialNom']?.toString();
            return (commerciauxMap[commId] ?? commNom ?? "") ==
                selectedCommercial;
          }).toList();
        }
        if (selectedTypeProduit != null) {
          filtered = filtered.where((v) {
            final emb = (v['emballagesVendus'] ?? []) as List;
            return emb.any((e) => e['type'] == selectedTypeProduit);
          }).toList();
        }
        if (selectedLocalite != null) {
          filtered =
              filtered.where((v) => v['localite'] == selectedLocalite).toList();
        }
        if (selectedPeriode != null) {
          filtered = filtered.where((v) {
            final d = v['dateVente'];
            if (d is Timestamp) {
              final dt = d.toDate();
              return dt.isAfter(selectedPeriode!.start
                      .subtract(const Duration(days: 1))) &&
                  dt.isBefore(
                      selectedPeriode!.end.add(const Duration(days: 1)));
            }
            return true;
          }).toList();
        }
        // Update for export PDF
        _latestVentesFiltered = filtered;

        return Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text("Date")),
                DataColumn(label: Text("Client")),
                DataColumn(label: Text("Commercial")),
                DataColumn(label: Text("Type vente")),
                DataColumn(label: Text("Montant total")),
                DataColumn(label: Text("Voir détails")),
              ],
              rows: filtered.map((v) {
                final dateV = v['dateVente'] is Timestamp
                    ? (v['dateVente'] as Timestamp).toDate()
                    : null;
                String? commId = v['commercialId']?.toString();
                String? commNom = v['commercialNom']?.toString();
                String displayComm = commerciauxMap[commId] ?? commNom ?? "";
                String displayClient =
                    clientsMap[v['clientId']] ?? v['clientNom'] ?? "";
                return DataRow(
                  cells: [
                    DataCell(Text(dateV != null
                        ? DateFormat('dd/MM/yyyy').format(dateV)
                        : "")),
                    DataCell(Text(displayClient)),
                    DataCell(Text(displayComm)),
                    DataCell(Text(v['typeVente'] ?? "")),
                    DataCell(Text("${v['montantTotal'] ?? ""}")),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.info_outline,
                            color: Colors.deepPurple),
                        onPressed: () => showDetailsDialog(context, v,
                            title: "Détails de la vente"),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget buildCollectesTable(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('collectes').snapshots(),
      builder: (context, snap) {
        if (snap.hasError)
          return Center(child: Text('Erreur Firestore: ${snap.error}'));
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final collectes = snap.data!.docs;
        final List<Map<String, dynamic>> lignes = [];

        for (final doc in collectes) {
          final parent = doc.data() as Map<String, dynamic>;
          final parentId = doc.id;
          if (parent['type'] == "achat" && parent['details'] != null) {
            final details = parent['details'] as List;
            for (final detail in details) {
              lignes.add({
                ...parent,
                ...detail,
                'mainId': parentId,
                'typeCol': parent['type'] ?? "",
                'nomProducteur':
                    parent['nomIndividuel'] ?? parent['nomPrenom'] ?? "",
                'localiteCol': parent['localite'] ?? parent['commune'] ?? "",
              });
            }
          } else {
            lignes.add({
              ...parent,
              'mainId': parentId,
              'typeCol': parent['type'] ?? "",
              'nomProducteur': parent['nomIndividuel'] ??
                  parent['nomPrenom'] ??
                  parent['utilisateurNom'] ??
                  "",
              'localiteCol': parent['localite'] ?? parent['commune'] ?? "",
            });
          }
        }
        var filtered = lignes;
        if (selectedCollecteType != null) {
          filtered = filtered
              .where((l) =>
                  (l['typeCol'] ?? l['type'] ?? "") == selectedCollecteType)
              .toList();
        }
        if (selectedLocalite != null) {
          filtered = filtered
              .where((l) => (l['localiteCol'] ?? "") == selectedLocalite)
              .toList();
        }
        // Update for export PDF
        _latestCollectesFiltered = filtered;

        return Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text("Date")),
                DataColumn(label: Text("Type")),
                DataColumn(label: Text("Producteur/SCOOPS")),
                DataColumn(label: Text("Produit")),
                DataColumn(label: Text("Qté")),
                DataColumn(label: Text("Localité")),
                DataColumn(label: Text("Voir détails")),
              ],
              rows: filtered.map((l) {
                final dateC = l['dateCollecte'] is Timestamp
                    ? (l['dateCollecte'] as Timestamp).toDate()
                    : null;
                return DataRow(
                  cells: [
                    DataCell(Text(dateC != null
                        ? DateFormat('dd/MM/yyyy').format(dateC)
                        : "")),
                    DataCell(Text("${l['typeCol'] ?? l['type'] ?? ""}")),
                    DataCell(Text("${l['nomProducteur'] ?? ""}")),
                    DataCell(Text("${l['typeProduit'] ?? ""}")),
                    DataCell(Text(
                        "${l['quantiteAcceptee'] ?? l['quantiteFiltree'] ?? l['quantite'] ?? ""}")),
                    DataCell(Text("${l['localiteCol'] ?? ""}")),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.info_outline,
                            color: Colors.deepPurple),
                        onPressed: () => showDetailsDialog(context, l,
                            title: "Détail de la collecte"),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget buildStockTable(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance.collection('conditionnement').snapshots(),
      builder: (context, snap) {
        if (snap.hasError)
          return Center(child: Text('Erreur Firestore: ${snap.error}'));
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final lots = snap.data!.docs
            .map((e) => e.data() as Map<String, dynamic>)
            .toList();
        List<Map<String, dynamic>> filtered = lots;
        if (selectedStockLocalite != null) {
          filtered = filtered
              .where((l) => (l['localite'] ?? "") == selectedStockLocalite)
              .toList();
        }
        if (selectedStockMagasin != null) {
          filtered = filtered
              .where((l) => (l['magasin'] ?? "") == selectedStockMagasin)
              .toList();
        }
        // Update for export PDF
        _latestStockFiltered = filtered;

        return Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text("Date")),
                DataColumn(label: Text("Lot origine")),
                DataColumn(label: Text("Florale")),
                DataColumn(label: Text("Nb total pots")),
                DataColumn(label: Text("Qté conditionnée")),
                DataColumn(label: Text("Qté reçue")),
                DataColumn(label: Text("Qté restante")),
                DataColumn(label: Text("Voir détails")),
              ],
              rows: filtered.map((lot) {
                final dateC = lot['date'] is Timestamp
                    ? (lot['date'] as Timestamp).toDate()
                    : null;
                return DataRow(
                  cells: [
                    DataCell(Text(dateC != null
                        ? DateFormat('dd/MM/yyyy').format(dateC)
                        : "")),
                    DataCell(Text("${lot['lotOrigine'] ?? ""}")),
                    DataCell(Text("${lot['predominanceFlorale'] ?? ""}")),
                    DataCell(Text("${lot['nbTotalPots'] ?? ""}")),
                    DataCell(Text("${lot['quantiteConditionnee'] ?? ""}")),
                    DataCell(Text("${lot['quantiteRecue'] ?? ""}")),
                    DataCell(Text("${lot['quantiteRestante'] ?? ""}")),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.info_outline,
                            color: Colors.deepPurple),
                        onPressed: () => showDetailsDialog(context, lot,
                            title: "Détail du lot conditionné"),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
