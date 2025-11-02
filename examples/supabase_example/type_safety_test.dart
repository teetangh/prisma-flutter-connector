/// Type Safety Test - Intentional Errors
/// This file contains intentional errors to test compile-time type safety
/// 
/// Expected: All errors should be caught by dart analyze BEFORE runtime

import 'package:prisma_flutter_connector/src/runtime/query/json_protocol.dart';
import 'package:prisma_flutter_connector/src/runtime/query/query_executor.dart';

void main() async {
  // Mock executor for testing
  late QueryExecutor executor;

  // ============================================================================
  // TEST 1: Invalid field name in where clause
  // ============================================================================
  print('Test 1: Invalid field name');
  
  final query1 = JsonQueryBuilder()
      .model('Domain')
      .action(QueryAction.findUnique)
      .where({
        'nonExistentField': '123',  // ❌ Should error: field doesn't exist
      })
      .build();

  // ============================================================================
  // TEST 2: Wrong type in where clause
  // ============================================================================
  print('Test 2: Wrong type in where');
  
  final query2 = JsonQueryBuilder()
      .model('Domain')
      .action(QueryAction.findMany)
      .where({
        'createdAt': 'not-a-date',  // ❌ Should error: expects DateTime
      })
      .build();

  // ============================================================================
  // TEST 3: Invalid model name
  // ============================================================================
  print('Test 3: Invalid model name');
  
  final query3 = JsonQueryBuilder()
      .model('NonExistentModel')  // ❌ Should error: model doesn't exist
      .action(QueryAction.findMany)
      .build();

  // ============================================================================
  // TEST 4: Invalid action for model
  // ============================================================================
  print('Test 4: Invalid orderBy field');
  
  final query4 = JsonQueryBuilder()
      .model('Domain')
      .action(QueryAction.findMany)
      .orderBy({'invalidField': 'asc'})  // ❌ Should error: field doesn't exist
      .build();

  // ============================================================================
  // TEST 5: Wrong data type in create
  // ============================================================================
  print('Test 5: Wrong type in create');
  
  final query5 = JsonQueryBuilder()
      .model('Domain')
      .action(QueryAction.create)
      .data({
        'id': 123,  // ❌ Should error: expects String, got int
        'name': 'Test',
        'createdAt': 'not-a-datetime',  // ❌ Should error: expects DateTime
      })
      .build();

  // ============================================================================
  // TEST 6: Missing required fields
  // ============================================================================
  print('Test 6: Missing required field');
  
  final query6 = JsonQueryBuilder()
      .model('Domain')
      .action(QueryAction.create)
      .data({
        'id': 'abc',
        // Missing 'name' which is required
      })
      .build();

  // ============================================================================
  // TEST 7: Invalid filter operator for type
  // ============================================================================
  print('Test 7: Invalid operator for type');
  
  final query7 = JsonQueryBuilder()
      .model('Domain')
      .action(QueryAction.findMany)
      .where({
        'name': {'gte': 5},  // ❌ Should error: can't use numeric operator on String
      })
      .build();

  print('All tests completed - check analyzer output!');
}
