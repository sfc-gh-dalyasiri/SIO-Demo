#!/usr/bin/env python3
"""
Test SIO Cortex Agent
Tests the agent's ability to handle different types of queries
"""

import requests
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configuration
SNOWFLAKE_HOST = os.getenv('SNOWFLAKE_HOST', 'your-account.snowflakecomputing.com')
SNOWFLAKE_PAT = os.getenv('SNOWFLAKE_PAT')

# Agent endpoint
url = f"https://{SNOWFLAKE_HOST}/api/v2/databases/SNOWFLAKE_INTELLIGENCE/schemas/AGENTS/agents/SIO_IRRIGATION_AGENT:run"

headers = {
    "Authorization": f"Bearer {SNOWFLAKE_PAT}",
    "Content-Type": "application/json",
    "X-Snowflake-Authorization-Token-Type": "PROGRAMMATIC_ACCESS_TOKEN"
}

def test_query(query, description=""):
    """Send a query to the agent and display the response"""
    print(f"\n{'='*80}")
    print(f"TEST: {description}")
    print(f"Query: {query}")
    print(f"{'='*80}")
    
    payload = {
        "messages": [
            {
                "role": "user",
                "content": [{"type": "text", "text": query}]
            }
        ]
    }
    
    try:
        response = requests.post(url, headers=headers, json=payload, timeout=120)
        
        if response.status_code == 200:
            result = response.json()
            message = result.get('message', {})
            content = message.get('content', [])
            
            # Extract text response
            for item in content:
                if item.get('type') == 'text':
                    print(f"\n✅ Response:\n{item.get('text', '')}")
            
            return True
        else:
            print(f"\n❌ Error {response.status_code}:")
            print(response.text)
            return False
    
    except Exception as e:
        print(f"\n❌ Exception: {str(e)}")
        return False

def main():
    """Run test suite"""
    print("\n" + "="*80)
    print("SIO IRRIGATION AGENT - TEST SUITE")
    print("="*80)
    
    if not SNOWFLAKE_PAT:
        print("\n❌ ERROR: SNOWFLAKE_PAT environment variable not set")
        print("Please set it in your .env file or export it:")
        print("  export SNOWFLAKE_PAT='your_token_here'")
        return
    
    # Test queries
    tests = [
        ("Which customers have unpaid bills?", "Payment Status Query"),
        ("What is the water resource status across all regions?", "Resource Status Query"),
        ("Predict water demand for Riyadh for the next 7 days", "ML Prediction Query"),
        ("Show me regional efficiency analysis", "Efficiency Analysis Query"),
        ("What are the water usage trends in the Eastern Province?", "Regional Usage Query"),
        ("Which regions need water resource optimization?", "Optimization Query")
    ]
    
    results = []
    for query, description in tests:
        success = test_query(query, description)
        results.append((description, success))
    
    # Summary
    print("\n" + "="*80)
    print("TEST SUMMARY")
    print("="*80)
    
    passed = sum(1 for _, success in results if success)
    total = len(results)
    
    for description, success in results:
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"{status}: {description}")
    
    print(f"\nTotal: {passed}/{total} tests passed")
    
    if passed == total:
        print("\n🎉 All tests passed!")
    else:
        print(f"\n⚠️ {total - passed} test(s) failed")

if __name__ == "__main__":
    main()

