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
      version: 4, // ✅ زيادة الإصدار
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        conversationId TEXT NOT NULL,
        senderId TEXT NOT NULL,
        receiverId TEXT NOT NULL,
        ciphertext TEXT NOT NULL,
        encryptionType INTEGER NOT NULL,
        plaintext TEXT,
        status TEXT DEFAULT 'sent',
        createdAt INTEGER NOT NULL,
        deliveredAt INTEGER,
        readAt INTEGER,
        isMine INTEGER DEFAULT 0,
        requiresBiometric INTEGER DEFAULT 1,
        isDecrypted INTEGER DEFAULT 0,
        deletedForRecipient INTEGER DEFAULT 0,
        attachmentData TEXT,
        attachmentType TEXT,
        attachmentName TEXT,
        FOREIGN KEY (conversationId) REFERENCES conversations(id)
      )
    ''');

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

    await db.execute('''
      CREATE INDEX idx_messages_conversation 
      ON messages(conversationId, createdAt DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_status 
      ON messages(status, conversationId)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE messages ADD COLUMN deletedForRecipient INTEGER DEFAULT 0');
      print('✅ Upgraded to v2');
    }
    
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE messages ADD COLUMN attachmentData TEXT');
      await db.execute('ALTER TABLE messages ADD COLUMN attachmentType TEXT');
      print('✅ Upgraded to v3');
    }
    
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE messages ADD COLUMN attachmentName TEXT');
      print('✅ Upgraded to v4');
    }
  }

  Future<void> saveMessage(Map<String, dynamic> message) async {
    final db = await database;
    await db.insert(
      'messages',
      message,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    await _updateConversationLastMessage(
      message['conversationId'],
      message['plaintext'] ?? '🔒 رسالة مشفرة',
      message['createdAt'],
    );
  }

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
      orderBy: 'createdAt ASC',
      limit: limit,
    );
  }

  Future<Map<String, dynamic>?> getMessage(String messageId) async {
    final db = await database;
    
    final result = await db.query(
      'messages',
      where: 'id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    
    if (result.isEmpty) return null;
    return result.first;
  }

  Future<void> updateMessageStatus(
    String messageId,
    String status,
  ) async {
    final db = await database;
    await db.update(
      'messages',
      {
        'status': status,
        if (status == 'delivered') 
          'deliveredAt': DateTime.now().millisecondsSinceEpoch,
        if (status == 'read') 
          'readAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> updateMessage(
    String messageId,
    Map<String, dynamic> updates,
  ) async {
    final db = await database;
    await db.update(
      'messages',
      updates,
      where: 'id = ?',
      whereArgs: [messageId],
    );
    
    if (updates.containsKey('plaintext')) {
      final message = await getMessage(messageId);
      if (message != null) {
        await _updateConversationLastMessage(
          message['conversationId'],
          updates['plaintext'],
          message['createdAt'],
        );
      }
    }
  }

  Future<int> getUnreadCount(String conversationId) async {
    final db = await database;
    
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM messages
      WHERE conversationId = ? 
      AND isMine = 0
      AND status != 'read'
    ''', [conversationId]);
    
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markConversationAsRead(String conversationId) async {
    final db = await database;
    
    await db.update(
      'messages',
      {
        'status': 'read',
        'readAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'conversationId = ? AND isMine = 0 AND status != ?',
      whereArgs: [conversationId, 'read'],
    );
    
    await db.update(
      'conversations',
      {'unreadCount': 0},
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  Future<List<Map<String, dynamic>>> getConversations() async {
    final db = await database;
    
    return await db.query(
      'conversations',
      orderBy: 'lastMessageTime DESC',
    );
  }

  Future<void> saveConversation(Map<String, dynamic> conversation) async {
    final db = await database;
    
    await db.insert(
      'conversations',
      conversation,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _updateConversationLastMessage(
    String conversationId,
    String lastMessage,
    int timestamp,
  ) async {
    final db = await database;
    
    final conversation = await db.query(
      'conversations',
      where: 'id = ?',
      whereArgs: [conversationId],
      limit: 1,
    );
    
    if (conversation.isNotEmpty) {
      await db.update(
        'conversations',
        {
          'lastMessage': lastMessage,
          'lastMessageTime': timestamp,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [conversationId],
      );
    }
  }

  Future<void> incrementUnreadCount(String conversationId) async {
    final db = await database;
    
    await db.rawUpdate('''
      UPDATE conversations 
      SET unreadCount = unreadCount + 1
      WHERE id = ?
    ''', [conversationId]);
  }

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

  Future<int> deleteMessage(String messageId) async {
    final db = await database;
    return await db.delete(
      'messages',
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('messages');
    await db.delete('conversations');
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}