-- ============================================================================
-- SIO - Water Demand Forecasting using Snowflake Cortex ML
-- ============================================================================
-- STATUS: ATTEMPTED BUT NOT AVAILABLE
-- 
-- Snowflake Cortex ML.FORECAST appears to not be available in all accounts
-- or requires different syntax. Cortex LLM functions work (COMPLETE, etc)
-- but FORECAST is either:
-- 1. Not available in this Snowflake edition
-- 2. Requires different configuration/privileges
-- 3. Has different syntax than documented
--
-- Current solution: Using statistical SQL forecasting in create_ml_functions_simple.sql
-- which provides smooth, realistic forecasts with:
-- - 30-day historical averages
-- - Seasonal patterns (summer/winter)
-- - Weekend variations
-- - Daily sine wave patterns
-- - Pseudo-random variation
--
-- This works well for demo purposes. For production ML:
-- - Option A: Fix Python UDF with scikit-learn (class-based handler)
-- - Option B: Use external ML service and import predictions
-- - Option C: Snowpark ML stored procedures
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE SIO_DB;
USE SCHEMA ML_ANALYTICS;
USE WAREHOUSE SIO_MED_WH;

-- ============================================================================
-- 1. Create training data view for ML.FORECAST
-- ============================================================================

CREATE OR REPLACE VIEW ML_WATER_DEMAND_TRAINING AS
SELECT 
    DATE_TRUNC('DAY', wu.READING_DATE) AS timestamp,
    c.REGION_ID,
    r.REGION_NAME,
    SUM(wu.VOLUME_M3) AS daily_demand
FROM SIO_DB.DATA.WATER_USAGE wu
JOIN SIO_DB.DATA.WATER_METERS wm ON wu.METER_ID = wm.METER_ID
JOIN SIO_DB.DATA.CUSTOMERS c ON wm.CUSTOMER_ID = c.CUSTOMER_ID
JOIN SIO_DB.DATA.REGIONS r ON c.REGION_ID = r.REGION_ID
WHERE wu.READING_DATE >= DATEADD(month, -6, CURRENT_DATE())
GROUP BY DATE_TRUNC('DAY', wu.READING_DATE), c.REGION_ID, r.REGION_NAME
ORDER BY timestamp;

-- ============================================================================
-- 2. Cortex ML Forecasting Function
-- ============================================================================

CREATE OR REPLACE FUNCTION PREDICT_WATER_DEMAND_ML(
    REGION_ID_INPUT NUMBER,
    DAYS_AHEAD NUMBER
)
RETURNS TABLE (
    PREDICTION_DATE DATE,
    PREDICTED_DEMAND_M3 NUMBER(38,2),
    CONFIDENCE_LEVEL VARCHAR,
    SEASONAL_FACTOR NUMBER(38,2),
    WEATHER_FACTOR NUMBER(38,2),
    RECOMMENDATION VARCHAR
)
LANGUAGE SQL
AS
$$
    WITH historical_data AS (
        -- Get training data for specific region
        SELECT 
            timestamp,
            daily_demand
        FROM ML_WATER_DEMAND_TRAINING
        WHERE REGION_ID = REGION_ID_INPUT
        ORDER BY timestamp
    ),
    forecast_result AS (
        -- Use Snowflake Cortex ML.FORECAST
        SELECT 
            ts AS prediction_date,
            forecast AS predicted_demand_m3,
            NULL AS lower_bound,
            NULL AS upper_bound
        FROM TABLE(
            SNOWFLAKE.CORTEX.FORECAST(
                INPUT_DATA => SYSTEM$REFERENCE('TABLE', 'ML_WATER_DEMAND_TRAINING'),
                SERIES_COLNAME => 'REGION_ID',
                TIMESTAMP_COLNAME => 'TIMESTAMP',
                TARGET_COLNAME => 'DAILY_DEMAND',
                CONFIG_OBJECT => {'prediction_interval': 0.95}
            )
        )
        WHERE REGION_ID = REGION_ID_INPUT
          AND ts::DATE > CURRENT_DATE()
        LIMIT DAYS_AHEAD
    ),
    stats AS (
        SELECT 
            AVG(daily_demand) AS avg_demand,
            STDDEV(daily_demand) AS stddev_demand,
            COUNT(*) AS data_points
        FROM historical_data
    )
    SELECT 
        fr.prediction_date::DATE AS prediction_date,
        ROUND(fr.predicted_demand_m3, 2)::NUMBER(38,2) AS predicted_demand_m3,
        CASE 
            WHEN s.data_points >= 30 THEN 'HIGH'
            WHEN s.data_points >= 15 THEN 'MEDIUM'
            ELSE 'LOW'
        END AS confidence_level,
        ROUND(
            CASE 
                WHEN MONTH(fr.prediction_date) IN (6, 7, 8, 9) THEN 1.5
                WHEN MONTH(fr.prediction_date) IN (3, 4, 5, 10) THEN 1.0
                ELSE 0.7
            END, 2
        )::NUMBER(38,2) AS seasonal_factor,
        1.0::NUMBER(38,2) AS weather_factor,
        CASE
            WHEN fr.predicted_demand_m3 > s.avg_demand * 1.3 THEN 
                'High demand expected (Cortex ML). Consider resource optimization.'
            WHEN fr.predicted_demand_m3 > s.avg_demand * 1.1 THEN 
                'Moderate increase expected (Cortex ML). Monitor closely.'
            WHEN fr.predicted_demand_m3 < s.avg_demand * 0.7 THEN 
                'Low demand period (Cortex ML). Opportunity for maintenance.'
            ELSE 
                'Normal demand expected (Cortex ML). No action needed.'
        END AS recommendation
    FROM forecast_result fr
    CROSS JOIN stats s
    ORDER BY fr.prediction_date
$$;

-- ============================================================================
-- 3. Test the Cortex ML function
-- ============================================================================

SELECT '============================================' AS STATUS;
SELECT 'Testing Cortex ML Forecast' AS STATUS;
SELECT '============================================' AS STATUS;

-- Test forecast for Riyadh (Region 1)
SELECT 'Cortex ML Forecast for Riyadh (7 days):' AS TEST;
SELECT * FROM TABLE(SIO_DB.ML_ANALYTICS.PREDICT_WATER_DEMAND_ML(1, 7));

SELECT '✅ Cortex ML forecast function created!' AS STATUS;

-- Note: The simple SQL version (PREDICT_WATER_DEMAND) is still available as backup

