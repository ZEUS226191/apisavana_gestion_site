import 'package:apisavana_gestion/controllers/collecte_controller.dart';
import 'package:apisavana_gestion/data/geographe/geographie.dart';
import 'package:apisavana_gestion/screens/collecte_de_donnes/selecteur_florale.dart';
import 'package:apisavana_gestion/screens/collecte_de_donnes/widgets/validators.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'mes_collectes.dart';

class CollectePage extends StatelessWidget {
  final CollecteController c = Get.put(CollecteController());

  CollectePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: "Retour au Dashboard",
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Get.offAllNamed('/dashboard'),
        ),
        title: Text("Collecte de miel"),
        backgroundColor: Colors.amber[700],
        actions: [
          TextButton(
            onPressed: () {
              Get.to(() => MesCollectesPage());
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.amber[50],
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 4,
              shadowColor: Colors.amber[200],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.collections_bookmark, color: Colors.black),
                SizedBox(width: 10),
                Text("Voir mes collectes",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          )
        ],
      ),
      backgroundColor: Colors.amber[50],
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Obx(() {
                    String img = 'assets/images/colleccte.jpeg';
                    if (c.typeCollecte.value == TypeCollecte.recolte) {
                      img = 'assets/images/recolte.jpg';
                    } else if (c.typeCollecte.value == TypeCollecte.achat) {
                      img = 'assets/images/colleccte.jpeg';
                    }
                    return AnimatedSwitcher(
                      duration: Duration(milliseconds: 500),
                      switchInCurve: Curves.easeIn,
                      switchOutCurve: Curves.easeOut,
                      child: ClipRRect(
                        key: ValueKey(img),
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          img,
                          height: 400,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  }),
                ),
                SizedBox(height: 22),
                _formulaireCommun(),
                SizedBox(height: 24),
                Obx(() {
                  if (c.typeCollecte.value == TypeCollecte.recolte) {
                    return _formulaireRecolte(context);
                  }
                  if (c.typeCollecte.value == TypeCollecte.achat) {
                    return _formulaireAchat(context);
                  }
                  return SizedBox();
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _formulaireCommun() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: _datePickerField("Date de collecte", c.dateCollecte),
            ),
            SizedBox(width: 20),
            Expanded(
              child: Obx(() => DropdownButtonFormField<TypeCollecte>(
                    value: c.typeCollecte.value,
                    decoration: InputDecoration(labelText: "Type de collecte"),
                    items: [
                      DropdownMenuItem(
                        value: TypeCollecte.recolte,
                        child: Text("Récolte"),
                      ),
                      DropdownMenuItem(
                        value: TypeCollecte.achat,
                        child: Text("Achat"),
                      ),
                    ],
                    onChanged: (v) => c.typeCollecte.value = v,
                  )),
            ),
          ],
        ),
      ),
    );
  }

  // --- ACHAT > SCOOPS
  // --- ACHAT > SCOOPS

  List<String> _processSelection(dynamic selectedItems) {
    if (selectedItems is List<String>) return selectedItems;
    if (selectedItems is String) return [selectedItems];
    if (selectedItems is Iterable)
      return selectedItems.map((e) => e.toString()).toList();
    return [];
  }

  Widget _formulaireAchat(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Obx(() => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Origine", style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<OrigineAchat>(
                        title: Text("SCOOPS"),
                        value: OrigineAchat.scoops,
                        groupValue: c.origineAchat.value,
                        onChanged: (v) {
                          c.origineAchat.value = v;
                          c.isAddingSCOOPS.value = false;
                          // Reset selection uniquement ici
                          c.selectedSCOOPS.value = null;
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<OrigineAchat>(
                        title: Text("Individuel"),
                        value: OrigineAchat.individuel,
                        groupValue: c.origineAchat.value,
                        onChanged: (v) {
                          c.origineAchat.value = v;
                          c.isAddingIndividuel.value = false;
                          // Reset selection uniquement ici
                          c.selectedIndividuel.value = null;
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                if (c.origineAchat.value == OrigineAchat.scoops)
                  _formulaireAchatScoops(),
                if (c.origineAchat.value == OrigineAchat.individuel)
                  _formulaireAchatIndividuel(),
                SizedBox(
                  height: 10,
                ),
                boutonRetour(context),
              ],
            )),
      ),
    );
  }

  Widget _formulaireAchatIndividuel() {
    final c = Get.find<CollecteController>();
    final _formKey = GlobalKey<FormState>();

    return Obx(() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Recherche Producteur individuel ou Ajouter",
                style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: DropdownSearch<String>(
                    items: c.individuelsConnus,
                    selectedItem: c.selectedIndividuel.value,
                    onChanged: (v) {
                      c.selectedIndividuel.value = v;
                      c.isAddingIndividuel.value = false;
                    },
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(
                        labelText: "Sélectionner un producteur",
                        prefixIcon: Icon(Icons.person, color: Colors.green),
                      ),
                    ),
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(labelText: "Rechercher..."),
                      ),
                    ),
                    validator: (v) =>
                        v == null ? "Sélectionner un producteur" : null,
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton.icon(
                  icon: Icon(Icons.add),
                  label: Text("Ajouter Individuel"),
                  onPressed: () => c.isAddingIndividuel.value = true,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700]),
                ),
              ],
            ),
            if (c.isAddingIndividuel.value) _formulaireAjouterIndividuel(),
            if (c.selectedIndividuel.value != null &&
                !c.isAddingIndividuel.value)
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 22),
                    Text("Types de ruches",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8,
                      children: c.typesRuche.map((ruche) {
                        final isSelected =
                            c.typesRucheAchatIndivMulti.contains(ruche);
                        return CustomMultiSelectCard(
                          value: ruche,
                          label: ruche,
                          selected: isSelected,
                          onTap: () {
                            if (isSelected) {
                              c.typesRucheAchatIndivMulti.remove(ruche);
                              c.typesProduitAchatIndivMulti.remove(ruche);
                              c.achatsIndivParRucheProduit.remove(ruche);
                            } else {
                              c.typesRucheAchatIndivMulti.add(ruche);
                              c.typesProduitAchatIndivMulti
                                  .putIfAbsent(ruche, () => <String>[].obs);
                              c.achatsIndivParRucheProduit
                                  .putIfAbsent(ruche, () => {});
                            }
                          },
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 16),
                    ...c.typesRucheAchatIndivMulti.map((ruche) => Card(
                          color: Colors.amber[50],
                          elevation: 1,
                          margin: EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.house, color: Colors.amber[800]),
                                    SizedBox(width: 6),
                                    Text("Ruche : $ruche",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  children: c.typesProduit.map((produit) {
                                    final isSelected = (c
                                            .typesProduitAchatIndivMulti[ruche]
                                            ?.contains(produit)) ??
                                        false;
                                    return CustomMultiSelectCard(
                                      value: produit,
                                      label: produit,
                                      selected: isSelected,
                                      onTap: () {
                                        if (isSelected) {
                                          c.typesProduitAchatIndivMulti[ruche]
                                              ?.remove(produit);
                                          c.achatsIndivParRucheProduit[ruche]
                                              ?.remove(produit);
                                        } else {
                                          c.typesProduitAchatIndivMulti[
                                              ruche] ??= <String>[].obs;
                                          c.typesProduitAchatIndivMulti[ruche]!
                                              .add(produit);
                                          c.achatsIndivParRucheProduit[
                                              ruche] ??= {};
                                          c.achatsIndivParRucheProduit[ruche]![
                                                  produit] =
                                              AchatProduitData(
                                                  unite: _getUniteForProduct(
                                                      produit));
                                        }
                                      },
                                    );
                                  }).toList(),
                                ),
                                SizedBox(height: 8),
                                ...((c.typesProduitAchatIndivMulti[ruche]
                                            ?.toList() ??
                                        [])
                                    .map((produit) {
                                  final achat =
                                      c.achatsIndivParRucheProduit[ruche]
                                          ?[produit];
                                  if (achat == null) return SizedBox();
                                  return Card(
                                    color: Colors.teal[50],
                                    child: Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.liquor,
                                                  color: Colors.teal),
                                              SizedBox(width: 6),
                                              Text("Produit : $produit",
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ],
                                          ),
                                          SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: TextFormField(
                                                  decoration: InputDecoration(
                                                    labelText:
                                                        "Quantité acceptée",
                                                    prefixIcon: Icon(
                                                        Icons.check,
                                                        color: Colors.green),
                                                    suffixText: achat.unite,
                                                  ),
                                                  keyboardType:
                                                      TextInputType.number,
                                                  onChanged: (v) {
                                                    achat.quantiteAcceptee
                                                            .value =
                                                        double.tryParse(v) ?? 0;
                                                  },
                                                  validator: (v) {
                                                    if (v == null ||
                                                        v.isEmpty ||
                                                        double.tryParse(v) ==
                                                            null ||
                                                        double.tryParse(v)! <=
                                                            0) {
                                                      return "Obligatoire (> 0)";
                                                    }
                                                    return null;
                                                  },
                                                ),
                                              ),
                                              SizedBox(width: 10),
                                              Expanded(
                                                child: TextFormField(
                                                  decoration: InputDecoration(
                                                    labelText:
                                                        "Quantité rejetée",
                                                    prefixIcon: Icon(
                                                        Icons.close,
                                                        color: Colors.red),
                                                    suffixText: achat.unite,
                                                  ),
                                                  keyboardType:
                                                      TextInputType.number,
                                                  onChanged: (v) {
                                                    achat.quantiteRejetee
                                                            .value =
                                                        double.tryParse(v) ?? 0;
                                                  },
                                                  validator: (v) {
                                                    if (v == null ||
                                                        v.isEmpty ||
                                                        double.tryParse(v) ==
                                                            null ||
                                                        double.tryParse(v)! <
                                                            0) {
                                                      return "Obligatoire (>= 0)";
                                                    }
                                                    return null;
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: TextFormField(
                                                  decoration: InputDecoration(
                                                    labelText: "Prix unitaire",
                                                    prefixIcon: Icon(Icons.euro,
                                                        color: Colors.blue),
                                                  ),
                                                  keyboardType:
                                                      TextInputType.number,
                                                  onChanged: (v) {
                                                    achat.prixUnitaire.value =
                                                        double.tryParse(v) ?? 0;
                                                  },
                                                  validator: (v) {
                                                    if (v == null ||
                                                        v.isEmpty ||
                                                        double.tryParse(v) ==
                                                            null ||
                                                        double.tryParse(v)! <=
                                                            0) {
                                                      return "Obligatoire (> 0)";
                                                    }
                                                    return null;
                                                  },
                                                ),
                                              ),
                                              SizedBox(width: 10),
                                              Expanded(
                                                child: Obx(() => Text(
                                                      "Prix total : ${achat.prixTotal.value.toStringAsFixed(2)} ${achat.unite}",
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors
                                                              .green[700]),
                                                    )),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList()),
                              ],
                            ),
                          ),
                        )),
                    SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.save),
                        label: Text("Enregistrer la collecte"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[700],
                        ),
                        onPressed: () async {
                          // Validation stricte avant enregistrement
                          if (c.selectedIndividuel.value == null ||
                              c.selectedIndividuel.value!.isEmpty) {
                            showFieldError("Erreur",
                                "Sélectionnez un producteur individuel !");
                            return;
                          }

                          bool atLeastOneProduit = false;
                          for (final ruche in c.typesRucheAchatIndivMulti) {
                            for (final produit
                                in c.typesProduitAchatIndivMulti[ruche] ?? []) {
                              atLeastOneProduit = true;
                              final achat =
                                  c.achatsIndivParRucheProduit[ruche]?[produit];
                              if (achat == null) continue;

                              if (achat.quantiteAcceptee.value.isNaN ||
                                  achat.quantiteAcceptee.value <= 0) {
                                showFieldError("Erreur quantité",
                                    "La quantité acceptée doit être > 0 pour '$produit' ($ruche)");
                                return;
                              }
                              if (achat.quantiteRejetee.value.isNaN ||
                                  achat.quantiteRejetee.value < 0) {
                                showFieldError("Erreur quantité",
                                    "La quantité rejetée doit être >= 0 pour '$produit' ($ruche)");
                                return;
                              }
                              if (achat.prixUnitaire.value.isNaN ||
                                  achat.prixUnitaire.value <= 0) {
                                showFieldError("Erreur prix",
                                    "Le prix unitaire doit être > 0 pour '$produit' ($ruche)");
                                return;
                              }
                            }
                          }
                          if (!atLeastOneProduit) {
                            showFieldError(
                                "Erreur", "Ajoutez au moins un produit !");
                            return;
                          }

                          final snapshot = await FirebaseFirestore.instance
                              .collection('Individuels')
                              .where('nomPrenom',
                                  isEqualTo: c.selectedIndividuel.value)
                              .limit(1)
                              .get();

                          if (snapshot.docs.isEmpty) {
                            showFieldError("Erreur", "Individuel non trouvé !");
                            return;
                          }

                          final individuelInfo = snapshot.docs.first.data();

                          final achatDetails = c.generateAchatIndivData();

                          await c.enregistrerCollecteAchat(
                            isScoops: false,
                            achatDetails: achatDetails,
                            fournisseurDetails: individuelInfo,
                          );
                          Get.snackbar("Succès", "Collecte enregistrée !");
                          c.selectedIndividuel.value = null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ));
  }

  Widget _formulaireAchatScoops() {
    final c = Get.find<CollecteController>();
    final _formKey = GlobalKey<FormState>();

    return Obx(() {
      if (c.typesRuche.isEmpty || c.typesProduit.isEmpty) {
        return Center(child: CircularProgressIndicator());
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PARTIE 1: Sélection/Ajout SCOOPS
          Text("Rechercher SCOOPS ou Ajouter SCOOPS",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownSearch<String>(
                  items: c.scoopsConnues,
                  selectedItem: c.selectedSCOOPS.value,
                  onChanged: (v) {
                    if (v == null) return;
                    if (c.typesRucheAchatScoopsMulti.isNotEmpty ||
                        c.typesProduitAchatScoopsMulti.isNotEmpty) {
                      Get.defaultDialog(
                        title: "Changement SCOOPS",
                        content: Text(
                            "Les données actuelles seront perdues. Continuer?"),
                        actions: [
                          TextButton(
                              onPressed: () => Get.back(),
                              child: Text("Annuler")),
                          TextButton(
                            onPressed: () {
                              Get.back();
                              _resetForm(c);
                              c.selectedSCOOPS.value = v;
                            },
                            child: Text("Confirmer"),
                          ),
                        ],
                      );
                    } else {
                      _resetForm(c);
                      c.selectedSCOOPS.value = v;
                    }
                  },
                  dropdownDecoratorProps: DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(
                      labelText: "Sélectionner une SCOOPS",
                      prefixIcon: Icon(Icons.apartment, color: Colors.green),
                    ),
                  ),
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                      decoration: InputDecoration(
                        labelText: "Rechercher...",
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  validator: (v) => v == null ? "Sélection obligatoire" : null,
                ),
              ),
              SizedBox(width: 10),
              ElevatedButton.icon(
                icon: Icon(Icons.add),
                label: Text("Nouvelle SCOOPS"),
                onPressed: () {
                  if (c.typesRucheAchatScoopsMulti.isNotEmpty) {
                    Get.snackbar("Attention",
                        "Veuillez d'abord terminer ou annuler la saisie en cours");
                    return;
                  }
                  c.isAddingSCOOPS.value = true;
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  padding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                ),
              ),
            ],
          ),
          SizedBox(height: 15),

          if (c.isAddingSCOOPS.value) ...[
            _formulaireAjouterScoops(),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => c.isAddingSCOOPS.value = false,
              child: Text("Annuler l'ajout"),
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.grey[400]),
            ),
            Divider(thickness: 2),
          ],

          if (c.selectedSCOOPS.value != null && !c.isAddingSCOOPS.value) ...[
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 20),
                  Text("Types de ruches",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: c.typesRuche.map((ruche) {
                      final isSelected =
                          c.typesRucheAchatScoopsMulti.contains(ruche);
                      return CustomMultiSelectCard(
                        value: ruche,
                        label: ruche,
                        selected: isSelected,
                        onTap: () {
                          if (isSelected) {
                            c.typesRucheAchatScoopsMulti.remove(ruche);
                            c.typesProduitAchatScoopsMulti.remove(ruche);
                            c.achatsParRucheProduit.remove(ruche);
                          } else {
                            c.typesRucheAchatScoopsMulti.add(ruche);
                            c.typesProduitAchatScoopsMulti
                                .putIfAbsent(ruche, () => <String>[].obs);
                            c.achatsParRucheProduit
                                .putIfAbsent(ruche, () => {});
                          }
                        },
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 25),
                  ...c.typesRucheAchatScoopsMulti.map(
                    (ruche) => _buildRucheCard(c, ruche, key: ValueKey(ruche)),
                  ),
                  if (c.typesRucheAchatScoopsMulti.isNotEmpty) ...[
                    SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.save),
                        label: Text("Enregistrer la collecte"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[700],
                          padding: EdgeInsets.symmetric(
                              vertical: 15, horizontal: 20),
                        ),
                        onPressed: () async {
                          // Vérification des champs requis
                          if (c.selectedSCOOPS.value == null ||
                              c.selectedSCOOPS.value!.isEmpty) {
                            Get.snackbar("Erreur", "Sélectionnez une SCOOPS!");
                            return;
                          }

                          // Exemples de validation AVANT toute sauvegarde
                          if (!validateDropdown(
                              c.selectedSCOOPS.value, "SCOOPS")) return;

                          for (final ruche in c.typesRucheAchatScoopsMulti) {
                            for (final produit
                                in c.typesProduitAchatScoopsMulti[ruche] ??
                                    []) {
                              final achat =
                                  c.achatsParRucheProduit[ruche]?[produit];
                              if (achat == null) continue;

                              if (!validateDouble(
                                  achat.quantiteAcceptee.value.toString(),
                                  "Quantité acceptée pour $produit ($ruche)"))
                                return;
                              if (!validateDouble(
                                  achat.quantiteRejetee.value.toString(),
                                  "Quantité rejetée pour $produit ($ruche)"))
                                return;
                              if (!validateDouble(
                                  achat.prixUnitaire.value.toString(),
                                  "Prix unitaire pour $produit ($ruche)"))
                                return;
                            }
                          }

                          // Vérifier qu'au moins un produit est saisi
                          bool hasProducts = false;
                          for (final ruche in c.typesRucheAchatScoopsMulti) {
                            if (c.typesProduitAchatScoopsMulti[ruche]
                                    ?.isNotEmpty ??
                                false) {
                              hasProducts = true;
                              break;
                            }
                          }
                          if (!hasProducts) {
                            Get.snackbar(
                                "Erreur", "Ajoutez au moins un produit!");
                            return;
                          }

                          // Validation de chaque achat produit
                          for (final ruche in c.typesRucheAchatScoopsMulti) {
                            for (final produit
                                in c.typesProduitAchatScoopsMulti[ruche] ??
                                    []) {
                              final achat =
                                  c.achatsParRucheProduit[ruche]?[produit];
                              if (achat == null) continue;

                              if (achat.quantiteAcceptee.value.isNaN ||
                                  achat.quantiteAcceptee.value <= 0) {
                                showFieldError(
                                  "Erreur quantité",
                                  "La quantité acceptée doit être > 0 pour '$produit' ($ruche)",
                                );
                                return;
                              }
                              if (achat.quantiteRejetee.value.isNaN ||
                                  achat.quantiteRejetee.value < 0) {
                                showFieldError(
                                  "Erreur quantité",
                                  "La quantité rejetée doit être >= 0 pour '$produit' ($ruche)",
                                );
                                return;
                              }
                              if (achat.prixUnitaire.value.isNaN ||
                                  achat.prixUnitaire.value <= 0) {
                                showFieldError(
                                  "Erreur prix",
                                  "Le prix unitaire doit être > 0 pour '$produit' ($ruche)",
                                );
                                return;
                              }
                            }
                          }

                          if (!hasProducts) {
                            showFieldError(
                                "Erreur", "Ajoutez au moins un produit !");
                            return;
                          }

                          // Vérifier existence de la SCOOPS dans Firestore
                          final snapshot = await FirebaseFirestore.instance
                              .collection('SCOOPS')
                              .where('nom', isEqualTo: c.selectedSCOOPS.value)
                              .limit(1)
                              .get();

                          if (snapshot.docs.isEmpty) {
                            Get.snackbar(
                                "Erreur", "SCOOPS non trouvée en base!");
                            return;
                          }

                          // Générer les données à enregistrer
                          final scoopsInfo = snapshot.docs.first.data();
                          final achatDetails = c.generateAchatScoopsData();

                          // Appel de la méthode du controller pour enregistrer dans Firestore
                          await c.enregistrerCollecteAchat(
                            isScoops: true,
                            achatDetails: achatDetails,
                            fournisseurDetails: scoopsInfo,
                          );
                          // Le controller s'occupe du reset et de la notification de succès/erreur
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    });
  }

  Widget _buildRucheCard(CollecteController c, String ruche, {Key? key}) {
    return Card(
      key: key,
      color: Colors.amber[50],
      margin: EdgeInsets.only(bottom: 20),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.hive, color: Colors.amber[800], size: 28),
                SizedBox(width: 10),
                Text("Ruche: $ruche",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.red),
                  onPressed: () {
                    Get.defaultDialog(
                      title: "Confirmer la suppression",
                      content: Text(
                          "Supprimer cette ruche et ses produits associés?"),
                      actions: [
                        TextButton(
                          onPressed: () => Get.back(),
                          child: Text("Annuler"),
                        ),
                        TextButton(
                          onPressed: () {
                            Get.back();
                            c.typesRucheAchatScoopsMulti.remove(ruche);
                            c.typesProduitAchatScoopsMulti.remove(ruche);
                            c.achatsParRucheProduit.remove(ruche);
                          },
                          child: Text("Confirmer",
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    );
                  },
                  tooltip: "Supprimer cette ruche",
                ),
              ],
            ),
            Divider(color: Colors.amber[300]),
            SizedBox(height: 10),
            Text("Sélectionnez les produits pour cette ruche:",
                style: TextStyle(fontWeight: FontWeight.w500)),
            SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: c.typesProduit.map((produit) {
                final isSelected = (c.typesProduitAchatScoopsMulti[ruche]
                        ?.contains(produit)) ??
                    false;
                return CustomMultiSelectCard(
                  value: produit,
                  label: produit,
                  selected: isSelected,
                  onTap: () {
                    if (isSelected) {
                      c.typesProduitAchatScoopsMulti[ruche]?.remove(produit);
                      c.achatsParRucheProduit[ruche]?.remove(produit);
                    } else {
                      c.typesProduitAchatScoopsMulti[ruche] ??= <String>[].obs;
                      c.typesProduitAchatScoopsMulti[ruche]!.add(produit);
                      c.achatsParRucheProduit[ruche] ??= {};
                      c.achatsParRucheProduit[ruche]![produit] =
                          AchatProduitData(unite: _getUniteForProduct(produit));
                    }
                  },
                );
              }).toList(),
            ),
            SizedBox(height: 15),
            ..._buildProductForms(c, ruche),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildProductForms(CollecteController c, String ruche) {
    final produits = c.typesProduitAchatScoopsMulti[ruche] ?? [];
    return produits.map((produit) {
      final achat = c.achatsParRucheProduit[ruche]?[produit];
      if (achat == null) return SizedBox.shrink();

      return Card(
        color: Colors.teal[50],
        margin: EdgeInsets.only(bottom: 15),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.liquor, color: Colors.teal[700]),
                  SizedBox(width: 10),
                  Text(produit, style: TextStyle(fontWeight: FontWeight.bold)),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, size: 20),
                    onPressed: () {
                      c.typesProduitAchatScoopsMulti[ruche]?.remove(produit);
                      c.achatsParRucheProduit[ruche]?.remove(produit);
                    },
                    tooltip: "Suprimer cette selection",
                  ),
                ],
              ),
              Divider(color: Colors.teal[100]),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: "Quantité acceptée",
                        prefixIcon: Icon(Icons.check, color: Colors.green),
                        suffixText: achat.unite,
                      ),
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) {
                        final value = double.tryParse(v) ?? 0;
                        if (value < 0) return;
                        achat.quantiteAcceptee.value = value;
                        _updatePrixTotal(achat);
                      },
                    ),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: "Quantité rejetée",
                        prefixIcon: Icon(Icons.close, color: Colors.red),
                        suffixText: achat.unite,
                      ),
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) {
                        final value = double.tryParse(v) ?? 0;
                        if (value < 0) return;
                        achat.quantiteRejetee.value = value;
                        _updatePrixTotal(achat);
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: "Prix unitaire (€)",
                        prefixIcon: Icon(Icons.euro, color: Colors.blue),
                      ),
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) {
                        final value = double.tryParse(v) ?? 0;
                        if (value < 0) return;
                        achat.prixUnitaire.value = value;
                        _updatePrixTotal(achat);
                      },
                    ),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: Obx(() => Container(
                          padding: EdgeInsets.symmetric(
                              vertical: 15, horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            "Total: ${achat.prixTotal.value.toStringAsFixed(2)} €",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                                fontSize: 16),
                          ),
                        )),
                  ),
                ],
              ),
              SizedBox(height: 5),
            ],
          ),
        ),
      );
    }).toList();
  }

  String _getUniteForProduct(String produit) {
    if (produit.toLowerCase().contains('miel')) return 'kg';
    if (produit.toLowerCase().contains('cire')) return 'kg';
    return 'unité';
  }

  void _updatePrixTotal(AchatProduitData achat) {
    final net = achat.quantiteAcceptee.value - achat.quantiteRejetee.value;
    achat.prixTotal.value = (net > 0 ? net : 0) * achat.prixUnitaire.value;
  }
  ///////////////////////////////////////

  Widget _formulaireRecolte(BuildContext context) {
    final c = Get.find<CollecteController>();
    final formKey = GlobalKey<FormState>();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: Column(
            children: [
              // Technicien
              DropdownSearch<String>(
                items: c.techniciens,
                selectedItem: c.nomRecolteur.value,
                onChanged: (v) => c.nomRecolteur.value = v,
                validator: (v) =>
                    v == null ? "Sélectionner un technicien" : null,
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration:
                      InputDecoration(labelText: "Technicien"),
                ),
                popupProps: PopupProps.menu(
                  showSearchBox: true,
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(labelText: "Rechercher..."),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Région
              DropdownSearch<String>(
                items: regionsBurkina,
                selectedItem: c.region.value,
                onChanged: (v) {
                  c.region.value = v;
                  c.province.value = null;
                  c.commune.value = null;
                  c.village.value = null;
                  c.arrondissement.value = null;
                  c.secteur.value = null;
                  c.quartier.value = null;
                },
                validator: (v) => v == null ? "Sélectionner une région" : null,
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration:
                      InputDecoration(labelText: "Région"),
                ),
                popupProps: PopupProps.menu(
                  showSearchBox: true,
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(labelText: "Rechercher..."),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Province (filtrée par région)
              Obx(() {
                final provinces = c.getProvincesForRegion(c.region.value);
                return DropdownSearch<String>(
                  items: provinces,
                  selectedItem: c.province.value,
                  onChanged: (v) {
                    c.province.value = v;
                    c.commune.value = null;
                    c.village.value = null;
                    c.arrondissement.value = null;
                    c.secteur.value = null;
                    c.quartier.value = null;
                  },
                  validator: (v) =>
                      v == null ? "Sélectionner une province" : null,
                  dropdownDecoratorProps: DropDownDecoratorProps(
                    dropdownSearchDecoration:
                        InputDecoration(labelText: "Province"),
                  ),
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                      decoration: InputDecoration(labelText: "Rechercher..."),
                    ),
                  ),
                );
              }),
              SizedBox(height: 16),

              // Commune (filtrée par province)
              Obx(() {
                final communes = c.getCommunesForProvince(c.province.value);
                return DropdownSearch<String>(
                  items: communes,
                  selectedItem: c.commune.value,
                  onChanged: (v) {
                    c.commune.value = v;
                    c.village.value = null;
                    c.arrondissement.value = null;
                    c.secteur.value = null;
                    c.quartier.value = null;
                  },
                  validator: (v) =>
                      v == null ? "Sélectionner une commune" : null,
                  dropdownDecoratorProps: DropDownDecoratorProps(
                    dropdownSearchDecoration:
                        InputDecoration(labelText: "Commune"),
                  ),
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                      decoration: InputDecoration(labelText: "Rechercher..."),
                    ),
                  ),
                );
              }),
              SizedBox(height: 16),

              // Arrondissement + Secteur + Quartier pour Ouaga/Bobo
              Obx(() {
                if (c.commune.value == "Ouagadougou" ||
                    c.commune.value == "BOBO-DIOULASSO" ||
                    c.commune.value == "Bobo-Dioulasso") {
                  // Arrondissement
                  final arrondissements = ArrondissementsParCommune[
                          c.commune.value == "BOBO-DIOULASSO"
                              ? "Bobo-Dioulasso"
                              : c.commune.value!] ??
                      [];
                  return Column(
                    children: [
                      DropdownSearch<String>(
                        items: arrondissements,
                        selectedItem: c.arrondissement.value,
                        onChanged: (v) {
                          c.arrondissement.value = v;
                          c.secteur.value = null;
                          c.quartier.value = null;
                        },
                        validator: (v) =>
                            v == null ? "Sélectionner un arrondissement" : null,
                        dropdownDecoratorProps: DropDownDecoratorProps(
                          dropdownSearchDecoration:
                              InputDecoration(labelText: "Arrondissement"),
                        ),
                        popupProps: PopupProps.menu(
                          showSearchBox: true,
                          searchFieldProps: TextFieldProps(
                            decoration:
                                InputDecoration(labelText: "Rechercher..."),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Secteur
                      Obx(() {
                        if (c.arrondissement.value == null) return Container();
                        final key =
                            "${c.commune.value == "BOBO-DIOULASSO" ? "Bobo-Dioulasso" : c.commune.value}_${c.arrondissement.value}";
                        final secteurs =
                            secteursParArrondissement[key] ?? <String>[];
                        return DropdownSearch<String>(
                          items: secteurs,
                          selectedItem: c.secteur.value,
                          onChanged: (v) {
                            c.secteur.value = v;
                            c.quartier.value = null;
                          },
                          validator: (v) =>
                              v == null ? "Sélectionner un secteur" : null,
                          dropdownDecoratorProps: DropDownDecoratorProps(
                            dropdownSearchDecoration:
                                InputDecoration(labelText: "Secteur"),
                          ),
                          popupProps: PopupProps.menu(
                            showSearchBox: true,
                            searchFieldProps: TextFieldProps(
                              decoration:
                                  InputDecoration(labelText: "Rechercher..."),
                            ),
                          ),
                        );
                      }),
                      SizedBox(height: 16),

                      // Quartier (au lieu de village)
                      Obx(() {
                        if (c.secteur.value == null) return Container();
                        final key =
                            "${c.commune.value == "BOBO-DIOULASSO" ? "Bobo-Dioulasso" : c.commune.value}_${c.secteur.value}";
                        final quartiers = QuartierParSecteur[key] ?? <String>[];
                        return DropdownSearch<String>(
                          items: quartiers,
                          selectedItem: c.quartier.value,
                          onChanged: (v) => c.quartier.value = v,
                          validator: (v) =>
                              v == null ? "Sélectionner un quartier" : null,
                          dropdownDecoratorProps: DropDownDecoratorProps(
                            dropdownSearchDecoration:
                                InputDecoration(labelText: "Quartier"),
                          ),
                          popupProps: PopupProps.menu(
                            showSearchBox: true,
                            searchFieldProps: TextFieldProps(
                              decoration:
                                  InputDecoration(labelText: "Rechercher..."),
                            ),
                          ),
                        );
                      }),
                      SizedBox(height: 16),
                    ],
                  );
                } else {
                  // Village classique
                  final villages = c.getVillagesForCommune(c.commune.value);
                  return DropdownSearch<String>(
                    items: villages,
                    selectedItem: c.village.value,
                    onChanged: (v) => c.village.value = v,
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      dropdownSearchDecoration:
                          InputDecoration(labelText: "Village"),
                    ),
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      showSelectedItems: true,
                      searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(
                            labelText: "Rechercher ou saisir..."),
                      ),
                      emptyBuilder: (context, searchEntry) {
                        return ListTile(
                          title: Text('Ajouter "$searchEntry" comme village'),
                          onTap: () {
                            c.village.value = searchEntry;
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
                    validator: (v) => v == null || v.isEmpty
                        ? "Sélectionner ou saisir un village"
                        : null,
                  );
                }
              }),
              SizedBox(height: 16),

              // Quantité récoltée
              TextFormField(
                decoration: InputDecoration(
                    labelText: "Quantité (kg)",
                    suffixText: "kg",
                    prefixIcon: Icon(Icons.balance, color: Colors.brown[400])),
                keyboardType: TextInputType.number,
                onChanged: (v) => c.quantiteRecolte.value = double.tryParse(v),
                validator: (v) =>
                    v == null || v.isEmpty || double.tryParse(v) == null
                        ? "Obligatoire"
                        : null,
              ),
              SizedBox(height: 16),

              // Nombre de ruches récoltées
              TextFormField(
                decoration: InputDecoration(
                    labelText: "Nombre de ruches récoltées",
                    prefixIcon: Icon(Icons.hive_rounded, color: Colors.amber)),
                keyboardType: TextInputType.number,
                onChanged: (v) =>
                    c.nbRuchesRecoltees.value = int.tryParse(v ?? ""),
                validator: (v) =>
                    v == null || v.isEmpty || int.tryParse(v) == null
                        ? "Obligatoire"
                        : null,
              ),
              MultiSelectFlorale(c),
              SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  icon: Icon(Icons.save),
                  label: Text("Enregistrer la collecte"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[700]),
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      await c.enregistrerCollecteRecolte();
                      formKey.currentState?.reset();
                    } else {
                      Get.snackbar(
                          "Erreur", "Veuillez remplir tous les champs !");
                    }
                  },
                ),
              ),
              boutonRetour(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formulaireAjouterScoops() {
    final c = Get.find<CollecteController>();
    final _formKey = GlobalKey<FormState>();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.add_business, color: Colors.blue[800], size: 26),
                  SizedBox(width: 8),
                  Text("Ajouter une SCOOPS",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.blue[900])),
                ],
              ),
              SizedBox(height: 16),
              _textFieldWithIcon("Nom SCOOPS", c.nomScoopsAjout,
                  Icons.apartment, "Nom requis"),
              SizedBox(height: 12),
              _textFieldWithIcon("Nom du président", c.nomPresidentAjout,
                  Icons.person, "Président requis"),
              SizedBox(height: 12),
              TextFormField(
                controller: c.numeroPresidentCtrl,
                decoration: InputDecoration(
                  labelText: "Numéro du Président",
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (v) => v == null || v.isEmpty ? "Obligatoire" : null,
              ),
              SizedBox(height: 12),
              DropdownSearch<String>(
                items: regionsBurkina,
                selectedItem: c.regionScoopsAjout.value,
                onChanged: (v) {
                  c.regionScoopsAjout.value = v;
                  c.provinceScoopsAjout.value = null;
                  c.communeScoopsAjout.value = null;
                  c.arrondissementScoopsAjout.value = null;
                  c.secteurScoopsAjout.value = null;
                  c.quartierScoopsAjout.value = null;
                  c.villageScoopsAjout.value = null;
                },
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration:
                      InputDecoration(labelText: "Région"),
                ),
                popupProps: PopupProps.menu(
                  showSearchBox: true,
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(labelText: "Rechercher..."),
                  ),
                ),
                validator: (v) => v == null ? "Sélectionner une région" : null,
              ),
              SizedBox(height: 12),
              Obx(() {
                final provinces =
                    c.getProvincesForRegion(c.regionScoopsAjout.value);
                return DropdownSearch<String>(
                  items: provinces,
                  selectedItem: c.provinceScoopsAjout.value,
                  onChanged: (v) {
                    c.provinceScoopsAjout.value = v;
                    c.communeScoopsAjout.value = null;
                    c.arrondissementScoopsAjout.value = null;
                    c.secteurScoopsAjout.value = null;
                    c.quartierScoopsAjout.value = null;
                    c.villageScoopsAjout.value = null;
                  },
                  dropdownDecoratorProps: DropDownDecoratorProps(
                    dropdownSearchDecoration:
                        InputDecoration(labelText: "Province"),
                  ),
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                      decoration: InputDecoration(labelText: "Rechercher..."),
                    ),
                  ),
                  validator: (v) =>
                      v == null ? "Sélectionner une province" : null,
                );
              }),
              SizedBox(height: 12),
              Obx(() {
                final communes =
                    c.getCommunesForProvince(c.provinceScoopsAjout.value);
                return DropdownSearch<String>(
                  items: communes,
                  selectedItem: c.communeScoopsAjout.value,
                  onChanged: (v) {
                    c.communeScoopsAjout.value = v;
                    c.arrondissementScoopsAjout.value = null;
                    c.secteurScoopsAjout.value = null;
                    c.quartierScoopsAjout.value = null;
                    c.villageScoopsAjout.value = null;
                  },
                  dropdownDecoratorProps: DropDownDecoratorProps(
                    dropdownSearchDecoration:
                        InputDecoration(labelText: "Commune"),
                  ),
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                      decoration: InputDecoration(labelText: "Rechercher..."),
                    ),
                  ),
                  validator: (v) =>
                      v == null ? "Sélectionner une commune" : null,
                );
              }),
              SizedBox(height: 12),

              // Arrondissement, Secteur, Quartier dynamique pour Ouaga/Bobo
              Obx(() {
                if (c.communeScoopsAjout.value == "Ouagadougou" ||
                    c.communeScoopsAjout.value == "BOBO-DIOULASSO" ||
                    c.communeScoopsAjout.value == "Bobo-Dioulasso") {
                  final arrondissements = ArrondissementsParCommune[
                          c.communeScoopsAjout.value == "BOBO-DIOULASSO"
                              ? "Bobo-Dioulasso"
                              : c.communeScoopsAjout.value!] ??
                      [];
                  return Column(
                    children: [
                      DropdownSearch<String>(
                        items: arrondissements,
                        selectedItem: c.arrondissementScoopsAjout.value,
                        onChanged: (v) {
                          c.arrondissementScoopsAjout.value = v;
                          c.secteurScoopsAjout.value = null;
                          c.quartierScoopsAjout.value = null;
                        },
                        validator: (v) =>
                            v == null ? "Sélectionner un arrondissement" : null,
                        dropdownDecoratorProps: DropDownDecoratorProps(
                          dropdownSearchDecoration:
                              InputDecoration(labelText: "Arrondissement"),
                        ),
                        popupProps: PopupProps.menu(
                          showSearchBox: true,
                          searchFieldProps: TextFieldProps(
                            decoration:
                                InputDecoration(labelText: "Rechercher..."),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      // Secteur
                      Obx(() {
                        if (c.arrondissementScoopsAjout.value == null)
                          return Container();
                        final key =
                            "${c.communeScoopsAjout.value == "BOBO-DIOULASSO" ? "Bobo-Dioulasso" : c.communeScoopsAjout.value}_${c.arrondissementScoopsAjout.value}";
                        final secteurs =
                            secteursParArrondissement[key] ?? <String>[];
                        return DropdownSearch<String>(
                          items: secteurs,
                          selectedItem: c.secteurScoopsAjout.value,
                          onChanged: (v) {
                            c.secteurScoopsAjout.value = v;
                            c.quartierScoopsAjout.value = null;
                          },
                          validator: (v) =>
                              v == null ? "Sélectionner un secteur" : null,
                          dropdownDecoratorProps: DropDownDecoratorProps(
                            dropdownSearchDecoration:
                                InputDecoration(labelText: "Secteur"),
                          ),
                          popupProps: PopupProps.menu(
                            showSearchBox: true,
                            searchFieldProps: TextFieldProps(
                              decoration:
                                  InputDecoration(labelText: "Rechercher..."),
                            ),
                          ),
                        );
                      }),
                      SizedBox(height: 12),
                      // Quartier (au lieu de village)
                      Obx(() {
                        if (c.secteurScoopsAjout.value == null)
                          return Container();
                        final key =
                            "${c.communeScoopsAjout.value == "BOBO-DIOULASSO" ? "Bobo-Dioulasso" : c.communeScoopsAjout.value}_${c.secteurScoopsAjout.value}";
                        final quartiers = QuartierParSecteur[key] ?? <String>[];
                        return DropdownSearch<String>(
                          items: quartiers,
                          selectedItem: c.quartierScoopsAjout.value,
                          onChanged: (v) => c.quartierScoopsAjout.value = v,
                          validator: (v) =>
                              v == null ? "Sélectionner un quartier" : null,
                          dropdownDecoratorProps: DropDownDecoratorProps(
                            dropdownSearchDecoration:
                                InputDecoration(labelText: "Quartier"),
                          ),
                          popupProps: PopupProps.menu(
                            showSearchBox: true,
                            searchFieldProps: TextFieldProps(
                              decoration:
                                  InputDecoration(labelText: "Rechercher..."),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                } else {
                  // Village classique si autre commune
                  final villages =
                      c.getVillagesForCommune(c.communeScoopsAjout.value);
                  return DropdownSearch<String>(
                    items: villages,
                    selectedItem: c.villageScoopsAjout.value,
                    onChanged: (v) => c.villageScoopsAjout.value = v,
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      dropdownSearchDecoration:
                          InputDecoration(labelText: "Village"),
                    ),
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(
                            labelText: "Rechercher ou saisir..."),
                      ),
                      emptyBuilder: (context, searchEntry) {
                        if (searchEntry.isNotEmpty) {
                          return ListTile(
                            leading: Icon(Icons.add_location_alt,
                                color: Colors.amber[700]),
                            title: Text('Ajouter "$searchEntry" comme village'),
                            onTap: () {
                              c.villageScoopsAjout.value = searchEntry;
                              Navigator.of(context).pop();
                            },
                          );
                        }
                        return const Center(
                            child: Text('Aucun village trouvé'));
                      },
                    ),
                    validator: (v) => v == null || v.isEmpty
                        ? "Sélectionner ou saisir un village"
                        : null,
                  );
                }
              }),
              // ... (reste du formulaire inchangé)
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _numberFieldCtrlWithIcon("Nb ruches traditionnelles",
                        c.nbRuchesTradScoopsAjout, Icons.grass, "Obligatoire"),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _numberFieldCtrlWithIcon("Nb ruches modernes",
                        c.nbRuchesModScoopsAjout, Icons.build, "Obligatoire"),
                  ),
                ],
              ),
              SizedBox(height: 12),
              MultiSelectFlorale(c),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _numberFieldCtrlWithIcon("Nb membres",
                        c.nbMembreScoopsAjout, Icons.group, "Obligatoire"),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _numberFieldCtrlWithIcon("Nb hommes",
                        c.nbHommeScoopsAjout, Icons.man, "Obligatoire"),
                  ),
                ],
              ),
              SizedBox(height: 12),
              _numberFieldCtrlWithIcon(
                "Inférieur à 35 ans",
                c.nbJeuneScoopsAjout,
                Icons.child_care,
                "Obligatoire",
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Obx(() => TextFormField(
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: "Nb femmes",
                            prefixIcon: Icon(Icons.woman, color: Colors.pink),
                          ),
                          controller: TextEditingController(
                              text: c.nbFemmeScoopsAjout.value.toString()),
                        )),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Obx(() => TextFormField(
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: "Supérieur à 36 ans",
                            prefixIcon:
                                Icon(Icons.elderly, color: Colors.brown),
                          ),
                          controller: TextEditingController(
                              text: c.nbVieuxScoopsAjout.value.toString()),
                        )),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: Text("Récipisé (PDF à importer)",
                          style: TextStyle(color: Colors.grey))),
                ],
              ),
              SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  icon: Icon(Icons.save),
                  label: Text("Enregistrer la SCOOPS"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[700]),
                  onPressed: () async {
                    final champs = c.champsManquantsScoops();
                    if (champs.isNotEmpty) {
                      Get.snackbar(
                        "Champs obligatoires manquants",
                        "Veuillez remplir les champs suivants :\n${champs.join(", ")}",
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.red[100],
                        colorText: Colors.red[900],
                        duration: Duration(seconds: 6),
                        icon: Icon(Icons.error, color: Colors.red[900]),
                      );
                      return;
                    }
                    await c.enregistrerNouvelleSCOOPS();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formulaireAjouterIndividuel() {
    final c = Get.find<CollecteController>();
    final _formKey = GlobalKey<FormState>();
    final RxString appartenance = "Propre".obs;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person_add, color: Colors.green[800], size: 28),
                  SizedBox(width: 10),
                  Text(
                    "Ajouter un producteur individuel",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.green[800]),
                  ),
                ],
              ),
              SizedBox(height: 16),
              _textFieldWithIcon("Nom et prénom", c.nomPrenomIndivAjout,
                  Icons.person, "Nom requis"),
              SizedBox(height: 12),

              // Localisation cascade
              DropdownSearch<String>(
                items: regionsBurkina,
                selectedItem: c.regionIndivAjout.value,
                onChanged: (v) {
                  c.regionIndivAjout.value = v;
                  c.provinceIndivAjout.value = null;
                  c.communeIndivAjout.value = null;
                  c.arrondissementIndivAjout.value = null;
                  c.secteurIndivAjout.value = null;
                  c.quartierIndivAjout.value = null;
                  c.villageIndivAjout.value = null;
                },
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration:
                      InputDecoration(labelText: "Région"),
                ),
                popupProps: PopupProps.menu(
                  showSearchBox: true,
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(labelText: "Rechercher..."),
                  ),
                ),
                validator: (v) => v == null ? "Sélectionner une région" : null,
              ),
              SizedBox(height: 12),
              Obx(() {
                final provinces =
                    c.getProvincesForRegion(c.regionIndivAjout.value);
                return DropdownSearch<String>(
                  items: provinces,
                  selectedItem: c.provinceIndivAjout.value,
                  onChanged: (v) {
                    c.provinceIndivAjout.value = v;
                    c.communeIndivAjout.value = null;
                    c.arrondissementIndivAjout.value = null;
                    c.secteurIndivAjout.value = null;
                    c.quartierIndivAjout.value = null;
                    c.villageIndivAjout.value = null;
                  },
                  dropdownDecoratorProps: DropDownDecoratorProps(
                    dropdownSearchDecoration:
                        InputDecoration(labelText: "Province"),
                  ),
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                      decoration: InputDecoration(labelText: "Rechercher..."),
                    ),
                  ),
                  validator: (v) =>
                      v == null ? "Sélectionner une province" : null,
                );
              }),
              SizedBox(height: 12),
              Obx(() {
                final communes =
                    c.getCommunesForProvince(c.provinceIndivAjout.value);
                return DropdownSearch<String>(
                  items: communes,
                  selectedItem: c.communeIndivAjout.value,
                  onChanged: (v) {
                    c.communeIndivAjout.value = v;
                    c.arrondissementIndivAjout.value = null;
                    c.secteurIndivAjout.value = null;
                    c.quartierIndivAjout.value = null;
                    c.villageIndivAjout.value = null;
                  },
                  dropdownDecoratorProps: DropDownDecoratorProps(
                    dropdownSearchDecoration:
                        InputDecoration(labelText: "Commune"),
                  ),
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                      decoration: InputDecoration(labelText: "Rechercher..."),
                    ),
                  ),
                  validator: (v) =>
                      v == null ? "Sélectionner une commune" : null,
                );
              }),
              SizedBox(height: 12),

              // Arrondissement, Secteur, Quartier dynamique pour Ouaga/Bobo
              Obx(() {
                if (c.communeIndivAjout.value == "Ouagadougou" ||
                    c.communeIndivAjout.value == "BOBO-DIOULASSO" ||
                    c.communeIndivAjout.value == "Bobo-Dioulasso") {
                  final arrondissements = ArrondissementsParCommune[
                          c.communeIndivAjout.value == "BOBO-DIOULASSO"
                              ? "Bobo-Dioulasso"
                              : c.communeIndivAjout.value!] ??
                      [];
                  return Column(
                    children: [
                      DropdownSearch<String>(
                        items: arrondissements,
                        selectedItem: c.arrondissementIndivAjout.value,
                        onChanged: (v) {
                          c.arrondissementIndivAjout.value = v;
                          c.secteurIndivAjout.value = null;
                          c.quartierIndivAjout.value = null;
                        },
                        validator: (v) =>
                            v == null ? "Sélectionner un arrondissement" : null,
                        dropdownDecoratorProps: DropDownDecoratorProps(
                          dropdownSearchDecoration:
                              InputDecoration(labelText: "Arrondissement"),
                        ),
                        popupProps: PopupProps.menu(
                          showSearchBox: true,
                          searchFieldProps: TextFieldProps(
                            decoration:
                                InputDecoration(labelText: "Rechercher..."),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      // Secteur
                      Obx(() {
                        if (c.arrondissementIndivAjout.value == null)
                          return Container();
                        final key =
                            "${c.communeIndivAjout.value == "BOBO-DIOULASSO" ? "Bobo-Dioulasso" : c.communeIndivAjout.value}_${c.arrondissementIndivAjout.value}";
                        final secteurs =
                            secteursParArrondissement[key] ?? <String>[];
                        return DropdownSearch<String>(
                          items: secteurs,
                          selectedItem: c.secteurIndivAjout.value,
                          onChanged: (v) {
                            c.secteurIndivAjout.value = v;
                            c.quartierIndivAjout.value = null;
                          },
                          validator: (v) =>
                              v == null ? "Sélectionner un secteur" : null,
                          dropdownDecoratorProps: DropDownDecoratorProps(
                            dropdownSearchDecoration:
                                InputDecoration(labelText: "Secteur"),
                          ),
                          popupProps: PopupProps.menu(
                            showSearchBox: true,
                            searchFieldProps: TextFieldProps(
                              decoration:
                                  InputDecoration(labelText: "Rechercher..."),
                            ),
                          ),
                        );
                      }),
                      SizedBox(height: 12),
                      // Quartier (au lieu de village)
                      Obx(() {
                        if (c.secteurIndivAjout.value == null)
                          return Container();
                        final key =
                            "${c.communeIndivAjout.value == "BOBO-DIOULASSO" ? "Bobo-Dioulasso" : c.communeIndivAjout.value}_${c.secteurIndivAjout.value}";
                        final quartiers = QuartierParSecteur[key] ?? <String>[];
                        return DropdownSearch<String>(
                          items: quartiers,
                          selectedItem: c.quartierIndivAjout.value,
                          onChanged: (v) => c.quartierIndivAjout.value = v,
                          validator: (v) =>
                              v == null ? "Sélectionner un quartier" : null,
                          dropdownDecoratorProps: DropDownDecoratorProps(
                            dropdownSearchDecoration:
                                InputDecoration(labelText: "Quartier"),
                          ),
                          popupProps: PopupProps.menu(
                            showSearchBox: true,
                            searchFieldProps: TextFieldProps(
                              decoration:
                                  InputDecoration(labelText: "Rechercher..."),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                } else {
                  // Village classique si autre commune
                  final villages =
                      c.getVillagesForCommune(c.communeIndivAjout.value);
                  return DropdownSearch<String>(
                    items: villages,
                    selectedItem: c.villageIndivAjout.value,
                    onChanged: (v) => c.villageIndivAjout.value = v,
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      dropdownSearchDecoration:
                          InputDecoration(labelText: "Village"),
                    ),
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(
                            labelText: "Rechercher ou saisir..."),
                      ),
                      emptyBuilder: (context, searchEntry) {
                        if (searchEntry.isNotEmpty) {
                          return ListTile(
                            leading: Icon(Icons.add_location_alt,
                                color: Colors.amber[700]),
                            title: Text('Ajouter "$searchEntry" comme village'),
                            onTap: () {
                              c.villageIndivAjout.value = searchEntry;
                              Navigator.of(context).pop();
                            },
                          );
                        }
                        return const Center(
                            child: Text('Aucun village trouvé'));
                      },
                    ),
                    validator: (v) => v == null || v.isEmpty
                        ? "Sélectionner ou saisir un village"
                        : null,
                  );
                }
              }),
              SizedBox(height: 12),
              TextFormField(
                controller: c.numeroIndividuelCtrl,
                decoration: InputDecoration(
                  labelText: "Numéro Individuel",
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (v) => v == null || v.isEmpty ? "Obligatoire" : null,
              ),
              SizedBox(height: 12),
              _dropdownWithIcon("Sexe", c.sexes, c.sexeIndivAjout, Icons.wc,
                  "Sélectionner le sexe"),
              SizedBox(height: 12),
              _dropdownWithIcon(
                  "Âge",
                  ["Inférieure ou Egale à 35", "Supérieure ou Egale à 35"],
                  c.ageIndivAjout,
                  Icons.cake,
                  "Sélectionner l'âge"),
              SizedBox(height: 12),
              Obx(() => DropdownButtonFormField<String>(
                    value: appartenance.value,
                    decoration: InputDecoration(
                      labelText: "Appartenance",
                      prefixIcon: Icon(Icons.group_work, color: Colors.orange),
                    ),
                    items: ["Propre", "Cooperative"]
                        .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                        .toList(),
                    onChanged: (v) {
                      appartenance.value = v!;
                      if (v == "Propre") {
                        c.cooperativeIndivAjout.value = "Propre";
                      } else {
                        c.cooperativeIndivAjout.value = null;
                      }
                    },
                    validator: (v) =>
                        v == null ? "Sélectionner l'appartenance" : null,
                  )),
              SizedBox(height: 12),
              Obx(() {
                if (appartenance.value == "Cooperative") {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Obx(() => DropdownButtonFormField<String>(
                              value: c.cooperativeIndivAjout.value,
                              decoration: InputDecoration(
                                labelText: "SCOOPS (Coopérative)",
                                prefixIcon: Icon(Icons.apartment,
                                    color: Colors.deepPurple),
                              ),
                              items: c.scoopsConnues
                                  .map((s) => DropdownMenuItem(
                                      value: s, child: Text(s)))
                                  .toList(),
                              onChanged: (v) =>
                                  c.cooperativeIndivAjout.value = v,
                              validator: (v) => v == null
                                  ? "Sélectionner une coopérative"
                                  : null,
                            )),
                      ),
                      SizedBox(width: 10),
                      ElevatedButton.icon(
                        icon: Icon(Icons.add),
                        label: Text("Ajouter Coopérative"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700]),
                        onPressed: () {
                          c.isAddingSCOOPS.value = true;
                          c.isAddingIndividuel.value = false;
                        },
                      ),
                    ],
                  );
                }
                return SizedBox.shrink();
              }),
              MultiSelectFlorale(c),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _numberFieldCtrlWithIcon("Nb ruches traditionnelles",
                        c.nbRuchesTradIndivAjout, Icons.grass, "Obligatoire"),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _numberFieldCtrlWithIcon("Nb ruches modernes",
                        c.nbRuchesModIndivAjout, Icons.build, "Obligatoire"),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  icon: Icon(Icons.save),
                  label: Text("Enregistrer l'Individuel"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[700]),
                  onPressed: () async {
                    if (appartenance.value == "Propre") {
                      c.cooperativeIndivAjout.value = "Propre";
                    }
                    if (_formKey.currentState?.validate() ?? false) {
                      await c.enregistrerNouvelIndividuel();
                    } else {
                      Get.snackbar(
                        "Erreur",
                        "Veuillez corriger les champs en rouge !",
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.red[100],
                        colorText: Colors.red[900],
                        duration: Duration(seconds: 4),
                        icon: Icon(Icons.error, color: Colors.red[900]),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Utilitaires
  void _resetForm(CollecteController c) {
    c.isAddingSCOOPS.value = false;
    c.typesRucheAchatScoopsMulti.clear();
    c.typesProduitAchatScoopsMulti.clear();
    c.achatsParRucheProduit.clear();
  }

  Widget _textFieldWithIcon(
      String label, TextEditingController ctrl, IconData icon, String erreur) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.amber),
      ),
      validator: (v) => v == null || v.isEmpty ? erreur : null,
    );
  }

  Widget _dropdownWithIcon(String label, List<String> data, RxnString sel,
      IconData icon, String erreur,
      {bool enabled = true}) {
    return Obx(() => DropdownButtonFormField<String>(
          value: sel.value,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: Colors.green),
          ),
          items: data
              .map((d) => DropdownMenuItem(value: d, child: Text(d)))
              .toList(),
          onChanged: enabled
              ? (v) {
                  sel.value = v;
                  // Ici, on sort du mode ajout si on était dessus
                  if (label.toLowerCase().contains("scoops") &&
                      c.isAddingSCOOPS.value) {
                    c.isAddingSCOOPS.value = false;
                  }
                  if (label.toLowerCase().contains("individuel") &&
                      c.isAddingIndividuel.value) {
                    c.isAddingIndividuel.value = false;
                  }
                }
              : null,
          validator: (v) => v == null ? erreur : null,
          disabledHint: sel.value == null
              ? Text("Sélectionnez d'abord")
              : Text(data.contains(sel.value) ? sel.value! : ""),
        ));
  }

  Widget _numberFieldCtrlWithIcon(
      String label, TextEditingController ctrl, IconData icon, String erreur) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.brown),
      ),
      keyboardType: TextInputType.number,
      validator: (v) => v == null || v.isEmpty ? erreur : null,
    );
  }

  Widget _datePickerField(String label, Rxn<DateTime> dateRx) {
    final controller = TextEditingController(
        text: dateRx.value != null
            ? "${dateRx.value!.day}/${dateRx.value!.month}/${dateRx.value!.year}"
            : "Choisir une date");
    return Obx(() {
      if (dateRx.value != null) {
        controller.text =
            "${dateRx.value!.day}/${dateRx.value!.month}/${dateRx.value!.year}";
      } else {
        controller.text = "Choisir une date";
      }
      return InkWell(
        onTap: () async {
          final DateTime? picked = await showDatePicker(
            context: Get.context!,
            initialDate: dateRx.value ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null && picked != dateRx.value) {
            dateRx.value = picked;
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: Icon(Icons.calendar_today),
            border: OutlineInputBorder(),
          ),
          child: Text(
            dateRx.value != null
                ? "${dateRx.value!.day}/${dateRx.value!.month}/${dateRx.value!.year}"
                : "Choisir une date",
            style: TextStyle(
              color: dateRx.value != null ? Colors.black : Colors.grey,
            ),
          ),
        ),
      );
    });
  }

  Widget boutonRetour(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Align(
        alignment: Alignment.centerRight,
        child: ElevatedButton.icon(
          icon: Icon(Icons.cancel),
          label: Text("Retour Au DashBoard"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[400],
            foregroundColor: Colors.black87,
          ),
          onPressed: () {
            Get.offAllNamed('/dashboard');
          },
        ),
      ),
    );
  }
}

class Achat {
  final String unite;
  RxDouble quantiteAcceptee = 0.0.obs;
  RxDouble quantiteRejetee = 0.0.obs;
  RxDouble prixUnitaire = 0.0.obs;
  RxDouble prixTotal = 0.0.obs;

  Achat({required this.unite});
}

class CustomMultiSelectCard extends StatelessWidget {
  final String value;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const CustomMultiSelectCard({
    Key? key,
    required this.value,
    required this.label,
    required this.selected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: selected ? 4 : 1,
        color: selected ? Colors.amber[700] : Colors.grey[100],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: selected
              ? BorderSide(color: Colors.amber, width: 2)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
