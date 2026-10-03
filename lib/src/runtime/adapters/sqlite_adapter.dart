/// SQLite database adapter implementation.
///
/// This adapter is 100% pure Dart and does not depend on the Flutter SDK.
/// It works with:
/// - Any [SQLiteDatabase] implementation (or [SQLiteCallbackDatabase])
/// - Flutter's `sqflite` `Database` (passed directly to [SQLiteAdapter])
/// - Pure-Dart `sqflite_common_ffi` or `sqlite3` wrappers
library;

import 'dart:async';
import 'package:prisma_flutter_connector/src/runtime/adapters/types.dart';

/// Pure-Dart interface for executing SQLite statements on a database or
/// transaction.
abstract class SQLiteExecutor {
  /// Execute a raw `SELECT` query and return rows as column-to-value maps.
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]);

  /// Execute a raw `INSERT` statement and return the last inserted row ID
  /// or affected row count.
  Future<int> rawInsert(
    String sql, [
    List<Object?>? arguments,
  ]);

  /// Execute a raw `UPDATE` statement and return the number of affected rows.
  Future<int> rawUpdate(
    String sql, [
    List<Object?>? arguments,
  ]);

  /// Execute a raw `DELETE` statement and return the number of affected rows.
  Future<int> rawDelete(
    String sql, [
    List<Object?>? arguments,
  ]);

  /// Execute a SQL statement that returns no rows (e.g. DDL).
  Future<void> execute(
    String sql, [
    List<Object?>? arguments,
  ]);
}

/// Pure-Dart interface for a SQLite database connection.
abstract class SQLiteDatabase extends SQLiteExecutor {
  /// Run [action] inside an atomic database transaction.
  Future<T> transaction<T>(Future<T> Function(SQLiteExecutor txn) action);

  /// Close the database connection.
  Future<void> close();
}

/// Lightweight callback-backed [SQLiteDatabase] for pure-Dart drivers
/// (such as `sqlite3`) or testing without `sqflite`.
class SQLiteCallbackDatabase implements SQLiteDatabase {
  final Future<List<Map<String, Object?>>> Function(
    String sql,
    List<Object?>? arguments,
  ) _onQuery;
  final Future<int> Function(
    String sql,
    List<Object?>? arguments,
  ) _onExecute;
  final Future<void> Function(
    String sql,
    List<Object?>? arguments,
  )? _onStatement;
  final Future<void> Function()? _onClose;
  int _transactionDepth = 0;

  SQLiteCallbackDatabase({
    required Future<List<Map<String, Object?>>> Function(
      String sql,
      List<Object?>? arguments,
    ) onQuery,
    required Future<int> Function(
      String sql,
      List<Object?>? arguments,
    ) onExecute,
    Future<void> Function(
      String sql,
      List<Object?>? arguments,
    )? onStatement,
    Future<void> Function()? onClose,
  })  : _onQuery = onQuery,
        _onExecute = onExecute,
        _onStatement = onStatement,
        _onClose = onClose;

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) =>
      _onQuery(sql, arguments);

  @override
  Future<int> rawInsert(
    String sql, [
    List<Object?>? arguments,
  ]) =>
      _onExecute(sql, arguments);

  @override
  Future<int> rawUpdate(
    String sql, [
    List<Object?>? arguments,
  ]) =>
      _onExecute(sql, arguments);

  @override
  Future<int> rawDelete(
    String sql, [
    List<Object?>? arguments,
  ]) =>
      _onExecute(sql, arguments);

  @override
  Future<void> execute(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final onStatement = _onStatement;
    if (onStatement != null) {
      await onStatement(sql, arguments);
    } else {
      await _onExecute(sql, arguments);
    }
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(SQLiteExecutor txn) action,
  ) async {
    final depth = _transactionDepth++;
    final savepoint = 'sp_$depth';
    if (depth == 0) {
      await execute('BEGIN');
    } else {
      await execute('SAVEPOINT $savepoint');
    }
    try {
      final result = await action(this);
      if (depth == 0) {
        await execute('COMMIT');
      } else {
        await execute('RELEASE SAVEPOINT $savepoint');
      }
      return result;
    } catch (_) {
      try {
        if (depth == 0) {
          await execute('ROLLBACK');
        } else {
          await execute('ROLLBACK TO SAVEPOINT $savepoint');
          await execute('RELEASE SAVEPOINT $savepoint');
        }
      } catch (_) {}
      rethrow;
    } finally {
      _transactionDepth--;
    }
  }

  @override
  Future<void> close() async {
    final onClose = _onClose;
    if (onClose != null) {
      await onClose();
    }
  }
}

/// Bridges any duck-typed `sqflite` `DatabaseExecutor` / `Transaction` without
/// importing `package:sqflite/sqflite.dart`.
class _DynamicSQLiteExecutor implements SQLiteExecutor {
  final dynamic _executor;

  const _DynamicSQLiteExecutor(this._executor);

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final dynamic raw = await _executor.rawQuery(sql, arguments);
    return (raw as List)
        .map((row) => Map<String, Object?>.from(row as Map))
        .toList();
  }

  @override
  Future<int> rawInsert(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final dynamic res = await _executor.rawInsert(sql, arguments);
    return res as int;
  }

  @override
  Future<int> rawUpdate(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final dynamic res = await _executor.rawUpdate(sql, arguments);
    return res as int;
  }

  @override
  Future<int> rawDelete(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final dynamic res = await _executor.rawDelete(sql, arguments);
    return res as int;
  }

  @override
  Future<void> execute(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    if (arguments != null && arguments.isNotEmpty) {
      await _executor.execute(sql, arguments);
    } else {
      await _executor.execute(sql);
    }
  }
}

/// Bridges a duck-typed `sqflite` `Database` to [SQLiteDatabase].
class _DynamicSQLiteDatabase extends _DynamicSQLiteExecutor
    implements SQLiteDatabase {
  const _DynamicSQLiteDatabase(super.database);

  @override
  Future<T> transaction<T>(
    Future<T> Function(SQLiteExecutor txn) action,
  ) async {
    final dynamic res = await _executor.transaction(
      (dynamic txn) => action(_DynamicSQLiteExecutor(txn)),
    );
    return res as T;
  }

  @override
  Future<void> close() async {
    await _executor.close();
  }
}

/// SQLite database adapter for Dart and Flutter apps.
///
/// Accepts either a [SQLiteDatabase] (such as [SQLiteCallbackDatabase]) or any
/// `sqflite`-compatible `Database` instance without requiring a direct
/// dependency on the Flutter SDK.
class SQLiteAdapter implements SqlDriverAdapter {
  final SQLiteDatabase _database;
  final ConnectionInfo? _connectionInfo;

  SQLiteAdapter(
    Object database, {
    ConnectionInfo? connectionInfo,
  })  : _database = database is SQLiteDatabase
            ? database
            : _DynamicSQLiteDatabase(database),
        _connectionInfo = connectionInfo;

  @override
  String get provider => 'sqlite';

  @override
  String get adapterName => 'prisma_flutter_connector:sqlite';

  @override
  Future<SqlResultSet> queryRaw(SqlQuery query) => _queryOn(_database, query);

  @override
  Future<int> executeRaw(SqlQuery query) => _executeOn(_database, query);

  @override
  Future<void> executeScript(String script) async {
    try {
      final statements = script.split(';').where((s) => s.trim().isNotEmpty);

      await _database.transaction((txn) async {
        for (final statement in statements) {
          await txn.execute(statement.trim());
        }
      });
    } catch (e) {
      throw AdapterError(
        'Failed to execute script: ${e.toString()}',
        originalError: e,
      );
    }
  }

  @override
  Future<Transaction> startTransaction([IsolationLevel? isolationLevel]) {
    // SQLite uses serializable transactions; open the transaction immediately
    // and execute statements directly on the transaction executor.
    return SQLiteTransaction._start(_database);
  }

  @override
  ConnectionInfo? getConnectionInfo() {
    return _connectionInfo ??
        const ConnectionInfo(
          maxBindValues: 999, // SQLite default limit
          supportsRelationJoins: true,
        );
  }

  @override
  Future<void> dispose() async {
    await _database.close();
  }

  static Future<SqlResultSet> _queryOn(
    SQLiteExecutor executor,
    SqlQuery query,
  ) async {
    try {
      final sqliteQuery = _convertPlaceholders(query.sql);
      final result = await executor.rawQuery(sqliteQuery, query.args);

      if (result.isEmpty) {
        return const SqlResultSet(
          columnNames: [],
          columnTypes: [],
          rows: [],
        );
      }

      final columnNames = result.first.keys.toList();
      final columnTypes = _inferColumnTypes(result.first, query.argTypes);
      final rows = result.map((row) {
        return columnNames.map((col) => _convertValue(row[col])).toList();
      }).toList();

      return SqlResultSet(
        columnNames: columnNames,
        columnTypes: columnTypes,
        rows: rows,
      );
    } catch (e) {
      throw AdapterError(
        'Failed to execute query: ${e.toString()}',
        originalError: e,
      );
    }
  }

  static Future<int> _executeOn(
    SQLiteExecutor executor,
    SqlQuery query,
  ) async {
    try {
      final sqliteQuery = _convertPlaceholders(query.sql);
      final verb = sqliteQuery.trimLeft().toUpperCase();

      if (verb.startsWith('DELETE')) {
        return await executor.rawDelete(sqliteQuery, query.args);
      } else {
        // Use rawUpdate for UPDATE, INSERT, REPLACE, and other DML statements
        // because sqflite's rawInsert returns last_insert_rowid() instead of
        // the affected row count (changes()).
        return await executor.rawUpdate(sqliteQuery, query.args);
      }
    } catch (e) {
      throw AdapterError(
        'Failed to execute command: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Convert PostgreSQL-style placeholders ($1, $2) to SQLite-style (?, ?).
  static String _convertPlaceholders(String sql) {
    return sql.replaceAllMapped(
      RegExp(r'\$\d+'),
      (match) => '?',
    );
  }

  /// Infer column types from first row data.
  static List<ColumnType> _inferColumnTypes(
    Map<String, Object?> firstRow,
    List<ArgType> argTypes,
  ) {
    return firstRow.values.map((value) {
      if (value == null) return ColumnType.unknown;
      if (value is int) return ColumnType.int64;
      if (value is double) return ColumnType.double;
      if (value is String) {
        if (_isDateTimeString(value)) return ColumnType.dateTime;
        return ColumnType.string;
      }
      if (value is List<int>) return ColumnType.bytes;
      return ColumnType.unknown;
    }).toList();
  }

  /// Check if a string looks like a DateTime.
  static bool _isDateTimeString(String value) {
    try {
      DateTime.parse(value);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Convert SQLite values to Prisma types.
  static dynamic _convertValue(dynamic value) => value;
}

class _SQLiteRollbackSignal implements Exception {
  const _SQLiteRollbackSignal();
}

/// SQLite transaction implementation.
///
/// Opens a live transaction context via [SQLiteDatabase.transaction] and
/// executes every [queryRaw] and [executeRaw] call directly on the underlying
/// [SQLiteExecutor] immediately (avoiding the uncompleted-`Completer` deadlock
/// when callers `await` queries inside `executeInTransaction`).
class SQLiteTransaction implements Transaction {
  final SQLiteExecutor _executor;
  final Completer<void> _finish;
  final Future<void> _done;
  bool _isActive = true;
  bool _isCommitted = false;
  bool _isRolledBack = false;

  SQLiteTransaction._(this._executor, this._finish, this._done);

  static Future<SQLiteTransaction> _start(SQLiteDatabase database) async {
    final ready = Completer<SQLiteExecutor>();
    final finish = Completer<void>();

    final done = database.transaction<void>((txn) async {
      ready.complete(txn);
      await finish.future;
    });

    // Prevent unhandled async errors if rollback completes `finish` with an
    // error before `rollback()` awaits `done`.
    done.ignore();

    try {
      final executor = await ready.future;
      return SQLiteTransaction._(executor, finish, done);
    } catch (e) {
      if (!finish.isCompleted) {
        finish.complete();
      }
      throw AdapterError(
        'Failed to start transaction: ${e.toString()}',
        originalError: e,
      );
    }
  }

  @override
  bool get isActive => _isActive;

  @override
  Future<SqlResultSet> queryRaw(SqlQuery query) {
    _checkActive();
    return SQLiteAdapter._queryOn(_executor, query);
  }

  @override
  Future<int> executeRaw(SqlQuery query) {
    _checkActive();
    return SQLiteAdapter._executeOn(_executor, query);
  }

  @override
  Future<void> commit() async {
    _checkActive();
    _isActive = false;

    try {
      if (!_finish.isCompleted) {
        _finish.complete();
      }
      await _done;
      _isCommitted = true;
    } catch (e) {
      throw AdapterError(
        'Transaction failed: ${e.toString()}',
        originalError: e,
      );
    }
  }

  @override
  Future<void> rollback() async {
    _checkActive();
    _isRolledBack = true;
    _isActive = false;

    if (!_finish.isCompleted) {
      _finish.completeError(const _SQLiteRollbackSignal());
    }
    try {
      await _done;
    } on _SQLiteRollbackSignal {
      // Expected signal used to unwind the transaction callback cleanly.
    } catch (e) {
      throw AdapterError(
        'Failed to rollback transaction: ${e.toString()}',
        originalError: e,
      );
    }
  }

  void _checkActive() {
    if (!_isActive) {
      if (_isCommitted) {
        throw const AdapterError('Transaction already committed');
      } else if (_isRolledBack) {
        throw const AdapterError('Transaction already rolled back');
      } else {
        throw const AdapterError('Transaction is no longer active');
      }
    }
  }
}
