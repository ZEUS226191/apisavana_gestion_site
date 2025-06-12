import 'package:apisavana_gestion/screens/collecte_de_donnes/collecte_donnes.dart';
import 'package:apisavana_gestion/screens/commercialisation/commer_home.dart';
import 'package:apisavana_gestion/screens/conditionnement/condionnement_home.dart';
import 'package:apisavana_gestion/screens/controle_de_donnes/controle_de_donnes.dart';
import 'package:apisavana_gestion/screens/dashboard/dashboard.dart';
import 'package:apisavana_gestion/screens/extraction_page/extraction.dart';
import 'package:apisavana_gestion/screens/filtrage/filtrage_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'authentication/login.dart';
import 'authentication/sign_up.dart';
import 'authentication/user_session.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCQVVqssk1aMPh5cgJi2a3XAqFJ2_cOXPc",
      authDomain: "apisavana-bf-226.firebaseapp.com",
      projectId: "apisavana-bf-226",
      storageBucket: "apisavana-bf-226.firebasestorage.app",
      messagingSenderId: "955408721623",
      appId: "1:955408721623:web:e78c39e6801db32545b292",
      measurementId: "G-NH4D0Q9NTS",
    ),
  );

  Get.put(UserSession());

  runApp(const ApisavanaApp());
}

class ApisavanaApp extends StatelessWidget {
  const ApisavanaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Apisavana',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.amber,
        fontFamily: 'Montserrat',
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/login',
      getPages: [
        GetPage(name: '/login', page: () => LoginPage()),
        GetPage(name: '/dashboard', page: () => DashboardScreen()),
        GetPage(name: '/signup', page: () => SignupPage()),
        GetPage(name: '/collecte', page: () => CollectePage()),
        GetPage(name: '/controle', page: () => ControlePage()),
        GetPage(name: '/extraction', page: () => ExtractionPage()),
        GetPage(name: '/filtrage', page: () => FiltragePage()),
        GetPage(
            name: '/conditionnement', page: () => ConditionnementHomePage()),
        GetPage(
            name: '/gestion_de_ventes',
            page: () => CommercialisationHomePage()),
      ],
    );
  }
}
