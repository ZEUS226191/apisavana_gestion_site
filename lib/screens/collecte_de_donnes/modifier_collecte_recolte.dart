import 'package:apisavana_gestion/controllers/collecte_controller.dart';
import 'package:apisavana_gestion/data/geographe/geographie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class EditRecolteForm extends StatefulWidget {
  final String collecteId;
  const EditRecolteForm({required this.collecteId, Key? key}) : super(key: key);

  @override
  State<EditRecolteForm> createState() => _EditRecolteFormState();
}

class _EditRecolteFormState extends State<EditRecolteForm> {
  final _formKey = GlobalKey<FormState>();
  final CollecteController c = Get.find<CollecteController>();

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAndPopulate();
  }

  Future<void> _loadAndPopulate() async {
    // Charge les données Firestore et set les Rx du controller
    final doc = await FirebaseFirestore.instance
        .collection('collectes')
        .doc(widget.collecteId)
        .get();
    final docData = doc.data();
    if (docData != null) {
      c.dateCollecte.value = (docData['dateCollecte'] as Timestamp?)?.toDate();
    }
    final recolteSnap = await FirebaseFirestore.instance
        .collection('collectes')
        .doc(widget.collecteId)
        .collection('Récolte')
        .limit(1)
        .get();
    if (recolteSnap.docs.isNotEmpty) {
      final data = recolteSnap.docs.first.data() as Map<String, dynamic>;
      c.nomRecolteur.value = data['nomRecolteur'];
      c.region.value = data['region'];
      c.province.value = data['province'];
      c.commune.value = data['commune'];
      c.village.value = data['village'];
      c.arrondissement.value = data['arrondissement'];
      c.secteur.value = data['secteur'];
      c.quartier.value = data['quartier'];
      c.quantiteRecolte.value = (data['quantiteKg'] as num?)?.toDouble();
      c.nbRuchesRecoltees.value = (data['nbRuchesRecoltees'] as num?)?.toInt();
      c.predominancesFloralesSelected.value =
          (data['predominanceFlorale'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
      c.dateRecolte.value = (data['dateRecolte'] as Timestamp?)?.toDate();
    }
    setState(() => _loading = false);
  }

  Future<void> _updateData() async {
    try {
      // update la sous-collection Récolte
      final recolteSnap = await FirebaseFirestore.instance
          .collection('collectes')
          .doc(widget.collecteId)
          .collection('Récolte')
          .limit(1)
          .get();
      if (recolteSnap.docs.isEmpty) {
        Get.snackbar("Erreur", "Impossible de trouver la récolte à modifier !");
        return;
      }
      final recolteId = recolteSnap.docs.first.id;
      final dataToUpdate = {
        'nomRecolteur': c.nomRecolteur.value,
        'region': c.region.value,
        'province': c.province.value,
        'commune': c.commune.value,
        'village': c.village.value,
        'arrondissement': c.arrondissement.value,
        'secteur': c.secteur.value,
        'quartier': c.quartier.value,
        'quantiteKg': c.quantiteRecolte.value,
        'nbRuchesRecoltees': c.nbRuchesRecoltees.value,
        'predominanceFlorale': c.predominancesFloralesSelected.toList(),
        'dateRecolte': c.dateRecolte.value,
      };
      await FirebaseFirestore.instance
          .collection('collectes')
          .doc(widget.collecteId)
          .collection('Récolte')
          .doc(recolteId)
          .update(dataToUpdate);

      await FirebaseFirestore.instance
          .collection('collectes')
          .doc(widget.collecteId)
          .update({
        'dateCollecte': c.dateCollecte.value,
      });

      Get.snackbar(
        "Succès",
        "Récolte modifiée !",
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      c.reset();
      Get.back();
    } catch (e) {
      Get.snackbar(
        "Erreur",
        "La modification a échoué. ${e.toString()}",
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Center(child: CircularProgressIndicator());
    return Obx(() => Padding(
          padding: EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: Text(c.dateCollecte.value != null
                      ? "Date de collecte: ${c.dateCollecte.value!.day}/${c.dateCollecte.value!.month}/${c.dateCollecte.value!.year}"
                      : "Date de collecte"),
                  trailing: Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: c.dateCollecte.value ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) c.dateCollecte.value = picked;
                  },
                ),
                DropdownSearch<String>(
                  items: c.techniciens,
                  selectedItem: c.nomRecolteur.value,
                  onChanged: (v) {
                    c.nomRecolteur.value = v;
                    // On ne remet à null que la région
                    c.region.value = null;
                  },
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
                DropdownSearch<String>(
                  items: regionsBurkina,
                  selectedItem: c.region.value,
                  onChanged: (v) {
                    c.region.value = v;
                    c.province.value = null;
                  },
                  validator: (v) =>
                      v == null ? "Sélectionner une région" : null,
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
                Obx(() {
                  final provinces = c.getProvincesForRegion(c.region.value);
                  return DropdownSearch<String>(
                    items: provinces,
                    selectedItem: c.province.value,
                    onChanged: (v) {
                      c.province.value = v;
                      c.commune.value = null;
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
                // Arrondissement, Secteur, Quartier pour Ouaga/Bobo
                Obx(() {
                  if (c.commune.value == "Ouagadougou" ||
                      c.commune.value == "BOBO-DIOULASSO" ||
                      c.commune.value == "Bobo-Dioulasso") {
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
                          },
                          validator: (v) => v == null
                              ? "Sélectionner un arrondissement"
                              : null,
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
                        Obx(() {
                          if (c.arrondissement.value == null)
                            return Container();
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
                        Obx(() {
                          if (c.secteur.value == null) return Container();
                          final key =
                              "${c.commune.value == "BOBO-DIOULASSO" ? "Bobo-Dioulasso" : c.commune.value}_${c.secteur.value}";
                          final quartiers =
                              QuartierParSecteur[key] ?? <String>[];
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
                TextFormField(
                  decoration: InputDecoration(
                      labelText: "Quantité (kg)",
                      suffixText: "kg",
                      prefixIcon:
                          Icon(Icons.balance, color: Colors.brown[400])),
                  keyboardType: TextInputType.number,
                  initialValue: c.quantiteRecolte.value?.toString(),
                  onChanged: (v) =>
                      c.quantiteRecolte.value = double.tryParse(v),
                  validator: (v) =>
                      v == null || v.isEmpty || double.tryParse(v) == null
                          ? "Obligatoire"
                          : null,
                ),
                TextFormField(
                  decoration: InputDecoration(
                      labelText: "Nombre de ruches récoltées",
                      prefixIcon:
                          Icon(Icons.hive_rounded, color: Colors.amber)),
                  keyboardType: TextInputType.number,
                  initialValue: c.nbRuchesRecoltees.value?.toString(),
                  onChanged: (v) =>
                      c.nbRuchesRecoltees.value = int.tryParse(v ?? ""),
                  validator: (v) =>
                      v == null || v.isEmpty || int.tryParse(v) == null
                          ? "Obligatoire"
                          : null,
                ),
                // Prédominance florale
                InputDecorator(
                  decoration: InputDecoration(
                      labelText: "Prédominance florale",
                      prefixIcon:
                          Icon(Icons.local_florist, color: Colors.orange)),
                  child: Obx(() => Wrap(
                        spacing: 6,
                        children: c.flores
                            .map((f) => FilterChip(
                                  label: Text(f),
                                  selected: c.predominancesFloralesSelected
                                      .contains(f),
                                  onSelected: (sel) {
                                    if (sel) {
                                      c.predominancesFloralesSelected.add(f);
                                    } else {
                                      c.predominancesFloralesSelected.remove(f);
                                    }
                                  },
                                ))
                            .toList(),
                      )),
                ),
                ListTile(
                  title: Text(c.dateRecolte.value != null
                      ? "Date de récolte: ${c.dateRecolte.value!.day}/${c.dateRecolte.value!.month}/${c.dateRecolte.value!.year}"
                      : "Date de récolte"),
                  trailing: Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: c.dateRecolte.value ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) c.dateRecolte.value = picked;
                  },
                ),
                SizedBox(height: 20),
                ElevatedButton.icon(
                    icon: Icon(Icons.save),
                    label: Text("Enregistrer les modifications"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber[700]),
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        _updateData();
                      } else {
                        Get.snackbar(
                            "Erreur", "Veuillez remplir tous les champs !");
                      }
                    }),
              ],
            ),
          ),
        ));
  }
}
