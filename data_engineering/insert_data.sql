-- ============================================================================
-- SIO - Load Generated Data into Snowflake
-- ============================================================================
-- Run after: python data_engineering/generate_data.py
-- Execute with: snow sql -f data_engineering/insert_data.sql -c myconnection
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE SIO_DB;
USE WAREHOUSE SIO_MED_WH;
USE SCHEMA DATA;

-- ============================================================================
-- 1. CREATE STAGE FOR DATA FILES
-- ============================================================================

CREATE STAGE IF NOT EXISTS DATA_STAGE
    COMMENT = 'Temporary stage for loading CSV data files';

-- ============================================================================
-- 2. UPLOAD CSV FILES
-- ============================================================================

-- Upload all CSV files to stage
-- Note: Run these PUT commands from your local machine
-- PUT file://data/regions.csv @DATA_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
-- PUT file://data/water_sources.csv @DATA_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
-- PUT file://data/customers.csv @DATA_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
-- PUT file://data/water_meters.csv @DATA_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
-- PUT file://data/water_usage.csv @DATA_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
-- PUT file://data/billing.csv @DATA_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
-- PUT file://data/payments.csv @DATA_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
-- PUT file://data/weather_data.csv @DATA_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- Or use snow CLI to upload:
!snow sql -q "PUT file://data/regions.csv @SIO_DB.DATA.DATA_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;" -c myconnection
!snow sql -q "PUT file://data/water_sources.csv @SIO_DB.DATA.DATA_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;" -c myconnection
!snow sql -q "PUT file://data/customers.csv @SIO_DB.DATA.DATA_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;" -c myconnection
!snow sql -q "PUT file://data/water_meters.csv @SIO_DB.DATA.DATA_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;" -c myconnection
!snow sql -q "PUT file://data/water_usage.csv @SIO_DB.DATA.DATA_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;" -c myconnection
!snow sql -q "PUT file://data/billing.csv @SIO_DB.DATA.DATA_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;" -c myconnection
!snow sql -q "PUT file://data/payments.csv @SIO_DB.DATA.DATA_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;" -c myconnection
!snow sql -q "PUT file://data/weather_data.csv @SIO_DB.DATA.DATA_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;" -c myconnection

-- ============================================================================
-- 3. LOAD DATA FROM STAGE
-- ============================================================================

-- Load Regions
COPY INTO REGIONS (REGION_NAME, REGION_NAME_AR, POPULATION, AGRICULTURAL_AREA_KM2, WATER_CAPACITY_M3)
FROM (
    SELECT 
        $1,  -- name
        $2,  -- name_ar
        $3,  -- pop
        $4,  -- ag_area
        $5   -- capacity
    FROM @DATA_STAGE/regions.csv
)
FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY='"')
ON_ERROR = CONTINUE;

SELECT 'Loaded regions:', COUNT(*) FROM REGIONS;

-- Load Water Sources
COPY INTO WATER_SOURCES (SOURCE_NAME, SOURCE_TYPE, REGION_ID, CAPACITY_M3, CURRENT_LEVEL_M3, 
                         EFFICIENCY_PERCENT, STATUS, LAST_MAINTENANCE_DATE, LATITUDE, LONGITUDE)
FROM (
    SELECT 
        $1,  -- SOURCE_NAME
        $2,  -- SOURCE_TYPE
        $3,  -- REGION_ID
        $4,  -- CAPACITY_M3
        $5,  -- CURRENT_LEVEL_M3
        $6,  -- EFFICIENCY_PERCENT
        $7,  -- STATUS
        $8,  -- LAST_MAINTENANCE_DATE
        $9,  -- LATITUDE
        $10  -- LONGITUDE
    FROM @DATA_STAGE/water_sources.csv
)
FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY='"')
ON_ERROR = CONTINUE;

SELECT 'Loaded water sources:', COUNT(*) FROM WATER_SOURCES;

-- Load Customers
COPY INTO CUSTOMERS (CUSTOMER_NAME, CUSTOMER_TYPE, REGION_ID, FARM_SIZE_HECTARES, CROP_TYPE,
                     CONTACT_PHONE, CONTACT_EMAIL, REGISTRATION_DATE, ACCOUNT_STATUS)
FROM (
    SELECT 
        $1,  -- CUSTOMER_NAME
        $2,  -- CUSTOMER_TYPE
        $3,  -- REGION_ID
        $4,  -- FARM_SIZE_HECTARES
        $5,  -- CROP_TYPE
        $6,  -- CONTACT_PHONE
        $7,  -- CONTACT_EMAIL
        $8,  -- REGISTRATION_DATE
        $9   -- ACCOUNT_STATUS
    FROM @DATA_STAGE/customers.csv
)
FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY='"')
ON_ERROR = CONTINUE;

SELECT 'Loaded customers:', COUNT(*) FROM CUSTOMERS;

-- Load Water Meters
COPY INTO WATER_METERS (CUSTOMER_ID, METER_NUMBER, INSTALLATION_DATE, LAST_CALIBRATION_DATE,
                        METER_STATUS, LOCATION_LATITUDE, LOCATION_LONGITUDE)
FROM (
    SELECT 
        $1,  -- CUSTOMER_ID
        $2,  -- METER_NUMBER
        $3,  -- INSTALLATION_DATE
        $4,  -- LAST_CALIBRATION_DATE
        $5,  -- METER_STATUS
        $6,  -- LOCATION_LATITUDE
        $7   -- LOCATION_LONGITUDE
    FROM @DATA_STAGE/water_meters.csv
)
FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY='"')
ON_ERROR = CONTINUE;

SELECT 'Loaded water meters:', COUNT(*) FROM WATER_METERS;

-- Load Water Usage (Large dataset - may take a few minutes)
COPY INTO WATER_USAGE (METER_ID, READING_DATE, VOLUME_M3, PRESSURE_BAR, FLOW_RATE_M3_H, TEMPERATURE_C)
FROM (
    SELECT 
        $1,  -- METER_ID
        $2,  -- READING_DATE
        $3,  -- VOLUME_M3
        $4,  -- PRESSURE_BAR
        $5,  -- FLOW_RATE_M3_H
        $6   -- TEMPERATURE_C
    FROM @DATA_STAGE/water_usage.csv
)
FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY='"')
ON_ERROR = CONTINUE;

SELECT 'Loaded water usage records:', COUNT(*) FROM WATER_USAGE;

-- Load Billing
COPY INTO BILLING (CUSTOMER_ID, BILLING_MONTH, USAGE_VOLUME_M3, BASE_RATE_SAR, USAGE_CHARGE_SAR,
                   SERVICE_FEE_SAR, TOTAL_AMOUNT_SAR, DUE_DATE, BILL_STATUS, GENERATED_DATE)
FROM (
    SELECT 
        $1,  -- CUSTOMER_ID
        $2,  -- BILLING_MONTH
        $3,  -- USAGE_VOLUME_M3
        $4,  -- BASE_RATE_SAR
        $5,  -- USAGE_CHARGE_SAR
        $6,  -- SERVICE_FEE_SAR
        $7,  -- TOTAL_AMOUNT_SAR
        $8,  -- DUE_DATE
        $9,  -- BILL_STATUS
        $10  -- GENERATED_DATE
    FROM @DATA_STAGE/billing.csv
)
FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY='"')
ON_ERROR = CONTINUE;

SELECT 'Loaded bills:', COUNT(*) FROM BILLING;

-- Load Payments
COPY INTO PAYMENTS (BILL_ID, PAYMENT_DATE, AMOUNT_PAID_SAR, PAYMENT_METHOD, TRANSACTION_REFERENCE, PAYMENT_STATUS)
FROM (
    SELECT 
        $1,  -- BILL_ID
        $2,  -- PAYMENT_DATE
        $3,  -- AMOUNT_PAID_SAR
        $4,  -- PAYMENT_METHOD
        $5,  -- TRANSACTION_REFERENCE
        $6   -- PAYMENT_STATUS
    FROM @DATA_STAGE/payments.csv
)
FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY='"')
ON_ERROR = CONTINUE;

SELECT 'Loaded payments:', COUNT(*) FROM PAYMENTS;

-- Load Weather Data
COPY INTO WEATHER_DATA (REGION_ID, WEATHER_DATE, TEMPERATURE_MAX_C, TEMPERATURE_MIN_C, 
                        TEMPERATURE_AVG_C, RAINFALL_MM, HUMIDITY_PERCENT, WIND_SPEED_KMH)
FROM (
    SELECT 
        $1,  -- REGION_ID
        $2,  -- WEATHER_DATE
        $3,  -- TEMPERATURE_MAX_C
        $4,  -- TEMPERATURE_MIN_C
        $5,  -- TEMPERATURE_AVG_C
        $6,  -- RAINFALL_MM
        $7,  -- HUMIDITY_PERCENT
        $8   -- WIND_SPEED_KMH
    FROM @DATA_STAGE/weather_data.csv
)
FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY='"')
ON_ERROR = CONTINUE;

SELECT 'Loaded weather records:', COUNT(*) FROM WEATHER_DATA;

-- ============================================================================
-- 4. VERIFICATION
-- ============================================================================

SELECT '============================================' AS STATUS;
SELECT 'DATA LOAD SUMMARY' AS STATUS;
SELECT '============================================' AS STATUS;

SELECT 'Regions:' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM REGIONS
UNION ALL
SELECT 'Water Sources:', COUNT(*) FROM WATER_SOURCES
UNION ALL
SELECT 'Customers:', COUNT(*) FROM CUSTOMERS
UNION ALL
SELECT 'Water Meters:', COUNT(*) FROM WATER_METERS
UNION ALL
SELECT 'Water Usage:', COUNT(*) FROM WATER_USAGE
UNION ALL
SELECT 'Billing:', COUNT(*) FROM BILLING
UNION ALL
SELECT 'Payments:', COUNT(*) FROM PAYMENTS
UNION ALL
SELECT 'Weather Data:', COUNT(*) FROM WEATHER_DATA;

SELECT '============================================' AS STATUS;
SELECT 'SAMPLE DATA VERIFICATION' AS STATUS;
SELECT '============================================' AS STATUS;

-- Sample queries to verify data
SELECT 'Top 5 regions by water capacity:' AS INFO;
SELECT REGION_NAME, WATER_CAPACITY_M3, POPULATION FROM REGIONS ORDER BY WATER_CAPACITY_M3 DESC LIMIT 5;

SELECT 'Water source utilization:' AS INFO;
SELECT * FROM REGIONAL_WATER_STATUS LIMIT 5;

SELECT 'Overdue bills count:' AS INFO;
SELECT COUNT(*) AS OVERDUE_BILLS, SUM(TOTAL_AMOUNT_SAR) AS TOTAL_OVERDUE_SAR 
FROM BILLING 
WHERE BILL_STATUS = 'OVERDUE';

SELECT 'Average daily water usage by region (last 30 days):' AS INFO;
SELECT 
    r.REGION_NAME,
    AVG(wu.VOLUME_M3) AS AVG_DAILY_USAGE_M3,
    COUNT(DISTINCT wu.METER_ID) AS ACTIVE_METERS
FROM WATER_USAGE wu
JOIN WATER_METERS wm ON wu.METER_ID = wm.METER_ID
JOIN CUSTOMERS c ON wm.CUSTOMER_ID = c.CUSTOMER_ID
JOIN REGIONS r ON c.REGION_ID = r.REGION_ID
WHERE wu.READING_DATE >= CURRENT_DATE() - 30
GROUP BY r.REGION_NAME
ORDER BY AVG_DAILY_USAGE_M3 DESC;

SELECT '✅ Data loading complete!' AS STATUS;

