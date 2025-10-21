-- ============================================================================
-- SIO - Setup Cortex Search with PDF Documents
-- ============================================================================
-- Run with: snow sql -f cortex/setup_cortex_search.sql -c myconnection
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE SIO_DB;
USE WAREHOUSE SIO_MED_WH;

-- ============================================================================
-- 1. CREATE KNOWLEDGE BASE SCHEMA
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS KNOWLEDGE_BASE
    COMMENT = 'SIO knowledge base for policies, procedures, and guidelines';

USE SCHEMA KNOWLEDGE_BASE;

-- ============================================================================
-- 2. CREATE STAGE FOR PDF DOCUMENTS
-- ============================================================================

-- CRITICAL: ENCRYPTION required for PARSE_DOCUMENT
CREATE STAGE IF NOT EXISTS DOCUMENT_STAGE
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    COMMENT = 'Stage for SIO policy PDF documents';

SELECT '✅ Document stage created' AS STATUS;

-- ============================================================================
-- 3. UPLOAD PDFs (Run these manually after this script)
-- ============================================================================

-- Upload commands (run these after the script completes):
-- cd /Users/dalyasiri/Projects/SIO - KSA
-- snow sql -q "PUT file://documents/*.pdf @SIO_DB.KNOWLEDGE_BASE.DOCUMENT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;" -c myconnection

-- ============================================================================
-- 4. PARSE PDF DOCUMENTS
-- ============================================================================

-- Refresh stage to register uploaded files
ALTER STAGE DOCUMENT_STAGE REFRESH;

-- Parse PDFs and extract content
CREATE OR REPLACE TABLE PARSED_DOCUMENTS AS
SELECT
    RELATIVE_PATH,
    REGEXP_REPLACE(REGEXP_SUBSTR(RELATIVE_PATH, '[^/]+$'), '.pdf', '') AS DOCUMENT_ID,
    REGEXP_REPLACE(REGEXP_SUBSTR(RELATIVE_PATH, '[^/]+$'), '.pdf', '') AS TITLE,
    SNOWFLAKE.CORTEX.PARSE_DOCUMENT(
        @DOCUMENT_STAGE,
        RELATIVE_PATH,
        {'mode': 'LAYOUT'}
    ):content::STRING AS CONTENT,
    CURRENT_TIMESTAMP() AS CREATED_DATE
FROM DIRECTORY(@DOCUMENT_STAGE)
WHERE RELATIVE_PATH ILIKE '%.pdf';

SELECT 'Parsed documents:' AS STATUS, COUNT(*) AS COUNT FROM PARSED_DOCUMENTS;

-- ============================================================================
-- 5. CREATE CORTEX SEARCH SERVICE
-- ============================================================================

CREATE OR REPLACE CORTEX SEARCH SERVICE SIO_KNOWLEDGE_SERVICE
ON CONTENT
ATTRIBUTES TITLE
WAREHOUSE = SIO_MED_WH
TARGET_LAG = '1 minute'
AS (
    SELECT 
        DOCUMENT_ID,
        TITLE,
        CONTENT
    FROM PARSED_DOCUMENTS
);

-- Wait for service to initialize
SELECT SYSTEM$WAIT(10);

-- Check service status
SELECT SYSTEM$GET_CORTEX_SEARCH_SERVICE_STATUS('SIO_KNOWLEDGE_SERVICE') AS SEARCH_SERVICE_STATUS;

SELECT '✅ Cortex Search service created and ready!' AS STATUS;

-- ============================================================================
-- 6. TEST CORTEX SEARCH
-- ============================================================================

-- Test search with sample query
SELECT PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        SIO_KNOWLEDGE_SERVICE,
        '{
            "query": "How do I apply for irrigation subsidy?",
            "columns": ["CONTENT"],
            "limit": 3
        }'
    )
) AS SEARCH_RESULTS;

SELECT '✅ Cortex Search tested successfully!' AS STATUS;

