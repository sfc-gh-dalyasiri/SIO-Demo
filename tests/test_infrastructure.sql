-- ============================================================================
-- SIO - Infrastructure Test Suite
-- ============================================================================
-- Tests database setup, data integrity, and ML functions
-- Run with: snow sql -f tests/test_infrastructure.sql -c myconnection
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE SIO_DB;
USE WAREHOUSE SIO_MED_WH;

SELECT '============================================' AS TEST;
SELECT 'SIO INFRASTRUCTURE TEST SUITE' AS TEST;
SELECT '============================================' AS TEST;

-- ============================================================================
-- TEST 1: DATABASE AND SCHEMA EXISTENCE
-- ============================================================================

SELECT 'TEST 1: Database and Schema Existence' AS TEST;

SELECT CASE 
    WHEN COUNT(*) = 1 THEN '✅ PASS: SIO_DB exists'
    ELSE '❌ FAIL: SIO_DB not found'
END AS RESULT
FROM INFORMATION_SCHEMA.DATABASES
WHERE DATABASE_NAME = 'SIO_DB';

SELECT CASE 
    WHEN COUNT(*) = 3 THEN '✅ PASS: All schemas exist'
    ELSE '❌ FAIL: Missing schemas'
END AS RESULT
FROM INFORMATION_SCHEMA.SCHEMATA
WHERE SCHEMA_NAME IN ('DATA', 'ML_ANALYTICS', 'SEMANTIC_MODELS')
  AND CATALOG_NAME = 'SIO_DB';

-- ============================================================================
-- TEST 2: TABLE EXISTENCE AND DATA
-- ============================================================================

SELECT 'TEST 2: Table Existence and Data' AS TEST;

USE SCHEMA DATA;

SELECT CASE 
    WHEN COUNT(*) > 0 THEN '✅ PASS: REGIONS table has data'
    ELSE '❌ FAIL: REGIONS table is empty'
END AS RESULT
FROM REGIONS;

SELECT CASE 
    WHEN COUNT(*) > 0 THEN '✅ PASS: CUSTOMERS table has data'
    ELSE '❌ FAIL: CUSTOMERS table is empty'
END AS RESULT
FROM CUSTOMERS;

SELECT CASE 
    WHEN COUNT(*) > 0 THEN '✅ PASS: WATER_USAGE table has data'
    ELSE '❌ FAIL: WATER_USAGE table is empty'
END AS RESULT
FROM WATER_USAGE;

SELECT CASE 
    WHEN COUNT(*) > 0 THEN '✅ PASS: BILLING table has data'
    ELSE '❌ FAIL: BILLING table is empty'
END AS RESULT
FROM BILLING;

-- ============================================================================
-- TEST 3: DATA INTEGRITY
-- ============================================================================

SELECT 'TEST 3: Data Integrity' AS TEST;

-- Check for orphaned water meters
SELECT CASE 
    WHEN COUNT(*) = 0 THEN '✅ PASS: No orphaned water meters'
    ELSE CONCAT('❌ FAIL: ', COUNT(*), ' orphaned water meters found')
END AS RESULT
FROM WATER_METERS wm
LEFT JOIN CUSTOMERS c ON wm.CUSTOMER_ID = c.CUSTOMER_ID
WHERE c.CUSTOMER_ID IS NULL;

-- Check for orphaned billing records
SELECT CASE 
    WHEN COUNT(*) = 0 THEN '✅ PASS: No orphaned billing records'
    ELSE CONCAT('❌ FAIL: ', COUNT(*), ' orphaned billing records found')
END AS RESULT
FROM BILLING b
LEFT JOIN CUSTOMERS c ON b.CUSTOMER_ID = c.CUSTOMER_ID
WHERE c.CUSTOMER_ID IS NULL;

-- Check for invalid water usage (negative volumes)
SELECT CASE 
    WHEN COUNT(*) = 0 THEN '✅ PASS: No negative water volumes'
    ELSE CONCAT('❌ FAIL: ', COUNT(*), ' negative water volumes found')
END AS RESULT
FROM WATER_USAGE
WHERE VOLUME_M3 < 0;

-- ============================================================================
-- TEST 4: VIEWS
-- ============================================================================

SELECT 'TEST 4: Views' AS TEST;

SELECT CASE 
    WHEN COUNT(*) > 0 THEN '✅ PASS: CUSTOMER_SUMMARY view works'
    ELSE '❌ FAIL: CUSTOMER_SUMMARY view is empty'
END AS RESULT
FROM CUSTOMER_SUMMARY;

SELECT CASE 
    WHEN COUNT(*) > 0 THEN '✅ PASS: REGIONAL_WATER_STATUS view works'
    ELSE '❌ FAIL: REGIONAL_WATER_STATUS view is empty'
END AS RESULT
FROM REGIONAL_WATER_STATUS;

-- ============================================================================
-- TEST 5: ML FUNCTIONS
-- ============================================================================

SELECT 'TEST 5: ML Functions' AS TEST;

-- Test water demand prediction function
SELECT CASE 
    WHEN COUNT(*) > 0 THEN '✅ PASS: PREDICT_WATER_DEMAND function works'
    ELSE '❌ FAIL: PREDICT_WATER_DEMAND function failed'
END AS RESULT
FROM TABLE(SIO_DB.ML_ANALYTICS.PREDICT_WATER_DEMAND(1, 7));

-- Test efficiency analysis function
SELECT CASE 
    WHEN COUNT(*) > 0 THEN '✅ PASS: ANALYZE_REGIONAL_EFFICIENCY function works'
    ELSE '❌ FAIL: ANALYZE_REGIONAL_EFFICIENCY function failed'
END AS RESULT
FROM TABLE(SIO_DB.ML_ANALYTICS.ANALYZE_REGIONAL_EFFICIENCY());

-- ============================================================================
-- TEST 6: SEMANTIC MODEL
-- ============================================================================

SELECT 'TEST 6: Semantic Model' AS TEST;

USE SCHEMA SEMANTIC_MODELS;

-- Check if stage exists
SELECT CASE 
    WHEN COUNT(*) > 0 THEN '✅ PASS: SEMANTIC_MODEL_STAGE exists'
    ELSE '❌ FAIL: SEMANTIC_MODEL_STAGE not found'
END AS RESULT
FROM INFORMATION_SCHEMA.STAGES
WHERE STAGE_NAME = 'SEMANTIC_MODEL_STAGE'
  AND STAGE_CATALOG = 'SIO_DB'
  AND STAGE_SCHEMA = 'SEMANTIC_MODELS';

-- Check if semantic model file exists
SELECT CASE 
    WHEN COUNT(*) > 0 THEN '✅ PASS: semantic_model.yaml uploaded'
    ELSE '❌ FAIL: semantic_model.yaml not found in stage'
END AS RESULT
FROM DIRECTORY(@SEMANTIC_MODEL_STAGE)
WHERE RELATIVE_PATH ILIKE '%semantic_model.yaml%';

-- ============================================================================
-- TEST 7: WAREHOUSE
-- ============================================================================

SELECT 'TEST 7: Warehouse' AS TEST;

SELECT CASE 
    WHEN STATE = 'STARTED' THEN '✅ PASS: SIO_MED_WH is running'
    ELSE '❌ FAIL: SIO_MED_WH is not running'
END AS RESULT
FROM INFORMATION_SCHEMA.WAREHOUSES
WHERE WAREHOUSE_NAME = 'SIO_MED_WH';

-- ============================================================================
-- TEST 8: AGENT (If exists)
-- ============================================================================

SELECT 'TEST 8: Agent Existence' AS TEST;

USE DATABASE SNOWFLAKE_INTELLIGENCE;
USE SCHEMA AGENTS;

SELECT CASE 
    WHEN COUNT(*) > 0 THEN '✅ PASS: SIO_IRRIGATION_AGENT exists'
    ELSE '⚠️ WARNING: SIO_IRRIGATION_AGENT not found (may not be created yet)'
END AS RESULT
FROM INFORMATION_SCHEMA.AGENTS
WHERE AGENT_NAME = 'SIO_IRRIGATION_AGENT';

-- ============================================================================
-- TEST SUMMARY
-- ============================================================================

SELECT '============================================' AS SUMMARY;
SELECT 'TEST SUITE COMPLETE' AS SUMMARY;
SELECT '============================================' AS SUMMARY;

-- Data counts summary
USE DATABASE SIO_DB;
USE SCHEMA DATA;

SELECT 'Data Summary:' AS INFO;
SELECT 'Regions:' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM REGIONS
UNION ALL
SELECT 'Water Sources:', COUNT(*) FROM WATER_SOURCES
UNION ALL
SELECT 'Customers:', COUNT(*) FROM CUSTOMERS
UNION ALL
SELECT 'Water Meters:', COUNT(*) FROM WATER_METERS
UNION ALL
SELECT 'Water Usage:', COUNT(*) FROM WATER_USAGE
UNION ALL
SELECT 'Billing:', COUNT(*) FROM BILLING
UNION ALL
SELECT 'Payments:', COUNT(*) FROM PAYMENTS
UNION ALL
SELECT 'Weather Data:', COUNT(*) FROM WEATHER_DATA;

SELECT '✅ Infrastructure tests complete!' AS STATUS;

