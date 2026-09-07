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
      version: 8, // Incremented version for daily closings, suppliers, and returns
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
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
    if (oldVersion < 7) {
      // Migrate to v7: Add stock_movements and customer_ledger tables
      await db.execute('''
        CREATE TABLE IF NOT EXISTS stock_movements (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          change_qty REAL NOT NULL,
          previous_qty REAL NOT NULL,
          new_qty REAL NOT NULL,
          type TEXT NOT NULL,
          reason TEXT,
          date_time TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS customer_ledger (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER NOT NULL,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          balance_after REAL NOT NULL,
          note TEXT,
          date_time TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 8) {
      // Migrate to v8: Add daily_closings, suppliers, and returns tables
      await db.execute('''
        CREATE TABLE IF NOT EXISTS daily_closings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          starting_float REAL NOT NULL,
          gross_sales REAL NOT NULL,
          cash_sales REAL NOT NULL,
          mpesa_sales REAL NOT NULL,
          credit_sales REAL NOT NULL,
          total_profit REAL NOT NULL,
          total_expenses REAL NOT NULL,
          net_profit REAL NOT NULL,
          expected_cash REAL NOT NULL,
          actual_cash REAL NOT NULL,
          cash_difference REAL NOT NULL,
          closed_at TEXT NOT NULL,
          notes TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS suppliers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT NOT NULL,
          company TEXT,
          payment_details TEXT,
          notes TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS returns (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sale_id INTEGER NOT NULL,
          product_id INTEGER NOT NULL,
          quantity REAL NOT NULL,
          refund_amount REAL NOT NULL,
          reason TEXT NOT NULL,
          date_time TEXT NOT NULL
        )
      ''');
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
        stock_qty $realType,
        unit TEXT DEFAULT 'Pcs',
        image_path TEXT 
      )
    ''');

    // 2. Sales (Changed quantity to realType)
    await db.execute('''
      CREATE TABLE sales (
        id $idType,
        product_id $intType,
        customer_id INTEGER, 
        quantity $realType,
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

    // 6. Settings
    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY,
        mpesa_mode TEXT DEFAULT 'Manual', 
        mpesa_number TEXT,               
        payhero_channel_id TEXT,         
        payhero_auth TEXT,
        mpesa_channel_type TEXT DEFAULT 'Paybill',
        mpesa_shortcode TEXT,
        mpesa_account TEXT
      )
    ''');
    await db.insert('settings', {'id': 1, 'mpesa_mode': 'Manual'});

    // 7. Expenses
    await db.execute('''
      CREATE TABLE expenses (
        id $idType,
        description $textType,
        amount $realType,
        category $textType,
        date_time $textType
      )
    ''');

    // 8. Stock Movements (Audit Trail)
    await db.execute('''
      CREATE TABLE stock_movements (
        id $idType,
        product_id $intType,
        change_qty $realType,
        previous_qty $realType,
        new_qty $realType,
        type $textType,
        reason TEXT,
        date_time $textType
      )
    ''');

    // 9. Customer Credit/Repayment Ledger
    await db.execute('''
      CREATE TABLE customer_ledger (
        id $idType,
        customer_id $intType,
        type $textType,
        amount $realType,
        balance_after $realType,
        note TEXT,
        date_time $textType
      )
    ''');

    // 10. Daily Closings (Z-Reports)
    await db.execute('''
      CREATE TABLE daily_closings (
        id $idType,
        date $textType,
        starting_float $realType,
        gross_sales $realType,
        cash_sales $realType,
        mpesa_sales $realType,
        credit_sales $realType,
        total_profit $realType,
        total_expenses $realType,
        net_profit $realType,
        expected_cash $realType,
        actual_cash $realType,
        cash_difference $realType,
        closed_at $textType,
        notes TEXT
      )
    ''');

    // 11. Suppliers
    await db.execute('''
      CREATE TABLE suppliers (
        id $idType,
        name $textType,
        phone $textType,
        company TEXT,
        payment_details TEXT,
        notes TEXT
      )
    ''');

    // 12. Returns & Refunds
    await db.execute('''
      CREATE TABLE returns (
        id $idType,
        sale_id $intType,
        product_id $intType,
        quantity $realType,
        refund_amount $realType,
        reason $textType,
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