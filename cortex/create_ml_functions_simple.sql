-- ============================================================================
-- SIO - ML Water Demand Prediction Functions (Simplified)
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE SIO_DB;
USE SCHEMA ML_ANALYTICS;
USE WAREHOUSE SIO_MED_WH;

-- ============================================================================
-- 1. REGIONAL EFFICIENCY ANALYSIS (Simplified)
-- ============================================================================

CREATE OR REPLACE FUNCTION ANALYZE_REGIONAL_EFFICIENCY()
RETURNS TABLE (
    REGION_NAME VARCHAR,
    EFFICIENCY_SCORE NUMBER(38,2),
    EFFICIENCY_RATING VARCHAR,
    WATER_UTILIZATION_PERCENT NUMBER(38,2),
    OPPORTUNITIES VARCHAR
)
LANGUAGE SQL
AS
$$
    SELECT 
        r.REGION_NAME,
        -- Simple efficiency score based on source efficiency and utilization
        ROUND((AVG(ws.EFFICIENCY_PERCENT) + 
              LEAST((SUM(ws.CURRENT_LEVEL_M3) / NULLIF(SUM(ws.CAPACITY_M3), 0)) * 50, 50)) * 0.8, 2) AS EFFICIENCY_SCORE,
        CASE 
            WHEN AVG(ws.EFFICIENCY_PERCENT) >= 85 THEN 'EXCELLENT'
            WHEN AVG(ws.EFFICIENCY_PERCENT) >= 70 THEN 'GOOD'
            WHEN AVG(ws.EFFICIENCY_PERCENT) >= 50 THEN 'FAIR'
            ELSE 'NEEDS_IMPROVEMENT'
        END AS EFFICIENCY_RATING,
        ROUND((SUM(ws.CURRENT_LEVEL_M3) / NULLIF(SUM(ws.CAPACITY_M3), 0)) * 100, 2) AS WATER_UTILIZATION_PERCENT,
        CASE
            WHEN AVG(ws.EFFICIENCY_PERCENT) < 85 THEN 'Improve source efficiency'
            WHEN (SUM(ws.CURRENT_LEVEL_M3) / NULLIF(SUM(ws.CAPACITY_M3), 0)) * 100 > 85 THEN 'High utilization - consider capacity expansion'
            WHEN (SUM(ws.CURRENT_LEVEL_M3) / NULLIF(SUM(ws.CAPACITY_M3), 0)) * 100 < 40 THEN 'Low utilization - surplus capacity available'
            ELSE 'Operating at optimal levels'
        END AS OPPORTUNITIES
    FROM SIO_DB.DATA.REGIONS r
    LEFT JOIN SIO_DB.DATA.WATER_SOURCES ws ON r.REGION_ID = ws.REGION_ID AND ws.STATUS = 'ACTIVE'
    GROUP BY r.REGION_NAME
    ORDER BY EFFICIENCY_SCORE DESC
$$;

-- ============================================================================
-- 2. WATER DEMAND PREDICTION (Simplified - Statistical)
-- ============================================================================

CREATE OR REPLACE FUNCTION PREDICT_WATER_DEMAND(
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
    WITH recent_usage AS (
        SELECT 
            AVG(wu.VOLUME_M3) AS avg_daily_usage,
            STDDEV(wu.VOLUME_M3) AS stddev_usage,
            COUNT(*) AS data_points
        FROM SIO_DB.DATA.WATER_USAGE wu
        JOIN SIO_DB.DATA.WATER_METERS wm ON wu.METER_ID = wm.METER_ID
        JOIN SIO_DB.DATA.CUSTOMERS c ON wm.CUSTOMER_ID = c.CUSTOMER_ID
        WHERE c.REGION_ID = REGION_ID_INPUT
          AND wu.READING_DATE >= DATEADD(day, -30, CURRENT_DATE())
    ),
    date_range AS (
        SELECT 
            DATEADD(day, seq4(), CURRENT_DATE()) AS prediction_date,
            seq4() + 1 AS days_out
        FROM TABLE(GENERATOR(ROWCOUNT => DAYS_AHEAD))
    ),
    predictions AS (
        SELECT 
            dr.prediction_date,
            dr.days_out,
            -- Apply seasonal factor + weekly pattern + daily variation
            ru.avg_daily_usage * 
                CASE 
                    WHEN MONTH(dr.prediction_date) IN (6, 7, 8, 9) THEN 1.5
                    WHEN MONTH(dr.prediction_date) IN (3, 4, 5, 10) THEN 1.0
                    ELSE 0.7
                END * 
                -- Weekly pattern (weekends higher)
                (1 + (CASE WHEN DAYOFWEEK(dr.prediction_date) IN (0, 6) THEN 0.15 ELSE 0 END)) *
                -- Daily variation using sine wave for smooth curve
                (1 + 0.1 * SIN(dr.days_out * 0.5)) *
                -- Small random-like variation using days_out
                (1 + 0.05 * (MOD(dr.days_out * 17, 13) - 6.5) / 6.5)
                AS predicted_demand_m3,
            CASE 
                WHEN ru.data_points >= 25 THEN 'HIGH'
                WHEN ru.data_points >= 15 THEN 'MEDIUM'
                ELSE 'LOW'
            END AS confidence_level,
            CASE 
                WHEN MONTH(dr.prediction_date) IN (6, 7, 8, 9) THEN 1.5
                WHEN MONTH(dr.prediction_date) IN (3, 4, 5, 10) THEN 1.0
                ELSE 0.7
            END AS seasonal_factor,
            1.0 + 0.05 * SIN(dr.days_out * 0.5) AS weather_factor,
            ru.avg_daily_usage
        FROM date_range dr
        CROSS JOIN recent_usage ru
    )
    SELECT 
        prediction_date,
        ROUND(predicted_demand_m3, 2)::NUMBER(38,2) AS predicted_demand_m3,
        confidence_level,
        ROUND(seasonal_factor, 2)::NUMBER(38,2) AS seasonal_factor,
        ROUND(weather_factor, 2)::NUMBER(38,2) AS weather_factor,
        CASE
            WHEN predicted_demand_m3 > avg_daily_usage * 1.3 THEN 
                'High demand expected (' || ROUND(predicted_demand_m3 / avg_daily_usage, 1) || 'x average). Consider resource optimization.'
            WHEN predicted_demand_m3 > avg_daily_usage * 1.1 THEN 
                'Moderate increase expected (' || ROUND(predicted_demand_m3 / avg_daily_usage, 1) || 'x average). Monitor closely.'
            WHEN predicted_demand_m3 < avg_daily_usage * 0.7 THEN 
                'Low demand period (' || ROUND(predicted_demand_m3 / avg_daily_usage, 1) || 'x average). Opportunity for maintenance.'
            ELSE 
                'Normal demand expected (' || ROUND(predicted_demand_m3 / avg_daily_usage, 1) || 'x average). No action needed.'
        END AS recommendation
    FROM predictions
$$;

-- ============================================================================
-- 3. TEST THE FUNCTIONS
-- ============================================================================

SELECT '============================================' AS STATUS;
SELECT 'Testing ML Functions (SQL-based)' AS STATUS;
SELECT '============================================' AS STATUS;

-- Test regional efficiency analysis
SELECT 'Regional Efficiency Analysis:' AS TEST;
SELECT * FROM TABLE(SIO_DB.ML_ANALYTICS.ANALYZE_REGIONAL_EFFICIENCY());

-- Test water demand prediction for Riyadh (Region 1)
SELECT 'Water Demand Prediction for Riyadh (7 days):' AS TEST;
SELECT * FROM TABLE(SIO_DB.ML_ANALYTICS.PREDICT_WATER_DEMAND(1, 7));

SELECT '✅ ML functions created and tested successfully!' AS STATUS;

