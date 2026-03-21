# uniguide

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
📚 UniGuide – AI-Powered Study Assistant

UniGuide is a smart study platform designed for university students. It combines organized academic resources (Books, Notes, PYQs) with an AI-powered chatbot (RAG-based) to help students learn faster and more efficiently.

🚀 Features
📖 Structured Content Browsing
Branch → Semester → Subject → Files
Supports Books, Notes, and PYQs
🤖 AI Chatbot (RAG-based)
Ask questions from your syllabus
Context-aware answers from study materials
📂 Dynamic File System
Automatically reads PDFs from folders
No need to manually update database
📱 Cross-platform UI
Built using Flutter
Works on Android (expandable to other platforms)
🔍 Search-ready architecture
Easily extendable for semantic search
🛠️ Tech Stack

Frontend

Flutter (Dart)

Backend

Flask (Python)

Database

SQLite

AI / NLP

SentenceTransformers
FAISS (Vector Database)
RAG (Retrieval-Augmented Generation)
📁 Project Structure
Uniguide/
│
├── backend/
│   ├── app/
│   ├── database/
│   ├── run.py
│   ├── requirements.txt
│
├── lib/
│   ├── screens/
│   ├── services/
│   ├── models/
│   └── main.dart
│
├── android/
├── pubspec.yaml
├── .env.example
├── README.md
📂 Data Folder Structure

Place your PDFs in this format:

data/
└── books/
    └── CSE/
        └── semester_1/
            └── maths/
                ├── book1.pdf
                ├── book2.pdf

Same structure applies for:

notes/
pyqs/
⚙️ Setup Instructions
🔹 Backend Setup
cd backend
pip install -r requirements.txt
python run.py

Backend will run on:

http://127.0.0.1:5000
🔹 Flutter Setup
flutter pub get
flutter run
🔑 Environment Variables

Create a .env file using .env.example:

GROQ_API_KEY=your_api_key_here
HF_TOKEN=your_huggingface_token_here
SECRET_KEY=your_secret_key_here

🌐 API Endpoints
Endpoint	Description
/items/branches	Get branches
/items/semesters	Get semesters
/items/subjects	Get subjects
/items/files	Get PDFs
/items/view	View PDF
/items/download	Download PDF
📸 Screenshots 



🧠 Future Improvements
📄 In-app PDF viewer
🔍 Semantic search inside PDFs
🎯 Personalized recommendations
☁️ Cloud storage integration
🔐 User authentication system
🤝 Contributing

Contributions are welcome!
Feel free to fork this repository and submit a pull request.
