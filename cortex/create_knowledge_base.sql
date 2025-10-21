-- ============================================================================
-- SIO - Create Knowledge Base and Cortex Search
-- ============================================================================
-- Run with: snow sql -f cortex/create_knowledge_base.sql -c myconnection
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE SIO_DB;
USE WAREHOUSE SIO_MED_WH;

-- ============================================================================
-- 1. CREATE KNOWLEDGE BASE SCHEMA AND TABLES
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS KNOWLEDGE_BASE
    COMMENT = 'Knowledge base for SIO policies, procedures, and guidelines';

USE SCHEMA KNOWLEDGE_BASE;

-- Documents table for Cortex Search
CREATE OR REPLACE TABLE DOCUMENTS (
    DOCUMENT_ID VARCHAR(100) PRIMARY KEY,
    TITLE VARCHAR(500) NOT NULL,
    CONTENT TEXT NOT NULL,
    CATEGORY VARCHAR(100),
    LANGUAGE VARCHAR(10) DEFAULT 'EN',
    CREATED_DATE TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    LAST_UPDATED TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================================
-- 2. INSERT SAMPLE DOCUMENTS
-- ============================================================================

-- Billing Policies
INSERT INTO DOCUMENTS (DOCUMENT_ID, TITLE, CONTENT, CATEGORY) VALUES
('BILL_001', 'Water Billing Policy', 
'The Saudi Irrigation Organization (SIO) bills customers on a monthly basis. Billing is calculated based on actual water consumption measured by smart meters. The rate is 0.50 SAR per cubic meter plus a monthly service fee of 50 SAR. Payment is due within 45 days of bill generation. Late payments incur a 5% monthly penalty.', 
'BILLING'),

('BILL_002', 'Payment Methods Guide',
'SIO accepts the following payment methods: Bank Transfer (preferred), Online Payment via SIO portal, Cash at SIO service centers, and Bank Checks. For bank transfers, use IBAN SA1234567890. Online payments are processed immediately. Cash payments must be made before 3 PM. Checks take 3-5 business days to clear.',
'BILLING'),

('BILL_003', 'Payment Extension Request Process',
'Farmers experiencing financial hardship may request payment extensions. Submit a request via the SIO portal or visit any service center. Required documents: valid ID, farm ownership certificate, and explanation letter. Extensions are reviewed within 5 business days. Maximum extension period is 60 days. No penalties applied during approved extension periods.',
'BILLING');

-- Water Conservation Guidelines
INSERT INTO DOCUMENTS (DOCUMENT_ID, TITLE, CONTENT, CATEGORY) VALUES
('CONS_001', 'Water Conservation Best Practices',
'Efficient water usage helps reduce costs and ensures sustainable agriculture. Best practices include: drip irrigation systems (save up to 40% water), scheduled watering during cooler hours (morning/evening), soil moisture monitoring, mulching to reduce evaporation, and regular maintenance of irrigation equipment. SIO offers subsidies for farmers installing efficient irrigation systems.',
'CONSERVATION'),

('CONS_002', 'Seasonal Water Management',
'Water demand varies by season in Saudi Arabia. Summer months (June-September) show 50% higher consumption. Recommendations: increase irrigation frequency in summer, reduce in winter, adjust crop planning to seasonal water availability, and use drought-resistant crops during peak heat. SIO provides free seasonal planning consultations.',
'CONSERVATION'),

('CONS_003', 'Smart Meter Benefits Guide',
'SIO smart meters provide real-time water usage monitoring. Benefits include: immediate leak detection, usage alerts via SMS, historical consumption analysis, and personalized efficiency recommendations. Access your meter data 24/7 via the SIO mobile app. Report meter malfunctions to SIO support at +966-11-4567890.',
'TECHNOLOGY');

-- Regional Guidelines  
INSERT INTO DOCUMENTS (DOCUMENT_ID, TITLE, CONTENT, CATEGORY) VALUES
('REG_001', 'Regional Water Allocation Policy',
'Water allocation is based on regional capacity and agricultural area. Riyadh region has the highest capacity (50M m³), followed by Eastern Province (45M m³). Priority allocation: essential crops (wheat, dates), food security crops, then export crops. During optimization periods, industrial users may face temporary restrictions. Allocation reviewed quarterly by SIO board.',
'REGIONAL'),

('REG_002', 'Emergency Water Protocols',
'During critical resource optimization periods (below 40% regional capacity), SIO implements tiered response: Stage 1 (50-40%): voluntary conservation encouraged. Stage 2 (40-30%): industrial usage restrictions. Stage 3 (below 30%): mandatory rationing with priority for essential agricultural needs. All farmers receive 48-hour advance notice via SMS and email.',
'REGIONAL'),

('REG_003', 'New Customer Registration Process',
'To register for SIO water services: 1) Complete online application at sio.gov.sa, 2) Submit farm ownership documents, 3) Schedule meter installation (free for first meter), 4) Pay 500 SAR activation fee, 5) Receive account number within 10 business days. Industrial customers require additional environmental compliance certificates.',
'PROCEDURES');

-- Subsidies and Support
INSERT INTO DOCUMENTS (DOCUMENT_ID, TITLE, CONTENT, CATEGORY) VALUES
('SUB_001', 'Irrigation Efficiency Subsidy Program',
'SIO offers up to 70% subsidy for farmers upgrading to efficient irrigation systems. Eligible systems: drip irrigation, sprinkler systems, smart controllers. Maximum subsidy: 50,000 SAR per farm. Application process: submit system quote, receive approval, install system, submit installation certificate, receive reimbursement within 30 days. Limited to one subsidy per farm every 5 years.',
'SUBSIDIES'),

('SUB_002', 'Crop Diversification Support',
'SIO encourages water-efficient crop diversification. Financial support available for: drought-resistant varieties (up to 20,000 SAR), organic farming transition (25,000 SAR), greenhouse installations (60% cost subsidy). Technical consultations provided free. Apply via SIO agricultural advisory department.',
'SUBSIDIES'),

('SUB_003', 'Farmer Training Programs',
'Free training programs available: Water-efficient farming techniques (monthly workshops), Smart technology adoption (quarterly courses), Business planning for farmers (bi-monthly). All programs conducted in Arabic and English. Certificates provided. Register online or call +966-11-4567899.',
'SUPPORT');

-- Technical Support
INSERT INTO DOCUMENTS (DOCUMENT_ID, TITLE, CONTENT, CATEGORY) VALUES
('TECH_001', 'Meter Troubleshooting Guide',
'Common meter issues: No reading displayed - check power supply or solar panel. Irregular readings - verify meter not blocked by debris. High unexplained usage - check for leaks in irrigation lines. For all issues, contact SIO technical support at support@sio.gov.sa or +966-11-4567890. Emergency leak reports available 24/7.',
'TECHNICAL'),

('TECH_002', 'SIO Mobile App Features',
'The SIO mobile app provides: real-time water usage monitoring, bill viewing and payment, usage alerts and notifications, efficiency recommendations, support ticket submission, and regional water status updates. Download from App Store or Google Play. Available in Arabic and English. Login using your customer ID and registered mobile number.',
'TECHNICAL'),

('TECH_003', 'Data Privacy and Security Policy',
'SIO protects all customer data per Saudi data protection laws. Water usage data used only for billing and optimization recommendations. Personal information never shared with third parties. Customers can request data exports via SIO portal. Data retention: usage data 7 years, billing records 10 years, payment records permanently.',
'LEGAL');

SELECT 'Documents loaded:' AS STATUS, COUNT(*) AS COUNT FROM DOCUMENTS;

-- ============================================================================
-- 3. CREATE CORTEX SEARCH SERVICE
-- ============================================================================

CREATE OR REPLACE CORTEX SEARCH SERVICE SIO_KNOWLEDGE_SERVICE
ON CONTENT
ATTRIBUTES CATEGORY, LANGUAGE
WAREHOUSE = SIO_MED_WH
TARGET_LAG = '1 minute'
AS (
    SELECT 
        DOCUMENT_ID,
        TITLE,
        CONTENT,
        CATEGORY,
        LANGUAGE
    FROM DOCUMENTS
);

-- Wait for service to build
SELECT SYSTEM$WAIT(10);

-- Verify search service
SELECT SYSTEM$GET_CORTEX_SEARCH_SERVICE_STATUS('SIO_KNOWLEDGE_SERVICE') AS STATUS;

SELECT '✅ Knowledge base and Cortex Search created successfully!' AS RESULT;

