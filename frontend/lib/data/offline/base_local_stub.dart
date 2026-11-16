import 'package:sembast/sembast_memory.dart';

Future<Database> abrirBaseLocalEnPlataforma(String nombre) => databaseFactoryMemory.openDatabase(nombre);
