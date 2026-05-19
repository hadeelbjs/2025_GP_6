import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  static  String? _dbPassword = dotenv.env['DB_PASSWORD'];

  DatabaseHelper._internal();

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'waseed_messages.db');

    return openDatabase(
      path,
      password: _dbPassword,
      version: 7,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ---------------------------------------------------------------------------
  // Schema creation (version 7 baseline)
  // ---------------------------------------------------------------------------

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE conversations (
        id               TEXT    PRIMARY KEY,
        contactId        TEXT    NOT NULL,
        contactName      TEXT    NOT NULL,
        lastMessage      TEXT,
        lastMessageTime  INTEGER,
        unreadCount      INTEGER DEFAULT 0,
        updatedAt        INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id                           TEXT    PRIMARY KEY,
        conversationId               TEXT    NOT NULL,
        allow_screenshots            INTEGER,
        senderId                     TEXT    NOT NULL,
        receiverId                   TEXT    NOT NULL,
        ciphertext                   TEXT    NOT NULL,
        encryptionType               INTEGER NOT NULL,
        plaintext                    TEXT,
        status                       TEXT    DEFAULT 'sent',
        createdAt                    INTEGER NOT NULL,
        deliveredAt                  INTEGER,
        readAt                       INTEGER,
        isMine                       INTEGER DEFAULT 0,
        requiresBiometric            INTEGER DEFAULT 1,
        isDecrypted                  INTEGER DEFAULT 0,
        isDeleted                    INTEGER DEFAULT 0,
        isDeletedForMe               INTEGER DEFAULT 0,
        deletedForRecipient          INTEGER DEFAULT 0,
        failedVerificationAtRecipient INTEGER DEFAULT 0,
        isLocked                     INTEGER DEFAULT 0,
        attachmentData               TEXT,
        attachmentType               TEXT,
        attachmentName               TEXT,
        visibilityDuration           INTEGER,
        expiresAt                    INTEGER,
        isExpired                    INTEGER DEFAULT 0,
        FOREIGN KEY (conversationId) REFERENCES conversations(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE user_conversation_duration (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        conversationId TEXT    NOT NULL UNIQUE,
        currentDuration INTEGER NOT NULL,
        lastModified   INTEGER NOT NULL
      )
    ''');

    // Indexes
    await db.execute('CREATE INDEX idx_messages_conversation ON messages(conversationId, createdAt DESC)');
    await db.execute('CREATE INDEX idx_messages_status      ON messages(status, conversationId)');
    await db.execute('CREATE INDEX idx_messages_deleted     ON messages(isDeleted, isDeletedForMe)');
    await db.execute('CREATE INDEX idx_messages_expiry      ON messages(expiresAt, isExpired)');
  }

  // ---------------------------------------------------------------------------
  // Incremental migrations
  // ---------------------------------------------------------------------------

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _tryAlter(db, 'ALTER TABLE messages ADD COLUMN deletedForRecipient INTEGER DEFAULT 0');
    }

    if (oldVersion < 3) {
      await _tryAlter(db, 'ALTER TABLE messages ADD COLUMN attachmentData TEXT');
      await _tryAlter(db, 'ALTER TABLE messages ADD COLUMN attachmentType TEXT');
    }

    if (oldVersion < 4) {
      await _tryAlter(db, 'ALTER TABLE messages ADD COLUMN attachmentName TEXT');
    }

    if (oldVersion < 5) {
      await _tryAlter(db, 'ALTER TABLE messages ADD COLUMN failedVerificationAtRecipient INTEGER DEFAULT 0');
    }

    if (oldVersion < 6) {
      await _tryAlter(db, 'ALTER TABLE messages ADD COLUMN isDeleted      INTEGER DEFAULT 0');
      await _tryAlter(db, 'ALTER TABLE messages ADD COLUMN isDeletedForMe INTEGER DEFAULT 0');
      await _tryAlter(db, 'ALTER TABLE messages ADD COLUMN isLocked       INTEGER DEFAULT 0');
      await _tryExec(db, 'CREATE INDEX idx_messages_deleted ON messages(isDeleted, isDeletedForMe)');
    }

    if (oldVersion < 7) {
      await _tryAlter(db, 'ALTER TABLE messages ADD COLUMN visibilityDuration INTEGER');
      await _tryAlter(db, 'ALTER TABLE messages ADD COLUMN expiresAt INTEGER');
      await _tryAlter(db, 'ALTER TABLE messages ADD COLUMN isExpired  INTEGER DEFAULT 0');
      await _tryExec(db, '''
        CREATE TABLE IF NOT EXISTS user_conversation_duration (
          id              INTEGER PRIMARY KEY AUTOINCREMENT,
          conversationId  TEXT    NOT NULL UNIQUE,
          currentDuration INTEGER NOT NULL,
          lastModified    INTEGER NOT NULL
        )
      ''');
      await _tryExec(db, 'CREATE INDEX IF NOT EXISTS idx_messages_expiry ON messages(expiresAt, isExpired)');
    }
  }

  // Silently swallows "already exists" errors that are harmless during migrations.
  Future<void> _tryAlter(Database db, String sql) async {
    try {
      await db.execute(sql);
    } catch (_) {}
  }

  Future<void> _tryExec(Database db, String sql) async {
    try {
      await db.execute(sql);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Messages – write
  // ---------------------------------------------------------------------------

  Future<void> saveMessage(Map<String, dynamic> message) async {
    final db = await database;

    await db.insert(
      'messages',
      {
        'id':                            message['id'],
        'conversationId':                message['conversationId'],
        'senderId':                      message['senderId'],
        'receiverId':                    message['receiverId'],
        'ciphertext':                    message['ciphertext'],
        'encryptionType':                message['encryptionType'],
        'plaintext':                     message['plaintext'],
        'status':                        message['status'] ?? 'sent',
        'createdAt':                     message['createdAt'],
        'deliveredAt':                   message['deliveredAt'],
        'readAt':                        message['readAt'],
        'isMine':                        message['isMine'] ?? 0,
        'requiresBiometric':             message['requiresBiometric'] ?? 1,
        'isDecrypted':                   message['isDecrypted'] ?? 0,
        'isDeleted':                     message['isDeleted'] ?? 0,
        'isDeletedForMe':                message['isDeletedForMe'] ?? 0,
        'deletedForRecipient':           message['deletedForRecipient'] ?? 0,
        'failedVerificationAtRecipient': message['failedVerificationAtRecipient'] ?? 0,
        'isLocked':                      message['isLocked'] ?? 0,
        'attachmentData':                message['attachmentData'],
        'attachmentType':                message['attachmentType'],
        'attachmentName':                message['attachmentName'],
        'visibilityDuration':            message['visibilityDuration'],
        'expiresAt':                     message['expiresAt'],
        'isExpired':                     message['isExpired'] ?? 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _updateConversationLastMessage(
      message['conversationId'] as String,
      message['plaintext'] as String? ?? '🔒 رسالة مشفرة',
      message['createdAt'] as int,
    );
  }

  Future<void> updateMessage(String messageId, Map<String, dynamic> updates) async {
    final db = await database;
    await db.update('messages', updates, where: 'id = ?', whereArgs: [messageId]);

    if (updates.containsKey('plaintext')) {
      final message = await getMessage(messageId);
      if (message != null) {
        await _updateConversationLastMessage(
          message['conversationId'] as String,
          updates['plaintext'] as String,
          message['createdAt'] as int,
        );
      }
    }
  }

  Future<void> updateMessageStatus(String messageId, String status) async {
    final db = await database;
    await db.update(
      'messages',
      {
        'status': status,
        if (status == 'delivered') 'deliveredAt': DateTime.now().millisecondsSinceEpoch,
        if (status == 'read')      'readAt':       DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> markMessageAsDeleted(String messageId, {bool forMe = false}) async {
    final db = await database;
    await db.update(
      'messages',
      forMe ? {'isDeletedForMe': 1} : {'isDeleted': 1},
      where: 'id = ?',
      whereArgs: [messageId],
    );
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

  Future<void> markMessageAsExpired(String messageId) async {
    final db = await database;
    await db.update(
      'messages',
      {'isExpired': 1},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  // ---------------------------------------------------------------------------
  // Messages – read
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getMessage(String messageId) async {
    final db = await database;
    final result = await db.query('messages', where: 'id = ?', whereArgs: [messageId], limit: 1);
    return result.isEmpty ? null : result.first;
  }

  /// Returns messages formatted for ChatScreen consumption.
  Future<List<Map<String, dynamic>>> getConversationMessages(String conversationId) async {
    final db = await database;
    final rows = await db.query(
      'messages',
      where: 'conversationId = ?',
      whereArgs: [conversationId],
      orderBy: 'createdAt DESC',
    );

    return rows.map((msg) => {
      'id':                        msg['id'],
      'content':                   msg['plaintext'] ?? msg['ciphertext'],
      'timestamp':                 DateTime.fromMillisecondsSinceEpoch(msg['createdAt'] as int).toIso8601String(),
      'isMine':                    msg['isMine'] == 1,
      'status':                    msg['status'],
      'isDeleted':                 msg['isDeleted'] == 1,
      'isDeletedForMe':            msg['isDeletedForMe'] == 1,
      'isDeletedForRecipient':     msg['deletedForRecipient'] == 1,
      'isLocked':                  msg['isLocked'] == 1,
      'failedVerificationAtRecipient': msg['failedVerificationAtRecipient'] == 1,
      'attachmentType':            msg['attachmentType'],
      'attachmentData':            msg['attachmentData'],
      'attachmentName':            msg['attachmentName'],
      'expiresAt':                 msg['expiresAt'],
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getMessages(
    String conversationId, {
    int limit = 50,
    int? before,
  }) async {
    final db = await database;
    final where = before != null
        ? 'conversationId = ? AND createdAt < ?'
        : 'conversationId = ?';
    final args = before != null ? [conversationId, before] : [conversationId];

    return db.query(
      'messages',
      where: where,
      whereArgs: args,
      orderBy: 'createdAt DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> getEncryptedMessages(String conversationId) async {
    final db = await database;
    return db.query(
      'messages',
      where: 'conversationId = ? AND isMine = 0 AND isDecrypted = 0 AND plaintext IS NULL',
      whereArgs: [conversationId],
      orderBy: 'createdAt ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getPendingMessages() async {
    final db = await database;
    return db.query(
      'messages',
      where: "status IN ('sending', 'pending')",
      orderBy: 'createdAt ASC',
    );
  }

  // ---------------------------------------------------------------------------
  // Messages – delete
  // ---------------------------------------------------------------------------

  Future<int> deleteMessage(String messageId) async {
    final db = await database;
    return db.delete('messages', where: 'id = ?', whereArgs: [messageId]);
  }

  /// Alias kept for callers that use the explicit name.
  Future<void> deleteMessageById(String messageId) => deleteMessage(messageId);

  Future<List<String>> deleteExpiredMessages() async {
    final db = await database;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    final expired = await db.query(
      'messages',
      columns: ['id'],
      where: 'expiresAt IS NOT NULL AND CAST(expiresAt AS INTEGER) < ?',
      whereArgs: [now],
    );

    if (expired.isEmpty) return [];

    final ids = expired.map((r) => r['id'] as String).toList();

    await db.delete(
      'messages',
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );

    return ids;
  }

  // ---------------------------------------------------------------------------
  // Conversations
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getConversations() async {
    final db = await database;
    return db.query('conversations', orderBy: 'lastMessageTime DESC');
  }

  Future<void> saveConversation(Map<String, dynamic> conversation) async {
    final db = await database;
    await db.insert('conversations', conversation, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> markConversationAsRead(String conversationId) async {
    final db = await database;
    await db.update(
      'messages',
      {'status': 'read', 'readAt': DateTime.now().millisecondsSinceEpoch},
      where: "conversationId = ? AND isMine = 0 AND status != 'read'",
      whereArgs: [conversationId],
    );
    await db.update('conversations', {'unreadCount': 0}, where: 'id = ?', whereArgs: [conversationId]);
  }

  Future<int> getUnreadCount(String conversationId) async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) AS count FROM messages WHERE conversationId = ? AND isMine = 0 AND status != 'read' AND isDeletedForMe = 0",
      [conversationId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> incrementUnreadCount(String conversationId) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE conversations SET unreadCount = unreadCount + 1 WHERE id = ?',
      [conversationId],
    );
  }

  Future<void> deleteConversation(String conversationId) async {
    final db = await database;
    await db.delete('messages',      where: 'conversationId = ?', whereArgs: [conversationId]);
    await db.delete('conversations', where: 'id = ?',             whereArgs: [conversationId]);
  }

  Future<void> _updateConversationLastMessage(
    String conversationId,
    String lastMessage,
    int timestamp,
  ) async {
    final db = await database;
    final exists = await db.query('conversations', where: 'id = ?', whereArgs: [conversationId], limit: 1);
    if (exists.isEmpty) return;

    await db.update(
      'conversations',
      {
        'lastMessage':     lastMessage,
        'lastMessageTime': timestamp,
        'updatedAt':       DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  // ---------------------------------------------------------------------------
  // Visibility / duration
  // ---------------------------------------------------------------------------

  Future<int?> getUserDuration(String conversationId) async {
    final db = await database;
    final result = await db.query(
      'user_conversation_duration',
      where: 'conversationId = ?',
      whereArgs: [conversationId],
    );
    return result.isEmpty ? null : result.first['currentDuration'] as int;
  }

  Future<void> setUserDuration(String conversationId, int duration) async {
    final db = await database;
    await db.insert(
      'user_conversation_duration',
      {
        'conversationId':  conversationId,
        'currentDuration': duration,
        'lastModified':    DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---------------------------------------------------------------------------
  // Housekeeping
  // ---------------------------------------------------------------------------

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('messages');
    await db.delete('conversations');
    await db.delete('user_conversation_duration');
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  // ---------------------------------------------------------------------------
  // Diagnostics
  // ---------------------------------------------------------------------------

  Future<int> getMessagesCount(String conversationId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM messages WHERE conversationId = ?',
      [conversationId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> printDatabaseSchema() async {
    final db = await database;
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    for (final table in tables) {
      final name = table['name'];
      final columns = await db.rawQuery('PRAGMA table_info($name)');
      print('📋 $name');
      for (final col in columns) {
        print('   ${col['name']}: ${col['type']} (${col['notnull'] == 1 ? 'NOT NULL' : 'NULLABLE'})');
      }
    }
  }
}