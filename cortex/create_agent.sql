-- ============================================================================
-- SIO - Create Cortex Agent with ML Integration
-- ============================================================================
-- Run with: snow sql -f cortex/create_agent.sql -c myconnection
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE SNOWFLAKE_INTELLIGENCE;
USE SCHEMA AGENTS;
USE WAREHOUSE SIO_MED_WH;

-- ============================================================================
-- CREATE SIO IRRIGATION AGENT
-- ============================================================================

CREATE OR REPLACE AGENT SIO_IRRIGATION_AGENT
WITH PROFILE='{ "display_name": "SIO Irrigation Assistant" }'
    COMMENT='AI assistant for Saudi Irrigation Organization - Water resource optimization and smart agriculture'
FROM SPECIFICATION $$
{
  "models": {
    "orchestration": "mistral-large2"
  },
  "instructions": {
    "response": "You are a helpful assistant for the Saudi Irrigation Organization (SIO). You help farmers and agricultural managers with water usage insights, billing information, and resource optimization.\n\n**Tone & Style**:\n- Professional, supportive, and encouraging\n- Use positive framing: 'resource optimization' not 'scarcity', 'efficiency opportunities' not 'problems'\n- Include relevant units (m³ for water, SAR for money, hectares for farm size)\n- Be concise (2-3 sentences for simple queries)\n\n**Response Format**:\n- Use bullet points for lists\n- Include numbers with units (e.g., 1,500 m³, 2,000 SAR)\n- For recommendations, frame positively and offer actionable next steps\n- When showing predictions, always include confidence level",
    
    "orchestration": "**Tool Selection Logic**:\n\n1. **Data Queries** (balances, usage, billing, statistics):\n   - Use 'data_analyst' tool\n   - Returns structured data about customers, water usage, billing, regions\n\n2. **Forecasting & Predictions** (future demand, ML insights):\n   - Use 'predict_demand' tool for water demand forecasting\n   - Use 'efficiency_analysis' tool for regional optimization insights\n   - Always include confidence levels and recommendations\n\n3. **Multi-Step Queries**:\n   - Example: 'Show usage and predict next week' → Use data_analyst first, then predict_demand\n   - Combine results in a coherent response\n\n**Positive Framing**:\n- Low water levels → 'Opportunity for resource optimization'\n- High usage → 'Active engagement, potential for efficiency gains'\n- Overdue bills → 'Payment reminders needed'\n- Predictions showing increase → 'Proactive planning opportunity'\n\n**Regional Queries**:\n- Support both English and Arabic region names\n- Map common names: Riyadh, Makkah, Eastern Province, etc.\n\n**Question Types**:\n- 'Which customers haven't paid?' → data_analyst (overdue bills)\n- 'Where do we need more water?' → efficiency_analysis (optimization opportunities)\n- 'Predict demand for next week' → predict_demand\n- 'Show me usage trends' → data_analyst (historical data)",
    
    "sample_questions": [
      {"question": "Which customers have unpaid bills?"},
      {"question": "What is the water resource status across regions?"},
      {"question": "Predict water demand for Riyadh for the next 7 days"},
      {"question": "Which regions have efficiency improvement opportunities?"},
      {"question": "Show me water usage trends over the past 3 months"},
      {"question": "What is the total outstanding balance across all regions?"},
      {"question": "Analyze regional water efficiency"}
    ]
  },
  "tools": [
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "data_analyst",
        "description": "Query irrigation database for water usage, billing, customer information, regional statistics, and historical data. Use this for all data retrieval queries about past and current information."
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "predict_demand",
        "description": "Predict future water demand using ML models. Provides forecasts with confidence levels and seasonal factors. Use when user asks about future demand, predictions, or forecasting.",
        "input_schema": {
          "type": "object",
          "properties": {
            "REGION_ID_INPUT": {
              "description": "Region ID to predict for (1=Riyadh, 2=Makkah, 3=Eastern Province, 4=Madinah, 5=Qassim, 6=Asir, 7=Tabuk, 8=Hail)",
              "type": "number"
            },
            "DAYS_AHEAD": {
              "description": "Number of days to forecast (typically 7-30 days)",
              "type": "number"
            }
          },
          "required": ["REGION_ID_INPUT", "DAYS_AHEAD"]
        }
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "efficiency_analysis",
        "description": "Analyze water usage efficiency across all regions. Identifies optimization opportunities and provides efficiency ratings. Use when user asks about efficiency, optimization, or which regions need attention.",
        "input_schema": {
          "type": "object",
          "properties": {}
        }
      }
    }
  ],
  "tool_resources": {
    "data_analyst": {
      "semantic_model_file": "@SIO_DB.SEMANTIC_MODELS.SEMANTIC_MODEL_STAGE/semantic_model.yaml",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "SIO_MED_WH"
      }
    },
    "predict_demand": {
      "type": "function",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "SIO_MED_WH",
        "query_timeout": 60
      },
      "identifier": "SIO_DB.ML_ANALYTICS.PREDICT_WATER_DEMAND"
    },
    "efficiency_analysis": {
      "type": "function",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "SIO_MED_WH",
        "query_timeout": 60
      },
      "identifier": "SIO_DB.ML_ANALYTICS.ANALYZE_REGIONAL_EFFICIENCY"
    }
  }
}
$$;

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

GRANT USAGE ON AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.SIO_IRRIGATION_AGENT TO ROLE ACCOUNTADMIN;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

SELECT '============================================' AS STATUS;
SELECT 'SIO Irrigation Agent Created Successfully!' AS STATUS;
SELECT '============================================' AS STATUS;

-- Show agent details
SHOW AGENTS LIKE 'SIO_IRRIGATION_AGENT';

-- Describe agent specification
DESCRIBE AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.SIO_IRRIGATION_AGENT;

SELECT '✅ Agent is ready to use!' AS STATUS;
SELECT 'Test queries:' AS INFO;
SELECT '  - Which customers have unpaid bills?' AS EXAMPLE;
SELECT '  - Predict water demand for Riyadh for next 7 days' AS EXAMPLE;
SELECT '  - Show me regional efficiency analysis' AS EXAMPLE;
SELECT '  - What is the water usage trend in Eastern Province?' AS EXAMPLE;

