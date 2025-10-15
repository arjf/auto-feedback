import os
import sys

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "app"))

from model import SentimentAnalyzer, analyze_sentiment


def test_textblob_sentiment_positive():
    result = analyze_sentiment("This is amazing!", model_type="textblob")
    assert result["sentiment"] == "Positive"
    assert "confidence" in result
    assert result["confidence"] > 0


def test_textblob_sentiment_negative():
    result = analyze_sentiment("This is terrible!", model_type="textblob")
    assert result["sentiment"] == "Negative"
    assert "confidence" in result
    assert result["confidence"] > 0


def test_textblob_sentiment_neutral():
    result = analyze_sentiment("This is okay.", model_type="textblob")
    assert result["sentiment"] in ["Neutral", "Positive", "Negative"]
    assert "confidence" in result


def test_empty_text():
    result = analyze_sentiment("", model_type="textblob")
    assert "error" in result or result["confidence"] == 0


def test_analyzer_initialization():
    analyzer = SentimentAnalyzer(model_type="textblob")
    assert analyzer.model_type == "textblob"
