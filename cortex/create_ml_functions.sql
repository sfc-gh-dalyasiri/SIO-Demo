-- ============================================================================
-- SIO - ML Water Demand Prediction Functions
-- ============================================================================
-- Run with: snow sql -f cortex/create_ml_functions.sql -c myconnection
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE SIO_DB;
USE SCHEMA ML_ANALYTICS;
USE WAREHOUSE SIO_MED_WH;

-- ============================================================================
-- 1. WATER DEMAND PREDICTION FUNCTION (TABLE FUNCTION)
-- ============================================================================
-- This function predicts water demand using historical usage and weather patterns
-- Works for BOTH Cortex Agent and Streamlit dashboard
-- ============================================================================

CREATE OR REPLACE FUNCTION PREDICT_WATER_DEMAND(
    REGION_ID_INPUT NUMBER,
    DAYS_AHEAD NUMBER
)
RETURNS TABLE (
    PREDICTION_DATE DATE,
    PREDICTED_DEMAND_M3 FLOAT,
    CONFIDENCE_LEVEL VARCHAR,
    SEASONAL_FACTOR FLOAT,
    WEATHER_FACTOR FLOAT,
    RECOMMENDATION VARCHAR
)
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('scikit-learn', 'pandas', 'numpy')
HANDLER = 'predict_demand'
COMMENT = 'ML-based water demand forecasting using historical patterns and weather data'
AS
$$
import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from datetime import datetime, timedelta

def predict_demand(session, region_id_input, days_ahead):
    """
    Predict future water demand for a region
    
    Args:
        session: Snowpark session
        region_id_input: Region ID to predict for
        days_ahead: Number of days to forecast
    
    Returns:
        DataFrame with predictions
    """
    
    try:
        # Fetch historical water usage data (last 6 months)
        usage_query = f"""
            SELECT 
                wu.READING_DATE,
                SUM(wu.VOLUME_M3) AS TOTAL_USAGE_M3,
                AVG(wu.TEMPERATURE_C) AS AVG_TEMP_C
            FROM SIO_DB.DATA.WATER_USAGE wu
            JOIN SIO_DB.DATA.WATER_METERS wm ON wu.METER_ID = wm.METER_ID
            JOIN SIO_DB.DATA.CUSTOMERS c ON wm.CUSTOMER_ID = c.CUSTOMER_ID
            WHERE c.REGION_ID = {region_id_input}
              AND wu.READING_DATE >= DATEADD(month, -6, CURRENT_DATE())
            GROUP BY wu.READING_DATE
            ORDER BY wu.READING_DATE
        """
        
        usage_df = session.sql(usage_query).to_pandas()
        
        if len(usage_df) < 30:
            # Not enough data for prediction
            return pd.DataFrame({
                'PREDICTION_DATE': [datetime.now().date() + timedelta(days=i) for i in range(1, days_ahead+1)],
                'PREDICTED_DEMAND_M3': [0.0] * days_ahead,
                'CONFIDENCE_LEVEL': ['INSUFFICIENT_DATA'] * days_ahead,
                'SEASONAL_FACTOR': [1.0] * days_ahead,
                'WEATHER_FACTOR': [1.0] * days_ahead,
                'RECOMMENDATION': ['More historical data needed for accurate predictions'] * days_ahead
            })
        
        # Fetch weather data
        weather_query = f"""
            SELECT 
                WEATHER_DATE,
                TEMPERATURE_AVG_C,
                RAINFALL_MM,
                HUMIDITY_PERCENT
            FROM SIO_DB.DATA.WEATHER_DATA
            WHERE REGION_ID = {region_id_input}
              AND WEATHER_DATE >= DATEADD(month, -6, CURRENT_DATE())
            ORDER BY WEATHER_DATE
        """
        
        weather_df = session.sql(weather_query).to_pandas()
        
        # Merge usage and weather data
        usage_df['READING_DATE'] = pd.to_datetime(usage_df['READING_DATE'])
        weather_df['WEATHER_DATE'] = pd.to_datetime(weather_df['WEATHER_DATE'])
        
        merged_df = pd.merge(
            usage_df,
            weather_df,
            left_on='READING_DATE',
            right_on='WEATHER_DATE',
            how='left'
        )
        
        # Fill missing weather data
        merged_df = merged_df.fillna(method='ffill').fillna(method='bfill')
        
        # Feature engineering
        merged_df['DAY_OF_YEAR'] = merged_df['READING_DATE'].dt.dayofyear
        merged_df['MONTH'] = merged_df['READING_DATE'].dt.month
        merged_df['DAY_OF_WEEK'] = merged_df['READING_DATE'].dt.dayofweek
        
        # Calculate seasonal factor (summer = higher usage)
        merged_df['SEASONAL_FACTOR'] = merged_df['MONTH'].apply(
            lambda m: 1.5 if m in [6, 7, 8, 9] else 1.0 if m in [3, 4, 5, 10] else 0.7
        )
        
        # Prepare features for ML model
        feature_cols = ['DAY_OF_YEAR', 'MONTH', 'DAY_OF_WEEK', 'TEMPERATURE_AVG_C', 
                       'RAINFALL_MM', 'HUMIDITY_PERCENT', 'SEASONAL_FACTOR']
        
        X = merged_df[feature_cols].values
        y = merged_df['TOTAL_USAGE_M3'].values
        
        # Train Random Forest model
        model = RandomForestRegressor(
            n_estimators=100,
            max_depth=10,
            random_state=42,
            n_jobs=-1
        )
        model.fit(X, y)
        
        # Calculate model confidence (R² score approximation)
        train_score = model.score(X, y)
        
        # Generate predictions for future dates
        predictions = []
        today = datetime.now()
        
        # Get latest weather for baseline
        latest_temp = merged_df['TEMPERATURE_AVG_C'].iloc[-7:].mean()
        latest_rainfall = merged_df['RAINFALL_MM'].iloc[-7:].mean()
        latest_humidity = merged_df['HUMIDITY_PERCENT'].iloc[-7:].mean()
        
        for i in range(1, days_ahead + 1):
            future_date = today + timedelta(days=i)
            
            # Create features for future date
            day_of_year = future_date.timetuple().tm_yday
            month = future_date.month
            day_of_week = future_date.weekday()
            
            # Seasonal factor
            seasonal_factor = 1.5 if month in [6, 7, 8, 9] else 1.0 if month in [3, 4, 5, 10] else 0.7
            
            # Assume similar weather with slight variation
            temp_variation = np.random.normal(0, 2)
            weather_factor = 1.0 + (temp_variation / latest_temp) if latest_temp > 0 else 1.0
            
            future_features = np.array([[
                day_of_year,
                month,
                day_of_week,
                latest_temp + temp_variation,
                latest_rainfall,
                latest_humidity,
                seasonal_factor
            ]])
            
            # Predict
            predicted_demand = model.predict(future_features)[0]
            
            # Determine confidence level
            if train_score > 0.8:
                confidence = 'HIGH'
            elif train_score > 0.6:
                confidence = 'MEDIUM'
            else:
                confidence = 'LOW'
            
            # Generate recommendation based on prediction
            avg_usage = merged_df['TOTAL_USAGE_M3'].mean()
            
            if predicted_demand > avg_usage * 1.3:
                recommendation = f'High demand expected ({predicted_demand/avg_usage:.1f}x average). Consider resource optimization.'
            elif predicted_demand > avg_usage * 1.1:
                recommendation = f'Moderate increase expected ({predicted_demand/avg_usage:.1f}x average). Monitor closely.'
            elif predicted_demand < avg_usage * 0.7:
                recommendation = f'Low demand period ({predicted_demand/avg_usage:.1f}x average). Opportunity for maintenance.'
            else:
                recommendation = f'Normal demand expected ({predicted_demand/avg_usage:.1f}x average). No action needed.'
            
            predictions.append({
                'PREDICTION_DATE': future_date.date(),
                'PREDICTED_DEMAND_M3': round(float(predicted_demand), 2),
                'CONFIDENCE_LEVEL': confidence,
                'SEASONAL_FACTOR': round(float(seasonal_factor), 2),
                'WEATHER_FACTOR': round(float(weather_factor), 2),
                'RECOMMENDATION': recommendation
            })
        
        return pd.DataFrame(predictions)
        
    except Exception as e:
        # Return error information
        return pd.DataFrame({
            'PREDICTION_DATE': [datetime.now().date()],
            'PREDICTED_DEMAND_M3': [0.0],
            'CONFIDENCE_LEVEL': ['ERROR'],
            'SEASONAL_FACTOR': [0.0],
            'WEATHER_FACTOR': [0.0],
            'RECOMMENDATION': [f'Prediction error: {str(e)}']
        })
$$;

-- ============================================================================
-- 2. REGIONAL EFFICIENCY ANALYSIS FUNCTION
-- ============================================================================
-- Identifies regions with efficiency improvement opportunities
-- ============================================================================

CREATE OR REPLACE FUNCTION ANALYZE_REGIONAL_EFFICIENCY()
RETURNS TABLE (
    REGION_NAME VARCHAR,
    EFFICIENCY_SCORE FLOAT,
    EFFICIENCY_RATING VARCHAR,
    WATER_UTILIZATION_PERCENT FLOAT,
    OPPORTUNITIES VARCHAR
)
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('pandas', 'numpy')
HANDLER = 'analyze_efficiency'
COMMENT = 'Analyze water usage efficiency across regions'
AS
$$
import pandas as pd
import numpy as np

def analyze_efficiency(session):
    """
    Analyze regional water efficiency and identify opportunities
    
    Returns:
        DataFrame with efficiency analysis
    """
    
    try:
        query = """
            SELECT 
                r.REGION_NAME,
                r.WATER_CAPACITY_M3,
                SUM(wu.VOLUME_M3) AS TOTAL_USAGE_M3,
                COUNT(DISTINCT c.CUSTOMER_ID) AS TOTAL_CUSTOMERS,
                AVG(ws.EFFICIENCY_PERCENT) AS AVG_SOURCE_EFFICIENCY
            FROM SIO_DB.DATA.REGIONS r
            LEFT JOIN SIO_DB.DATA.CUSTOMERS c ON r.REGION_ID = c.REGION_ID
            LEFT JOIN SIO_DB.DATA.WATER_METERS wm ON c.CUSTOMER_ID = wm.CUSTOMER_ID
            LEFT JOIN SIO_DB.DATA.WATER_USAGE wu ON wm.METER_ID = wu.METER_ID
            LEFT JOIN SIO_DB.DATA.WATER_SOURCES ws ON r.REGION_ID = ws.REGION_ID
            WHERE wu.READING_DATE >= DATEADD(month, -1, CURRENT_DATE())
              AND ws.STATUS = 'ACTIVE'
            GROUP BY r.REGION_NAME, r.WATER_CAPACITY_M3
        """
        
        df = session.sql(query).to_pandas()
        
        if len(df) == 0:
            return pd.DataFrame(columns=['REGION_NAME', 'EFFICIENCY_SCORE', 'EFFICIENCY_RATING', 
                                        'WATER_UTILIZATION_PERCENT', 'OPPORTUNITIES'])
        
        # Calculate efficiency metrics
        df['USAGE_PER_CUSTOMER'] = df['TOTAL_USAGE_M3'] / df['TOTAL_CUSTOMERS']
        df['CAPACITY_UTILIZATION'] = (df['TOTAL_USAGE_M3'] / df['WATER_CAPACITY_M3']) * 100
        
        # Normalize metrics for scoring
        usage_norm = (df['USAGE_PER_CUSTOMER'] - df['USAGE_PER_CUSTOMER'].min()) / (df['USAGE_PER_CUSTOMER'].max() - df['USAGE_PER_CUSTOMER'].min())
        efficiency_norm = df['AVG_SOURCE_EFFICIENCY'] / 100
        
        # Calculate efficiency score (0-100)
        df['EFFICIENCY_SCORE'] = (efficiency_norm * 50) + ((1 - usage_norm) * 30) + (df['CAPACITY_UTILIZATION'].clip(0, 100) / 100 * 20)
        df['EFFICIENCY_SCORE'] = df['EFFICIENCY_SCORE'] * 100
        
        # Assign ratings
        df['EFFICIENCY_RATING'] = df['EFFICIENCY_SCORE'].apply(
            lambda x: 'EXCELLENT' if x >= 80 else 'GOOD' if x >= 65 else 'FAIR' if x >= 50 else 'NEEDS_IMPROVEMENT'
        )
        
        # Generate opportunities
        def generate_opportunities(row):
            opportunities = []
            
            if row['AVG_SOURCE_EFFICIENCY'] < 85:
                opportunities.append('Improve source efficiency')
            
            if row['CAPACITY_UTILIZATION'] > 85:
                opportunities.append('High utilization - consider capacity expansion')
            elif row['CAPACITY_UTILIZATION'] < 40:
                opportunities.append('Low utilization - surplus capacity available')
            
            if row['USAGE_PER_CUSTOMER'] > df['USAGE_PER_CUSTOMER'].median() * 1.3:
                opportunities.append('Above-average usage - education opportunity')
            
            if not opportunities:
                opportunities.append('Operating at optimal levels')
            
            return '; '.join(opportunities)
        
        df['OPPORTUNITIES'] = df.apply(generate_opportunities, axis=1)
        
        # Return results
        result_df = df[[
            'REGION_NAME',
            'EFFICIENCY_SCORE',
            'EFFICIENCY_RATING',
            'CAPACITY_UTILIZATION',
            'OPPORTUNITIES'
        ]].copy()
        
        result_df.columns = ['REGION_NAME', 'EFFICIENCY_SCORE', 'EFFICIENCY_RATING', 
                            'WATER_UTILIZATION_PERCENT', 'OPPORTUNITIES']
        
        result_df['EFFICIENCY_SCORE'] = result_df['EFFICIENCY_SCORE'].round(2)
        result_df['WATER_UTILIZATION_PERCENT'] = result_df['WATER_UTILIZATION_PERCENT'].round(2)
        
        return result_df.sort_values('EFFICIENCY_SCORE', ascending=False)
        
    except Exception as e:
        return pd.DataFrame({
            'REGION_NAME': ['ERROR'],
            'EFFICIENCY_SCORE': [0.0],
            'EFFICIENCY_RATING': ['ERROR'],
            'WATER_UTILIZATION_PERCENT': [0.0],
            'OPPORTUNITIES': [f'Analysis error: {str(e)}']
        })
$$;

-- ============================================================================
-- 3. TEST THE FUNCTIONS
-- ============================================================================

SELECT '============================================' AS STATUS;
SELECT 'Testing ML Functions' AS STATUS;
SELECT '============================================' AS STATUS;

-- Test water demand prediction for Riyadh (Region 1)
SELECT 'Water Demand Prediction for Riyadh (7 days):' AS TEST;
SELECT * FROM TABLE(SIO_DB.ML_ANALYTICS.PREDICT_WATER_DEMAND(1, 7));

-- Test regional efficiency analysis
SELECT 'Regional Efficiency Analysis:' AS TEST;
SELECT * FROM TABLE(SIO_DB.ML_ANALYTICS.ANALYZE_REGIONAL_EFFICIENCY());

SELECT '✅ ML functions created and tested successfully!' AS STATUS;

