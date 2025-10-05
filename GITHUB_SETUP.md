# GitHub Integration Guide

## Step 1: Create GitHub Repository

You have two options to create and push to GitHub:

### Option A: Using GitHub CLI (Recommended)

1. **Install GitHub CLI** if you haven't already:
   - Windows: `winget install --id GitHub.cli`
   - Or download from: https://cli.github.com/

2. **Authenticate with GitHub:**
   ```bash
   gh auth login
   ```

3. **Create and push repository:**
   ```bash
   cd c:\Users\I7\Projects\auto-feedback
   gh repo create auto-feedback --public --source=. --remote=origin --push
   ```

   Or for a private repository:
   ```bash
   gh repo create auto-feedback --private --source=. --remote=origin --push
   ```

### Option B: Using GitHub Website

1. **Go to GitHub** and create a new repository:
   - Visit: https://github.com/new
   - Repository name: `auto-feedback` (or your preferred name)
   - Description: "AI-powered sentiment analysis web app with Flask API and Streamlit dashboard"
   - Choose Public or Private
   - **DO NOT** initialize with README, .gitignore, or license (we already have these)
   - Click "Create repository"

2. **Link your local repository to GitHub:**
   ```bash
   cd c:\Users\I7\Projects\auto-feedback
   git remote add origin https://github.com/YOUR_USERNAME/auto-feedback.git
   git branch -M main
   git push -u origin main
   ```

   Replace `YOUR_USERNAME` with your actual GitHub username.

## Step 2: Verify Upload

After pushing, verify your repository at:
```
https://github.com/YOUR_USERNAME/auto-feedback
```

## Step 3: Add Repository Badges (Optional)

Add these badges to the top of your README.md:

```markdown
![Python](https://img.shields.io/badge/python-3.10+-blue.svg)
![Flask](https://img.shields.io/badge/flask-3.0.0-green.svg)
![Streamlit](https://img.shields.io/badge/streamlit-1.28.1-red.svg)
![License](https://img.shields.io/badge/license-MIT-yellow.svg)
```

## Step 4: Set Up GitHub Actions (Optional)

Create `.github/workflows/test.yml` for automated testing:

```yaml
name: Test Application

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.10'
      - name: Install dependencies
        run: |
          pip install -r requirements.txt
      - name: Test model
        run: |
          python app/model.py
```

## Quick Commands Reference

```bash
# Check repository status
git status

# Add new changes
git add .

# Commit changes
git commit -m "Your commit message"

# Push to GitHub
git push

# Pull latest changes
git pull

# Create new branch
git checkout -b feature-name

# View remote repositories
git remote -v

# View commit history
git log --oneline
```

## Repository Structure on GitHub

Your repository will include:
```
auto-feedback/
├── .gitignore              # Git ignore patterns
├── Dockerfile              # Docker configuration
├── README.md               # Project documentation
├── requirements.txt        # Python dependencies
├── GITHUB_SETUP.md         # This file
└── app/
    ├── main.py            # Flask API
    ├── model.py           # Sentiment analysis
    └── dashboard.py       # Streamlit dashboard
```

## Next Steps After GitHub Setup

1. **Share your repository** - Send the link to collaborators
2. **Add topics** - On GitHub, add topics like: `sentiment-analysis`, `flask`, `streamlit`, `nlp`, `ai`
3. **Enable GitHub Pages** - Host documentation if needed
4. **Set up branch protection** - Protect main branch from direct pushes
5. **Create issues** - Track bugs and feature requests
6. **Add collaborators** - Invite team members

## Troubleshooting

### "Remote origin already exists"
```bash
git remote remove origin
git remote add origin https://github.com/YOUR_USERNAME/auto-feedback.git
```

### "Permission denied"
- Make sure you're authenticated with GitHub
- Use HTTPS URL or set up SSH keys
- Check your GitHub username and repository name

### "Updates were rejected"
```bash
git pull origin main --rebase
git push origin main
```

## Need Help?

- GitHub Docs: https://docs.github.com/
- GitHub CLI: https://cli.github.com/manual/
- Git Documentation: https://git-scm.com/doc
