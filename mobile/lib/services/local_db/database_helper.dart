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
      version: 6, // ✅ تحديث النسخة إلى 6
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // ✅ جدول الرسائل مع جميع الأعمدة
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
        isDeleted INTEGER DEFAULT 0,
        isDeletedForMe INTEGER DEFAULT 0,
        deletedForRecipient INTEGER DEFAULT 0,
        failedVerificationAtRecipient INTEGER DEFAULT 0,
        isLocked INTEGER DEFAULT 0,
        attachmentData TEXT,
        attachmentType TEXT,
        attachmentName TEXT,
        FOREIGN KEY (conversationId) REFERENCES conversations(id)
      )
    ''');

    // ✅ جدول المحادثات
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

    // ✅ Indexes للأداء
    await db.execute('''
      CREATE INDEX idx_messages_conversation 
      ON messages(conversationId, createdAt DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_status 
      ON messages(status, conversationId)
    ''');
    
    await db.execute('''
      CREATE INDEX idx_messages_deleted
      ON messages(isDeleted, isDeletedForMe)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('🔄 Upgrading database from v$oldVersion to v$newVersion');
    
    // Version 2: إضافة deletedForRecipient
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE messages ADD COLUMN deletedForRecipient INTEGER DEFAULT 0');
        print('✅ Upgraded to v2: Added deletedForRecipient');
      } catch (e) {
        print('⚠️ Column deletedForRecipient might already exist');
      }
    }
    
    // Version 3: إضافة المرفقات
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE messages ADD COLUMN attachmentData TEXT');
        await db.execute('ALTER TABLE messages ADD COLUMN attachmentType TEXT');
        print('✅ Upgraded to v3: Added attachments');
      } catch (e) {
        print('⚠️ Attachment columns might already exist');
      }
    }
    
    // Version 4: إضافة attachmentName
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE messages ADD COLUMN attachmentName TEXT');
        print('✅ Upgraded to v4: Added attachmentName');
      } catch (e) {
        print('⚠️ Column attachmentName might already exist');
      }
    }

    // Version 5: إضافة failedVerificationAtRecipient
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE messages ADD COLUMN failedVerificationAtRecipient INTEGER DEFAULT 0');
        print('✅ Upgraded to v5: Added failedVerificationAtRecipient');
      } catch (e) {
        print('⚠️ Column failedVerificationAtRecipient might already exist');
      }
    }
    
    // ✅ Version 6: إضافة أعمدة الحذف والقفل
    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE messages ADD COLUMN isDeleted INTEGER DEFAULT 0');
        print('✅ Added isDeleted');
      } catch (e) {
        print('⚠️ Column isDeleted might already exist');
      }
      
      try {
        await db.execute('ALTER TABLE messages ADD COLUMN isDeletedForMe INTEGER DEFAULT 0');
        print('✅ Added isDeletedForMe');
      } catch (e) {
        print('⚠️ Column isDeletedForMe might already exist');
      }
      
      try {
        await db.execute('ALTER TABLE messages ADD COLUMN isLocked INTEGER DEFAULT 0');
        print('✅ Added isLocked');
      } catch (e) {
        print('⚠️ Column isLocked might already exist');
      }
      
      // إضافة Index جديد
      try {
        await db.execute('''
          CREATE INDEX idx_messages_deleted
          ON messages(isDeleted, isDeletedForMe)
        ''');
        print('✅ Created index for deleted messages');
      } catch (e) {
        print('⚠️ Index might already exist');
      }
      
      print('✅ Upgraded to v6: Added deletion and lock columns');
    }
  }

  // ============================================
  // ✅ دوال حفظ وتحديث الرسائل
  // ============================================

  Future<void> saveMessage(Map<String, dynamic> message) async {
    final db = await database;
    
    // ✅ التأكد من وجود جميع الأعمدة المطلوبة
    final messageToSave = {
      'id': message['id'],
      'conversationId': message['conversationId'],
      'senderId': message['senderId'],
      'receiverId': message['receiverId'],
      'ciphertext': message['ciphertext'],
      'encryptionType': message['encryptionType'],
      'plaintext': message['plaintext'],
      'status': message['status'] ?? 'sent',
      'createdAt': message['createdAt'],
      'deliveredAt': message['deliveredAt'],
      'readAt': message['readAt'],
      'isMine': message['isMine'] ?? 0,
      'requiresBiometric': message['requiresBiometric'] ?? 1,
      'isDecrypted': message['isDecrypted'] ?? 0,
      'isDeleted': message['isDeleted'] ?? 0,
      'isDeletedForMe': message['isDeletedForMe'] ?? 0,
      'deletedForRecipient': message['deletedForRecipient'] ?? 0,
      'failedVerificationAtRecipient': message['failedVerificationAtRecipient'] ?? 0,
      'isLocked': message['isLocked'] ?? 0,
      'attachmentData': message['attachmentData'],
      'attachmentType': message['attachmentType'],
      'attachmentName': message['attachmentName'],
    };
    
    await db.insert(
      'messages',
      messageToSave,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    // تحديث آخر رسالة في المحادثة
    await _updateConversationLastMessage(
      message['conversationId'],
      message['plaintext'] ?? '🔒 رسالة مشفرة',
      message['createdAt'],
    );
  }

  // ✅ جلب رسائل المحادثة (مع دعم الأعمدة الجديدة)
  Future<List<Map<String, dynamic>>> getConversationMessages(String conversationId) async {
    final db = await database;
    
    final messages = await db.query(
      'messages',
      where: 'conversationId = ?',
      whereArgs: [conversationId],
      orderBy: 'createdAt ASC',
    );
    
    // ✅ تحويل الرسائل إلى format يفهمه ChatScreen
    return messages.map((msg) => {
      'id': msg['id'],
      'content': msg['plaintext'] ?? msg['ciphertext'],
      'timestamp': DateTime.fromMillisecondsSinceEpoch(msg['createdAt'] as int).toIso8601String(),
      'isMine': msg['isMine'] == 1,
      'status': msg['status'],
      'isDeleted': msg['isDeleted'] == 1,
      'isDeletedForMe': msg['isDeletedForMe'] == 1,
      'isDeletedForRecipient': msg['deletedForRecipient'] == 1,
      'isLocked': msg['isLocked'] == 1,
      'failedVerificationAtRecipient': msg['failedVerificationAtRecipient'] == 1,
      'attachmentType': msg['attachmentType'],
      'attachmentData': msg['attachmentData'],
      'attachmentName': msg['attachmentName'],
    }).toList();
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

  Future<List<Map<String, dynamic>>> getEncryptedMessages(String conversationId) async {
    final db = await database;
    
    final result = await db.query(
      'messages',
      where: 'conversationId = ? AND isMine = ? AND isDecrypted = ? AND plaintext IS NULL',
      whereArgs: [conversationId, 0, 0],
      orderBy: 'createdAt ASC',
    );
    
    return result;
  }

  Future<List<Map<String, dynamic>>> getPendingMessages() async {
    final db = await database;
    
    final result = await db.query(
      'messages',
      where: 'status IN (?, ?)',
      whereArgs: ['sending', 'pending'],
      orderBy: 'createdAt ASC',
    );
    
    return result;
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

  // ============================================
  // ✅ تحديث حالة الرسائل
  // ============================================

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
          message['createdAt'] as int,
        );
      }
    }
  }

  // ✅ تحديث حالة الحذف
  Future<void> markMessageAsDeleted(String messageId, {bool forMe = false}) async {
    final db = await database;
    
    if (forMe) {
      await db.update(
        'messages',
        {'isDeletedForMe': 1},
        where: 'id = ?',
        whereArgs: [messageId],
      );
    } else {
      await db.update(
        'messages',
        {'isDeleted': 1},
        where: 'id = ?',
        whereArgs: [messageId],
      );
    }
  }

  Future<void> markMessageAsDeletedForRecipient(String messageId) async {
    final db = await database;
    await db.update(
      'messages',
      {'deletedForRecipient': 1},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  // ============================================
  // ✅ إدارة المحادثات
  // ============================================

  Future<int> getUnreadCount(String conversationId) async {
    final db = await database;
    
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM messages
      WHERE conversationId = ? 
      AND isMine = 0
      AND status != 'read'
      AND isDeletedForMe = 0
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

  // ============================================
  // ✅ حذف البيانات
  // ============================================

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

  // ============================================
  // ✅ دوال مساعدة للتشخيص
  // ============================================

  Future<void> printDatabaseSchema() async {
    final db = await database;
    
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'"
    );
    
    print('📊 Database Tables:');
    for (var table in tables) {
      final tableName = table['name'];
      print('\n📋 Table: $tableName');
      
      final columns = await db.rawQuery(
        "PRAGMA table_info($tableName)"
      );
      
      for (var col in columns) {
        print('   - ${col['name']}: ${col['type']} (${col['notnull'] == 1 ? 'NOT NULL' : 'NULL'})');
      }
    }
  }

  Future<int> getMessagesCount(String conversationId) async {
    final db = await database;
    
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM messages
      WHERE conversationId = ?
    ''', [conversationId]);
    
    return Sqflite.firstIntValue(result) ?? 0;
  }
}