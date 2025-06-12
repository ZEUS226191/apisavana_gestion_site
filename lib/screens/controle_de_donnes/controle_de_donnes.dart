import 'package:apisavana_gestion/controllers/controle_donnes_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'delyed_animation.dart';

class ControlePage extends StatefulWidget {
  ControlePage({super.key});
  @override
  State<ControlePage> createState() => _ControlePageState();
}

class _ControlePageState extends State<ControlePage>
    with SingleTickerProviderStateMixin {
  final ControleController c = Get.put(ControleController());
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _slideAnim = Tween<Offset>(
      begin: Offset(0, 0.48),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: "Retour au Dashboard",
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Get.offAllNamed('/dashboard'),
          ),
          title: Text("Contrôle et Réception"),
          backgroundColor: Colors.amber[800],
          elevation: 4,
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.amber[200],
            tabs: [
              Tab(
                icon: Icon(Icons.eco_rounded),
                text: "Récolte",
              ),
              Tab(
                icon: Icon(Icons.groups_2_rounded),
                text: "Achat SCOOPS",
              ),
              Tab(
                icon: Icon(Icons.person_rounded),
                text: "Achat Individuel",
              ),
            ],
          ),
        ),
        backgroundColor: Colors.amber[50],
        body: Obx(() {
          if (c.isLoading.value) {
            return Center(
              child: CircularProgressIndicator(
                color: Colors.amber[800],
                strokeWidth: 4,
              ),
            );
          }
          return TabBarView(
            children: [
              _buildCollecteSectionWithImage(
                c.recoltes,
                "Récolte",
                Icons.eco_rounded,
                Colors.green[400],
                context,
                _controller,
                _fadeAnim,
                _slideAnim,
              ),
              _buildCollecteSectionWithImage(
                c.achatsScoops,
                "Achat - SCOOPS",
                Icons.groups_2_rounded,
                Colors.orange[200],
                context,
                _controller,
                _fadeAnim,
                _slideAnim,
              ),
              _buildCollecteSectionWithImage(
                c.achatsIndividuels,
                "Achat - Individuel",
                Icons.person_rounded,
                Colors.blue[100],
                context,
                _controller,
                _fadeAnim,
                _slideAnim,
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// Ajoute l'image en haut, elle scrolle avec les cards, animée slide+fade, responsive.
Widget _buildCollecteSectionWithImage(
  RxList<Map> list,
  String type,
  IconData icon,
  Color? color,
  BuildContext context,
  AnimationController controller,
  Animation<double> fadeAnim,
  Animation<Offset> slideAnim,
) {
  return SingleChildScrollView(
    padding: EdgeInsets.all(18),
    child: Column(
      children: [
        // ------- IMAGE ANIMÉE EN SLIDE+FADE --------
        AnimatedBuilder(
          animation: controller,
          builder: (context, child) => SlideTransition(
            position: slideAnim,
            child: FadeTransition(
              opacity: fadeAnim,
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxHeight: 220,
                  minHeight: 110,
                ),
                margin: EdgeInsets.only(bottom: 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset(
                    'assets/images/controle.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ),
        // ------- FIN IMAGE ---------
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.all(28.0),
            child: Text(
              "Aucune collecte à afficher.",
              style: TextStyle(color: Colors.grey[600], fontSize: 18),
            ),
          )
        else
          ...list
              .asMap()
              .entries
              .map((entry) => DelayedAnimatedCard(
                    delay: entry.key * 80,
                    child: _carteCollecte(
                      context: context,
                      collecte: entry.value,
                      type: type,
                      icon: icon,
                      color: color,
                      onControle: () => Get.find<ControleController>()
                          .goToControle(context, entry.value, type),
                    ),
                  ))
              .toList(),
      ],
    ),
  );
}

Widget _carteCollecte({
  required BuildContext context,
  required Map collecte,
  required String type,
  required IconData icon,
  required Color? color,
  required VoidCallback onControle,
}) {
  return MouseRegion(
    cursor: SystemMouseCursors.click,
    child: Card(
      elevation: 6,
      shadowColor: color?.withOpacity(0.25),
      margin: EdgeInsets.symmetric(vertical: 12, horizontal: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
            color: color?.withOpacity(0.2) ?? Colors.amber, width: 1.2),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (color ?? Colors.amber).withOpacity(0.11),
              Colors.white,
            ],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color ?? Colors.amber,
                  child: Icon(icon, color: Colors.white, size: 22),
                  radius: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "${collecte['producteurNom'] ?? 'Producteur inconnu'}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18.5,
                      color: Colors.grey[900],
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color?.withOpacity(0.23),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      color: color ?? Colors.amber[800],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              ],
            ),
            Divider(
                height: 22, thickness: 1.1, color: color?.withOpacity(0.18)),
            Wrap(
              spacing: 30,
              runSpacing: 6,
              children: [
                _infoChip("Type producteur", collecte['producteurType']),
                _infoChip("Village", collecte['village']),
                _infoChip(
                    "Date collecte", _formatDate(collecte['dateCollecte'])),
                _infoChip("Produit", collecte['typeProduit']),
                _infoChip(
                    "Quantité", "${collecte['quantite']} ${collecte['unite']}"),
                _infoChip(
                    "Prix unitaire",
                    collecte['prixUnitaire'] != null
                        ? "${collecte['prixUnitaire']} F"
                        : null),
                _infoChip(
                    "Prix total",
                    collecte['prixTotal'] != null
                        ? "${collecte['prixTotal']} F"
                        : null),
                _infoChip("Florale", collecte['predominanceFlorale']),
              ].where((w) => w != null).toList().cast<Widget>(),
            ),
            SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: Icon(Icons.assignment_turned_in_rounded,
                    color: Colors.white),
                label: Text("Procéder au contrôle"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color ?? Colors.amber[800],
                  foregroundColor: Colors.white,
                  textStyle:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                  shadowColor: color,
                ),
                onPressed: onControle,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget? _infoChip(String label, dynamic value) {
  if (value == null || (value is String && value.isEmpty)) return null;
  return Padding(
    padding: const EdgeInsets.only(bottom: 4.0),
    child: Chip(
      labelPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      label: Text.rich(
        TextSpan(
          children: [
            TextSpan(
                text: "$label: ",
                style: TextStyle(
                    color: Colors.grey[700], fontWeight: FontWeight.bold)),
            TextSpan(
                text: "$value",
                style: TextStyle(
                    color: Colors.black87, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
      backgroundColor: Colors.amber[50],
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.amber[100]!)),
    ),
  );
}

String _formatDate(dynamic date) {
  if (date == null) return "";
  if (date is DateTime) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }
  return date.toString();
}
