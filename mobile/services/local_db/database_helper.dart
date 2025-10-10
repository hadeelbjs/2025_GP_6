// lib/services/local_db/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'waseed_messages.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // جدول الرسائل المحلي
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        conversationId TEXT NOT NULL,
        senderId TEXT NOT NULL,
        receiverId TEXT NOT NULL,
        ciphertext TEXT NOT NULL,
        type TEXT NOT NULL,
        plaintext TEXT,
        status TEXT DEFAULT 'sent',
        createdAt INTEGER NOT NULL,
        deliveredAt INTEGER,
        readAt INTEGER,
        isMine INTEGER DEFAULT 0,
        FOREIGN KEY (conversationId) REFERENCES conversations(id)
      )
    ''');

    // جدول المحادثات
    await db.execute('''
      CREATE TABLE conversations (
        id TEXT PRIMARY KEY,
        contactId TEXT NOT NULL,
        contactName TEXT NOT NULL,
        lastMessage TEXT,
        lastMessageTime INTEGER,
        unreadCount INTEGER DEFAULT 0,
        updatedAt INTEGER NOT NULL
      )
    ''');

    // فهارس للبحث السريع
    await db.execute('''
      CREATE INDEX idx_messages_conversation 
      ON messages(conversationId, createdAt DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_status 
      ON messages(status, conversationId)
    ''');
  }

  // حفظ رسالة محلياً
  Future<void> saveMessage(Map<String, dynamic> message) async {
    final db = await database;
    await db.insert(
      'messages',
      message,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // جلب رسائل محادثة
  Future<List<Map<String, dynamic>>> getMessages(
    String conversationId, {
    int limit = 50,
    int? before,
  }) async {
    final db = await database;
    
    String whereClause = 'conversationId = ?';
    List<dynamic> whereArgs = [conversationId];
    
    if (before != null) {
      whereClause += ' AND createdAt < ?';
      whereArgs.add(before);
    }
    
    return await db.query(
      'messages',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'createdAt DESC',
      limit: limit,
    );
  }

  // تحديث حالة رسالة
  Future<void> updateMessageStatus(
    String messageId,
    String status,
  ) async {
    final db = await database;
    await db.update(
      'messages',
      {
        'status': status,
        if (status == 'delivered') 'deliveredAt': DateTime.now().millisecondsSinceEpoch,
        if (status == 'read') 'readAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  // حذف كل رسائل محادثة (عند حذف الصديق)
  Future<void> deleteConversation(String conversationId) async {
    final db = await database;
    await db.delete(
      'messages',
      where: 'conversationId = ?',
      whereArgs: [conversationId],
    );
    await db.delete(
      'conversations',
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  // حذف كل البيانات (عند تسجيل الخروج)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('messages');
    await db.delete('conversations');
  }
}