import 'package:apisavana_gestion/authentication/user_session.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

final Map<String, List<String>> roleModules = {
  "Admin": [
    "collecte",
    "controle",
    "extraction",
    "filtrage",
    "conditionnement",
    "gestion de ventes",
    "ventes",
    "stock",
    "rapports"
  ],
  "Collecteur": ["collecte"],
  "Contrôleur": ["controle"],
  "Extracteur": ["extraction"],
  "Filtreur": ["filtrage"],
  "Conditionneur": ["conditionnement"],
  "Commercial": ["gestion de ventes", "ventes", "rapports"],
  "Gestionaire Commerciale": ["gestion de ventes", "ventes", "rapports"],
  "Magazinier": ["gestion de ventes", "stock", "rapports"],
  "Caissier": ["gestion de ventes", "ventes", "rapports"],
};

class DashboardScreen extends StatefulWidget {
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final GlobalKey<ScaffoldState> _scaffoldKey;
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;

  bool get isLargeScreen =>
      MediaQuery.of(context).size.width >= 900; // seuil PC

  // --- Statistiques dynamiques (Firestore)
  Map<String, dynamic> statsData = {};
  bool loadingStats = true;

  // PDF
  Future<void> exportPDF(String section) async {
    try {
      final pdf = pw.Document();
      List<String> columns = [];
      List<List<String>> rows = [];

      if (section == "collecte") {
        columns = [
          "Date",
          "Type",
          "Quantité",
          "Unité",
          "Producteur/SCOOPS",
          "Localité"
        ];
        rows = (statsData["collecteRows"] ?? []).map<List<String>>((row) {
          return [
            row["date"] ?? "",
            row["type"] ?? "",
            row["quantite"].toString(),
            row["unite"] ?? "",
            row["producteur"] ?? "",
            row["localite"] ?? ""
          ].map((e) => e.toString()).toList();
        }).toList();
      } else if (section == "ventes") {
        columns = [
          "Date",
          "Client",
          "Commercial",
          "Type vente",
          "Montant total"
        ];
        rows = (statsData["ventesRows"] ?? []).map<List<String>>((row) {
          return [
            row["date"] ?? "",
            row["client"] ?? "",
            row["commercial"] ?? "",
            row["typeVente"] ?? "",
            row["montantTotal"]?.toString() ?? ""
          ].map((e) => e.toString()).toList();
        }).toList();
      } else if (section == "stock") {
        columns = [
          "Date",
          "Produit",
          "Quantité",
          "Unité",
          "Localité",
          "Magasin"
        ];
        rows = (statsData["stockRows"] ?? []).map<List<String>>((row) {
          return [
            row["date"] ?? "",
            row["produit"] ?? "",
            row["quantite"].toString(),
            row["unite"] ?? "",
            row["localite"] ?? "",
            row["magasin"] ?? ""
          ].map((e) => e.toString()).toList();
        }).toList();
      }
      if (rows.isEmpty) {
        pdf.addPage(pw.Page(
            build: (context) =>
                pw.Center(child: pw.Text("Aucune donnée à exporter"))));
      } else {
        pdf.addPage(
          pw.Page(
            build: (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "Export $section",
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 22),
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
      }
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erreur export PDF: $e")));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(duration: Duration(milliseconds: 900), vsync: this);
    _fadeInAnimation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeIn);
    _animationController.forward();
    _scaffoldKey = GlobalKey<ScaffoldState>();
    if (!Get.isRegistered<UserSession>()) {
      Get.put(UserSession());
    }
    loadStats();
  }

  Future<void> loadStats() async {
    setState(() => loadingStats = true);
    Map<String, dynamic> stats = {};
    // --- COLLECTE ---
    final collecteSnap =
        await FirebaseFirestore.instance.collection('collectes').get();
    int qteRecolte = 0, qteAchat = 0;
    String uniteRecolte = "kg", uniteAchat = "litres";
    List collecteRows = [];
    for (final doc in collecteSnap.docs) {
      final data = doc.data();
      String date = "";
      if (data["dateCollecte"] is Timestamp) {
        date = DateFormat('dd/MM/yyyy')
            .format((data["dateCollecte"] as Timestamp).toDate());
      }
      final type = data["type"] ?? "";
      int quantite = int.tryParse(data["quantite"].toString()) ?? 0;
      String unite = data["unite"] ?? (type == "achat" ? "litres" : "kg");
      String producteur = data["nomIndividuel"] ?? data["nomPrenom"] ?? "";
      String localite = data["localite"] ?? data["commune"] ?? "";
      collecteRows.add({
        "date": date,
        "type": type,
        "quantite": quantite,
        "unite": unite,
        "producteur": producteur,
        "localite": localite
      });
      if (type == "achat") {
        qteAchat += quantite;
        uniteAchat = unite;
      } else if (type == "récolte" || type == "recolte") {
        qteRecolte += quantite;
        uniteRecolte = unite;
      }
    }
    stats["collecte"] = {
      "recolte": {"valeur": qteRecolte, "unite": uniteRecolte},
      "achat": {"valeur": qteAchat, "unite": uniteAchat},
    };
    stats["collecteRows"] = collecteRows;

    // --- VENTES ---
    final ventesSnap = await FirebaseFirestore.instance
        .collectionGroup('ventes_effectuees')
        .get();
    int vComptant = 0, vCredit = 0, vRecouv = 0;
    String uniteVente = "kg";
    List ventesRows = [];
    Map<String, String> clientsMap = {};
    Map<String, String> commerciauxMap = {};
    // Récupérer tous les clients et commerciaux pour mapping noms
    final clientsSnap =
        await FirebaseFirestore.instance.collection('clients').get();
    for (var d in clientsSnap.docs) {
      clientsMap[d.id] =
          d.data()['nomBoutique'] ?? d.data()['nomGerant'] ?? d.id;
    }
    final commSnap = await FirebaseFirestore.instance
        .collection('utilisateurs')
        .where('role', isEqualTo: 'commercial')
        .get();
    for (var d in commSnap.docs) {
      final nom = d.data()['nom'] ?? d.id;
      commerciauxMap[d.id] = nom;
      final uid = d.data()['uid'];
      if (uid != null && uid != d.id) {
        commerciauxMap[uid] = nom;
      }
    }
    for (final doc in ventesSnap.docs) {
      final v = doc.data() as Map<String, dynamic>;
      String date = "";
      if (v["dateVente"] is Timestamp) {
        date = DateFormat('dd/MM/yyyy')
            .format((v["dateVente"] as Timestamp).toDate());
      }
      String client = clientsMap[v['clientId']] ?? v['clientNom'] ?? "";
      String commId = v['commercialId']?.toString() ?? "";
      String commNom = v['commercialNom']?.toString() ?? "";
      String commercial = commerciauxMap[commId] ?? commNom ?? "";
      String typeVente = v['typeVente'] ?? "";
      int montantTotal = int.tryParse(v['montantTotal']?.toString() ?? "") ?? 0;
      ventesRows.add({
        "date": date,
        "client": client,
        "commercial": commercial,
        "typeVente": typeVente,
        "montantTotal": montantTotal
      });
      if (typeVente == "Comptant")
        vComptant += montantTotal;
      else if (typeVente == "Crédit")
        vCredit += montantTotal;
      else if (typeVente == "Recouvrement") vRecouv += montantTotal;
    }
    stats["ventes"] = {
      "comptant": {"valeur": vComptant, "unite": uniteVente},
      "credit": {"valeur": vCredit, "unite": uniteVente},
      "recouvrement": {"valeur": vRecouv, "unite": uniteVente},
    };
    stats["ventesRows"] = ventesRows;

    // --- STOCK ---
    final stockSnap =
        await FirebaseFirestore.instance.collection('conditionnement').get();
    int brut = 0, semiFini = 0, finiKoudougou = 0, finiOuaga = 0;
    String uniteBrut = "kg",
        uniteSemiFini = "kg",
        uniteFiniKdg = "litres",
        uniteFiniOuaga = "kg";
    List stockRows = [];
    for (final doc in stockSnap.docs) {
      final lot = doc.data();
      String date = "";
      if (lot["date"] is Timestamp) {
        date = DateFormat('dd/MM/yyyy')
            .format((lot["date"] as Timestamp).toDate());
      }
      String produit = lot["predominanceFlorale"] ?? "";
      int quantite =
          int.tryParse(lot["quantiteRestante"]?.toString() ?? "") ?? 0;
      String localite = lot["localite"] ?? "";
      String magasin = lot["magasin"] ?? "";
      String unite = "kg";
      stockRows.add({
        "date": date,
        "produit": produit,
        "quantite": quantite,
        "unite": unite,
        "localite": localite,
        "magasin": magasin
      });
      if ((magasin.toLowerCase() == "koudougou" ||
          localite.toLowerCase() == "koudougou")) {
        finiKoudougou += quantite;
      } else if ((magasin.toLowerCase() == "ouagadougou" ||
          localite.toLowerCase() == "ouagadougou")) {
        finiOuaga += quantite;
      } else {
        brut += quantite;
      }
    }
    stats["stock"] = {
      "brut": brut,
      "semi_fini": semiFini,
      "fini": {
        "koudougou": {"valeur": finiKoudougou, "unite": uniteFiniKdg},
        "ouaga": {"valeur": finiOuaga, "unite": uniteFiniOuaga},
      }
    };
    stats["stockRows"] = stockRows;

    // Alertes
    stats["alertes"] = [
      if (brut < 20)
        {"type": "Stock bas", "message": "Stock brut inférieur à 20kg"},
      if (vCredit > 0)
        {
          "type": "Crédit en attente",
          "message": "Il y a des crédits non réglés"
        },
      if ((semiFini + brut + finiKoudougou + finiOuaga) == 0)
        {"type": "Anomalie", "message": "Aucun stock enregistré"},
    ];

    setState(() {
      statsData = stats;
      loadingStats = false;
    });
  }

  void _onModuleSelected(String module) {
    Get.snackbar(
      "Navigation",
      "Aller au module $module",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.amber[100],
      duration: Duration(seconds: 1),
    );
    String route = "";
    switch (module.toLowerCase()) {
      case "collecte":
        route = "/collecte";
        break;
      case "controle":
        route = "/controle";
        break;
      case "extraction":
        route = "/extraction";
        break;
      case "filtrage":
        route = "/filtrage";
        break;
      case "conditionnement":
        route = "/conditionnement";
        break;
      case "gestion de ventes":
        route = "/gestion_de_ventes";
        break;
      case "ventes":
        route = "/ventes";
        break;
      case "stock":
        route = "/stock";
        break;
      case "rapports":
        route = "/rapports";
        break;
      default:
        route = "/";
    }
    if (route.isNotEmpty) {
      Get.toNamed(route);
    }
  }

  void _onSettings() {
    Get.snackbar(
      "Paramètres",
      "Ici tu peux gérer les paramètres de l'application.",
      backgroundColor: Colors.blue[100],
      snackPosition: SnackPosition.BOTTOM,
      duration: Duration(seconds: 1),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final userSession = Get.find<UserSession>();
    final role = userSession.role ?? "";
    final isAdmin = role.toLowerCase() == "admin";
    final allowedModules = roleModules[role] ?? [];

    final navButtons = [
      _headerBtn("collecte", Icons.api, () => _onModuleSelected("collecte"),
          enabled: isAdmin || allowedModules.contains("collecte")),
      _headerBtn(
          "controle", Icons.verified, () => _onModuleSelected("controle"),
          enabled: isAdmin || allowedModules.contains("controle")),
      _headerBtn(
          "extraction", Icons.science, () => _onModuleSelected("extraction"),
          enabled: isAdmin || allowedModules.contains("extraction")),
      _headerBtn("filtrage", Icons.science, () => _onModuleSelected("filtrage"),
          enabled: isAdmin || allowedModules.contains("filtrage")),
      _headerBtn("conditionnement", Icons.science,
          () => _onModuleSelected("conditionnement"),
          enabled: isAdmin || allowedModules.contains("conditionnement")),
      _headerBtn("gestion de ventes", Icons.science,
          () => _onModuleSelected("gestion de ventes"),
          enabled: isAdmin || allowedModules.contains("gestion de ventes")),
      _headerBtn(
          "ventes", Icons.shopping_cart, () => _onModuleSelected("ventes"),
          enabled: isAdmin || allowedModules.contains("ventes")),
      _headerBtn("stock", Icons.storage, () => _onModuleSelected("stock"),
          enabled: isAdmin || allowedModules.contains("stock")),
      _headerBtn(
          "rapports", Icons.bar_chart, () => _onModuleSelected("rapports"),
          enabled: isAdmin || allowedModules.contains("rapports")),
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      color: Colors.amber[50],
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                "assets/logo/logo.jpeg",
                width: 60,
                height: 60,
              ),
              SizedBox(width: 10),
              Text(
                "Apisavana",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber[900],
                  fontSize: 22,
                  letterSpacing: 2,
                ),
              )
            ],
          ),
          Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (userSession.photoUrl != null)
                CircleAvatar(
                  backgroundImage: NetworkImage(userSession.photoUrl!),
                  radius: 17,
                  backgroundColor: Colors.amber[100],
                )
              else
                CircleAvatar(
                  radius: 17,
                  backgroundColor: Colors.amber[100],
                  child: Icon(Icons.person, color: Colors.amber[800], size: 18),
                ),
              SizedBox(width: 7),
              Text(
                "${userSession.nom ?? ''} (${userSession.role ?? ''})",
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
              ),
              SizedBox(width: 16),
            ],
          ),
          if (isLargeScreen)
            Expanded(
              flex: 8,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...navButtons,
                    SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.settings, color: Colors.blueGrey[900]),
                      tooltip: "Paramètres",
                      onPressed: _onSettings,
                      splashRadius: 22,
                    ),
                    SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.logout, color: Colors.red[900]),
                      tooltip: "Déconnexion",
                      onPressed: () => Get.offAllNamed('/login'),
                      splashRadius: 22,
                    ),
                  ],
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.menu, color: Colors.amber[900], size: 32),
              tooltip: "Menu",
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              splashRadius: 28,
            ),
        ],
      ),
    );
  }

  Widget _headerBtn(String label, IconData icon, VoidCallback onPressed,
      {bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: TextButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon,
            color: enabled ? Colors.amber[900] : Colors.grey[400], size: 21),
        label: Text(
          label,
          style: TextStyle(
              color: enabled ? Colors.amber[900] : Colors.grey[400],
              fontWeight: FontWeight.w600,
              fontSize: 14),
        ),
        style: TextButton.styleFrom(
          foregroundColor: enabled ? Colors.amber[900] : Colors.grey[400],
          backgroundColor:
              enabled ? Colors.amber[100]?.withOpacity(0.4) : Colors.grey[200],
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          shape: StadiumBorder(),
        ),
      ),
    );
  }

  Widget _buildDrawerMenu() {
    final userSession = Get.find<UserSession>();
    final role = userSession.role ?? "";
    final isAdmin = role.toLowerCase() == "admin";
    final allowedModules = roleModules[role] ?? [];
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.amber[100]),
            child: Row(
              children: [
                Image.asset("assets/logo/logo.jpeg", width: 40, height: 40),
                SizedBox(width: 90),
                Text(
                  "Apisavana",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber[900],
                      fontSize: 22),
                ),
              ],
            ),
          ),
          _drawerItem("Collecte", Icons.api, "collecte",
              isAdmin || allowedModules.contains("collecte")),
          _drawerItem("Contrôle", Icons.verified, "controle",
              isAdmin || allowedModules.contains("controle")),
          _drawerItem("Extraction", Icons.science, "extraction",
              isAdmin || allowedModules.contains("extraction")),
          _drawerItem("Filtrage", Icons.science, "filtrage",
              isAdmin || allowedModules.contains("filtrage")),
          _drawerItem("Conditionnement", Icons.science, "conditionnement",
              isAdmin || allowedModules.contains("conditionnement")),
          _drawerItem("Gestion de ventes", Icons.science, "gestion de ventes",
              isAdmin || allowedModules.contains("gestion de ventes")),
          _drawerItem("Ventes", Icons.shopping_cart, "ventes",
              isAdmin || allowedModules.contains("ventes")),
          _drawerItem("Stock", Icons.storage, "stock",
              isAdmin || allowedModules.contains("stock")),
          _drawerItem("Rapports", Icons.bar_chart, "rapports",
              isAdmin || allowedModules.contains("rapports")),
          Divider(),
          ListTile(
            leading: Icon(Icons.settings, color: Colors.blueGrey[900]),
            title: Text("Paramètres"),
            onTap: _onSettings,
          ),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red[900]),
            title: Text("Déconnexion"),
            onTap: () => Get.offAllNamed('/login'),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(String title, IconData icon, String module, bool enabled) {
    return ListTile(
      leading:
          Icon(icon, color: enabled ? Colors.amber[900] : Colors.grey[400]),
      title: Text(
        title,
        style: TextStyle(
          color: enabled ? Colors.amber[900] : Colors.grey[400],
          fontWeight: FontWeight.w500,
        ),
      ),
      enabled: enabled,
      onTap: enabled ? () => _onModuleSelected(module) : null,
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12.0, top: 24.0),
        child: Text(
          text,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      );

  Widget _dashboardCard(
      {required String label,
      required List<Widget> children,
      required IconData icon,
      bool enabled = true,
      void Function()? onTap}) {
    return FadeTransition(
      opacity: _fadeInAnimation,
      child: MouseRegion(
        cursor:
            enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            margin: EdgeInsets.symmetric(vertical: 7.0, horizontal: 3.0),
            decoration: BoxDecoration(
              color: enabled ? Colors.white : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.08),
                  offset: Offset(0, 5),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Opacity(
              opacity: enabled ? 1.0 : 0.5,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedScale(
                      scale: 1.1,
                      duration: Duration(milliseconds: 300),
                      child: Icon(icon, size: 36, color: Colors.amber[800]),
                    ),
                    SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          ...children,
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: Colors.amber[800], size: 28)
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, bottom: 2.0),
      child: Row(
        children: [
          Text(
            "$label : ",
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          AnimatedSwitcher(
            duration: Duration(milliseconds: 350),
            child: Text(
              value,
              key: ValueKey(value),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map alerte) {
    Color color;
    IconData icon;
    if (alerte["type"] == "Stock bas") {
      color = Colors.orange[200]!;
      icon = Icons.warning_amber_rounded;
    } else if (alerte["type"] == "Crédit en attente") {
      color = Colors.red[100]!;
      icon = Icons.money_off;
    } else {
      color = Colors.red[50]!;
      icon = Icons.error_outline;
    }
    return FadeTransition(
      opacity: _fadeInAnimation,
      child: Card(
        color: color,
        child: ListTile(
          leading: Icon(icon, color: Colors.red[700]),
          title: Text(
            alerte["type"],
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(alerte["message"]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userSession = Get.find<UserSession>();
    final role = userSession.role ?? "";
    final isAdmin = role.toLowerCase() == "admin";
    final allowedModules = roleModules[role] ?? [];

    final cards = [
      _dashboardCard(
        label: "Quantités de miel collectées",
        children: [
          _infoRow(
              "Récolte",
              loadingStats
                  ? "..."
                  : "${statsData["collecte"]?["recolte"]["valeur"] ?? 0} ${statsData["collecte"]?["recolte"]["unite"] ?? ""}"),
          _infoRow(
              "Achat",
              loadingStats
                  ? "..."
                  : "${statsData["collecte"]?["achat"]["valeur"] ?? 0} ${statsData["collecte"]?["achat"]["unite"] ?? ""}"),
          ElevatedButton.icon(
            onPressed: loadingStats ? null : () => exportPDF("collecte"),
            icon: Icon(Icons.picture_as_pdf),
            label: Text("Exporter PDF"),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[100],
                foregroundColor: Colors.amber[900],
                elevation: 0),
          ),
        ],
        icon: Icons.api,
        enabled: isAdmin || allowedModules.contains("collecte"),
        onTap: (isAdmin || allowedModules.contains("collecte"))
            ? () => _onModuleSelected("collecte")
            : null,
      ),
      _dashboardCard(
        label: "Ventes",
        children: [
          _infoRow(
              "Comptant",
              loadingStats
                  ? "..."
                  : "${statsData["ventes"]?["comptant"]["valeur"] ?? 0} ${statsData["ventes"]?["comptant"]["unite"] ?? ""}"),
          _infoRow(
              "Crédit",
              loadingStats
                  ? "..."
                  : "${statsData["ventes"]?["credit"]["valeur"] ?? 0} ${statsData["ventes"]?["credit"]["unite"] ?? ""}"),
          _infoRow(
              "Recouvrement",
              loadingStats
                  ? "..."
                  : "${statsData["ventes"]?["recouvrement"]["valeur"] ?? 0} ${statsData["ventes"]?["recouvrement"]["unite"] ?? ""}"),
          ElevatedButton.icon(
            onPressed: loadingStats ? null : () => exportPDF("ventes"),
            icon: Icon(Icons.picture_as_pdf),
            label: Text("Exporter PDF"),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[100],
                foregroundColor: Colors.amber[900],
                elevation: 0),
          ),
        ],
        icon: Icons.shopping_cart,
        enabled: isAdmin ||
            allowedModules.contains("gestion de ventes") ||
            allowedModules.contains("ventes"),
        onTap: (isAdmin ||
                allowedModules.contains("gestion de ventes") ||
                allowedModules.contains("ventes"))
            ? () => _onModuleSelected("ventes")
            : null,
      ),
      _dashboardCard(
        label: "Stock disponible",
        children: [
          _infoRow("Matière première (Miel brut)",
              loadingStats ? "..." : "${statsData["stock"]?["brut"] ?? 0} kg"),
          _infoRow(
              "Produit fini Koudougou",
              loadingStats
                  ? "..."
                  : "${statsData["stock"]?["fini"]["koudougou"]["valeur"] ?? 0} ${statsData["stock"]?["fini"]["koudougou"]["unite"] ?? ""}"),
          _infoRow(
              "Produit fini Ouagadougou",
              loadingStats
                  ? "..."
                  : "${statsData["stock"]?["fini"]["ouaga"]["valeur"] ?? 0} ${statsData["stock"]?["fini"]["ouaga"]["unite"] ?? ""}"),
          ElevatedButton.icon(
            onPressed: loadingStats ? null : () => exportPDF("stock"),
            icon: Icon(Icons.picture_as_pdf),
            label: Text("Exporter PDF"),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[100],
                foregroundColor: Colors.amber[900],
                elevation: 0),
          ),
        ],
        icon: Icons.storage,
        enabled: isAdmin || allowedModules.contains("stock"),
        onTap: (isAdmin || allowedModules.contains("stock"))
            ? () => _onModuleSelected("stock")
            : null,
      ),
    ];

    return Scaffold(
      key: _scaffoldKey,
      drawer: isLargeScreen ? null : _buildDrawerMenu(),
      backgroundColor: Colors.amber[50],
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: FadeTransition(
              opacity: _fadeInAnimation,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 1100),
                  child: loadingStats
                      ? Center(child: CircularProgressIndicator())
                      : ListView(
                          padding: EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          children: [
                            _sectionTitle("Résumé des informations clés"),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                int crossAxisCount = constraints.maxWidth > 900
                                    ? 2
                                    : constraints.maxWidth > 600
                                        ? 1
                                        : 1;
                                return Wrap(
                                  spacing: 24,
                                  runSpacing: 18,
                                  children: List.generate(
                                    cards.length,
                                    (i) => SizedBox(
                                      width: constraints.maxWidth /
                                              crossAxisCount -
                                          (crossAxisCount == 2 ? 24 : 0),
                                      child: cards[i],
                                    ),
                                  ),
                                );
                              },
                            ),
                            _sectionTitle("Alertes"),
                            ...List.generate(
                              (statsData["alertes"] ?? []).length,
                              (i) => _buildAlertCard(statsData["alertes"][i]),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
