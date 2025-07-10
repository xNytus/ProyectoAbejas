import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:app_abejas/models/sensor.dart';
import 'package:app_abejas/models/sensor_data.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'abejas_app.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, 
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sensors (
        nombre TEXT PRIMARY KEY,
        lat REAL NOT NULL,
        lng REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sensor_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sensorId TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        temperaturaInt REAL NOT NULL,
        temperaturaExt REAL NOT NULL,
        humedadInt REAL NOT NULL,
        humedadExt REAL NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        UNIQUE(sensorId, timestamp)
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE sensor_data ADD COLUMN lat REAL NOT NULL DEFAULT 0.0");
      await db.execute("ALTER TABLE sensor_data ADD COLUMN lng REAL NOT NULL DEFAULT 0.0");
    }
  }


  Future<void> insertSensors(List<Sensor> sensors) async {
    final db = await database;
    Batch batch = db.batch();
    for (var sensor in sensors) {
      batch.insert(
        'sensors',
        {
          'nombre': sensor.nombre,
          'lat': sensor.ubicacion.latitude,
          'lng': sensor.ubicacion.longitude,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Sensor>> getUniqueSensors() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('sensors');

    return List.generate(maps.length, (i) {
      return Sensor(
        nombre: maps[i]['nombre'],
        ubicacion: LatLng(maps[i]['lat'], maps[i]['lng']),
        color: Colors.blueGrey, 
      );
    });
  }


  Future<void> insertSensorData(List<SensorData> data) async {
    final db = await database;
    Batch batch = db.batch();
    for (var item in data) {
      batch.insert(
        'sensor_data',
        {
          'sensorId': item.sensorId,
          'timestamp': item.timestamp.toIso8601String(),
          'temperaturaInt': item.temperaturaInt,
          'temperaturaExt': item.temperaturaExt,
          'humedadInt': item.humedadInt,
          'humedadExt': item.humedadExt,
          'lat': item.lat,
          'lng': item.lng,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<SensorData>> getSensorData(String sensorId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sensor_data',
      where: 'sensorId = ?',
      whereArgs: [sensorId],
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) {
      return SensorData(
        sensorId: maps[i]['sensorId'],
        timestamp: DateTime.parse(maps[i]['timestamp']),
        temperaturaInt: maps[i]['temperaturaInt'],
        temperaturaExt: maps[i]['temperaturaExt'],
        humedadInt: maps[i]['humedadInt'],
        humedadExt: maps[i]['humedadExt'],
        lat: maps[i]['lat'],
        lng: maps[i]['lng'],
      );
    });
  }
}