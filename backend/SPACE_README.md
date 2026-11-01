---
title: UniGuide API
sdk: docker
app_port: 7860
---

# UniGuide API

Flask-based retrieval-augmented generation API for UniGuide.

Configure these Space variables and secrets:

- Secrets: `SECRET_KEY`, `GROQ_API_KEY`, `DEMO_PASSWORD`
- Variables: `GROQ_MODEL`, `DEMO_EMAIL`, `CORS_ORIGINS`, `DISABLE_FILE_DOWNLOADS`
- `DISABLE_FILE_DOWNLOADS` defaults to `false`; set it to `true` to disable PDF viewing and downloads.