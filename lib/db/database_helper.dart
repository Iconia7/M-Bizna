import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('m_bizna_main.db'); // 🛡️ Stable filename
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path, 
      version: 6, // 🚀 Incremented version for new features
      onCreate: _createDB,
      onUpgrade: _onUpgrade, // 👈 Added migration handler
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migrate from v1 to v2: Add wallet and history if missing
    }
    if (oldVersion < 3) {
      // Migrate to v3: Add settings table
      await db.execute('CREATE TABLE IF NOT EXISTS settings (id INTEGER PRIMARY KEY, mpesa_mode TEXT DEFAULT "Manual", mpesa_number TEXT, payhero_channel_id TEXT, payhero_auth TEXT)');
      await db.insert('settings', {'id': 1, 'mpesa_mode': 'Manual'});
    }
    if (oldVersion < 4) {
      // Migrate to v4: Add expenses table and unit column
      await db.execute('CREATE TABLE IF NOT EXISTS expenses (id INTEGER PRIMARY KEY AUTOINCREMENT, description TEXT NOT NULL, amount REAL NOT NULL, category TEXT NOT NULL, date_time TEXT NOT NULL)');
      
      // Check if unit column exists before adding
      var tableInfo = await db.rawQuery('PRAGMA table_info(products)');
      bool columnExists = tableInfo.any((column) => column['name'] == 'unit');
      if (!columnExists) {
        await db.execute('ALTER TABLE products ADD COLUMN unit TEXT DEFAULT "Pcs"');
      }
    }
    if (oldVersion < 5) {
       // Placeholder for v5
    }
    if (oldVersion < 6) {
      // Migrate to v6: Add missing settings columns
      try {
        await db.execute('ALTER TABLE settings ADD COLUMN mpesa_channel_type TEXT DEFAULT "Paybill"');
        await db.execute('ALTER TABLE settings ADD COLUMN mpesa_shortcode TEXT');
        await db.execute('ALTER TABLE settings ADD COLUMN mpesa_account TEXT');
      } catch (e) {
        print("Migration v6 error (columns might exist): $e");
      }
    }
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    const intType = 'INTEGER NOT NULL';

    // 1. Products (Added 'unit' and changed stock_qty to realType)
    await db.execute('''
      CREATE TABLE products (
        id $idType,
        name $textType,
        barcode $textType,
        buy_price $realType,
        sell_price $realType,
        stock_qty $realType, -- 👈 Changed to REAL for decimal stock (e.g. 50.5 kg)
        unit TEXT DEFAULT 'Pcs', -- 👈 NEW: 'Kg', 'Litre', 'Bunch'
        image_path TEXT 
      )
    ''');

    // 2. Sales (Changed quantity to realType)
    await db.execute('''
      CREATE TABLE sales (
        id $idType,
        product_id $intType,
        customer_id INTEGER, 
        quantity $realType, -- 👈 Changed to REAL for decimal sales (e.g. 1.75 kg)
        total_price $realType,
        profit $realType,
        payment_method TEXT,
        date_time $textType,
        synced $intType 
      )
    ''');

    // 3. Customers
    await db.execute('''
      CREATE TABLE customers (
        id $idType,
        name $textType,
        phone $textType,
        current_debt $realType DEFAULT 0,
        credit_limit $realType DEFAULT 2000
      )
    ''');

    // 4. Wallet
    await db.execute('''
      CREATE TABLE wallet (
        id INTEGER PRIMARY KEY,
        balance REAL DEFAULT 0.0
      )
    ''');
    await db.insert('wallet', {'id': 1, 'balance': 0.0});

    // 5. Wallet History
    await db.execute('''
      CREATE TABLE wallet_transactions (
        id $idType,
        amount $realType,
        type $textType, 
        description $textType, 
        date_time $textType
      )
    ''');
    await db.execute('''
  CREATE TABLE settings (
    id INTEGER PRIMARY KEY,
    mpesa_mode TEXT DEFAULT 'Manual', 
    mpesa_number TEXT,               
    payhero_channel_id TEXT,         
    payhero_auth TEXT,
    mpesa_channel_type TEXT DEFAULT 'Paybill', -- 👈 NEW
    mpesa_shortcode TEXT, -- 👈 NEW
    mpesa_account TEXT -- 👈 NEW
  )
''');
await db.insert('settings', {'id': 1, 'mpesa_mode': 'Manual'});

    // 6. Expenses
    await db.execute('''
      CREATE TABLE expenses (
        id $idType,
        description $textType,
        amount $realType,
        category $textType,
        date_time $textType
      )
    ''');
  }

  Future<void> resetDatabase() async {
    final db = await instance.database;
    await db.delete('products');
    await db.delete('sales');
    await db.delete('customers');
    await db.delete('wallet_transactions');
  }

  // Add this inside your DatabaseHelper class
Future<Map<String, dynamic>> getSettings() async {
  final db = await instance.database;
  final maps = await db.query('settings', where: 'id = ?', whereArgs: [1]);

  if (maps.isNotEmpty) {
    return maps.first;
  } else {
    // Return default values if table is empty
    return {'mpesa_mode': 'Manual', 'mpesa_number': ''};
  }
}

Future<int> updateSettings(Map<String, dynamic> settings) async {
  final db = await instance.database;
  return await db.update(
    'settings',
    settings,
    where: 'id = ?',
    whereArgs: [1],
  );
}
}