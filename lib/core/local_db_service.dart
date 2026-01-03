import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDBService {
  static final LocalDBService _instance = LocalDBService._internal();
  static Database? _database;

  factory LocalDBService() => _instance;
  LocalDBService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'famvault.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        // Table for Folders
        await db.execute('''
          CREATE TABLE folders(
            id TEXT PRIMARY KEY,
            name TEXT,
            icon TEXT,
            family_id TEXT,
            owner_id TEXT
          )
        ''');

        // Table for Documents
        await db.execute('''
          CREATE TABLE documents(
            id TEXT PRIMARY KEY,
            name TEXT,
            folder_id TEXT,
            file_path TEXT,
            file_type TEXT,
            created_at TEXT,
            is_deleted INTEGER
          )
        ''');

        // Table for Family Members
        await db.execute('''
          CREATE TABLE family_members(
            user_id TEXT,
            family_id TEXT,
            role TEXT,
            full_name TEXT,
            avatar_url TEXT,
            PRIMARY KEY (user_id, family_id)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add family_members table for version 2
          await db.execute('''
            CREATE TABLE family_members(
              user_id TEXT,
              family_id TEXT,
              role TEXT,
              full_name TEXT,
              avatar_url TEXT,
              PRIMARY KEY (user_id, family_id)
            )
          ''');
        }
      },
    );
  }

  // --- 1. SAVE & GET FOLDERS ---
  Future<void> cacheFolders(List<Map<String, dynamic>> folders) async {
    final db = await database;
    final batch = db.batch();

    // Clear old data for these specific IDs to avoid duplicates/stale data
    // (Simple approach: we just replace on conflict)
    for (var folder in folders) {
      batch.insert(
        'folders',
        {
          'id': folder['id'],
          'name': folder['name'],
          'icon': folder['icon'],
          'family_id': folder['family_id'],
          'owner_id': folder['owner_id'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getFolders(String familyId) async {
    final db = await database;
    // Get general folders (owner_id is null)
    return await db.query('folders', where: 'family_id = ? AND owner_id IS NULL', whereArgs: [familyId]);
  }

  Future<List<Map<String, dynamic>>> getPersonalFolders(String userId) async {
    final db = await database;
    return await db.query('folders', where: 'owner_id = ?', whereArgs: [userId]);
  }

  // --- 2. SAVE & GET DOCUMENTS ---
  Future<void> cacheDocuments(List<Map<String, dynamic>> docs) async {
    final db = await database;
    final batch = db.batch();
    for (var doc in docs) {
      batch.insert(
        'documents',
        {
          'id': doc['id'],
          'name': doc['name'],
          'folder_id': doc['folder_id'],
          'file_path': doc['file_path'],
          'file_type': doc['file_type'],
          'created_at': doc['created_at'],
          'is_deleted': doc['is_deleted'] == true ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getDocuments(String folderId) async {
    final db = await database;
    final res = await db.query(
      'documents',
      where: 'folder_id = ? AND is_deleted = 0',
      whereArgs: [folderId],
      orderBy: 'created_at DESC'
    );
    // Convert SQLite 0/1 back to boolean for the app
    return res.map((e) {
      final map = Map<String, dynamic>.from(e);
      map['is_deleted'] = e['is_deleted'] == 1;
      return map;
    }).toList();
  }

  // --- 3. SAVE & GET FAMILY MEMBERS ---
  Future<void> cacheFamilyMembers(List<Map<String, dynamic>> members, String familyId) async {
    final db = await database;
    final batch = db.batch();

    // Clear old members for this family to avoid stale data
    await db.delete('family_members', where: 'family_id = ?', whereArgs: [familyId]);

    for (var member in members) {
      final profile = member['profiles'] ?? {};
      batch.insert(
        'family_members',
        {
          'user_id': member['user_id'],
          'family_id': familyId,
          'role': member['role'],
          'full_name': profile['full_name'] ?? 'Unknown Member',
          'avatar_url': profile['avatar_url'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getFamilyMembers(String familyId) async {
    final db = await database;
    final res = await db.query('family_members', where: 'family_id = ?', whereArgs: [familyId]);
    // Convert back to the format expected by the UI
    return res.map((e) {
      final map = Map<String, dynamic>.from(e);
      map['profiles'] = {
        'full_name': e['full_name'],
        'avatar_url': e['avatar_url'],
      };
      return map;
    }).toList();
  }
}
