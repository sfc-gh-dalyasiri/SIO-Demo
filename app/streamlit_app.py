"""
SIO (Saudi Irrigation Organization) - AI Dashboard
Water resource optimization and smart agriculture management
"""

import streamlit as st
import pandas as pd
import numpy as np
from datetime import datetime, timedelta

# Page config - MUST be first Streamlit command
st.set_page_config(
    page_title="SIO Irrigation Dashboard",
    page_icon="🌊",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Try to import plotly, fallback to streamlit built-in charts
try:
    import plotly.express as px
    import plotly.graph_objects as go
    PLOTLY_AVAILABLE = True
except ImportError:
    PLOTLY_AVAILABLE = False
    # Show warning after page config
    st.sidebar.warning("⚠️ Plotly not available. Using Streamlit built-in charts.")

# Initialize Snowflake connection
@st.cache_resource
def init_connection():
    """Initialize Snowflake connection - works for both local and hosted"""
    try:
        # Try hosted Snowflake Streamlit first
        from snowflake.snowpark.context import get_active_session
        return get_active_session()
    except:
        # Fall back to local development with st.connection
        return st.connection("snowflake")

def get_data(query):
    """Execute query and return results"""
    try:
        session = init_connection()
        # Check if it's Snowpark session (hosted) or connection object (local)
        if hasattr(session, 'sql'):
            # Hosted Snowflake Streamlit (Snowpark session)
            return session.sql(query).to_pandas()
        else:
            # Local development (connection object)
            return session.query(query, ttl=60)
    except Exception as e:
        st.error(f"Error executing query: {str(e)}")
        return pd.DataFrame()

# App title
st.title("🌊 SIO Irrigation Management Dashboard")
st.markdown("**Saudi Irrigation Organization** - Smart Water Resource Optimization")

# Sidebar
with st.sidebar:
    st.header("⚙️ Dashboard Controls")
    
    # Refresh button
    if st.button("🔄 Refresh Data", use_container_width=True):
        st.cache_data.clear()
        st.rerun()
    
    st.divider()
    
    # Region selector
    st.subheader("🗺️ Region Selection")
    regions_df = get_data("SELECT REGION_ID, REGION_NAME FROM SIO_DB.DATA.REGIONS ORDER BY REGION_NAME")
    
    if not regions_df.empty:
        # Add "Show All" option
        region_options = ["Show All"] + regions_df['REGION_NAME'].tolist()
        selected_region = st.selectbox(
            "Select Region",
            options=region_options,
            index=0
        )
        
        if selected_region == "Show All":
            selected_region_id = None
            region_filter = ""
        else:
            selected_region_id = regions_df[regions_df['REGION_NAME'] == selected_region]['REGION_ID'].values[0]
            region_filter = f"AND r.REGION_ID = {selected_region_id}"
    else:
        selected_region = "Show All"
        selected_region_id = None
        region_filter = ""
    
    st.divider()
    
    # Date range
    st.subheader("📅 Time Period")
    days_back = st.slider("Days of history", 7, 90, 30)
    
    st.divider()
    
    # About
    st.subheader("ℹ️ About")
    st.markdown("""
    This dashboard provides:
    - Real-time water usage monitoring
    - ML-powered demand forecasting  
    - Resource optimization insights
    - Payment status tracking
    """)

# Main dashboard tabs
tab1, tab2, tab3, tab4 = st.tabs([
    "📊 Overview",
    "🗺️ Regional Analysis",
    "🔮 ML Predictions",
    "💰 Billing & Payments"
])

# ============================================================================
# TAB 1: OVERVIEW
# ============================================================================
with tab1:
    st.header("System Overview")
    
    # KPIs
    col1, col2, col3, col4 = st.columns(4)
    
    # Total Customers
    total_customers = get_data("SELECT COUNT(*) AS CNT FROM SIO_DB.DATA.CUSTOMERS WHERE ACCOUNT_STATUS = 'ACTIVE'")
    with col1:
        if not total_customers.empty:
            st.metric("Active Customers", f"{total_customers['CNT'].values[0]:,}")
        else:
            st.metric("Active Customers", "N/A")
    
    # Total Water Usage (Last 30 days)
    total_usage = get_data(f"""
        SELECT SUM(VOLUME_M3) AS TOTAL_USAGE
        FROM SIO_DB.DATA.WATER_USAGE
        WHERE READING_DATE >= DATEADD(day, -{days_back}, CURRENT_DATE())
    """)
    with col2:
        if not total_usage.empty and total_usage['TOTAL_USAGE'].values[0] is not None:
            usage_val = total_usage['TOTAL_USAGE'].values[0]
            st.metric("Total Usage", f"{usage_val:,.0f} m³")
        else:
            st.metric("Total Usage", "N/A")
    
    # Outstanding Balance
    outstanding = get_data("""
        SELECT SUM(TOTAL_AMOUNT_SAR) AS OUTSTANDING
        FROM SIO_DB.DATA.BILLING
        WHERE BILL_STATUS IN ('PENDING', 'OVERDUE')
    """)
    with col3:
        if not outstanding.empty and outstanding['OUTSTANDING'].values[0] is not None:
            out_val = outstanding['OUTSTANDING'].values[0]
            st.metric("Outstanding", f"{out_val:,.0f} SAR")
        else:
            st.metric("Outstanding", "0 SAR")
    
    # Active Water Sources
    active_sources = get_data("SELECT COUNT(*) AS CNT FROM SIO_DB.DATA.WATER_SOURCES WHERE STATUS = 'ACTIVE'")
    with col4:
        if not active_sources.empty:
            st.metric("Active Sources", f"{active_sources['CNT'].values[0]:,}")
        else:
            st.metric("Active Sources", "N/A")
    
    st.divider()
    
    # Usage Trends
    st.subheader("📈 Water Usage Trends")
    
    usage_trends = get_data(f"""
        SELECT 
            DATE_TRUNC('DAY', READING_DATE) AS DATE,
            SUM(VOLUME_M3) AS DAILY_USAGE
        FROM SIO_DB.DATA.WATER_USAGE
        WHERE READING_DATE >= DATEADD(day, -{days_back}, CURRENT_DATE())
        GROUP BY DATE_TRUNC('DAY', READING_DATE)
        ORDER BY DATE
    """)
    
    if not usage_trends.empty:
        if PLOTLY_AVAILABLE:
            fig = px.line(usage_trends, x='DATE', y='DAILY_USAGE',
                         title=f'Daily Water Usage - Last {days_back} Days',
                         labels={'DAILY_USAGE': 'Usage (m³)', 'DATE': 'Date'})
            fig.update_traces(line_color='#1f77b4', line_width=2)
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.line_chart(usage_trends.set_index('DATE')['DAILY_USAGE'])
    else:
        st.info("No usage data available")
    
    # Regional Summary
    st.subheader("🌍 Regional Summary")
    
    regional_summary = get_data("""
        SELECT 
            r.REGION_NAME,
            COUNT(DISTINCT c.CUSTOMER_ID) AS CUSTOMERS,
            COALESCE(SUM(ws.CURRENT_LEVEL_M3), 0) AS CURRENT_WATER_M3,
            COALESCE(SUM(ws.CAPACITY_M3), 0) AS CAPACITY_M3,
            CASE 
                WHEN SUM(ws.CAPACITY_M3) > 0 
                THEN ROUND((SUM(ws.CURRENT_LEVEL_M3) / SUM(ws.CAPACITY_M3)) * 100, 1)
                ELSE 0 
            END AS UTILIZATION_PCT
        FROM SIO_DB.DATA.REGIONS r
        LEFT JOIN SIO_DB.DATA.CUSTOMERS c ON r.REGION_ID = c.REGION_ID
        LEFT JOIN SIO_DB.DATA.WATER_SOURCES ws ON r.REGION_ID = ws.REGION_ID AND ws.STATUS = 'ACTIVE'
        GROUP BY r.REGION_NAME
        ORDER BY UTILIZATION_PCT ASC
    """)
    
    if not regional_summary.empty:
        # Format data for display (compatible with older Streamlit versions)
        display_df = regional_summary.copy()
        display_df = display_df.rename(columns={
            "REGION_NAME": "Region",
            "CUSTOMERS": "Customers",
            "CURRENT_WATER_M3": "Current Level (m³)",
            "CAPACITY_M3": "Capacity (m³)",
            "UTILIZATION_PCT": "Utilization %"
        })
        # Format numeric columns - convert to numeric type first
        display_df["Customers"] = pd.to_numeric(display_df["Customers"], errors='coerce').fillna(0).astype(int)
        display_df["Current Level (m³)"] = pd.to_numeric(display_df["Current Level (m³)"], errors='coerce').fillna(0).round(0).astype(int)
        display_df["Capacity (m³)"] = pd.to_numeric(display_df["Capacity (m³)"], errors='coerce').fillna(0).round(0).astype(int)
        display_df["Utilization %"] = pd.to_numeric(display_df["Utilization %"], errors='coerce').fillna(0).round(1)
        
        st.dataframe(
            display_df,
            hide_index=True,
            use_container_width=True
        )
    else:
        st.info("No regional data available")

# ============================================================================
# TAB 2: REGIONAL ANALYSIS
# ============================================================================
with tab2:
    st.header("🗺️ Regional Water Resource Analysis")
    
    # Efficiency Analysis
    st.subheader("⚡ Regional Efficiency Score")
    
    with st.spinner("Analyzing regional efficiency..."):
        efficiency_data = get_data("""
            SELECT * FROM TABLE(SIO_DB.ML_ANALYTICS.ANALYZE_REGIONAL_EFFICIENCY())
            ORDER BY EFFICIENCY_SCORE DESC
        """)
    
    if not efficiency_data.empty:
        if PLOTLY_AVAILABLE:
            # Horizontal bar chart
            fig = px.bar(
                efficiency_data,
                x='EFFICIENCY_SCORE',
                y='REGION_NAME',
                orientation='h',
                title='Regional Efficiency Scores',
                labels={'EFFICIENCY_SCORE': 'Efficiency Score', 'REGION_NAME': 'Region'},
                color='EFFICIENCY_SCORE',
                color_continuous_scale='RdYlGn'
            )
            fig.update_layout(height=400)
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.bar_chart(efficiency_data.set_index('REGION_NAME')['EFFICIENCY_SCORE'])
        
        st.divider()
        
        # Detailed efficiency table
        st.subheader("📊 Efficiency Details")
        # Format data for display (compatible with older Streamlit versions)
        display_df = efficiency_data.copy()
        display_df = display_df.rename(columns={
            "REGION_NAME": "Region",
            "EFFICIENCY_SCORE": "Score",
            "EFFICIENCY_RATING": "Rating",
            "WATER_UTILIZATION_PERCENT": "Utilization %",
            "OPPORTUNITIES": "Opportunities"
        })
        # Format numeric columns - convert to numeric type first
        display_df["Score"] = pd.to_numeric(display_df["Score"], errors='coerce').fillna(0).round(1)
        display_df["Utilization %"] = pd.to_numeric(display_df["Utilization %"], errors='coerce').fillna(0).round(1)
        
        st.dataframe(
            display_df,
            hide_index=True,
            use_container_width=True
        )
    else:
        st.warning("⚠️ ML Analytics functions not available. Run `snow sql -f cortex/create_ml_functions.sql` to enable advanced analytics.")
    
    st.divider()
    
    # Regional Heatmap
    st.subheader("🌡️ Regional Water Resource Heatmap")
    
    heatmap_data = get_data("""
        SELECT 
            r.REGION_NAME,
            r.REGION_ID,
            COUNT(DISTINCT c.CUSTOMER_ID) AS CUSTOMERS,
            COALESCE(SUM(wu.VOLUME_M3), 0) AS TOTAL_USAGE_M3,
            COALESCE(SUM(ws.CURRENT_LEVEL_M3), 0) AS CURRENT_LEVEL_M3,
            COALESCE(SUM(ws.CAPACITY_M3), 1) AS CAPACITY_M3
        FROM SIO_DB.DATA.REGIONS r
        LEFT JOIN SIO_DB.DATA.CUSTOMERS c ON r.REGION_ID = c.REGION_ID
        LEFT JOIN SIO_DB.DATA.WATER_USAGE wu ON c.CUSTOMER_ID IN (
            SELECT wm.CUSTOMER_ID FROM SIO_DB.DATA.WATER_METERS wm WHERE wm.METER_ID = wu.METER_ID
        )
        LEFT JOIN SIO_DB.DATA.WATER_SOURCES ws ON r.REGION_ID = ws.REGION_ID
        WHERE wu.READING_DATE >= DATEADD(day, -30, CURRENT_DATE()) OR wu.READING_DATE IS NULL
        GROUP BY r.REGION_NAME, r.REGION_ID
    """)
    
    if not heatmap_data.empty and PLOTLY_AVAILABLE:
        heatmap_data['UTILIZATION_PCT'] = (heatmap_data['CURRENT_LEVEL_M3'] / heatmap_data['CAPACITY_M3']) * 100
        heatmap_data['USAGE_PER_CUSTOMER'] = heatmap_data['TOTAL_USAGE_M3'] / heatmap_data['CUSTOMERS'].replace(0, 1)
        
        # Create treemap visualization
        fig = px.treemap(
            heatmap_data,
            path=['REGION_NAME'],
            values='TOTAL_USAGE_M3',
            color='UTILIZATION_PCT',
            color_continuous_scale='RdYlGn_r',
            title='Regional Water Usage & Resource Utilization',
            labels={'UTILIZATION_PCT': 'Utilization %', 'TOTAL_USAGE_M3': 'Total Usage (m³)'}
        )
        fig.update_traces(textinfo="label+value")
        fig.update_layout(height=500)
        st.plotly_chart(fig, use_container_width=True)
    else:
        st.info("Heatmap visualization requires data and Plotly library")

# ============================================================================
# TAB 3: ML PREDICTIONS
# ============================================================================
with tab3:
    st.header("🔮 ML-Powered Water Demand Forecasting")
    
    col1, col2 = st.columns([2, 1])
    
    with col2:
        st.subheader("Forecast Settings")
        forecast_days = st.slider("Days to forecast", 7, 30, 14)
        
        if st.button("🚀 Generate Forecast", use_container_width=True, type="primary"):
            if selected_region == "Show All":
                st.error("⚠️ Please select a specific region to generate predictions.")
            elif selected_region_id is None:
                st.error("⚠️ No region selected.")
            else:
                with st.spinner(f"Generating {forecast_days}-day forecast for {selected_region}..."):
                    predictions = get_data(f"""
                        SELECT * FROM TABLE(SIO_DB.ML_ANALYTICS.PREDICT_WATER_DEMAND({selected_region_id}, {forecast_days}))
                        ORDER BY PREDICTION_DATE
                    """)
                    
                    if not predictions.empty:
                        st.session_state['predictions'] = predictions
                        st.session_state['forecast_region'] = selected_region
                    else:
                        st.warning("⚠️ ML prediction function not available. Run `snow sql -f cortex/create_ml_functions.sql` to enable forecasting.")
    
    with col1:
        if 'predictions' in st.session_state and not st.session_state['predictions'].empty:
            predictions = st.session_state['predictions']
            forecast_region = st.session_state.get('forecast_region', selected_region)
            
            st.subheader(f"📊 Forecast for {forecast_region}")
            
            if PLOTLY_AVAILABLE:
                # Create forecast chart
                fig = go.Figure()
                
                # Add prediction line
                fig.add_trace(go.Scatter(
                    x=predictions['PREDICTION_DATE'],
                    y=predictions['PREDICTED_DEMAND_M3'],
                    mode='lines+markers',
                    name='Predicted Demand',
                    line=dict(color='#1f77b4', width=3),
                    marker=dict(size=8)
                ))
                
                # Add confidence shading
                high_conf = predictions[predictions['CONFIDENCE_LEVEL'] == 'HIGH']
                medium_conf = predictions[predictions['CONFIDENCE_LEVEL'] == 'MEDIUM']
                low_conf = predictions[predictions['CONFIDENCE_LEVEL'] == 'LOW']
                
                fig.update_layout(
                    title=f'{forecast_days}-Day Water Demand Forecast',
                    xaxis_title='Date',
                    yaxis_title='Predicted Demand (m³)',
                    hovermode='x unified',
                    height=400
                )
                
                st.plotly_chart(fig, use_container_width=True)
            else:
                st.line_chart(predictions.set_index('PREDICTION_DATE')['PREDICTED_DEMAND_M3'])
            
            st.divider()
            
            # Prediction details
            st.subheader("📋 Detailed Predictions")
            # Format data for display (compatible with older Streamlit versions)
            display_df = predictions.copy()
            display_df = display_df.rename(columns={
                "PREDICTION_DATE": "Date",
                "PREDICTED_DEMAND_M3": "Predicted Demand (m³)",
                "CONFIDENCE_LEVEL": "Confidence",
                "SEASONAL_FACTOR": "Seasonal Factor",
                "WEATHER_FACTOR": "Weather Factor",
                "RECOMMENDATION": "Recommendation"
            })
            # Format numeric columns - convert to numeric type first
            display_df["Predicted Demand (m³)"] = pd.to_numeric(display_df["Predicted Demand (m³)"], errors='coerce').fillna(0).round(2)
            display_df["Seasonal Factor"] = pd.to_numeric(display_df["Seasonal Factor"], errors='coerce').fillna(0).round(2)
            display_df["Weather Factor"] = pd.to_numeric(display_df["Weather Factor"], errors='coerce').fillna(0).round(2)
            
            st.dataframe(
                display_df,
                hide_index=True,
                use_container_width=True
            )
            
            # Key insights
            st.divider()
            st.subheader("💡 Key Insights")
            
            avg_demand = predictions['PREDICTED_DEMAND_M3'].mean()
            max_demand = predictions['PREDICTED_DEMAND_M3'].max()
            max_date = predictions.loc[predictions['PREDICTED_DEMAND_M3'].idxmax(), 'PREDICTION_DATE']
            high_conf_pct = (len(predictions[predictions['CONFIDENCE_LEVEL'] == 'HIGH']) / len(predictions)) * 100
            
            col1, col2, col3 = st.columns(3)
            with col1:
                st.metric("Average Predicted Demand", f"{avg_demand:,.0f} m³")
            with col2:
                st.metric("Peak Demand", f"{max_demand:,.0f} m³", delta=f"on {max_date}")
            with col3:
                st.metric("High Confidence Predictions", f"{high_conf_pct:.0f}%")
        else:
            st.info("👆 Select a region and click 'Generate Forecast' to see predictions")

# ============================================================================
# TAB 4: BILLING & PAYMENTS
# ============================================================================
with tab4:
    st.header("💰 Billing & Payment Status")
    
    # Payment status overview
    st.subheader("📊 Payment Status Overview")
    
    payment_status = get_data("""
        SELECT 
            BILL_STATUS,
            COUNT(*) AS BILL_COUNT,
            SUM(TOTAL_AMOUNT_SAR) AS TOTAL_AMOUNT
        FROM SIO_DB.DATA.BILLING
        GROUP BY BILL_STATUS
    """)
    
    if not payment_status.empty and PLOTLY_AVAILABLE:
        col1, col2 = st.columns(2)
        
        with col1:
            fig = px.pie(
                payment_status,
                values='BILL_COUNT',
                names='BILL_STATUS',
                title='Bills by Status (Count)',
                color='BILL_STATUS',
                color_discrete_map={'PAID': 'green', 'PENDING': 'orange', 'OVERDUE': 'red'}
            )
            st.plotly_chart(fig, use_container_width=True)
        
        with col2:
            fig = px.pie(
                payment_status,
                values='TOTAL_AMOUNT',
                names='BILL_STATUS',
                title='Bills by Status (Amount SAR)',
                color='BILL_STATUS',
                color_discrete_map={'PAID': 'green', 'PENDING': 'orange', 'OVERDUE': 'red'}
            )
            st.plotly_chart(fig, use_container_width=True)
    
    st.divider()
    
    # Overdue bills
    st.subheader("⚠️ Customers with Overdue Payments")
    
    overdue_bills = get_data("""
        SELECT 
            c.CUSTOMER_NAME,
            r.REGION_NAME,
            c.CUSTOMER_TYPE,
            b.BILLING_MONTH,
            b.TOTAL_AMOUNT_SAR,
            b.DUE_DATE,
            DATEDIFF(day, b.DUE_DATE, CURRENT_DATE()) AS DAYS_OVERDUE
        FROM SIO_DB.DATA.BILLING b
        JOIN SIO_DB.DATA.CUSTOMERS c ON b.CUSTOMER_ID = c.CUSTOMER_ID
        JOIN SIO_DB.DATA.REGIONS r ON c.REGION_ID = r.REGION_ID
        WHERE b.BILL_STATUS = 'OVERDUE'
        ORDER BY DAYS_OVERDUE DESC
        LIMIT 50
    """)
    
    if not overdue_bills.empty:
        # Format data for display (compatible with older Streamlit versions)
        display_df = overdue_bills.copy()
        display_df = display_df.rename(columns={
            "CUSTOMER_NAME": "Customer",
            "REGION_NAME": "Region",
            "CUSTOMER_TYPE": "Type",
            "BILLING_MONTH": "Billing Month",
            "TOTAL_AMOUNT_SAR": "Amount (SAR)",
            "DUE_DATE": "Due Date",
            "DAYS_OVERDUE": "Days Overdue"
        })
        # Format numeric columns - convert to numeric type first
        display_df["Amount (SAR)"] = pd.to_numeric(display_df["Amount (SAR)"], errors='coerce').fillna(0).round(2)
        display_df["Days Overdue"] = pd.to_numeric(display_df["Days Overdue"], errors='coerce').fillna(0).astype(int)
        
        st.dataframe(
            display_df,
            hide_index=True,
            use_container_width=True
        )
        
        # Summary metrics
        total_overdue = overdue_bills['TOTAL_AMOUNT_SAR'].sum()
        avg_days_overdue = overdue_bills['DAYS_OVERDUE'].mean()
        
        col1, col2 = st.columns(2)
        with col1:
            st.metric("Total Overdue Amount", f"{total_overdue:,.2f} SAR")
        with col2:
            st.metric("Average Days Overdue", f"{avg_days_overdue:.0f} days")
    else:
        st.success("✅ No overdue bills! All customers are up to date.")
    
    st.divider()
    
    # Regional payment analysis
    st.subheader("🌍 Regional Payment Analysis")
    
    regional_payments = get_data("""
        SELECT 
            r.REGION_NAME,
            COUNT(DISTINCT CASE WHEN b.BILL_STATUS = 'OVERDUE' THEN b.CUSTOMER_ID END) AS OVERDUE_CUSTOMERS,
            SUM(CASE WHEN b.BILL_STATUS = 'OVERDUE' THEN b.TOTAL_AMOUNT_SAR ELSE 0 END) AS OVERDUE_AMOUNT,
            COUNT(DISTINCT b.CUSTOMER_ID) AS TOTAL_CUSTOMERS
        FROM SIO_DB.DATA.BILLING b
        JOIN SIO_DB.DATA.CUSTOMERS c ON b.CUSTOMER_ID = c.CUSTOMER_ID
        JOIN SIO_DB.DATA.REGIONS r ON c.REGION_ID = r.REGION_ID
        GROUP BY r.REGION_NAME
        ORDER BY OVERDUE_AMOUNT DESC
    """)
    
    if not regional_payments.empty:
        if PLOTLY_AVAILABLE:
            fig = px.bar(
                regional_payments,
                x='REGION_NAME',
                y='OVERDUE_AMOUNT',
                title='Overdue Amounts by Region',
                labels={'OVERDUE_AMOUNT': 'Overdue Amount (SAR)', 'REGION_NAME': 'Region'},
                color='OVERDUE_AMOUNT',
                color_continuous_scale='Reds'
            )
            fig.update_layout(xaxis_tickangle=-45)
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.bar_chart(regional_payments.set_index('REGION_NAME')['OVERDUE_AMOUNT'])

# Footer
st.divider()
st.markdown("""
<div style='text-align: center; color: #666; padding: 20px;'>
    <p>SIO (Saudi Irrigation Organization) - Smart Water Resource Management</p>
    <p>Powered by Snowflake Cortex AI | Built with Streamlit</p>
</div>
""", unsafe_allow_html=True)

