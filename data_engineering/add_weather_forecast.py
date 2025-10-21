#!/usr/bin/env python3
"""
Add future weather forecast data to WEATHER_DATA table
Generates 90 days (3 months) of forecast data for all regions
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import random

# Set seed for reproducibility
np.random.seed(42)
random.seed(42)

# Regions
REGION_IDS = range(1, 9)  # 8 regions

def generate_future_weather(days_ahead=90):
    """Generate future weather forecast for next 90 days"""
    weather = []
    start_date = datetime.now() + timedelta(days=1)
    
    for region_id in REGION_IDS:
        current_date = start_date
        
        for day in range(days_ahead):
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
            current_date = start_date + timedelta(days=day+1)  # Reset for next iteration
    
    return pd.DataFrame(weather)

def main():
    print("🌡️ Generating future weather forecast data...")
    
    # Generate 90 days forecast
    forecast_df = generate_future_weather(90)
    forecast_df.to_csv('data/weather_forecast.csv', index=False)
    
    print(f"✅ Generated {len(forecast_df)} forecast records (90 days × 8 regions)")
    print(f"   Forecast period: {forecast_df['WEATHER_DATE'].min()} to {forecast_df['WEATHER_DATE'].max()}")
    print(f"\nFile saved: data/weather_forecast.csv")
    print(f"\nNext step: Load into WEATHER_DATA table")

if __name__ == "__main__":
    main()

