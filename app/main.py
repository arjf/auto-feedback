"""
Flask API for Sentiment Analysis
Provides REST endpoints for analyzing feedback text
"""

import logging
from datetime import datetime

from flask import Flask, jsonify, request
from flask_cors import CORS
from model import analyze_sentiment

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Store analysis history (in production, use a database)
analysis_history = []


@app.route("/", methods=["GET"])
def home():
    """Home endpoint with API information"""
    return jsonify(
        {
            "message": "Sentiment Analysis API",
            "version": "1.0.0",
            "endpoints": {
                "/analyze": "POST - Analyze sentiment of feedback text",
                "/history": "GET - Get analysis history",
                "/stats": "GET - Get sentiment statistics",
                "/health": "GET - Health check",
            },
        }
    )


@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint"""
    return jsonify({"status": "healthy", "timestamp": datetime.now().isoformat()})


@app.route("/analyze", methods=["POST"])
def analyze():
    """
    Analyze sentiment of provided text

    Expected JSON payload:
    {
        "text": "Your feedback text here",
        "model": "textblob" (optional, defaults to "textblob")
    }

    Returns:
    {
        "text": "original text",
        "sentiment": "Positive/Negative/Neutral",
        "confidence": 85.5,
        "model": "TextBlob",
        "timestamp": "2025-10-06T..."
    }
    """
    try:
        # Get JSON data from request
        data = request.get_json()

        if not data:
            return (
                jsonify(
                    {
                        "error": "No JSON data provided",
                        "message": "Please send JSON data with 'text' field",
                    }
                ),
                400,
            )

        # Extract text from request
        text = data.get("text", "").strip()
        model_type = data.get("model", "textblob").lower()

        # Validate text
        if not text:
            return (
                jsonify(
                    {
                        "error": "Empty text provided",
                        "message": "Please provide text to analyze",
                    }
                ),
                400,
            )

        # Validate model type
        if model_type not in ["textblob", "transformers"]:
            model_type = "textblob"

        # Perform sentiment analysis
        logger.info(f"Analyzing text with {model_type}: {text[:50]}...")
        result = analyze_sentiment(text, model_type=model_type)

        # Add metadata
        result["text"] = text
        result["timestamp"] = datetime.now().isoformat()

        # Store in history
        analysis_history.append(
            {
                "text": text[:100],  # Store first 100 chars
                "sentiment": result.get("sentiment"),
                "confidence": result.get("confidence"),
                "timestamp": result["timestamp"],
            }
        )

        # Keep only last 100 analyses
        if len(analysis_history) > 100:
            analysis_history.pop(0)

        logger.info(
            f"Analysis complete: {result.get('sentiment')} ({result.get('confidence')}%)"
        )

        return jsonify(result), 200

    except Exception as e:
        logger.error(f"Error in analyze endpoint: {str(e)}")
        return jsonify({"error": "Internal server error", "message": str(e)}), 500


@app.route("/history", methods=["GET"])
def history():
    """Get analysis history"""
    try:
        limit = request.args.get("limit", 50, type=int)
        limit = min(limit, 100)  # Max 100 records

        return (
            jsonify(
                {"count": len(analysis_history), "history": analysis_history[-limit:]}
            ),
            200,
        )

    except Exception as e:
        logger.error(f"Error in history endpoint: {str(e)}")
        return jsonify({"error": "Internal server error", "message": str(e)}), 500


@app.route("/stats", methods=["GET"])
def stats():
    """Get sentiment statistics from analysis history"""
    try:
        if not analysis_history:
            return (
                jsonify(
                    {
                        "message": "No analysis history available",
                        "stats": {
                            "total": 0,
                            "positive": 0,
                            "negative": 0,
                            "neutral": 0,
                        },
                    }
                ),
                200,
            )

        # Calculate statistics
        total = len(analysis_history)
        positive = sum(
            1 for item in analysis_history if item.get("sentiment") == "Positive"
        )
        negative = sum(
            1 for item in analysis_history if item.get("sentiment") == "Negative"
        )
        neutral = sum(
            1 for item in analysis_history if item.get("sentiment") == "Neutral"
        )

        avg_confidence = (
            sum(item.get("confidence", 0) for item in analysis_history) / total
        )

        return (
            jsonify(
                {
                    "stats": {
                        "total": total,
                        "positive": positive,
                        "negative": negative,
                        "neutral": neutral,
                        "positive_percentage": round((positive / total) * 100, 2),
                        "negative_percentage": round((negative / total) * 100, 2),
                        "neutral_percentage": round((neutral / total) * 100, 2),
                        "average_confidence": round(avg_confidence, 2),
                    }
                }
            ),
            200,
        )

    except Exception as e:
        logger.error(f"Error in stats endpoint: {str(e)}")
        return jsonify({"error": "Internal server error", "message": str(e)}), 500


@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    return (
        jsonify(
            {"error": "Not found", "message": "The requested endpoint does not exist"}
        ),
        404,
    )


@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors"""
    return (
        jsonify(
            {
                "error": "Internal server error",
                "message": "An unexpected error occurred",
            }
        ),
        500,
    )


if __name__ == "__main__":
    logger.info("Starting Flask API server...")
    logger.info("API available at http://localhost:5000")
    logger.info("POST to /analyze to analyze sentiment")
    app.run(host="0.0.0.0", port=5000, debug=True)
