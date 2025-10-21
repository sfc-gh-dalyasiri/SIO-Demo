-- ============================================================================
-- Water Usage Anomaly Detection - ML Stored Procedure
-- ============================================================================
-- Based on proven payroll anomaly detection pattern
-- Returns TEXT summary (for agent use) instead of table
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE SIO_DB;
USE SCHEMA ML_ANALYTICS;
USE WAREHOUSE SIO_MED_WH;

-- ============================================================================
-- ML Anomaly Detection Procedure
-- ============================================================================

CREATE OR REPLACE PROCEDURE ANALYZE_WATER_USAGE_ANOMALIES(
    CUSTOMER_ID_INPUT NUMBER,
    MONTHS_BACK NUMBER
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('scikit-learn', 'pandas', 'numpy', 'snowflake-snowpark-python')
HANDLER = 'analyze_anomalies'
COMMENT = 'ML anomaly detection for water usage - returns TEXT summary'
EXECUTE AS OWNER
AS
$$
import pandas as pd
import numpy as np
from sklearn.ensemble import IsolationForest

def analyze_anomalies(session, customer_id_input, months_back):
    """
    Detect water usage anomalies using Isolation Forest ML
    Returns: Text summary of findings
    """
    
    # Query water usage data
    query = f"""
        SELECT 
            wu.READING_DATE,
            wu.VOLUME_M3,
            wu.TEMPERATURE_C,
            wu.FLOW_RATE_M3_H,
            wu.PRESSURE_BAR
        FROM SIO_DB.DATA.WATER_USAGE wu
        JOIN SIO_DB.DATA.WATER_METERS wm ON wu.METER_ID = wm.METER_ID
        WHERE wm.CUSTOMER_ID = {customer_id_input}
        AND wu.READING_DATE >= DATEADD(month, -{months_back}, CURRENT_DATE())
        ORDER BY wu.READING_DATE
    """
    
    df = session.sql(query).to_pandas()
    
    if len(df) < 7:
        return f'Insufficient data - need at least 7 days of usage history. Found {len(df)} records.'
    
    # Prepare features for ML
    features = df[['VOLUME_M3', 'TEMPERATURE_C', 'FLOW_RATE_M3_H', 'PRESSURE_BAR']].fillna(0)
    
    # Train Isolation Forest model
    model = IsolationForest(
        contamination=0.15,  # Expect 15% anomalies
        random_state=42,
        n_estimators=50
    )
    
    # Detect anomalies (-1 = anomaly, 1 = normal)
    predictions = model.fit_predict(features)
    
    # Get anomaly scores (lower = more anomalous)
    scores = model.score_samples(features)
    
    # Normalize scores to 0-100 (100 = most anomalous)
    norm_scores = 100 * (scores.max() - scores) / (scores.max() - scores.min() + 0.0001)
    
    # Calculate summary statistics
    anomalies = int((predictions == -1).sum())
    high_risk = int((norm_scores >= 70).sum())
    medium_risk = int(((norm_scores >= 40) & (norm_scores < 70)).sum())
    max_score = float(norm_scores.max())
    avg_score = float(norm_scores.mean())
    avg_usage = float(df['VOLUME_M3'].mean())
    max_usage = float(df['VOLUME_M3'].max())
    min_usage = float(df['VOLUME_M3'].min())
    
    # Identify most anomalous period and explain why
    max_anomaly_idx = norm_scores.argmax()
    max_anomaly_date = str(df.iloc[max_anomaly_idx]['READING_DATE'])
    max_anomaly_volume = float(df.iloc[max_anomaly_idx]['VOLUME_M3'])
    
    # Calculate feature deviations to explain anomalies
    feature_means = features.mean()
    feature_stds = features.std()
    
    # Get the anomalous record's features
    anomaly_features = features.iloc[max_anomaly_idx]
    
    # Calculate percentage deviations for ALL features and rank them
    deviations = {}
    
    vol_diff = ((anomaly_features['VOLUME_M3'] - feature_means['VOLUME_M3']) / feature_means['VOLUME_M3']) * 100
    deviations['Volume'] = (abs(vol_diff), f"Volume {abs(vol_diff):.0f}% {'higher' if vol_diff > 0 else 'lower'} than average ({anomaly_features['VOLUME_M3']:.0f} vs {feature_means['VOLUME_M3']:.0f} m³)")
    
    if feature_means['TEMPERATURE_C'] > 0:
        temp_diff = ((anomaly_features['TEMPERATURE_C'] - feature_means['TEMPERATURE_C']) / feature_means['TEMPERATURE_C']) * 100
        deviations['Temperature'] = (abs(temp_diff), f"Temperature {abs(temp_diff):.0f}% {'higher' if temp_diff > 0 else 'lower'} ({anomaly_features['TEMPERATURE_C']:.1f}°C vs {feature_means['TEMPERATURE_C']:.1f}°C)")
    
    if feature_means['FLOW_RATE_M3_H'] > 0:
        flow_diff = ((anomaly_features['FLOW_RATE_M3_H'] - feature_means['FLOW_RATE_M3_H']) / feature_means['FLOW_RATE_M3_H']) * 100
        deviations['Flow Rate'] = (abs(flow_diff), f"Flow rate {abs(flow_diff):.0f}% {'higher' if flow_diff > 0 else 'lower'} ({anomaly_features['FLOW_RATE_M3_H']:.1f} vs {feature_means['FLOW_RATE_M3_H']:.1f} m³/h)")
    
    if feature_means['PRESSURE_BAR'] > 0:
        pressure_diff = ((anomaly_features['PRESSURE_BAR'] - feature_means['PRESSURE_BAR']) / feature_means['PRESSURE_BAR']) * 100
        deviations['Pressure'] = (abs(pressure_diff), f"Pressure {abs(pressure_diff):.0f}% {'higher' if pressure_diff > 0 else 'lower'} ({anomaly_features['PRESSURE_BAR']:.1f} vs {feature_means['PRESSURE_BAR']:.1f} bar)")
    
    # Sort by deviation magnitude and take top contributors
    sorted_deviations = sorted(deviations.items(), key=lambda x: x[1][0], reverse=True)
    technical_explanation = "; ".join([dev[1][1] for dev in sorted_deviations[:3]])
    
    # Use Cortex AI to generate natural language explanation
    prompt = f"""You are a water facility expert. Analyze this anomaly and provide ONLY a 2-sentence diagnosis without any preamble.

Anomaly Date: {max_anomaly_date}
Technical Data: {technical_explanation}
Normal usage: {avg_usage:.0f} m³/day, This day: {max_anomaly_volume:.0f} m³
Risk Score: {norm_scores[max_anomaly_idx]:.0f}/100

Write 2 sentences: First sentence explains the likely cause. Second sentence states what to check or investigate."""
    
    try:
        ai_explanation_query = f"""
            SELECT SNOWFLAKE.CORTEX.COMPLETE(
                'llama3.1-8b',
                '{prompt.replace("'", "''")}'
            ) AS explanation
        """
        ai_result = session.sql(ai_explanation_query).to_pandas()
        if not ai_result.empty:
            ai_explanation = str(ai_result.iloc[0, 0])
            explanation_text = f"{technical_explanation}\\n\\n🤖 AI Analysis: {ai_explanation}"
        else:
            explanation_text = technical_explanation
    except:
        explanation_text = technical_explanation
    
    # Build text summary for agent
    summary = f"""ML Water Usage Anomaly Analysis Complete

Customer ID: {customer_id_input}
Analysis Period: Last {months_back} months
Total Days Analyzed: {len(df)}

USAGE STATISTICS:
- Average Daily Usage: {avg_usage:.2f} m³
- Maximum Usage: {max_usage:.2f} m³
- Minimum Usage: {min_usage:.2f} m³

ANOMALY DETECTION:
- Total Anomalies Detected: {anomalies}
- High Risk Days: {high_risk}
- Medium Risk Days: {medium_risk}
- Maximum Anomaly Score: {max_score:.1f}/100
- Average Anomaly Score: {avg_score:.1f}/100

MOST ANOMALOUS DAY:
- Date: {max_anomaly_date}
- Usage: {max_anomaly_volume:.2f} m³
- Score: {norm_scores[max_anomaly_idx]:.1f}/100
- Why Anomalous: {explanation_text}

RECOMMENDATION: {'URGENT - High risk anomalies detected, investigate immediately' if high_risk > 0 else 'REVIEW - Some anomalies detected, review recommended' if anomalies > 0 else 'NORMAL - No significant anomalies detected'}
"""
    
    return summary
$$;

-- ============================================================================
-- Test the procedure
-- ============================================================================

SELECT '============================================' AS STATUS;
SELECT 'Testing Water Usage Anomaly Detection' AS STATUS;
SELECT '============================================' AS STATUS;

-- Test for first customer
CALL SIO_DB.ML_ANALYTICS.ANALYZE_WATER_USAGE_ANOMALIES(1, 6);

SELECT '✅ ML anomaly detection procedure created and tested!' AS STATUS;

