# 🚀 Quick Start Guide

## Fastest Way to Get Started

### Windows Users

1. **Double-click `start.bat`** 
   - This will automatically:
     - Create virtual environment
     - Install all dependencies
     - Download required models
     - Start Flask API (http://localhost:5000)
     - Start Streamlit Dashboard (http://localhost:8501)

2. **Or manually:**
   ```bash
   # Create and activate virtual environment
   python -m venv venv
   venv\Scripts\activate
   
   # Install dependencies
   pip install -r requirements.txt
   python -m textblob.download_corpora
   
   # Terminal 1: Start Flask API
   python app\main.py
   
   # Terminal 2: Start Streamlit Dashboard
   streamlit run app\dashboard.py
   ```

### macOS/Linux Users

1. **Make script executable and run:**
   ```bash
   chmod +x start.sh
   ./start.sh
   ```

2. **Or manually:**
   ```bash
   # Create and activate virtual environment
   python3 -m venv venv
   source venv/bin/activate
   
   # Install dependencies
   pip install -r requirements.txt
   python -m textblob.download_corpora
   
   # Terminal 1: Start Flask API
   python app/main.py
   
   # Terminal 2: Start Streamlit Dashboard
   streamlit run app/dashboard.py
   ```

## Test the Application

### 1. Test the API
Open a new terminal and run:
```bash
python examples.py
```

This will:
- Test API connection
- Run sentiment analysis on sample texts
- Show statistics and history
- Demonstrate both TextBlob and Transformers models

### 2. Test via Web Dashboard

1. Open browser to http://localhost:8501
2. Go to "Analyze" tab
3. Try sample feedback:
   - "This product is absolutely amazing!"
   - "Terrible experience, very disappointed"
   - "It's okay, nothing special"
4. View statistics, trends, and history tabs

### 3. Test via API Direct

Using curl:
```bash
curl -X POST http://localhost:5000/analyze \
  -H "Content-Type: application/json" \
  -d "{\"text\": \"I love this product!\"}"
```

Using PowerShell:
```powershell
Invoke-RestMethod -Uri http://localhost:5000/analyze -Method Post -ContentType "application/json" -Body '{"text": "I love this product!"}'
```

## What You Get

✅ **Flask API** - RESTful API for sentiment analysis
- POST /analyze - Analyze sentiment
- GET /stats - View statistics
- GET /history - View analysis history
- GET /health - Health check

✅ **Streamlit Dashboard** - Interactive web interface
- Real-time sentiment analysis
- Visual charts and graphs
- Sentiment trends over time
- Export history to CSV

✅ **Two AI Models**
- **TextBlob** - Fast, lightweight (default)
- **Transformers** - Accurate, ML-based (DistilBERT)

✅ **Docker Support** - Containerized deployment
```bash
docker build -t sentiment-app .
docker run -p 8501:8501 sentiment-app
```

## Project Files

```
auto-feedback/
├── app/
│   ├── main.py          ⭐ Flask API server
│   ├── model.py         ⭐ Sentiment analysis models
│   └── dashboard.py     ⭐ Streamlit dashboard
├── examples.py          📘 Example API usage
├── start.bat           🚀 Windows startup script
├── start.sh            🚀 Unix startup script
├── requirements.txt    📦 Python dependencies
├── Dockerfile          🐳 Docker configuration
├── .gitignore         🚫 Git ignore patterns
├── README.md          📖 Full documentation
├── GITHUB_SETUP.md    🌐 GitHub integration guide
└── QUICKSTART.md      ⚡ This file
```

## Common Issues

### Port Already in Use
```bash
# Windows - Find and kill process on port 5000
netstat -ano | findstr :5000
taskkill /PID <PID> /F

# macOS/Linux - Find and kill process
lsof -ti:5000 | xargs kill -9
```

### Import Errors
```bash
# Ensure virtual environment is activated
# Windows:
venv\Scripts\activate

# macOS/Linux:
source venv/bin/activate

# Reinstall dependencies
pip install -r requirements.txt
```

### "Cannot connect to API" in Dashboard
- Make sure Flask API is running on port 5000
- Check Flask terminal for errors
- Verify API health: http://localhost:5000/health

## Next Steps

1. ✅ **Test locally** - Use `start.bat` or `start.sh`
2. 📊 **Try the dashboard** - http://localhost:8501
3. 🧪 **Run examples** - `python examples.py`
4. 🌐 **Push to GitHub** - See `GITHUB_SETUP.md`
5. 🐳 **Deploy with Docker** - See `README.md`
6. 🚀 **Deploy to cloud** - Heroku, AWS, Azure, GCP

## Need Help?

- 📖 Read `README.md` for full documentation
- 🌐 See `GITHUB_SETUP.md` for GitHub integration
- 🐛 Check troubleshooting section in README
- 💬 Open an issue on GitHub

## Sample Feedback for Testing

**Positive:**
- "This product is absolutely amazing! Best purchase ever!"
- "Outstanding customer service and quality. Highly recommend!"
- "Love it! Exceeded all my expectations!"

**Negative:**
- "Terrible experience. Complete waste of money."
- "Very disappointed with the quality. Would not recommend."
- "Horrible customer service. Never buying again."

**Neutral:**
- "It's okay, nothing special but does the job."
- "Average product, met basic expectations."
- "Works as described, no complaints or praise."

---

**Happy Analyzing! 🎭📊**
