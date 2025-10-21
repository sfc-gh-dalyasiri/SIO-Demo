#!/usr/bin/env python3
"""
Generate PDF documents for SIO Knowledge Base
Creates realistic policy, procedure, and guideline documents
"""

from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_RIGHT
import os
from datetime import datetime

# Ensure documents directory exists
os.makedirs('documents', exist_ok=True)

def create_header(doc_title, doc_id):
    """Create document header"""
    styles = getSampleStyleSheet()
    
    # Custom styles
    title_style = ParagraphStyle(
        'CustomTitle',
        parent=styles['Heading1'],
        fontSize=18,
        textColor='#0066cc',
        spaceAfter=12,
        alignment=TA_CENTER
    )
    
    header_style = ParagraphStyle(
        'Header',
        parent=styles['Normal'],
        fontSize=10,
        textColor='#666666',
        alignment=TA_RIGHT
    )
    
    return [
        Paragraph(doc_title, title_style),
        Paragraph(f"Document ID: {doc_id} | Issued: {datetime.now().strftime('%B %Y')}", header_style),
        Spacer(1, 0.5*cm)
    ]

def create_pdf_document(filename, title, doc_id, sections):
    """Create a PDF document with multiple sections"""
    
    pdf_path = f'documents/{filename}'
    doc = SimpleDocTemplate(pdf_path, pagesize=A4,
                           rightMargin=2*cm, leftMargin=2*cm,
                           topMargin=2*cm, bottomMargin=2*cm)
    
    styles = getSampleStyleSheet()
    story = []
    
    # Add header
    story.extend(create_header(title, doc_id))
    
    # Custom styles
    body_style = ParagraphStyle(
        'Body',
        parent=styles['Normal'],
        fontSize=11,
        leading=14,
        alignment=TA_JUSTIFY,
        spaceAfter=12
    )
    
    heading_style = ParagraphStyle(
        'SectionHeading',
        parent=styles['Heading2'],
        fontSize=14,
        textColor='#0066cc',
        spaceAfter=6,
        spaceBefore=12
    )
    
    # Add sections
    for section_title, content in sections:
        if section_title:
            story.append(Paragraph(section_title, heading_style))
        story.append(Paragraph(content, body_style))
        story.append(Spacer(1, 0.3*cm))
    
    # Build PDF
    doc.build(story)
    print(f"  ✅ Created: {filename}")

# ============================================================================
# DOCUMENT 1: Water Billing and Payment Policy
# ============================================================================

def create_billing_policy():
    sections = [
        ("1. Overview", 
         "The Saudi Irrigation Organization (SIO) provides water services to agricultural and industrial customers across the Kingdom. This document outlines our billing structure, payment terms, and customer support policies."),
        
        ("2. Billing Structure",
         "Water consumption is billed monthly based on smart meter readings. The current rate is 0.50 SAR per cubic meter (m³) of water consumed. Additionally, a monthly service fee of 50.00 SAR applies to all active accounts. Bills are generated on the first day of each month for the previous month's consumption."),
        
        ("3. Payment Terms",
         "Payment is due within 45 days of bill generation. Late payments incur a 5% monthly penalty on the outstanding balance. Bills can be paid via bank transfer, online payment through the SIO portal, cash at any SIO service center, or bank check."),
        
        ("4. Payment Extension Requests",
         "Farmers experiencing financial hardship may request payment extensions of up to 60 days. To apply, submit a request through the SIO portal or visit any service center with: valid ID, farm ownership certificate, and a brief explanation. Extensions are reviewed within 5 business days. No penalties apply during approved extension periods."),
        
        ("5. Dispute Resolution",
         "If you believe your bill is incorrect, contact SIO customer service at +966-11-4567890 within 15 days of bill generation. Provide your customer ID, bill reference, and reason for dispute. Meter readings will be re-verified within 7 days. If an error is confirmed, an adjusted bill will be issued with credit for overpayment."),
        
        ("6. Account Suspension Policy",
         "Accounts with bills overdue by more than 90 days will be suspended. Water service will be temporarily discontinued until payment is made. A reconnection fee of 200 SAR applies. To avoid suspension, contact SIO immediately to arrange a payment plan."),
        
        ("7. Customer Support",
         "For billing inquiries, contact SIO customer service Monday-Thursday 8 AM - 4 PM, closed Fridays and Saturdays. Email: billing@sio.gov.sa | Phone: +966-11-4567890 | Portal: www.sio.gov.sa")
    ]
    
    create_pdf_document(
        'billing_payment_policy.pdf',
        'SIO Water Billing and Payment Policy',
        'POL-BILL-001',
        sections
    )

# ============================================================================
# DOCUMENT 2: Water Conservation Guidelines
# ============================================================================

def create_conservation_guide():
    sections = [
        ("Introduction",
         "Water conservation is essential for sustainable agriculture in Saudi Arabia. This guide provides practical techniques to optimize water usage while maintaining crop yields."),
        
        ("Efficient Irrigation Systems",
         "Drip irrigation is the most water-efficient method, reducing consumption by 30-40% compared to flood irrigation. Drip systems deliver water directly to plant roots, minimizing evaporation. SIO subsidizes up to 70% of drip irrigation installation costs (maximum 50,000 SAR per farm). Sprinkler systems are suitable for larger areas and save 15-25% water compared to traditional methods."),
        
        ("Optimal Watering Schedule",
         "Water during cooler hours to reduce evaporation: 5-7 AM or 7-9 PM. Avoid watering during peak heat (12-4 PM) when evaporation rates exceed 60%. Adjust frequency based on season: daily in summer, every 2-3 days in spring/fall, weekly in winter. Monitor soil moisture before watering."),
        
        ("Soil Management Techniques",
         "Apply organic mulch to reduce evaporation by up to 30%. Mulch also improves soil health and reduces weed growth. Implement contour plowing to prevent water runoff. Add compost to improve soil water retention. Test soil moisture regularly using sensors or manual testing."),
        
        ("Crop Selection",
         "Choose water-efficient crop varieties suited to Saudi climate. Recommended drought-resistant crops: date palms (traditional), olive trees, pomegranates, and certain wheat varieties. Avoid water-intensive crops like rice and cotton. SIO provides free consultations on optimal crop selection for your region."),
        
        ("Leak Detection and Prevention",
         "Regular maintenance prevents water waste. Check irrigation pipes weekly for leaks. SIO smart meters alert you to unusual consumption patterns indicating possible leaks. Small leaks can waste 100-500 m³ per month. Report meter anomalies to SIO technical support immediately."),
        
        ("SIO Support Programs",
         "SIO offers free training workshops on water-efficient farming, technical consultations for system design, mobile app for real-time usage monitoring, and subsidies for efficiency upgrades. Contact your regional SIO office for more information.")
    ]
    
    create_pdf_document(
        'water_conservation_guidelines.pdf',
        'Water Conservation Best Practices for Saudi Farmers',
        'GUIDE-CONS-001',
        sections
    )

# ============================================================================
# DOCUMENT 3: Subsidy Programs Guide
# ============================================================================

def create_subsidy_guide():
    sections = [
        ("Available Subsidies",
         "The Saudi Irrigation Organization offers multiple financial support programs to encourage water-efficient agriculture and sustainable farming practices."),
        
        ("1. Irrigation Efficiency Subsidy",
         "SIO subsidizes up to 70% of costs for farmers upgrading to efficient irrigation systems. Eligible systems include drip irrigation, sprinkler systems, and smart irrigation controllers. Maximum subsidy: 50,000 SAR per farm. Minimum farm size: 5 hectares. Limited to one subsidy per farm every 5 years."),
        
        ("Application Process - Irrigation Subsidy",
         "Step 1: Obtain quotes from SIO-approved irrigation suppliers. Step 2: Submit online application at sio.gov.sa/subsidies with farm ownership certificate and system quote. Step 3: Receive approval notification within 15 business days. Step 4: Install system within 90 days of approval. Step 5: Submit installation certificate and photos. Step 6: Receive reimbursement via bank transfer within 30 days."),
        
        ("2. Crop Diversification Support",
         "Financial support for farmers transitioning to water-efficient crops. Drought-resistant varieties: up to 20,000 SAR. Organic farming transition: up to 25,000 SAR. Greenhouse installation: 60% cost subsidy (max 100,000 SAR). Eligibility: minimum 3 hectares, active SIO account in good standing, minimum 2 years farming experience."),
        
        ("3. Smart Technology Adoption",
         "Subsidies for adopting smart farming technology: soil moisture sensors (80% subsidy, max 10,000 SAR), weather stations (70% subsidy, max 15,000 SAR), automated irrigation controllers (75% subsidy, max 12,000 SAR). Installation and training included. Technical support provided for first year."),
        
        ("4. Small Farmer Support Program",
         "Special program for farms under 10 hectares. Higher subsidy rates: up to 85% for irrigation upgrades. Priority processing for applications. Free technical consultations. Flexible payment terms for customer portion. Dedicated support hotline: +966-11-4567899."),
        
        ("Required Documentation",
         "All subsidy applications require: valid Saudi ID or business license, farm ownership certificate or long-term lease (minimum 5 years remaining), SIO customer account in good standing, detailed project plan with quotes, recent farm photos, and bank account information for reimbursement."),
        
        ("Contact Information",
         "Subsidy inquiries: subsidies@sio.gov.sa | Phone: +966-11-4567895 | Visit your regional SIO office for in-person consultations. Office hours: Sunday-Thursday 8 AM - 3 PM.")
    ]
    
    create_pdf_document(
        'subsidy_programs_guide.pdf',
        'SIO Financial Support and Subsidy Programs',
        'GUIDE-SUB-001',
        sections
    )

# ============================================================================
# DOCUMENT 4: Emergency Protocols
# ============================================================================

def create_emergency_protocols():
    sections = [
        ("Purpose",
         "This document outlines SIO's protocols during water resource optimization periods to ensure fair distribution and sustainable usage across all regions."),
        
        ("Resource Optimization Stages",
         "SIO implements a tiered response system based on regional water source capacity levels. Stage 1 (Green): 50-100% capacity - normal operations. Stage 2 (Yellow): 40-50% capacity - voluntary conservation encouraged. Stage 3 (Orange): 30-40% capacity - industrial restrictions. Stage 4 (Red): below 30% capacity - mandatory rationing."),
        
        ("Stage 1: Normal Operations",
         "All customers receive standard water allocation. No restrictions apply. SIO encourages best practices and efficient usage. Regular monitoring and reporting continues. Educational campaigns on water conservation."),
        
        ("Stage 2: Voluntary Conservation",
         "SIO requests voluntary 10% reduction in consumption. Conservation tips distributed via SMS and email. Customers meeting conservation targets receive recognition and priority for future subsidies. No penalties for non-compliance. Duration typically 2-4 weeks based on rainfall and source replenishment."),
        
        ("Stage 3: Industrial Restrictions",
         "Industrial and large commercial users limited to 70% of average consumption. Essential agricultural crops maintain full allocation. Industrial users receive 7-day advance notice. Violations subject to temporary service suspension. Small farms (under 20 hectares) exempt from restrictions."),
        
        ("Stage 4: Mandatory Rationing",
         "Rarely invoked (last occurrence: 2019). All customers limited to essential needs only. Priority allocation: food security crops (wheat, dates, vegetables). Scheduled distribution on rotation basis. Daily limits enforced via smart meter controls. Government support programs activated. Emergency water deliveries for critical needs."),
        
        ("Communication Protocols",
         "SIO provides 48-hour minimum advance notice before implementing any stage change. Notifications sent via: SMS to registered mobile numbers, email to account addresses, SIO mobile app push notifications, regional office announcements, and website updates. Customer service hotline remains available 24/7 during emergency periods."),
        
        ("Rights and Responsibilities",
         "Customers have the right to: advance notification, fair allocation based on farm size and crop type, appeal decisions through regional SIO office, and emergency support for crop protection. Responsibilities include: compliance with restrictions, accurate usage reporting, and cooperation with SIO monitoring."),
        
        ("Historical Context",
         "SIO's emergency protocols have successfully managed resource challenges while protecting agricultural livelihoods. Average Stage 2 duration: 18 days. Stage 3 invoked 3 times in past 10 years. Stage 4 last used in 2019 for 12 days. SIO's proactive approach has prevented severe crises.")
    ]
    
    create_pdf_document(
        'emergency_water_protocols.pdf',
        'SIO Water Resource Optimization Emergency Protocols',
        'POL-EMERG-001',
        sections
    )

# ============================================================================
# DOCUMENT 5: Technical Support Guide
# ============================================================================

def create_technical_support():
    sections = [
        ("SIO Technical Support Services",
         "SIO provides comprehensive technical support for all customers to ensure optimal water system performance and accurate billing."),
        
        ("Smart Meter Troubleshooting",
         "Common issues and solutions: NO DISPLAY - check solar panel alignment and clean surface, verify battery compartment sealed. ERRATIC READINGS - inspect meter for debris or damage, check water pressure (should be 2-4 bar). HIGH UNEXPLAINED USAGE - check entire irrigation system for leaks, verify no unauthorized connections. For persistent issues, contact SIO technical support."),
        
        ("Leak Detection Service",
         "SIO offers free leak detection assistance. Your smart meter provides 24/7 monitoring and sends automatic alerts for unusual consumption patterns. Leak indicators: sudden usage spikes, continuous flow during non-irrigation hours, gradual increase in baseline consumption. SIO technicians available for on-site inspection within 48 hours of request."),
        
        ("Meter Calibration",
         "All meters calibrated annually by SIO-certified technicians. Calibration ensures accurate billing and leak detection. Customers notified 2 weeks before scheduled calibration. Process takes 30-45 minutes. No service interruption. Free of charge. Request early calibration if accuracy concerns arise."),
        
        ("Mobile App Support",
         "The SIO Mobile App provides real-time access to your water data. Features: live usage dashboard, bill payment, usage alerts and notifications, historical consumption graphs, efficiency tips, support ticket submission. Download from App Store or Google Play. Login using customer ID and registered mobile number. App support: appsupport@sio.gov.sa"),
        
        ("System Upgrade Consultation",
         "Free consultations available for planning irrigation system upgrades. SIO technical advisors assess your current system, recommend improvements, estimate water savings, provide cost analysis including subsidies, and assist with supplier selection. Schedule consultation via portal or phone +966-11-4567892."),
        
        ("Emergency Support",
         "24/7 emergency hotline for critical issues: major leaks, meter malfunctions affecting billing, system failures during critical irrigation periods. Emergency number: +966-11-4567890. Response time: urgent issues within 4 hours, non-urgent within 24 hours. Emergency support free for all customers."),
        
        ("Contact Information",
         "Technical Support: +966-11-4567892 | Email: techsupport@sio.gov.sa | Office Hours: Sunday-Thursday 7 AM - 5 PM | Emergency Hotline: +966-11-4567890 (24/7)")
    ]
    
    create_pdf_document(
        'technical_support_guide.pdf',
        'SIO Technical Support and Maintenance Guide',
        'GUIDE-TECH-001',
        sections
    )

# ============================================================================
# DOCUMENT 6: Regional Water Allocation Policy
# ============================================================================

def create_allocation_policy():
    sections = [
        ("Allocation Principles",
         "SIO's water allocation policy ensures equitable distribution based on regional capacity, agricultural needs, and sustainability considerations. Allocations reviewed quarterly by the SIO board."),
        
        ("Regional Capacities",
         "Riyadh Region: 50 million m³ total capacity, serves 15,000 km² agricultural area. Makkah Region: 40 million m³, serves 8,000 km². Eastern Province: 45 million m³, serves 12,000 km². Qassim Region: 35 million m³, serves 20,000 km². Other regions: 22-30 million m³ each. Total Kingdom capacity: 267 million m³."),
        
        ("Priority Allocation System",
         "Tier 1: Essential food security crops (wheat, dates, vegetables) - guaranteed full allocation. Tier 2: Traditional agricultural crops (barley, alfalfa) - 90% allocation during normal periods. Tier 3: Industrial users and export crops - 80% allocation, subject to optimization restrictions. Tier 4: Ornamental and recreational - lowest priority, first restricted during optimization."),
        
        ("Farm Size Considerations",
         "Small farms (under 10 hectares): protected allocation, last to face restrictions. Medium farms (10-50 hectares): standard allocation, proportional restrictions if needed. Large farms (over 50 hectares): expected to lead conservation efforts, implement efficiency measures. Industrial users (over 100 hectares): quarterly efficiency audits required."),
        
        ("Seasonal Adjustments",
         "Allocations adjusted seasonally to match crop water requirements. Summer (June-September): 150% of baseline allocation. Spring/Fall (March-May, October): 100% baseline. Winter (November-February): 70% baseline. Dates and citrus receive year-round priority. Adjustments announced 30 days in advance."),
        
        ("New Allocation Requests",
         "Existing customers may request increased allocation for expansion. Requirements: demonstrate current efficient usage (under regional average), submit expansion plan with crop details, environmental impact assessment for large increases (over 1,000 m³/month), and payment of 1,000 SAR application fee (refunded if approved). Processing time: 30-45 days."),
        
        ("Transparency and Reporting",
         "SIO publishes quarterly regional allocation reports showing: total capacity, current utilization, allocation by customer type, efficiency metrics, and conservation achievements. Reports available at sio.gov.sa/reports. Customers can access their allocation history and benchmarks via the SIO portal."),
        
        ("Appeals Process",
         "Customers may appeal allocation decisions within 14 days. Submit appeal to regional SIO director with: account information, reason for appeal, supporting documentation. Appeals reviewed by SIO technical committee. Decision provided within 21 days. No fees for appeals.")
    ]
    
    create_pdf_document(
        'water_allocation_policy.pdf',
        'SIO Regional Water Allocation and Management Policy',
        'POL-ALLOC-001',
        sections
    )

# ============================================================================
# DOCUMENT 7: Meter Installation and Maintenance
# ============================================================================

def create_meter_guide():
    sections = [
        ("Smart Meter Overview",
         "SIO smart meters provide accurate water measurement and real-time consumption monitoring. All new connections receive smart meters at no cost. Existing customers can upgrade free of charge."),
        
        ("Installation Process",
         "New customer installation: completed within 10 business days of account approval. Schedule installation via SIO portal or phone. Technician arrives with meter and installation equipment. Installation takes 2-3 hours. Meter activated immediately. Customer receives SMS confirmation and app access credentials. First month prorated based on installation date."),
        
        ("Meter Features",
         "SIO smart meters include: real-time flow measurement (±2% accuracy), automatic daily readings transmitted to SIO, leak detection alerts (sensitivity: 10 liters/hour continuous flow), tamper detection and alerts, solar-powered with 10-year battery backup, LCD display showing current flow rate, and IP67 waterproof rating."),
        
        ("Maintenance Schedule",
         "Annual calibration: SIO technician verifies accuracy against certified reference standard. Every 3 years: comprehensive inspection including seal verification, communication module testing, and battery health check. Every 5 years: major service including firmware updates and component replacement if needed. All maintenance scheduled via SMS notification."),
        
        ("Customer Responsibilities",
         "Keep meter accessible for SIO technicians. Protect meter from physical damage and extreme weather when possible. Do not attempt to open or modify meter (violations subject to 5,000 SAR fine). Report damage or malfunction within 24 hours. Clear vegetation around meter quarterly. Do not paint or cover meter display."),
        
        ("Meter Accuracy Guarantee",
         "SIO guarantees meter accuracy within ±2% for first 5 years, ±3% for years 6-10. If accuracy testing shows error exceeding guarantee, customer entitled to bill adjustment for up to 6 months retroactive. Request accuracy test any time via SIO portal. Testing completed within 10 days. No charge for test if error found, 200 SAR fee if meter within specification."),
        
        ("Replacement and Upgrades",
         "Meters replaced free if: damaged by natural causes, accuracy out of specification, technology obsolete (SIO initiative), or customer requests newer model (300 SAR upgrade fee). Replacement scheduled within 5 business days. Usage estimated during replacement period based on historical average."),
        
        ("Support Contact",
         "Meter technical support: +966-11-4567892 | Email: meters@sio.gov.sa | Emergency (leaks, major malfunctions): +966-11-4567890 (24/7)")
    ]
    
    create_pdf_document(
        'meter_installation_maintenance.pdf',
        'SIO Smart Water Meter Installation and Maintenance Guide',
        'GUIDE-METER-001',
        sections
    )

# ============================================================================
# DOCUMENT 8: Seasonal Planning Guide
# ============================================================================

def create_seasonal_planning():
    sections = [
        ("Introduction",
         "Effective seasonal planning optimizes water usage and crop yields. This guide helps farmers plan irrigation schedules aligned with Saudi Arabia's climate patterns."),
        
        ("Saudi Agricultural Seasons",
         "Summer (June-September): Peak water demand period. Average temperatures 35-45°C. Minimal rainfall. High evaporation rates. Critical irrigation period for summer crops and date palms. Winter (December-February): Low water demand. Temperatures 15-25°C. Occasional rainfall. Opportunity for system maintenance. Spring/Fall (March-May, October-November): Moderate demand. Ideal planting seasons. Variable weather requires flexible irrigation."),
        
        ("Summer Strategy (June-September)",
         "Expect 50% higher water consumption than annual average. Increase irrigation frequency to compensate for high evaporation. Water twice daily: early morning (5-7 AM) and evening (7-9 PM). Monitor soil moisture closely. Consider shade netting for sensitive crops. Prepare backup water sources. SIO typically allocates 150% of baseline during this period."),
        
        ("Winter Strategy (December-February)",
         "Reduce irrigation to 70% of baseline. Take advantage of any rainfall (typical: 20-40 mm total). Ideal time for: system maintenance and repairs, soil preparation and enrichment, planning crop rotation, and inspecting irrigation infrastructure. SIO offers off-season training workshops during this period."),
        
        ("Crop Calendar Recommendations",
         "Dates: year-round irrigation, peak demand May-September. Wheat: plant October-November, harvest March-April, moderate water needs. Vegetables: winter planting (October-December) recommended for lower water usage. Alfalfa: plant year-round, requires consistent moisture. Citrus: year-round irrigation, peak during fruit development."),
        
        ("Weather Monitoring",
         "Use SIO mobile app for regional weather forecasts updated daily. Key factors: temperature (affects evaporation rate), rainfall (may reduce irrigation needs), humidity (lower humidity = higher water loss), and wind speed (high wind increases evaporation). App provides irrigation recommendations based on 7-day forecast."),
        
        ("Water Budget Planning",
         "Calculate annual water budget: summer months (40% of annual usage), spring/fall months (35%), winter months (25%). Example: 100-hectare farm averaging 5,000 m³/month baseline: Budget 7,500 m³/month summer, 5,000 m³/month spring/fall, 3,500 m³/month winter. Total annual: 66,000 m³. Build 10% buffer for unexpected needs."),
        
        ("SIO Support",
         "Free seasonal planning consultations available. Schedule via sio.gov.sa or call +966-11-4567895. Regional agricultural advisors assist with crop selection, irrigation scheduling, and efficiency optimization. Seasonal workshops held quarterly in each region.")
    ]
    
    create_pdf_document(
        'seasonal_planning_guide.pdf',
        'SIO Seasonal Water Management and Crop Planning Guide',
        'GUIDE-SEASON-001',
        sections
    )

# ============================================================================
# DOCUMENT 9: SIO Customer Rights and Responsibilities
# ============================================================================

def create_rights_responsibilities():
    sections = [
        ("Customer Rights",
         "As an SIO customer, you are entitled to: reliable water supply subject to availability, accurate metering and fair billing, 48-hour notice before service modifications, transparent pricing and allocation policies, access to your consumption data, support for efficiency improvements, subsidy programs, dispute resolution process, and protection of personal information."),
        
        ("Right to Information",
         "Customers entitled to: monthly usage reports and billing statements, historical consumption data (up to 7 years), regional water status updates, advance notice of policy changes (minimum 30 days), explanation of any unusual charges, and access to SIO board meeting minutes (published quarterly)."),
        
        ("Right to Support",
         "Free access to: technical support for meter and system issues, agricultural advisory services, seasonal planning consultations, efficiency improvement recommendations, subsidy application assistance, and dispute mediation services. Support available in Arabic and English."),
        
        ("Customer Responsibilities",
         "Customers must: pay bills on time or request extensions, maintain meter accessibility and protection, report usage anomalies and leaks promptly, comply with conservation measures during optimization periods, use water only for registered purposes, prevent water waste through proper maintenance, and provide accurate information in all communications with SIO."),
        
        ("Compliance and Enforcement",
         "SIO monitors water usage patterns for compliance. Violations include: unauthorized connections, meter tampering, water resale or transfer, exceeding allocation limits during restrictions, and commercial use on residential accounts. Penalties range from warnings to service suspension. Repeat violations: account termination and legal action."),
        
        ("Data Privacy",
         "SIO protects customer data per Kingdom data protection laws. Usage data used only for billing, system optimization, and customer service. Personal information not shared with third parties except as required by law. Customers may request data deletion (billing history retained per legal requirements). Privacy policy: sio.gov.sa/privacy"),
        
        ("Feedback and Complaints",
         "SIO welcomes customer feedback. Submit via: online portal (sio.gov.sa/feedback), phone hotline (+966-11-4567890), email (feedback@sio.gov.sa), or in-person at any regional office. All feedback reviewed within 5 business days. Complex issues escalated to management. Quarterly satisfaction surveys help improve service quality.")
    ]
    
    create_pdf_document(
        'customer_rights_responsibilities.pdf',
        'SIO Customer Rights and Responsibilities Charter',
        'POL-RIGHTS-001',
        sections
    )

# ============================================================================
# DOCUMENT 10: FAQ Quick Reference
# ============================================================================

def create_faq():
    sections = [
        ("Frequently Asked Questions",
         "Quick answers to common SIO customer inquiries."),
        
        ("Q1: How is my water bill calculated?",
         "A: Your bill = (Water Usage in m³ × 0.50 SAR) + 50 SAR monthly service fee. Example: 10,000 m³ usage = (10,000 × 0.50) + 50 = 5,050 SAR total."),
        
        ("Q2: What payment methods do you accept?",
         "A: Bank transfer (IBAN: SA1234567890123456789), online via sio.gov.sa/pay, cash at SIO service centers (before 3 PM), or bank check (3-5 days processing)."),
        
        ("Q3: Can I get a payment extension?",
         "A: Yes. Apply via SIO portal with farm ownership certificate and explanation. Extensions up to 60 days available. No penalties during approved extensions. Approval within 5 days."),
        
        ("Q4: How do I check my water usage?",
         "A: Use SIO mobile app for real-time data, login to sio.gov.sa portal, check meter LCD display, or call +966-11-4567890 for latest reading."),
        
        ("Q5: What subsidies are available?",
         "A: Drip irrigation (70% subsidy, max 50,000 SAR), crop diversification (up to 25,000 SAR), smart technology (75-85% subsidy), small farmer program (higher rates). Apply at sio.gov.sa/subsidies."),
        
        ("Q6: How do I report a leak?",
         "A: Call emergency hotline +966-11-4567890 immediately. Major leaks: technician within 4 hours. Your smart meter may auto-alert SIO. Check mobile app for leak warnings."),
        
        ("Q7: Can I install a second meter?",
         "A: Yes. First meter free. Additional meters: 800 SAR installation fee. Submit request via portal. Installation within 15 days. Separate billing for each meter."),
        
        ("Q8: What crops use least water?",
         "A: Drought-resistant options: date palms (traditional, efficient), olives, pomegranates, certain wheat varieties. SIO agricultural advisors provide free crop selection consultations."),
        
        ("Q9: How do I upgrade to drip irrigation?",
         "A: Get quotes from SIO-approved suppliers, apply for 70% subsidy online, receive approval (15 days), install system (90 days), submit completion certificate, receive reimbursement (30 days)."),
        
        ("Q10: What if I disagree with my bill?",
         "A: Contact customer service within 15 days with: customer ID, bill reference, and concern details. Meter re-verification within 7 days. If error confirmed, adjusted bill issued with credit."),
        
        ("More Questions?",
         "Contact SIO Customer Service: +966-11-4567890 | Email: support@sio.gov.sa | Portal: sio.gov.sa/support | Visit any regional office Sunday-Thursday 8 AM - 3 PM")
    ]
    
    create_pdf_document(
        'faq_quick_reference.pdf',
        'SIO Frequently Asked Questions - Quick Reference',
        'FAQ-001',
        sections
    )

# ============================================================================
# MAIN EXECUTION
# ============================================================================

def main():
    print("📄 Generating SIO Knowledge Base PDF Documents...")
    print()
    
    create_billing_policy()
    create_conservation_guide()
    create_subsidy_guide()
    create_emergency_protocols()
    create_technical_support()
    create_allocation_policy()
    create_faq()
    
    print()
    print("✅ PDF generation complete!")
    print(f"   7 documents created in 'documents/' directory")
    print()
    print("Next steps:")
    print("  1. Upload PDFs to Snowflake stage")
    print("  2. Parse with SNOWFLAKE.CORTEX.PARSE_DOCUMENT")
    print("  3. Create Cortex Search service")
    print("  4. Add to SIO agent")

if __name__ == "__main__":
    main()

