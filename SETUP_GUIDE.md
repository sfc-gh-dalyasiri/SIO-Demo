# SIO Irrigation System - Setup Guide

Complete step-by-step guide to set up the SIO (Saudi Irrigation Organization) AI demo.

## Prerequisites

1. **Snowflake Account** with Cortex enabled
2. **Snow CLI** installed (`pip install snowflake-cli-labs`)
3. **Python 3.10+**
4. **Git** for version control

## Step 1: Configure Snowflake Connection

### Option A: Using Snow CLI

```bash
snow connection add myconnection
```

Follow the prompts to enter:
- Account URL (e.g., `your-account.snowflakecomputing.com`)
- Username
- Password or Personal Access Token (PAT)
- Role: `ACCOUNTADMIN`

### Option B: Verify existing connection

```bash
snow connection test -c myconnection
```

## Step 2: Create Database Infrastructure

```bash
# Create database, warehouse, and tables
snow sql -f data_engineering/setup_database.sql -c myconnection
```

This creates:
- Database: `SIO_DB`
- Warehouse: `SIO_MED_WH` (Medium size)
- Schemas: `DATA`, `ML_ANALYTICS`, `SEMANTIC_MODELS`
- 8 tables with proper relationships
- 3 views for analytics

**Expected time:** 1-2 minutes

## Step 3: Generate and Load Data

### Generate synthetic data

```bash
# Install dependencies
pip install pandas numpy

# Generate data (creates 1000 customers, 12 months history)
python data_engineering/generate_data.py
```

This generates CSV files in the `data/` directory:
- regions.csv (8 Saudi provinces)
- customers.csv (1000 farmers)
- water_usage.csv (~365K daily readings)
- billing.csv (~12K monthly bills)
- payments.csv (~10K payment records)
- And more...

**Expected time:** 30-60 seconds

### Load data into Snowflake

```bash
# Upload CSV files and load into tables
snow sql -q "PUT file://data/regions.csv @SIO_DB.DATA.DATA_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;" -c myconnection
snow sql -q "PUT file://data/water_sources.csv @SIO_DB.DATA.DATA_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;" -c myconnection
snow sql -q "PUT file://data/customers.csv @SIO_DB.DATA.DATA_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;" -c myconnection
snow sql -q "PUT file://data/water_meters.csv @SIO_DB.DATA.DATA_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;" -c myconnection
snow sql -q "PUT file://data/water_usage.csv @SIO_DB.DATA.DATA_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;" -c myconnection
snow sql -q "PUT file://data/billing.csv @SIO_DB.DATA.DATA_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;" -c myconnection
snow sql -q "PUT file://data/payments.csv @SIO_DB.DATA.DATA_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;" -c myconnection
snow sql -q "PUT file://data/weather_data.csv @SIO_DB.DATA.DATA_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;" -c myconnection

# Load data from stage into tables
snow sql -f data_engineering/insert_data.sql -c myconnection
```

**Expected time:** 2-3 minutes

## Step 4: Create Semantic Model

```bash
# Upload semantic model to Snowflake stage
snow sql -q "PUT file://cortex/semantic_model.yaml @SIO_DB.SEMANTIC_MODELS.SEMANTIC_MODEL_STAGE auto_compress=false overwrite=true;" -c myconnection
```

**Expected time:** 5-10 seconds

## Step 5: Create ML Functions

```bash
# Create ML prediction and analysis functions
snow sql -f cortex/create_ml_functions.sql -c myconnection
```

Creates:
- `PREDICT_WATER_DEMAND()` - 7-30 day forecasting
- `ANALYZE_REGIONAL_EFFICIENCY()` - Optimization insights

**Expected time:** 10-15 seconds

## Step 6: Create Cortex Agent

```bash
# Create the AI agent
snow sql -f cortex/create_agent.sql -c myconnection
```

This creates the `SIO_IRRIGATION_AGENT` with:
- Cortex Analyst for data queries
- ML functions for predictions
- Positive, actionable messaging

**Expected time:** 5-10 seconds

## Step 7: Test Infrastructure

```bash
# Run infrastructure tests
snow sql -f tests/test_infrastructure.sql -c myconnection
```

Verifies:
- Database and tables exist
- Data is loaded correctly
- ML functions work
- Views are accessible
- Agent exists

**Expected time:** 30-60 seconds

## Step 8: Setup Streamlit Dashboard

### Create secrets file

```bash
# Copy template and edit with your credentials
cp app/.streamlit/secrets.toml.template app/.streamlit/secrets.toml
```

Edit `app/.streamlit/secrets.toml` with your Snowflake credentials.

### Install dependencies

```bash
cd app
pip install -r requirements.txt
```

### Run locally

```bash
streamlit run streamlit_app.py
```

The dashboard should open at `http://localhost:8501`

**Features:**
- 📊 System overview with KPIs
- 🗺️ Regional analysis with heatmap
- 🔮 ML demand forecasting
- 💰 Billing and payment tracking

## Step 9: Test Agent (Optional)

### Setup environment

```bash
# Create .env file
cp .env.template .env
```

Edit `.env` with your Snowflake credentials.

### Run tests

```bash
python tests/test_agent.py
```

Tests various query types:
- Payment status queries
- Resource optimization
- ML predictions
- Regional analysis

## Troubleshooting

### Issue: Connection failed

**Solution:** Verify your Snow CLI configuration
```bash
snow connection test -c myconnection
```

### Issue: Permission denied

**Solution:** Ensure you're using `ACCOUNTADMIN` role
```bash
snow sql -q "USE ROLE ACCOUNTADMIN;" -c myconnection
```

### Issue: Data generation fails

**Solution:** Install required packages
```bash
pip install pandas numpy
```

### Issue: Agent not found

**Solution:** Verify agent was created
```bash
snow sql -q "SHOW AGENTS LIKE 'SIO_IRRIGATION_AGENT';" -c myconnection
```

### Issue: Streamlit connection error

**Solution:** Check secrets.toml has correct credentials
```bash
cat app/.streamlit/secrets.toml
```

## Usage Examples

### Query the Agent

Via Snow CLI:
```bash
snow sql -q "SELECT SNOWFLAKE_INTELLIGENCE.AGENTIC.SIO_IRRIGATION_AGENT('Which customers have unpaid bills?');" -c myconnection
```

### Query ML Functions

```sql
-- Predict demand for Riyadh (7 days)
SELECT * FROM TABLE(SIO_DB.ML_ANALYTICS.PREDICT_WATER_DEMAND(1, 7));

-- Analyze regional efficiency
SELECT * FROM TABLE(SIO_DB.ML_ANALYTICS.ANALYZE_REGIONAL_EFFICIENCY());
```

### View Data

```sql
-- Check water resource status
SELECT * FROM SIO_DB.DATA.REGIONAL_WATER_STATUS;

-- View customer summary
SELECT * FROM SIO_DB.DATA.CUSTOMER_SUMMARY LIMIT 10;
```

## Next Steps

- Deploy Streamlit app to Snowflake (Streamlit in Snowflake)
- Integrate with WhatsApp Business API
- Add more ML models (anomaly detection, optimization)
- Create alerts for critical thresholds
- Add multi-language support (Arabic/English)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Snowflake documentation
3. Check the cursor rules in `.cursor/rules/`

## Clean Up (Optional)

To remove all resources:

```sql
USE ROLE ACCOUNTADMIN;

-- Drop agent
DROP AGENT IF EXISTS SNOWFLAKE_INTELLIGENCE.AGENTIC.SIO_IRRIGATION_AGENT;

-- Drop ML functions
DROP FUNCTION IF EXISTS SIO_DB.ML_ANALYTICS.PREDICT_WATER_DEMAND(NUMBER, NUMBER);
DROP FUNCTION IF EXISTS SIO_DB.ML_ANALYTICS.ANALYZE_REGIONAL_EFFICIENCY();

-- Drop database (WARNING: This deletes all data!)
DROP DATABASE IF EXISTS SIO_DB;

-- Drop warehouse
DROP WAREHOUSE IF EXISTS SIO_MED_WH;
```

