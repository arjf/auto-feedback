"""
Streamlit Dashboard for Sentiment Analysis
Interactive web interface for analyzing feedback sentiment
"""

import streamlit as st
import requests
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime
import time

# Configure page
st.set_page_config(
    page_title="AI Sentiment Analysis Dashboard",
    page_icon="",
    layout="wide",
    initial_sidebar_state="expanded",
)

# API configuration
API_URL = "http://localhost:5000"

# Initialize session state
if "analysis_results" not in st.session_state:
    st.session_state.analysis_results = []
if "sentiment_counts" not in st.session_state:
    st.session_state.sentiment_counts = {"Positive": 0, "Negative": 0, "Neutral": 0}


def analyze_text_api(text, model_type="textblob"):
    """Call the Flask API to analyze sentiment"""
    try:
        response = requests.post(
            f"{API_URL}/analyze", json={"text": text, "model": model_type}, timeout=10
        )
        if response.status_code == 200:
            return response.json()
        else:
            return {"error": response.json().get("message", "Unknown error")}
    except requests.exceptions.ConnectionError:
        return {
            "error": "Cannot connect to API. Make sure Flask server is running on port 5000."
        }
    except Exception as e:
        return {"error": str(e)}


def get_sentiment_color(sentiment):
    """Get color for sentiment"""
    colors = {"Positive": "#28a745", "Negative": "#dc3545", "Neutral": "#ffc107"}
    return colors.get(sentiment, "#6c757d")


def get_sentiment_emoji(sentiment):
    """Get emoji for sentiment"""
    emojis = {"Positive": "", "Negative": "", "Neutral": ""}
    return emojis.get(sentiment, "")


# Main dashboard
st.title("AI-Powered Sentiment Analysis Dashboard")
st.markdown("Analyze customer feedback and reviews with AI-powered sentiment detection")

# Sidebar
with st.sidebar:
    st.header("Settings")

    # Model selection
    model_type = st.selectbox(
        "Select Analysis Model",
        ["textblob", "transformers"],
        help="Choose between TextBlob (fast) or Transformers (more accurate)",
    )

    st.markdown("---")

    # API Status check
    st.subheader("API Status")
    try:
        health_response = requests.get(f"{API_URL}/health", timeout=2)
        if health_response.status_code == 200:
            st.success("API Connected")
        else:
            st.error("API Error")
    except:
        st.error("API Offline")
        st.caption("Start Flask server: `python app/main.py`")

    st.markdown("---")

    # About section
    st.subheader("About")
    st.info(
        """
    This dashboard uses AI to analyze the sentiment of text feedback.
    
    **Models:**
    - **TextBlob**: Fast, rule-based
    - **Transformers**: Advanced, ML-based
    
    **Sentiments:**
    - Positive
    - Negative
    - Neutral
    """
    )

# Main content area
tab1, tab2, tab3, tab4 = st.tabs(["Analyze", "Statistics", "Trends", "History"])

# Tab 1: Analyze
with tab1:
    st.header("Analyze Feedback")

    col1, col2 = st.columns([2, 1])

    with col1:
        # Text input methods
        input_method = st.radio(
            "Input Method", ["Type/Paste Text", "Sample Feedback"], horizontal=True
        )

        if input_method == "Type/Paste Text":
            feedback_text = st.text_area(
                "Enter feedback text to analyze:",
                height=150,
                placeholder="Type or paste customer feedback here...",
            )
        else:
            sample_texts = [
                "This product is absolutely amazing! Best purchase ever!",
                "Terrible experience. Would not recommend to anyone.",
                "It's okay, nothing special but does the job.",
                "Outstanding customer service and high quality product!",
                "Very disappointed with the quality. Waste of money.",
                "Average product, met my basic expectations.",
            ]
            feedback_text = st.selectbox("Select sample feedback:", sample_texts)

        analyze_button = st.button(
            "Analyze Sentiment", type="primary", use_container_width=True
        )

        if analyze_button and feedback_text:
            with st.spinner("Analyzing sentiment..."):
                result = analyze_text_api(feedback_text, model_type)

                if "error" in result:
                    st.error(f"Error: {result['error']}")
                else:
                    # Store result
                    result["timestamp"] = datetime.now().isoformat()
                    st.session_state.analysis_results.append(result)

                    # Update counts
                    sentiment = result.get("sentiment", "Neutral")
                    st.session_state.sentiment_counts[sentiment] += 1

                    # Display result
                    sentiment = result.get("sentiment", "Unknown")
                    confidence = result.get("confidence", 0)
                    emoji = get_sentiment_emoji(sentiment)
                    color = get_sentiment_color(sentiment)

                    st.markdown("### Analysis Result")

                    # Result card
                    st.markdown(
                        f"""
                    <div style="background-color: {color}20; padding: 20px; border-radius: 10px; border-left: 5px solid {color};">
                        <h2 style="color: {color}; margin: 0;">{emoji} {sentiment}</h2>
                        <p style="font-size: 18px; margin: 10px 0;">Confidence: {confidence}%</p>
                        <p style="color: #666; margin: 0;">Model: {result.get('model', 'Unknown')}</p>
                    </div>
                    """,
                        unsafe_allow_html=True,
                    )

                    # Additional metrics
                    if "polarity" in result:
                        st.markdown("#### Detailed Metrics")
                        metric_col1, metric_col2 = st.columns(2)
                        with metric_col1:
                            st.metric("Polarity", result.get("polarity", "N/A"))
                        with metric_col2:
                            st.metric("Subjectivity", result.get("subjectivity", "N/A"))

    with col2:
        st.markdown("### Quick Stats")

        total = sum(st.session_state.sentiment_counts.values())

        if total > 0:
            # Display sentiment distribution
            for sentiment, count in st.session_state.sentiment_counts.items():
                percentage = (count / total) * 100
                emoji = get_sentiment_emoji(sentiment)
                st.metric(f"{emoji} {sentiment}", f"{count}", f"{percentage:.1f}%")
        else:
            st.info("No analyses yet. Start analyzing feedback to see statistics.")

# Tab 2: Statistics
with tab2:
    st.header("Sentiment Statistics")

    if st.session_state.analysis_results:
        col1, col2 = st.columns(2)

        with col1:
            # Pie chart
            st.subheader("Sentiment Distribution")
            sentiment_df = pd.DataFrame.from_dict(
                st.session_state.sentiment_counts, orient="index", columns=["Count"]
            ).reset_index()
            sentiment_df.columns = ["Sentiment", "Count"]

            fig_pie = px.pie(
                sentiment_df,
                values="Count",
                names="Sentiment",
                color="Sentiment",
                color_discrete_map={
                    "Positive": "#28a745",
                    "Negative": "#dc3545",
                    "Neutral": "#ffc107",
                },
                hole=0.4,
            )
            fig_pie.update_traces(textposition="inside", textinfo="percent+label")
            st.plotly_chart(fig_pie, use_container_width=True)

        with col2:
            # Bar chart
            st.subheader("Sentiment Counts")
            fig_bar = px.bar(
                sentiment_df,
                x="Sentiment",
                y="Count",
                color="Sentiment",
                color_discrete_map={
                    "Positive": "#28a745",
                    "Negative": "#dc3545",
                    "Neutral": "#ffc107",
                },
            )
            fig_bar.update_layout(showlegend=False)
            st.plotly_chart(fig_bar, use_container_width=True)

        # Confidence metrics
        st.subheader("Confidence Metrics")
        confidences = [
            r.get("confidence", 0) for r in st.session_state.analysis_results
        ]
        avg_confidence = sum(confidences) / len(confidences) if confidences else 0

        conf_col1, conf_col2, conf_col3 = st.columns(3)
        with conf_col1:
            st.metric("Average Confidence", f"{avg_confidence:.2f}%")
        with conf_col2:
            st.metric(
                "Min Confidence", f"{min(confidences):.2f}%" if confidences else "N/A"
            )
        with conf_col3:
            st.metric(
                "Max Confidence", f"{max(confidences):.2f}%" if confidences else "N/A"
            )
    else:
        st.info("No data available yet. Analyze some feedback to see statistics.")

# Tab 3: Trends
with tab3:
    st.header("Sentiment Trends")

    if st.session_state.analysis_results:
        # Create DataFrame
        df = pd.DataFrame(st.session_state.analysis_results)
        df["analysis_number"] = range(1, len(df) + 1)

        # Sentiment over time
        st.subheader("Sentiment Analysis Timeline")
        fig_timeline = px.scatter(
            df,
            x="analysis_number",
            y="confidence",
            color="sentiment",
            color_discrete_map={
                "Positive": "#28a745",
                "Negative": "#dc3545",
                "Neutral": "#ffc107",
            },
            size="confidence",
            hover_data=["text"],
            labels={
                "analysis_number": "Analysis Number",
                "confidence": "Confidence (%)",
            },
        )
        st.plotly_chart(fig_timeline, use_container_width=True)

        # Confidence distribution
        st.subheader("Confidence Distribution")
        fig_hist = px.histogram(
            df,
            x="confidence",
            color="sentiment",
            color_discrete_map={
                "Positive": "#28a745",
                "Negative": "#dc3545",
                "Neutral": "#ffc107",
            },
            nbins=20,
            labels={"confidence": "Confidence (%)"},
        )
        st.plotly_chart(fig_hist, use_container_width=True)
    else:
        st.info("No data available yet. Analyze some feedback to see trends.")

# Tab 4: History
with tab4:
    st.header("Analysis History")

    if st.session_state.analysis_results:
        # Show recent analyses
        st.subheader(
            f"Recent Analyses ({len(st.session_state.analysis_results)} total)"
        )

        # Create DataFrame
        history_df = pd.DataFrame(st.session_state.analysis_results)

        # Select columns to display
        display_columns = ["sentiment", "confidence", "text", "model"]
        available_columns = [
            col for col in display_columns if col in history_df.columns
        ]

        # Display table
        st.dataframe(
            history_df[available_columns].iloc[::-1],  # Reverse to show latest first
            use_container_width=True,
            hide_index=True,
        )

        # Download button
        csv = history_df.to_csv(index=False)
        st.download_button(
            label="Download History as CSV",
            data=csv,
            file_name=f"sentiment_analysis_history_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv",
            mime="text/csv",
        )

        # Clear history button
        if st.button("Clear History", type="secondary"):
            st.session_state.analysis_results = []
            st.session_state.sentiment_counts = {
                "Positive": 0,
                "Negative": 0,
                "Neutral": 0,
            }
            st.rerun()
    else:
        st.info("No analysis history yet. Start analyzing feedback to build history.")

# Footer
st.markdown("---")
st.markdown(
    """
    <div style="text-align: center; color: #666; padding: 20px;">
        <p>Built with Streamlit, Flask, and AI</p>
        <p>Copyright 2025 AI Sentiment Analysis Dashboard</p>
    </div>
    """,
    unsafe_allow_html=True,
)
