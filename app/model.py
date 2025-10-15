"""
Sentiment Analysis Model Module
Supports both TextBlob and Hugging Face transformers for sentiment analysis
"""

from textblob import TextBlob
from typing import Dict, Literal
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Try to import transformers for advanced sentiment analysis
try:
    from transformers import pipeline

    TRANSFORMERS_AVAILABLE = True
    logger.info("Transformers library loaded successfully")
except ImportError:
    TRANSFORMERS_AVAILABLE = False
    logger.warning("Transformers library not available, using TextBlob only")


class SentimentAnalyzer:
    """Sentiment analysis using TextBlob and optionally Hugging Face transformers"""

    def __init__(self, model_type: Literal["textblob", "transformers"] = "textblob"):
        """
        Initialize sentiment analyzer

        Args:
            model_type: Either 'textblob' or 'transformers'
        """
        self.model_type = model_type
        self.transformer_model = None

        if model_type == "transformers":
            if TRANSFORMERS_AVAILABLE:
                try:
                    logger.info("Loading Hugging Face sentiment analysis pipeline...")
                    self.transformer_model = pipeline(
                        "sentiment-analysis",
                        model="distilbert-base-uncased-finetuned-sst-2-english",
                    )
                    logger.info("Transformer model loaded successfully")
                except Exception as e:
                    logger.error(f"Error loading transformer model: {e}")
                    logger.info("Falling back to TextBlob")
                    self.model_type = "textblob"
            else:
                logger.warning("Transformers not available, using TextBlob")
                self.model_type = "textblob"

    def analyze_with_textblob(self, text: str) -> Dict[str, any]:
        """
        Analyze sentiment using TextBlob

        Args:
            text: Input text to analyze

        Returns:
            Dictionary with sentiment, polarity, subjectivity, and confidence
        """
        blob = TextBlob(text)
        polarity = blob.sentiment.polarity
        subjectivity = blob.sentiment.subjectivity

        # Classify sentiment based on polarity
        if polarity > 0.1:
            sentiment = "Positive"
            confidence = min(polarity * 100, 100)
        elif polarity < -0.1:
            sentiment = "Negative"
            confidence = min(abs(polarity) * 100, 100)
        else:
            sentiment = "Neutral"
            confidence = 100 - (abs(polarity) * 100)

        return {
            "sentiment": sentiment,
            "polarity": round(polarity, 3),
            "subjectivity": round(subjectivity, 3),
            "confidence": round(confidence, 2),
            "model": "TextBlob",
        }

    def analyze_with_transformers(self, text: str) -> Dict[str, any]:
        """
        Analyze sentiment using Hugging Face transformers

        Args:
            text: Input text to analyze

        Returns:
            Dictionary with sentiment, score, and confidence
        """
        if not self.transformer_model:
            logger.warning("Transformer model not available, falling back to TextBlob")
            return self.analyze_with_textblob(text)

        try:
            # Truncate text if too long (transformers have token limits)
            max_length = 512
            if len(text.split()) > max_length:
                text = " ".join(text.split()[:max_length])

            result = self.transformer_model(text)[0]

            # Map transformer labels to our sentiment categories
            label = result["label"]
            score = result["score"]

            if label == "POSITIVE":
                sentiment = "Positive"
            elif label == "NEGATIVE":
                sentiment = "Negative"
            else:
                sentiment = "Neutral"

            return {
                "sentiment": sentiment,
                "confidence": round(score * 100, 2),
                "score": round(score, 3),
                "model": "DistilBERT",
            }
        except Exception as e:
            logger.error(f"Error in transformer analysis: {e}")
            logger.info("Falling back to TextBlob")
            return self.analyze_with_textblob(text)

    def analyze(self, text: str) -> Dict[str, any]:
        """
        Analyze sentiment using the configured model

        Args:
            text: Input text to analyze

        Returns:
            Dictionary with sentiment analysis results
        """
        if not text or not text.strip():
            return {
                "error": "Empty text provided",
                "sentiment": "Neutral",
                "confidence": 0,
            }

        if self.model_type == "transformers":
            return self.analyze_with_transformers(text)
        else:
            return self.analyze_with_textblob(text)


# Create default analyzer instance
default_analyzer = SentimentAnalyzer(model_type="textblob")


def analyze_sentiment(text: str, model_type: str = "textblob") -> Dict[str, any]:
    """
    Convenience function for sentiment analysis

    Args:
        text: Text to analyze
        model_type: Either 'textblob' or 'transformers'

    Returns:
        Sentiment analysis results
    """
    analyzer = SentimentAnalyzer(model_type=model_type)
    return analyzer.analyze(text)


if __name__ == "__main__":
    # Test the sentiment analyzer
    test_texts = [
        "I absolutely love this product! It's amazing and works perfectly!",
        "This is terrible. I hate it and want my money back.",
        "It's okay, nothing special but not bad either.",
        "The customer service was excellent and very helpful!",
    ]

    print("Testing TextBlob:")
    print("-" * 60)
    for text in test_texts:
        result = analyze_sentiment(text, model_type="textblob")
        print(f"Text: {text}")
        print(f"Result: {result}")
        print()

    if TRANSFORMERS_AVAILABLE:
        print("\nTesting Transformers:")
        print("-" * 60)
        for text in test_texts:
            result = analyze_sentiment(text, model_type="transformers")
            print(f"Text: {text}")
            print(f"Result: {result}")
            print()
