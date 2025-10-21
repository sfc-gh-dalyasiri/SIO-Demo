-- ============================================================================
-- SIO - Link Git Repository and Create Streamlit App in Snowflake
-- ============================================================================
-- Run with: snow sql -f cortex/setup_git_and_streamlit.sql -c myconnection
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE SIO_DB;
USE WAREHOUSE SIO_MED_WH;

-- ============================================================================
-- 1. CREATE SCHEMA FOR GIT REPOSITORIES
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS GIT_REPOS
    COMMENT = 'Git repository integrations for SIO applications';

USE SCHEMA GIT_REPOS;

-- ============================================================================
-- 2. CREATE GIT REPOSITORY LINK
-- ============================================================================

CREATE OR REPLACE GIT REPOSITORY SIO_DB.GIT_REPOS.SIO_DEMO_REPO
  API_INTEGRATION = github_api_integration
  ORIGIN = 'https://github.com/sfc-gh-dalyasiri/SIO-Demo.git'
  COMMENT = 'SIO Irrigation Management Demo - Streamlit application repository';

SELECT '✅ Git repository linked successfully' AS STATUS;

-- Fetch latest from git
ALTER GIT REPOSITORY SIO_DB.GIT_REPOS.SIO_DEMO_REPO FETCH;

-- List files in repository
LS @SIO_DB.GIT_REPOS.SIO_DEMO_REPO/branches/master/;

-- ============================================================================
-- 3. CREATE STREAMLIT APP FROM GIT REPOSITORY
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS STREAMLIT_APPS
    COMMENT = 'Streamlit applications for SIO';

USE SCHEMA STREAMLIT_APPS;

CREATE OR REPLACE STREAMLIT SIO_IRRIGATION_DASHBOARD
  FROM @SIO_DB.GIT_REPOS.SIO_DEMO_REPO/branches/master/app
  MAIN_FILE = 'streamlit_app.py'
  QUERY_WAREHOUSE = SIO_MED_WH
  TITLE = 'SIO Irrigation Management Dashboard'
  COMMENT = 'Interactive dashboard for water resource management and analytics';

SELECT '✅ Streamlit app created from Git repository' AS STATUS;

-- Make the app live (CRITICAL STEP!)
ALTER STREAMLIT SIO_IRRIGATION_DASHBOARD ADD LIVE VERSION FROM LAST;

SELECT '✅ Streamlit app is now LIVE!' AS STATUS;

-- ============================================================================
-- 4. GRANT PERMISSIONS
-- ============================================================================

GRANT USAGE ON STREAMLIT SIO_DB.STREAMLIT_APPS.SIO_IRRIGATION_DASHBOARD TO ROLE ACCOUNTADMIN;

-- ============================================================================
-- 5. VERIFICATION
-- ============================================================================

SELECT '============================================' AS INFO;
SELECT 'Git Repository and Streamlit Setup Complete!' AS INFO;
SELECT '============================================' AS INFO;

-- Show git repository
SHOW GIT REPOSITORIES IN SCHEMA SIO_DB.GIT_REPOS;

-- Show Streamlit app
SHOW STREAMLITS IN SCHEMA SIO_DB.STREAMLIT_APPS;

-- Describe Streamlit
DESCRIBE STREAMLIT SIO_DB.STREAMLIT_APPS.SIO_IRRIGATION_DASHBOARD;

SELECT '============================================' AS INFO;
SELECT 'Access your Streamlit app in Snowsight:' AS INFO;
SELECT 'Projects → Streamlit → SIO_IRRIGATION_DASHBOARD' AS INFO;
SELECT '============================================' AS INFO;

SELECT '✅ Setup complete! App is live in Snowflake.' AS STATUS;

