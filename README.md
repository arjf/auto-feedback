# 🎭 AI-Powered Sentiment Analysis Web App

A complete sentiment analysis application with Flask REST API, Streamlit dashboard, and Docker support. Analyze customer feedback using AI-powered models (TextBlob and Hugging Face Transformers).

## 📋 Features

- ✅ **Flask REST API** - Analyze sentiment via HTTP endpoints
- ✅ **Streamlit Dashboard** - Interactive web interface with real-time analysis
- ✅ **Multiple AI Models** - TextBlob (fast) and Transformers (accurate)
- ✅ **Real-time Analysis** - Instant sentiment classification
- ✅ **Visualization** - Charts and graphs for sentiment trends
- ✅ **History Tracking** - Track and export analysis history
- ✅ **Docker Support** - Containerized deployment
- ✅ **API Endpoints** - RESTful API with comprehensive endpoints

## 🏗️ Project Structure

```
auto-feedback/
├── app/
│   ├── main.py          # Flask API server
│   ├── model.py         # Sentiment analysis models
│   └── dashboard.py     # Streamlit dashboard
├── requirements.txt     # Python dependencies
├── Dockerfile          # Docker configuration
├── .gitignore         # Git ignore patterns
└── README.md          # This file
```

## 🚀 Quick Start

### Prerequisites

- Python 3.10 or higher
- pip (Python package manager)
- Docker (optional, for containerized deployment)

### Installation

1. **Clone the repository:**
```bash
git clone <your-repo-url>
cd auto-feedback
```

2. **Create a virtual environment:**
```bash
# Windows
python -m venv venv
venv\Scripts\activate

# macOS/Linux
python3 -m venv venv
source venv/bin/activate
```

3. **Install dependencies:**
```bash
pip install -r requirements.txt
```

4. **Download NLTK data (required for TextBlob):**
```bash
python -m textblob.download_corpora
```

## 💻 Running Locally

### Option 1: Run Flask API Only

```bash
python app/main.py
```

The API will be available at `http://localhost:5000`

**Test the API:**
```bash
curl -X POST http://localhost:5000/analyze -H "Content-Type: application/json" -d "{\"text\": \"This product is amazing!\"}"
```

### Option 2: Run Streamlit Dashboard Only

```bash
streamlit run app/dashboard.py
```

The dashboard will open automatically at `http://localhost:8501`

> **Note:** To use the dashboard with API features, you need to run the Flask API separately in another terminal.

### Option 3: Run Both (Recommended)

**Terminal 1 - Flask API:**
```bash
python app/main.py
```

**Terminal 2 - Streamlit Dashboard:**
```bash
streamlit run app/dashboard.py
```

Now you can:
- Access the API at `http://localhost:5000`
- Access the Dashboard at `http://localhost:8501`

## 🐳 Running with Docker

### Build the Docker image:
```bash
docker build -t sentiment-analysis-app .
```

### Run the container (Streamlit only):
```bash
docker run -p 8501:8501 sentiment-analysis-app
```

### Run both Flask and Streamlit:
```bash
docker run -p 5000:5000 -p 8501:8501 sentiment-analysis-app /app/start.sh
```

Access:
- Streamlit Dashboard: `http://localhost:8501`
- Flask API: `http://localhost:5000`

## 📡 API Endpoints

### `GET /`
Get API information and available endpoints.

**Response:**
```json
{
  "message": "Sentiment Analysis API",
  "version": "1.0.0",
  "endpoints": { ... }
}
```

### `POST /analyze`
Analyze sentiment of feedback text.

**Request:**
```json
{
  "text": "This product is amazing!",
  "model": "textblob"  // optional: "textblob" or "transformers"
}
```

**Response:**
```json
{
  "text": "This product is amazing!",
  "sentiment": "Positive",
  "confidence": 85.5,
  "polarity": 0.855,
  "subjectivity": 0.75,
  "model": "TextBlob",
  "timestamp": "2025-10-06T12:00:00"
}
```

### `GET /history`
Get analysis history.

**Query Parameters:**
- `limit` (optional): Number of records to return (default: 50, max: 100)

**Response:**
```json
{
  "count": 10,
  "history": [ ... ]
}
```

### `GET /stats`
Get sentiment statistics.

**Response:**
```json
{
  "stats": {
    "total": 100,
    "positive": 45,
    "negative": 30,
    "neutral": 25,
    "positive_percentage": 45.0,
    "negative_percentage": 30.0,
    "neutral_percentage": 25.0,
    "average_confidence": 82.5
  }
}
```

### `GET /health`
Health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2025-10-06T12:00:00"
}
```

## 🎨 Using the Streamlit Dashboard

1. **Navigate to** `http://localhost:8501`

2. **Analyze Tab:**
   - Type or paste feedback text
   - Select analysis model (TextBlob or Transformers)
   - Click "Analyze Sentiment"
   - View results with sentiment, confidence, and metrics

3. **Statistics Tab:**
   - View sentiment distribution pie chart
   - See sentiment counts bar chart
   - Check confidence metrics

4. **Trends Tab:**
   - Analyze sentiment timeline
   - View confidence distribution
   - Track patterns over multiple analyses

5. **History Tab:**
   - Review all past analyses
   - Download history as CSV
   - Clear history

## 🧠 AI Models

### TextBlob (Default)
- **Speed:** Fast ⚡
- **Accuracy:** Good for general use
- **Requirements:** Lightweight, no GPU needed
- **Best for:** Quick analysis, real-time feedback

### Hugging Face Transformers
- **Speed:** Slower (first run downloads model)
- **Accuracy:** High precision
- **Requirements:** More memory, GPU recommended
- **Model:** DistilBERT fine-tuned on SST-2
- **Best for:** Detailed analysis, high accuracy needs

## 📦 Dependencies

Main dependencies:
- **Flask 3.0.0** - Web framework for API
- **Streamlit 1.28.1** - Dashboard framework
- **TextBlob 0.17.1** - Simple sentiment analysis
- **Transformers 4.35.0** - Advanced NLP models
- **Pandas 2.1.3** - Data manipulation
- **Plotly 5.18.0** - Interactive visualizations
- **Requests 2.31.0** - HTTP library

See `requirements.txt` for complete list.

## 🔧 Configuration

### Changing API Port
Edit `app/main.py`:
```python
app.run(host='0.0.0.0', port=5000, debug=True)  # Change port here
```

### Changing Dashboard Port
Run with custom port:
```bash
streamlit run app/dashboard.py --server.port=8502
```

### Switching Default Model
Edit `app/model.py`:
```python
default_analyzer = SentimentAnalyzer(model_type="transformers")  # or "textblob"
```

## 🐛 Troubleshooting

### Issue: "Cannot connect to API"
- Ensure Flask server is running on port 5000
- Check if another application is using port 5000
- Verify API URL in dashboard.py matches your Flask host

### Issue: "Transformers model download fails"
- Ensure stable internet connection
- First download takes time (model is ~250MB)
- Falls back to TextBlob automatically on failure

### Issue: "Import errors"
- Ensure virtual environment is activated
- Run `pip install -r requirements.txt` again
- Check Python version (3.10+ required)

### Issue: "Port already in use"
- Windows: `netstat -ano | findstr :5000` then kill process
- macOS/Linux: `lsof -ti:5000 | xargs kill -9`

## 📊 Sample Use Cases

1. **Customer Support:** Analyze customer feedback to prioritize urgent negative reviews
2. **Product Reviews:** Aggregate sentiment from product reviews
3. **Social Media:** Monitor brand sentiment from social posts
4. **Survey Analysis:** Quickly classify open-ended survey responses
5. **Email Triage:** Categorize incoming emails by sentiment

## 🔐 Security Notes

- This is a development setup - not production-ready
- Enable authentication before deploying publicly
- Use environment variables for sensitive configuration
- Implement rate limiting for production API
- Add HTTPS/SSL for production deployments

## 🚢 Deployment

### Deploy to Cloud

**Heroku:**
1. Create `Procfile`:
   ```
   web: streamlit run app/dashboard.py --server.port=$PORT
   ```
2. Deploy: `git push heroku main`

**Docker Hub:**
```bash
docker tag sentiment-analysis-app username/sentiment-analysis-app
docker push username/sentiment-analysis-app
```

**AWS/Azure/GCP:**
- Use the provided Dockerfile
- Configure environment variables
- Set up load balancing if needed

## 📝 Testing

### Test the Model:
```bash
cd app
python model.py
```

### Test the API:
```bash
python app/main.py
# In another terminal:
curl -X POST http://localhost:5000/analyze \
  -H "Content-Type: application/json" \
  -d '{"text": "This is amazing!"}'
```

### Test the Dashboard:
```bash
streamlit run app/dashboard.py
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 👨‍💻 Author

Created with ❤️ for sentiment analysis and AI applications.

## 🙏 Acknowledgments

- **TextBlob** - Simple text processing
- **Hugging Face** - State-of-the-art NLP models
- **Streamlit** - Beautiful data apps
- **Flask** - Lightweight web framework

## 📞 Support

For issues and questions:
- Open an issue on GitHub
- Check the troubleshooting section
- Review the API documentation

---

**Happy Analyzing! 🎭📊**
