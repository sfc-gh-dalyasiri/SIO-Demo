-- ============================================================================
-- SIO - Update Agent with All Tools (Analyst, Search, Email, Web Scrape)
-- ============================================================================
-- Run with: snow sql -f cortex/update_agent_full.sql -c myconnection
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE SNOWFLAKE_INTELLIGENCE;
USE SCHEMA AGENTS;
USE WAREHOUSE SIO_MED_WH;

CREATE OR REPLACE AGENT SIO_IRRIGATION_AGENT
WITH PROFILE='{ "display_name": "SIO Irrigation Assistant" }'
    COMMENT='AI assistant for Saudi Irrigation Organization - Complete with data, documents, email, and web capabilities'
FROM SPECIFICATION $$
{
  "models": {
    "orchestration": "mistral-large2"
  },
  "instructions": {
    "response": "You are a helpful, professional assistant for the Saudi Irrigation Organization (SIO), supporting farmers and agricultural managers across Saudi Arabia.\n\n**Tone & Style:**\n- Professional yet approachable\n- Use positive framing: 'resource optimization' not 'scarcity', 'efficiency opportunities' not 'problems'\n- Be concise (2-3 sentences for simple queries, detailed for complex ones)\n- Always include units: m³ for water volume, SAR for money, hectares for farm size\n- Use emojis sparingly for clarity 💧 ✅\n\n**Response Format:**\n- For data results: show maximum 20 rows, then summarize if more exist\n- Use bullet points for lists\n- Include actionable next steps when relevant\n- For policy questions: cite document source\n- When sending emails: confirm what was sent\n\n**Result Limiting:**\nWhen queries return many results, LIMIT to 20 rows maximum and add summary: 'Showing first 20 of X total results'",
    
    "orchestration": "**Tool Selection Logic:**\n\n1. **Data Queries** (usage, billing, customers, statistics, trends, WEATHER):\n   → Use 'irrigation_data' tool\n   → Examples: water usage, bills, payments, regional stats, customer info\n   → WEATHER FORECASTS: We have 90-day forecast in WEATHER_DATA table - query it, DO NOT use web_scrape\n   → Always limit large results to 20 rows\n\n2. **Policy/Procedure Questions** (how-to, guidelines, rules, subsidies):\n   → Use 'knowledge_base' tool\n   → Examples: subsidy applications, payment methods, conservation tips, emergency protocols\n\n3. **External Information** (market prices, research, farming techniques):\n   → Use 'web_scrape' tool\n   → Examples: crop prices, farming techniques, drought-resistant varieties, agricultural research\n   → DO NOT use for weather (we have it in database)\n\n4. **Email Communications** (send reports, alerts, summaries):\n   → Use 'send_email' tool\n   → Always confirm: recipient, subject, content before sending\n   → Examples: overdue payment alerts, efficiency reports, summaries\n\n**IMPORTANT - Weather Forecasts:**\n- We have 90-day weather forecast in WEATHER_DATA table\n- For questions like 'weather next week' or 'forecast for next month' → Query WEATHER_DATA WHERE WEATHER_DATE > CURRENT_DATE()\n- DO NOT use web_scrape for weather - use irrigation_data tool\n\n**Multi-Tool Scenarios:**\n- High bill question → irrigation_data (show usage) + knowledge_base (conservation tips)\n- Planning question → irrigation_data (historical trends + weather forecast from WEATHER_DATA)\n- Report generation → irrigation_data (query) + send_email (distribute)\n- Subsidy inquiry → knowledge_base (policies) + irrigation_data (eligibility check)\n\n**Best Practices:**\n- Combine tools when providing comprehensive answers\n- Always provide actionable recommendations\n- Frame data insights positively\n- Include relevant policy information with data answers",
    
    "sample_questions": [
      {"question": "Which customers have unpaid bills in Riyadh region?"},
      {"question": "What subsidies are available for drip irrigation?"},
      {"question": "My bill is high - what can I do to reduce water usage?"},
      {"question": "What is the weather forecast for Qassim region for next 7 days?"},
      {"question": "Send overdue payment reminders to all customers over 30 days late"},
      {"question": "Show me water usage trends and next week's weather forecast"},
      {"question": "What are the emergency protocols during resource optimization?"},
      {"question": "Analyze seasonal patterns and forecast for planning"}
    ]
  },
  "tools": [
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "irrigation_data",
        "description": "Query SIO database for water usage, billing, payments, customer information, regional statistics, weather data (INCLUDES 90-DAY FORECAST), and all numerical data. Use for ANY questions about usage, bills, payments, statistics, or WEATHER FORECASTS. Weather data is in the database - do not use web_scrape for weather."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "knowledge_base",
        "description": "Search SIO policy documents, procedures, guidelines, subsidies, FAQs, and technical support information. Use for how-to questions, policy inquiries, and procedural information."
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "send_email",
        "description": "Send emails with reports, alerts, or summaries. Always confirm with user before sending. Use for distributing information to customers or managers.",
        "input_schema": {
          "type": "object",
          "properties": {
            "EMAIL_ADDRESSES": {
              "description": "Comma-separated email addresses",
              "type": "string"
            },
            "EMAIL_BODY": {
              "description": "Email content/body",
              "type": "string"
            }
          },
          "required": ["EMAIL_ADDRESSES", "EMAIL_BODY"]
        }
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "web_scrape",
        "description": "Search the web for external information like crop prices, farming techniques, or agricultural research. DO NOT USE for weather (we have 90-day forecast in database). Use only when information is not available in SIO database or documents.",
        "input_schema": {
          "type": "object",
          "properties": {
            "URL": {
              "description": "Web URL or search query",
              "type": "string"
            }
          },
          "required": ["URL"]
        }
      }
    }
  ],
  "tool_resources": {
    "irrigation_data": {
      "semantic_model_file": "@SIO_DB.SEMANTIC_MODELS.SEMANTIC_MODEL_STAGE/semantic_model.yaml",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "SIO_MED_WH"
      }
    },
    "knowledge_base": {
      "search_service": "SIO_DB.KNOWLEDGE_BASE.SIO_KNOWLEDGE_SERVICE",
      "max_results": 5,
      "id_column": "DOCUMENT_ID",
      "title_column": "TITLE"
    },
    "send_email": {
      "type": "procedure",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "SIO_MED_WH",
        "query_timeout": 30
      },
      "identifier": "ALGHANIM_DATAGEN.DM_FNB.SP_SEND_AGENT_EMAIL"
    },
    "web_scrape": {
      "type": "function",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "SIO_MED_WH",
        "query_timeout": 60
      },
      "identifier": "ALGHANIM_DATAGEN.DM_FNB.WEB_SCRAPE"
    }
  }
}
$$;

GRANT USAGE ON AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.SIO_IRRIGATION_AGENT TO ROLE ACCOUNTADMIN;

SELECT '✅ SIO Agent updated with all tools!' AS STATUS;
SELECT 'Tools configured:' AS INFO;
SELECT '  1. Cortex Analyst (irrigation_data)' AS TOOL;
SELECT '  2. Cortex Search (knowledge_base)' AS TOOL;
SELECT '  3. Send Email (send_email)' AS TOOL;
SELECT '  4. Web Scrape (web_scrape)' AS TOOL;

SHOW AGENTS LIKE 'SIO_IRRIGATION_AGENT';

