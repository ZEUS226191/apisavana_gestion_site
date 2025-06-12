import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ClientFormPage extends StatefulWidget {
  final String commercialId;
  final String? commercialNom;
  final DateTime? dateVente;
  const ClientFormPage({
    super.key,
    required this.commercialId,
    this.commercialNom,
    this.dateVente,
  });

  @override
  State<ClientFormPage> createState() => _ClientFormPageState();
}

class _ClientFormPageState extends State<ClientFormPage> {
  final _formKey = GlobalKey<FormState>();
  DateTime? dateVente;
  String? nomCommercial;
  String? nomBoutique;
  String? region;
  String? province;
  String? nomLocalite;
  String? nomGerant;
  String? telephone1;
  String? telephone2;
  String? photoUrl;
  Position? localisation; // Geolocator.Position
  bool isUploading = false;

  XFile? _pickedImage;

  // Listes pour selecteurs
  final List<String> regions = [
    "Boucle du Mouhoun",
    "Cascades",
    "Centre",
    "Centre-Est",
    "Centre-Nord",
    "Centre-Ouest",
    "Centre-Sud",
    "Est",
    "Hauts-Bassins",
    "Nord",
    "Plateau-Central",
    "Sahel",
    "Sud-Ouest"
  ];
  final List<String> provinces = [
    "Bale",
    "Bam",
    "Banwa",
    "Bazega",
    "Bougouriba",
    "Boulgou",
    "Boulkiemde",
    "Comoe",
    "Ganzourgou",
    "Gnagna",
    "Gourma",
    "Houet",
    "Ioba",
    "Kadiogo",
    "Kenedougou",
    "Komandjari",
    "Kompienga",
    "Kossi",
    "Koulpelogo",
    "Kouritenga",
    "Kourweogo",
    "Leraba",
    "Loroum",
    "Mouhoun",
    "Nahouri",
    "Namentenga",
    "Nayala",
    "Noumbiel",
    "Oubritenga",
    "Oudalan",
    "Passore",
    "Poni",
    "Sanguie",
    "Sanmatenga",
    "Seno",
    "Sissili",
    "Soum",
    "Sourou",
    "Tapoa",
    "Tuy",
    "Yagha",
    "Yatenga",
    "Ziro",
    "Zondoma",
    "Zoundweogo"
  ];

  String? _selectedAddress;
  Map<String, dynamic>? currentUserDoc;
  List<Map<String, dynamic>> commerciaux = [];

  @override
  void initState() {
    super.initState();
    dateVente = widget.dateVente ?? DateTime.now();
    _loadCommerciaux();
  }

  Future<void> _loadCommerciaux() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userDoc = await FirebaseFirestore.instance
        .collection('utilisateurs')
        .doc(user.uid)
        .get();
    final data = userDoc.data() ?? {};
    setState(() {
      currentUserDoc = data;
      nomCommercial = data['nom'] ?? '!';
    });
    final snapCom = await FirebaseFirestore.instance
        .collection('utilisateurs')
        .where('role', isEqualTo: 'Commercial(e)')
        .get();
    setState(() {
      commerciaux = snapCom.docs
          .map((d) => {"id": d.id, ...d.data() as Map<String, dynamic>})
          .toList();
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    XFile? picked;
    if (kIsWeb) {
      picked = await picker.pickImage(source: ImageSource.gallery);
    } else {
      picked = await showModalBottomSheet<XFile?>(
        context: context,
        builder: (_) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Prendre une photo'),
                onTap: () async {
                  final img =
                      await picker.pickImage(source: ImageSource.camera);
                  Navigator.pop(context, img);
                }),
            ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choisir dans la galerie'),
                onTap: () async {
                  final img =
                      await picker.pickImage(source: ImageSource.gallery);
                  Navigator.pop(context, img);
                })
          ],
        ),
      );
    }
    if (picked != null) {
      setState(() {
        _pickedImage = picked;
      });
    }
  }

  Future<String?> _uploadImage(XFile file) async {
    // À adapter si tu utilises Firebase Storage
    return null;
  }

  Future<void> _updateAddressFromPosition(Position position) async {
    try {
      final url =
          "https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1";
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        String? displayName = decoded["display_name"];
        setState(() {
          _selectedAddress = displayName ?? "Adresse inconnue";
        });
      } else {
        setState(() {
          _selectedAddress = "Adresse inconnue";
        });
      }
    } catch (e) {
      setState(() {
        _selectedAddress = "Adresse inconnue";
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      Get.snackbar("Erreur", "Activez la localisation de votre appareil.");
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        Get.snackbar("Erreur", "Permission de localisation refusée.");
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      Get.snackbar(
          "Erreur", "Permission de localisation refusée définitivement.");
      return;
    }
    final pos = await Geolocator.getCurrentPosition();
    setState(() {
      localisation = pos;
    });
    await _updateAddressFromPosition(pos);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (localisation == null) {
      Get.snackbar("Erreur", "Sélectionnez la localisation du client !");
      return;
    }
    setState(() => isUploading = true);
    String? url;
    if (_pickedImage != null) {
      url = await _uploadImage(_pickedImage!);
    }
    await FirebaseFirestore.instance.collection('clients').add({
      "dateVente": dateVente,
      "commercialId": widget.commercialId,
      "commercialNom": nomCommercial ?? "",
      "nomBoutique": nomBoutique,
      "region": region,
      "province": province,
      "nomLocalite": nomLocalite,
      "nomGerant": nomGerant,
      "telephone1": telephone1,
      "telephone2": telephone2 ?? "",
      "photoUrl": url ?? "",
      "localisation": localisation != null
          ? GeoPoint(localisation!.latitude, localisation!.longitude)
          : null,
      "adresse": _selectedAddress ?? "",
      "createdAt": FieldValue.serverTimestamp(),
    });
    setState(() {
      isUploading = false;
      // Reset all fields after save!
      dateVente = DateTime.now();
      nomBoutique = null;
      region = null;
      province = null;
      nomLocalite = null;
      nomGerant = null;
      telephone1 = null;
      telephone2 = null;
      photoUrl = null;
      localisation = null;
      _selectedAddress = null;
      _pickedImage = null;
    });
    if (mounted) {
      Get.snackbar("Succès", "Client ajouté !");
      // Attendre un petit moment pour laisser voir le message puis pop (retour)
      await Future.delayed(const Duration(milliseconds: 800));
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // on revient à la page précédente
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nouveau client"),
        backgroundColor: Colors.orange[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Date de vente
              ListTile(
                leading: const Icon(Icons.date_range, color: Colors.orange),
                title: Text(
                  dateVente != null
                      ? "Date de vente : ${dateVente!.day}/${dateVente!.month}/${dateVente!.year}"
                      : "Sélectionner une date",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_calendar, color: Colors.orange),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: dateVente ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => dateVente = picked);
                  },
                ),
              ),
              const SizedBox(height: 12),
              // Commercial
              TextFormField(
                initialValue: nomCommercial ?? "",
                enabled: false,
                decoration: const InputDecoration(
                  labelText: "Nom du commercial",
                  prefixIcon: Icon(Icons.person, color: Colors.deepOrange),
                  filled: true,
                  fillColor: Color(0xFFFFF3E0),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
              const SizedBox(height: 12),
              // Nom de la boutique
              TextFormField(
                decoration: const InputDecoration(
                  labelText: "Nom de la boutique",
                  prefixIcon: Icon(Icons.storefront, color: Colors.orange),
                  filled: true,
                  fillColor: Color(0xFFFFF3E0),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
                onChanged: (v) => nomBoutique = v,
                validator: (v) => v == null || v.isEmpty ? "Obligatoire" : null,
              ),
              const SizedBox(height: 12),
              // Localité : Région, Province, Localité
              const Text("Localité",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.orange)),
              const SizedBox(height: 8),
              // Région
              SearchableDropdown(
                label: "Région",
                hint: "Choisir une région",
                value: region,
                items: regions,
                onChanged: (v) => setState(() => region = v),
              ),
              const SizedBox(height: 8),
              // Province
              SearchableDropdown(
                label: "Province",
                hint: "Choisir une province",
                value: province,
                items: provinces,
                onChanged: (v) => setState(() => province = v),
              ),
              const SizedBox(height: 8),
              // Nom Localité
              TextFormField(
                decoration: const InputDecoration(
                  labelText: "Nom de la localité",
                  prefixIcon: Icon(Icons.location_on, color: Colors.orange),
                  filled: true,
                  fillColor: Color(0xFFFFF3E0),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
                onChanged: (v) => nomLocalite = v,
                validator: (v) => v == null || v.isEmpty ? "Obligatoire" : null,
              ),
              const SizedBox(height: 12),
              // Nom du gérant
              TextFormField(
                decoration: const InputDecoration(
                  labelText: "Nom du gérant",
                  prefixIcon: Icon(Icons.person_pin, color: Colors.deepOrange),
                  filled: true,
                  fillColor: Color(0xFFFFF3E0),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
                onChanged: (v) => nomGerant = v,
                validator: (v) => v == null || v.isEmpty ? "Obligatoire" : null,
              ),
              const SizedBox(height: 12),
              // Téléphone 1
              TextFormField(
                decoration: const InputDecoration(
                  labelText: "Téléphone",
                  prefixIcon: Icon(Icons.phone, color: Colors.orange),
                  filled: true,
                  fillColor: Color(0xFFFFF3E0),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
                keyboardType: TextInputType.phone,
                onChanged: (v) => telephone1 = v,
                validator: (v) => v == null || v.isEmpty ? "Obligatoire" : null,
              ),
              // Ajout deuxième téléphone
              if (telephone2 != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: "Téléphone secondaire",
                      prefixIcon: Icon(Icons.phone, color: Colors.orange),
                      filled: true,
                      fillColor: Color(0xFFFFF3E0),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    keyboardType: TextInputType.phone,
                    onChanged: (v) => telephone2 = v,
                  ),
                ),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text("Ajouter un 2ème numéro de téléphone"),
                onPressed: () {
                  setState(() {
                    if (telephone2 == null) telephone2 = "";
                  });
                },
              ),
              const SizedBox(height: 12),
              // Photo de la boutique
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.camera_alt, color: Colors.orange),
                      label: const Text("Ajouter une photo de la boutique"),
                      onPressed: _pickImage,
                    ),
                  ),
                  if (_pickedImage != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: SizedBox(
                        width: 70,
                        height: 70,
                        child: kIsWeb
                            ? Image.network(_pickedImage!.path,
                                fit: BoxFit.cover)
                            : Image.file(File(_pickedImage!.path),
                                fit: BoxFit.cover),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Géolocalisation
              GestureDetector(
                onTap: _getCurrentLocation,
                child: ListTile(
                  tileColor: const Color(0xFFFFF3E0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  leading: const Icon(Icons.map, color: Colors.orange),
                  title: localisation != null
                      ? (_selectedAddress != null &&
                              _selectedAddress!.isNotEmpty)
                          ? Text(
                              "Localisation sélectionnée :\n$_selectedAddress")
                          : Text(
                              "Localisation sélectionnée :\n${localisation!.latitude}, ${localisation!.longitude}")
                      : const Text(
                          "Ajouter ma position actuelle (cliquer ici)"),
                  trailing: Icon(Icons.my_location, color: Colors.green),
                  subtitle: localisation == null
                      ? const Text(
                          "Clique ici pour enregistrer ta position actuelle",
                          style: TextStyle(color: Colors.red))
                      : null,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                icon: isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: const Text("Enregistrer le client"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    minimumSize: const Size(220, 45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    )),
                onPressed: isUploading ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------- DROPDOWN RECHERCHE PERSONNALISÉ ---------------

class SearchableDropdown extends StatefulWidget {
  final String label;
  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const SearchableDropdown({
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    super.key,
  });

  @override
  State<SearchableDropdown> createState() => _SearchableDropdownState();
}

class _SearchableDropdownState extends State<SearchableDropdown> {
  late TextEditingController controller;
  String? selectedValue;
  String filter = "";

  @override
  void initState() {
    super.initState();
    selectedValue = widget.value;
    controller = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant SearchableDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != selectedValue) {
      selectedValue = widget.value;
    }
  }

  void _openDropdownDialog() async {
    filter = "";
    controller.clear();
    String? value = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            List<String> filtered = widget.items
                .where((e) =>
                    e.toLowerCase().contains(filter.trim().toLowerCase()))
                .toList();
            return AlertDialog(
              title: Text(widget.label),
              content: SizedBox(
                width: 350,
                height: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: "Rechercher ${widget.label.toLowerCase()}",
                      ),
                      onChanged: (val) => setStateDialog(() => filter = val),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text("Aucun résultat"))
                          : ListView(
                              shrinkWrap: true,
                              children: filtered
                                  .map((e) => ListTile(
                                        title: Text(e),
                                        onTap: () => Navigator.pop(context, e),
                                        selected: selectedValue == e,
                                      ))
                                  .toList(),
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text("Annuler"),
                ),
              ],
            );
          },
        );
      },
    );
    if (value != null) {
      widget.onChanged(value);
      setState(() {
        selectedValue = value;
        controller.clear();
        filter = "";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openDropdownDialog,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          filled: true,
          fillColor: const Color(0xFFFFF3E0),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                selectedValue ?? widget.hint,
                style: TextStyle(
                  color: selectedValue == null ? Colors.grey : Colors.black,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}
