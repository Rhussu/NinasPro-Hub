import 'package:sembast_web/sembast_web.dart';

Future<Database> abrirBaseLocalEnPlataforma(String nombre) => databaseFactoryWeb.openDatabase(nombre);
