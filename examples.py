"""
Example usage of the Sentiment Analysis API
Demonstrates how to use the API programmatically
"""

import requests
import json

# API Configuration
API_URL = "http://localhost:5000"


def test_api_connection():
    """Test if the API is running"""
    try:
        response = requests.get(f"{API_URL}/health", timeout=5)
        if response.status_code == 200:
            print(" API is running and healthy")
            return True
        else:
            print("API returned error status")
            return False
    except requests.exceptions.ConnectionError:
        print("Cannot connect to API. Make sure Flask server is running.")
        print("   Start it with: python app/main.py")
        return False
    except Exception as e:
        print(f"Error: {e}")
        return False


def analyze_single_text(text, model="textblob"):
    """Analyze a single piece of text"""
    print(f"\n{'='*60}")
    print(f"Analyzing: {text[:50]}...")
    print(f"Model: {model}")
    print(f"{'='*60}")

    try:
        response = requests.post(
            f"{API_URL}/analyze", json={"text": text, "model": model}, timeout=30
        )

        if response.status_code == 200:
            result = response.json()
            print(f" Sentiment: {result.get('sentiment')}")
            print(f"   Confidence: {result.get('confidence')}%")
            if "polarity" in result:
                print(f"   Polarity: {result.get('polarity')}")
                print(f"   Subjectivity: {result.get('subjectivity')}")
            print(f"   Model Used: {result.get('model')}")
            return result
        else:
            error = response.json()
            print(f"Error: {error.get('message', 'Unknown error')}")
            return None
    except Exception as e:
        print(f"Error: {e}")
        return None


def analyze_batch(texts, model="textblob"):
    """Analyze multiple texts"""
    print(f"\n{'='*60}")
    print(f"Batch Analysis ({len(texts)} texts)")
    print(f"{'='*60}")

    results = []
    for i, text in enumerate(texts, 1):
        print(f"\n[{i}/{len(texts)}] Analyzing: {text[:40]}...")
        result = analyze_single_text(text, model)
        if result:
            results.append(result)

    return results


def get_statistics():
    """Get sentiment statistics from API"""
    print(f"\n{'='*60}")
    print("Fetching Statistics")
    print(f"{'='*60}")

    try:
        response = requests.get(f"{API_URL}/stats", timeout=5)
        if response.status_code == 200:
            data = response.json()
            stats = data.get("stats", {})

            print(f"\nTotal Analyses: {stats.get('total', 0)}")
            print(
                f"Positive: {stats.get('positive', 0)} ({stats.get('positive_percentage', 0)}%)"
            )
            print(
                f"Negative: {stats.get('negative', 0)} ({stats.get('negative_percentage', 0)}%)"
            )
            print(
                f"Neutral: {stats.get('neutral', 0)} ({stats.get('neutral_percentage', 0)}%)"
            )
            print(f"Average Confidence: {stats.get('average_confidence', 0)}%")

            return stats
        else:
            print("Could not fetch statistics")
            return None
    except Exception as e:
        print(f"Error: {e}")
        return None


def get_history(limit=10):
    """Get analysis history from API"""
    print(f"\n{'='*60}")
    print(f"Fetching History (last {limit} analyses)")
    print(f"{'='*60}")

    try:
        response = requests.get(f"{API_URL}/history?limit={limit}", timeout=5)
        if response.status_code == 200:
            data = response.json()
            history = data.get("history", [])

            print(f"\nTotal Records: {data.get('count', 0)}")
            print(f"\nRecent Analyses:")
            for i, item in enumerate(history[-5:], 1):  # Show last 5
                print(f"\n{i}. {item.get('text', '')[:50]}...")
                print(
                    f"   Sentiment: {item.get('sentiment')} ({item.get('confidence')}%)"
                )
                print(f"   Time: {item.get('timestamp', '')[:19]}")

            return history
        else:
            print("Could not fetch history")
            return None
    except Exception as e:
        print(f"Error: {e}")
        return None


def main():
    """Main example function"""
    print("\n" + "=" * 60)
    print("SENTIMENT ANALYSIS API - EXAMPLE USAGE")
    print("=" * 60)

    # Test API connection
    if not test_api_connection():
        return

    # Example texts
    sample_texts = [
        "I absolutely love this product! It's amazing and works perfectly!",
        "This is terrible. I hate it and want my money back.",
        "It's okay, nothing special but not bad either.",
        "Outstanding customer service! Very helpful and professional.",
        "Disappointed with the quality. Expected much better.",
        "The product arrived on time and works as described.",
    ]

    # Example 1: Analyze single text with TextBlob
    print("\n" + "=" * 60)
    print("EXAMPLE 1: Single Text Analysis (TextBlob)")
    print("=" * 60)
    analyze_single_text(sample_texts[0], model="textblob")

    # Example 2: Analyze single text with Transformers
    print("\n" + "=" * 60)
    print("EXAMPLE 2: Single Text Analysis (Transformers)")
    print("=" * 60)
    analyze_single_text(sample_texts[0], model="transformers")

    # Example 3: Batch analysis
    print("\n" + "=" * 60)
    print("EXAMPLE 3: Batch Analysis")
    print("=" * 60)
    results = analyze_batch(sample_texts[:3], model="textblob")

    # Example 4: Get statistics
    print("\n" + "=" * 60)
    print("EXAMPLE 4: View Statistics")
    print("=" * 60)
    get_statistics()

    # Example 5: Get history
    print("\n" + "=" * 60)
    print("EXAMPLE 5: View History")
    print("=" * 60)
    get_history(limit=10)

    print("\n" + "=" * 60)
    print("Examples completed!")
    print("=" * 60)
    print("\nNext steps:")
    print("1. Open Streamlit dashboard: streamlit run app/dashboard.py")
    print("2. Try the interactive web interface")
    print("3. Explore the API documentation in README.md")
    print("=" * 60 + "\n")


if __name__ == "__main__":
    main()
