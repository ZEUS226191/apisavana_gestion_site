import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'client_form.dart';

class VenteFormPage extends StatefulWidget {
  final Map<String, dynamic> prelevement;
  const VenteFormPage({super.key, required this.prelevement});

  @override
  State<VenteFormPage> createState() => _VenteFormPageState();
}

class _VenteFormPageState extends State<VenteFormPage> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _dateVente;
  String? _clientId;
  String typeVente = "Comptant";
  Map<String, TextEditingController> nbPotsController = {};
  Map<String, int> quantiteParType = {};
  double quantiteTotale = 0;
  double montantTotal = 0;
  double montantPaye = 0;
  double montantRestant = 0;

  // Pour stocker la version "restante" du prélèvement (décrémentée)
  Map<String, int> maxPotsRestants = {};
  bool isLoading = true;

  // Nouvelle: pour clients en temps réel
  Stream<List<Map<String, dynamic>>> get clientsStream {
    return FirebaseFirestore.instance
        .collection('clients')
        .where('commercialId', isEqualTo: widget.prelevement['commercialId'])
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {"id": d.id, ...d.data() as Map<String, dynamic>})
            .toList());
  }

  @override
  void initState() {
    super.initState();
    _loadVentesEtInit();
  }

  Future<void> _loadVentesEtInit() async {
    // 1. Récupérer toutes les ventes déjà faites sur ce prélèvement
    final snapshot = await FirebaseFirestore.instance
        .collection('ventes')
        .doc(widget.prelevement['commercialId'])
        .collection('ventes_effectuees')
        .where('prelevementId', isEqualTo: widget.prelevement['id'])
        .get();

    // 2. Calculer la quantité déjà vendue par type d'emballage
    Map<String, int> potsDejaVendus = {};
    for (var e in widget.prelevement['emballages'] ?? []) {
      potsDejaVendus[e['type']] = 0;
    }
    double qteVendue = 0;
    double montantDejaVendu = 0;

    for (final doc in snapshot.docs) {
      final v = doc.data();
      final embVendus = v['emballagesVendus'] ?? [];
      for (final emb in embVendus) {
        final type = emb['type'];
        potsDejaVendus[type] =
            (potsDejaVendus[type] ?? 0) + ((emb['nombre'] ?? 0) as num).toInt();
        qteVendue += (emb['contenanceKg'] ?? 0.0) * (emb['nombre'] ?? 0);
        montantDejaVendu += (emb['prixTotal'] ?? 0.0);
      }
    }

    // 3. Calculer les max restants
    maxPotsRestants = {};
    for (final e in widget.prelevement['emballages'] ?? []) {
      final type = e['type'];
      final maxDispo = (e['nombre'] ?? 0) - (potsDejaVendus[type] ?? 0);
      maxPotsRestants[type] = maxDispo > 0 ? maxDispo : 0;
      // Initialiser le contrôleur avec la valeur max restante (par défaut)
      nbPotsController[type] =
          TextEditingController(text: maxPotsRestants[type].toString());
      nbPotsController[type]!.addListener(_recalc);
    }

    // 4. Initialiser les champs d'affichage
    _recalc();

    setState(() {
      isLoading = false;
    });
  }

  void _recalc() {
    double qte = 0, montant = 0;
    quantiteParType = {};
    for (final e in widget.prelevement['emballages'] ?? []) {
      final type = e['type'];
      final maxPots = maxPotsRestants[type] ?? 0;
      final textVal = nbPotsController[type]?.text ?? '';
      int currVal = int.tryParse(textVal) ?? 0;
      // Clamp entre 0 et maxPots restants
      if (currVal > maxPots) {
        currVal = maxPots;
        nbPotsController[type]?.text = maxPots.toString();
        nbPotsController[type]?.selection = TextSelection.collapsed(
            offset: nbPotsController[type]!.text.length);
      }
      if (currVal < 0) {
        currVal = 0;
        nbPotsController[type]?.text = '0';
        nbPotsController[type]?.selection = TextSelection.collapsed(offset: 1);
      }
      final kg = e['contenanceKg'] * currVal;
      final prix = e['prixUnitaire'] * currVal;
      qte += kg;
      montant += prix;
      quantiteParType[type] = currVal;
    }
    setState(() {
      quantiteTotale = qte;
      montantTotal = montant;
      montantRestant = montantTotal - montantPaye;
    });
  }

  void _onMontantPayeChanged(String v) {
    montantPaye = double.tryParse(v) ?? 0;
    setState(() {
      montantRestant = montantTotal - montantPaye;
    });
  }

  Future<void> _saveVente() async {
    if (!_formKey.currentState!.validate()) return;
    if (_clientId == null) {
      Get.snackbar("Erreur", "Sélectionnez un client !");
      return;
    }
    // Enregistrer la vente dans la sous-collection du commercial
    final venteData = {
      "dateVente": _dateVente,
      "commercialId": widget.prelevement['commercialId'],
      "clientId": _clientId,
      "prelevementId": widget.prelevement['id'],
      "typeVente": typeVente,
      "emballagesVendus": [
        for (final e in widget.prelevement['emballages'] ?? [])
          {
            "type": e['type'],
            "nombre": quantiteParType[e['type']] ?? 0,
            "contenanceKg": e['contenanceKg'],
            "prixUnitaire": e['prixUnitaire'],
            "prixTotal": (quantiteParType[e['type']] ?? 0) * e['prixUnitaire'],
          }
      ],
      "quantiteTotale": quantiteTotale,
      "montantTotal": montantTotal,
      "montantPaye": montantPaye,
      "montantRestant": montantTotal - montantPaye,
      "createdAt": FieldValue.serverTimestamp(),
    };
    await FirebaseFirestore.instance
        .collection('ventes')
        .doc(widget.prelevement['commercialId'])
        .collection('ventes_effectuees')
        .add(venteData);
    Get.snackbar("Succès", "Vente enregistrée !");
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nouvelle vente"),
        backgroundColor: Colors.blue[700],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(18),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // Date de vente
                    ListTile(
                      title: Text(_dateVente != null
                          ? "Date : ${_dateVente!.day}/${_dateVente!.month}/${_dateVente!.year}"
                          : "Sélectionner la date de vente"),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dateVente ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => _dateVente = picked);
                      },
                    ),
                    const SizedBox(height: 10),
                    // Client existant ou nouveau (en temps réel)
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: clientsStream,
                      builder: (context, snap) {
                        final clients = snap.data ?? [];
                        return Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _clientId,
                                items: clients
                                    .map((c) => DropdownMenuItem<String>(
                                          value: c['id'] as String,
                                          child: Text(c['nomBoutique'] ??
                                              c['nomGerant'] ??
                                              "Client"),
                                        ))
                                    .toList(),
                                decoration: const InputDecoration(
                                    labelText: "Nom du client"),
                                onChanged: (v) => setState(() => _clientId = v),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.person_add),
                              tooltip: "Ajouter un client",
                              onPressed: () async {
                                final newClientId = await Get.to(() =>
                                    ClientFormPage(
                                        commercialId: widget
                                            .prelevement['commercialId']));
                                if (newClientId != null) {
                                  setState(() {
                                    _clientId = newClientId;
                                  });
                                }
                              },
                            )
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    // Type de vente
                    DropdownButtonFormField<String>(
                      value: typeVente,
                      items: [
                        "Comptant",
                        "Crédit",
                        "Recouvrement",
                      ]
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t),
                              ))
                          .toList(),
                      decoration:
                          const InputDecoration(labelText: "Type de vente"),
                      onChanged: (v) {
                        setState(() {
                          typeVente = v ?? "Comptant";
                          if (typeVente == "Comptant") {
                            montantPaye = montantTotal;
                            montantRestant = 0;
                          } else {
                            montantPaye = 0;
                            montantRestant = montantTotal;
                          }
                        });
                      },
                    ),
                    const Divider(height: 30),
                    // Emballages à vendre
                    ...widget.prelevement['emballages'].map<Widget>((e) {
                      final type = e['type'];
                      final maxPots = maxPotsRestants[type] ?? 0;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(type),
                          const SizedBox(width: 8),
                          Text(
                            "($maxPots dispo)",
                            style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                fontSize: 13,
                                color: Colors.grey),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: nbPotsController[type],
                              keyboardType: TextInputType.number,
                              decoration:
                                  const InputDecoration(labelText: "Nb pots"),
                              validator: (v) {
                                final num = int.tryParse(v ?? '') ?? 0;
                                if (num < 0) return "Invalide";
                                if (num > maxPots) return "Max: $maxPots";
                                return null;
                              },
                              onChanged: (_) {
                                int val = int.tryParse(
                                        nbPotsController[type]?.text ?? '') ??
                                    0;
                                if (val > maxPots) {
                                  nbPotsController[type]?.text =
                                      maxPots.toString();
                                  nbPotsController[type]?.selection =
                                      TextSelection.collapsed(
                                          offset: nbPotsController[type]!
                                              .text
                                              .length);
                                }
                                if (val < 0) {
                                  nbPotsController[type]?.text = '0';
                                  nbPotsController[type]?.selection =
                                      TextSelection.collapsed(offset: 1);
                                }
                                _recalc();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text("${e['prixUnitaire']} FCFA/pot"),
                        ],
                      );
                    }),
                    const Divider(height: 30),
                    // Montants dynamiques
                    Text(
                        "Quantité totale : ${quantiteTotale.toStringAsFixed(2)} kg"),
                    Text(
                        "Montant total : ${montantTotal.toStringAsFixed(0)} FCFA"),
                    TextFormField(
                      decoration:
                          const InputDecoration(labelText: "Montant payé"),
                      keyboardType: TextInputType.number,
                      initialValue:
                          montantPaye > 0 ? montantPaye.toString() : "",
                      onChanged: _onMontantPayeChanged,
                    ),
                    Text(
                        "Montant restant à payer : ${montantRestant < 0 ? 0 : montantRestant.toStringAsFixed(0)} FCFA"),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text("Enregistrer la vente"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700]),
                      onPressed: _saveVente,
                    )
                  ],
                ),
              ),
            ),
    );
  }
}
