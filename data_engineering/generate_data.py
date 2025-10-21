#!/usr/bin/env python3
"""
Generate synthetic irrigation data for SIO (Saudi Irrigation Organization)
Simulates 1000 farmers across 8 Saudi provinces with 12 months of data
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import random
import os

# Set random seed for reproducibility
np.random.seed(42)
random.seed(42)

# Saudi provinces (regions)
REGIONS = [
    {'name': 'Riyadh', 'name_ar': 'الرياض', 'pop': 8000000, 'ag_area': 15000, 'capacity': 50000000},
    {'name': 'Makkah', 'name_ar': 'مكة', 'pop': 9000000, 'ag_area': 8000, 'capacity': 40000000},
    {'name': 'Eastern Province', 'name_ar': 'الشرقية', 'pop': 5000000, 'ag_area': 12000, 'capacity': 45000000},
    {'name': 'Madinah', 'name_ar': 'المدينة', 'pop': 2200000, 'ag_area': 6000, 'capacity': 25000000},
    {'name': 'Qassim', 'name_ar': 'القصيم', 'pop': 1500000, 'ag_area': 20000, 'capacity': 35000000},
    {'name': 'Asir', 'name_ar': 'عسير', 'pop': 2200000, 'ag_area': 10000, 'capacity': 30000000},
    {'name': 'Tabuk', 'name_ar': 'تبوك', 'pop': 900000, 'ag_area': 8000, 'capacity': 20000000},
    {'name': 'Hail', 'name_ar': 'حائل', 'pop': 700000, 'ag_area': 9000, 'capacity': 22000000}
]

# Farm types and crops
CUSTOMER_TYPES = ['FARM', 'AGRICULTURAL_BUSINESS', 'INDUSTRIAL']
CROP_TYPES = ['Dates', 'Wheat', 'Vegetables', 'Alfalfa', 'Fruits', 'Barley', 'Mixed Crops']
PAYMENT_METHODS = ['BANK_TRANSFER', 'ONLINE', 'CASH', 'CHECK']

# Water source types
SOURCE_TYPES = ['RESERVOIR', 'WELL', 'TREATMENT_PLANT', 'DESALINATION']

def generate_regions():
    """Generate regions data"""
    return pd.DataFrame(REGIONS)

def generate_water_sources(regions_df):
    """Generate water sources for each region"""
    sources = []
    source_id = 1
    
    for _, region in regions_df.iterrows():
        region_id = _ + 1
        num_sources = random.randint(3, 6)
        
        for i in range(num_sources):
            capacity = random.uniform(1000000, 10000000)
            # Current level between 40% and 95% of capacity (positive framing)
            current_level = capacity * random.uniform(0.40, 0.95)
            
            sources.append({
                'SOURCE_NAME': f"{region['name']} {random.choice(SOURCE_TYPES)} {i+1}",
                'SOURCE_TYPE': random.choice(SOURCE_TYPES),
                'REGION_ID': region_id,
                'CAPACITY_M3': round(capacity, 2),
                'CURRENT_LEVEL_M3': round(current_level, 2),
                'EFFICIENCY_PERCENT': round(random.uniform(75, 95), 2),
                'STATUS': 'ACTIVE' if random.random() > 0.1 else 'MAINTENANCE',
                'LAST_MAINTENANCE_DATE': (datetime.now() - timedelta(days=random.randint(1, 180))).date(),
                'LATITUDE': round(random.uniform(17.0, 32.0), 7),
                'LONGITUDE': round(random.uniform(34.0, 56.0), 7)
            })
            source_id += 1
    
    return pd.DataFrame(sources)

def generate_customers(regions_df, num_customers=1000):
    """Generate farmer/agricultural business customers"""
    customers = []
    
    arabic_names = ['محمد', 'أحمد', 'عبدالله', 'سعد', 'فهد', 'خالد', 'عبدالعزيز', 'سلمان', 'فيصل', 'عمر']
    
    for i in range(num_customers):
        region_id = random.randint(1, len(regions_df))
        customer_type = random.choice(CUSTOMER_TYPES)
        
        # Larger farms for AGRICULTURAL_BUSINESS
        if customer_type == 'AGRICULTURAL_BUSINESS':
            farm_size = random.uniform(100, 500)
        elif customer_type == 'INDUSTRIAL':
            farm_size = random.uniform(50, 200)
        else:
            farm_size = random.uniform(10, 100)
        
        customers.append({
            'CUSTOMER_NAME': f"Farm {i+1} - {random.choice(arabic_names)}",
            'CUSTOMER_TYPE': customer_type,
            'REGION_ID': region_id,
            'FARM_SIZE_HECTARES': round(farm_size, 2),
            'CROP_TYPE': random.choice(CROP_TYPES),
            'CONTACT_PHONE': f'+966{random.randint(500000000, 599999999)}',
            'CONTACT_EMAIL': f'farmer{i+1}@sio-ksa.gov.sa',
            'REGISTRATION_DATE': (datetime.now() - timedelta(days=random.randint(365, 1825))).date(),
            'ACCOUNT_STATUS': 'ACTIVE' if random.random() > 0.05 else 'SUSPENDED'
        })
    
    return pd.DataFrame(customers)

def generate_water_meters(customers_df):
    """Generate water meters for each customer"""
    meters = []
    
    for idx, customer in customers_df.iterrows():
        customer_id = idx + 1
        
        meters.append({
            'CUSTOMER_ID': customer_id,
            'METER_NUMBER': f'WM-{customer_id:06d}',
            'INSTALLATION_DATE': customer['REGISTRATION_DATE'] + timedelta(days=random.randint(1, 30)),
            'LAST_CALIBRATION_DATE': (datetime.now() - timedelta(days=random.randint(1, 365))).date(),
            'METER_STATUS': 'ACTIVE' if customer['ACCOUNT_STATUS'] == 'ACTIVE' else 'INACTIVE',
            'LOCATION_LATITUDE': round(random.uniform(17.0, 32.0), 7),
            'LOCATION_LONGITUDE': round(random.uniform(34.0, 56.0), 7)
        })
    
    return pd.DataFrame(meters)

def generate_water_usage(meters_df, customers_df, months=12):
    """Generate daily water usage readings for the past N months"""
    usage = []
    start_date = datetime.now() - timedelta(days=30 * months)
    
    for idx, meter in meters_df.iterrows():
        meter_id = idx + 1
        customer_id = meter['CUSTOMER_ID']
        customer_type = customers_df.loc[customer_id - 1, 'CUSTOMER_TYPE']
        farm_size = customers_df.loc[customer_id - 1, 'FARM_SIZE_HECTARES']
        
        # Base usage depends on farm size and type
        if customer_type == 'AGRICULTURAL_BUSINESS':
            base_usage = farm_size * random.uniform(50, 80)
        elif customer_type == 'INDUSTRIAL':
            base_usage = farm_size * random.uniform(40, 70)
        else:
            base_usage = farm_size * random.uniform(30, 60)
        
        # Generate daily readings for past 12 months
        current_date = start_date
        while current_date <= datetime.now():
            # Seasonal variation (summer higher)
            month = current_date.month
            seasonal_factor = 1.5 if month in [6, 7, 8, 9] else 1.0 if month in [3, 4, 5, 10] else 0.7
            
            # Daily variation
            daily_usage = base_usage * seasonal_factor * random.uniform(0.8, 1.2)
            
            usage.append({
                'METER_ID': meter_id,
                'READING_DATE': current_date.date(),
                'VOLUME_M3': round(daily_usage, 3),
                'PRESSURE_BAR': round(random.uniform(2.0, 4.5), 2),
                'FLOW_RATE_M3_H': round(daily_usage / 10, 3),
                'TEMPERATURE_C': round(random.uniform(15, 45), 2)
            })
            
            current_date += timedelta(days=1)
    
    return pd.DataFrame(usage)

def generate_billing(customers_df, usage_df):
    """Generate monthly bills based on water usage"""
    bills = []
    
    # Get unique months from usage data
    usage_df['MONTH'] = pd.to_datetime(usage_df['READING_DATE']).dt.to_period('M')
    
    for idx, customer in customers_df.iterrows():
        customer_id = idx + 1
        
        # Get meter ID for this customer
        meter_id = customer_id  # 1:1 relationship
        
        # Get usage for this customer by month
        customer_usage = usage_df[usage_df['METER_ID'] == meter_id]
        
        for month in customer_usage['MONTH'].unique():
            month_data = customer_usage[customer_usage['MONTH'] == month]
            total_volume = month_data['VOLUME_M3'].sum()
            
            # Pricing tiers (SAR per m3)
            base_rate = 0.50
            usage_charge = total_volume * base_rate
            service_fee = 50.00
            total_amount = usage_charge + service_fee
            
            billing_month = month.to_timestamp().date()
            due_date = billing_month + timedelta(days=45)
            
            # Bill status: 85% paid, 10% pending, 5% overdue
            status_rand = random.random()
            if status_rand < 0.85:
                bill_status = 'PAID'
            elif status_rand < 0.95:
                bill_status = 'PENDING'
            else:
                bill_status = 'OVERDUE'
            
            bills.append({
                'CUSTOMER_ID': customer_id,
                'BILLING_MONTH': billing_month,
                'USAGE_VOLUME_M3': round(total_volume, 3),
                'BASE_RATE_SAR': base_rate,
                'USAGE_CHARGE_SAR': round(usage_charge, 2),
                'SERVICE_FEE_SAR': service_fee,
                'TOTAL_AMOUNT_SAR': round(total_amount, 2),
                'DUE_DATE': due_date,
                'BILL_STATUS': bill_status,
                'GENERATED_DATE': billing_month
            })
    
    return pd.DataFrame(bills)

def generate_payments(billing_df):
    """Generate payment records for paid bills"""
    payments = []
    payment_id = 1
    
    paid_bills = billing_df[billing_df['BILL_STATUS'] == 'PAID'].copy()
    paid_bills['BILL_ID'] = range(1, len(paid_bills) + 1)
    
    for idx, bill in paid_bills.iterrows():
        # Payment date between due date and 30 days before
        days_before_due = random.randint(0, 30)
        payment_date = bill['DUE_DATE'] - timedelta(days=days_before_due)
        
        payments.append({
            'BILL_ID': bill['BILL_ID'],
            'PAYMENT_DATE': payment_date,
            'AMOUNT_PAID_SAR': bill['TOTAL_AMOUNT_SAR'],
            'PAYMENT_METHOD': random.choice(PAYMENT_METHODS),
            'TRANSACTION_REFERENCE': f'TXN-{payment_id:08d}',
            'PAYMENT_STATUS': 'COMPLETED'
        })
        payment_id += 1
    
    return pd.DataFrame(payments)

def generate_weather_data(regions_df, months=12):
    """Generate weather data for ML predictions"""
    weather = []
    start_date = datetime.now() - timedelta(days=30 * months)
    
    for _, region in regions_df.iterrows():
        region_id = _ + 1
        
        current_date = start_date
        while current_date <= datetime.now():
            month = current_date.month
            
            # Temperature patterns (Saudi Arabia climate)
            if month in [6, 7, 8]:  # Summer
                temp_avg = random.uniform(38, 45)
            elif month in [12, 1, 2]:  # Winter
                temp_avg = random.uniform(15, 22)
            else:  # Spring/Fall
                temp_avg = random.uniform(25, 35)
            
            weather.append({
                'REGION_ID': region_id,
                'WEATHER_DATE': current_date.date(),
                'TEMPERATURE_MAX_C': round(temp_avg + random.uniform(2, 5), 2),
                'TEMPERATURE_MIN_C': round(temp_avg - random.uniform(5, 10), 2),
                'TEMPERATURE_AVG_C': round(temp_avg, 2),
                'RAINFALL_MM': round(random.uniform(0, 2) if month in [11, 12, 1, 2, 3] else 0, 2),
                'HUMIDITY_PERCENT': round(random.uniform(20, 60), 2),
                'WIND_SPEED_KMH': round(random.uniform(5, 25), 2)
            })
            
            current_date += timedelta(days=1)
    
    return pd.DataFrame(weather)

def main():
    """Generate all data and save to CSV files"""
    
    print("🌊 Generating SIO irrigation data...")
    
    # Create data directory
    os.makedirs('data', exist_ok=True)
    
    # Generate data
    print("  📍 Generating regions...")
    regions_df = generate_regions()
    regions_df.to_csv('data/regions.csv', index=False)
    print(f"     ✅ {len(regions_df)} regions")
    
    print("  💧 Generating water sources...")
    sources_df = generate_water_sources(regions_df)
    sources_df.to_csv('data/water_sources.csv', index=False)
    print(f"     ✅ {len(sources_df)} water sources")
    
    print("  👨‍🌾 Generating customers...")
    customers_df = generate_customers(regions_df, 1000)
    customers_df.to_csv('data/customers.csv', index=False)
    print(f"     ✅ {len(customers_df)} customers")
    
    print("  📟 Generating water meters...")
    meters_df = generate_water_meters(customers_df)
    meters_df.to_csv('data/water_meters.csv', index=False)
    print(f"     ✅ {len(meters_df)} meters")
    
    print("  📊 Generating water usage (12 months)...")
    usage_df = generate_water_usage(meters_df, customers_df, months=12)
    usage_df.to_csv('data/water_usage.csv', index=False)
    print(f"     ✅ {len(usage_df)} usage readings")
    
    print("  💳 Generating billing...")
    billing_df = generate_billing(customers_df, usage_df)
    billing_df.to_csv('data/billing.csv', index=False)
    print(f"     ✅ {len(billing_df)} bills")
    
    print("  💰 Generating payments...")
    payments_df = generate_payments(billing_df)
    payments_df.to_csv('data/payments.csv', index=False)
    print(f"     ✅ {len(payments_df)} payments")
    
    print("  🌡️ Generating weather data...")
    weather_df = generate_weather_data(regions_df, months=12)
    weather_df.to_csv('data/weather_data.csv', index=False)
    print(f"     ✅ {len(weather_df)} weather records")
    
    print("\n✅ Data generation complete!")
    print(f"\nGenerated files in 'data/' directory:")
    print(f"  - regions.csv ({len(regions_df)} rows)")
    print(f"  - water_sources.csv ({len(sources_df)} rows)")
    print(f"  - customers.csv ({len(customers_df)} rows)")
    print(f"  - water_meters.csv ({len(meters_df)} rows)")
    print(f"  - water_usage.csv ({len(usage_df)} rows)")
    print(f"  - billing.csv ({len(billing_df)} rows)")
    print(f"  - payments.csv ({len(payments_df)} rows)")
    print(f"  - weather_data.csv ({len(weather_df)} rows)")
    print(f"\n📈 Summary Statistics:")
    print(f"  - Total water usage: {usage_df['VOLUME_M3'].sum():,.0f} m³")
    print(f"  - Total billing: {billing_df['TOTAL_AMOUNT_SAR'].sum():,.0f} SAR")
    print(f"  - Overdue bills: {len(billing_df[billing_df['BILL_STATUS'] == 'OVERDUE'])} ({len(billing_df[billing_df['BILL_STATUS'] == 'OVERDUE'])/len(billing_df)*100:.1f}%)")

if __name__ == "__main__":
    main()

