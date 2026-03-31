<div align="center">
  <img src="https://readme-typing-svg.herokuapp.com?font=Fira+Code&size=28&pause=1000&color=60A5FA&center=true&vCenter=true&lines=Triplens+Tourism;+Landmark+Discovery;Graduation+Project+%F0%9F%8E%89" />
  <br><br>
  <img src="https://img.shields.io/badge/🎓-Graduation%20Project-1E40AF?style=for-the-badge&logo=university&logoColor=white" />
  <img src="https://img.shields.io/badge/⭐-92%25%20CV%20Accuracy-3B82F6?style=for-the-badge&logo=tensorflow&logoColor=white" />
</div>

---

## <div align="center"><b style="color:#1E40AF">📱 Project Overview</b></div>

**Triplens Tourism** is an **intelligent mobile application** that revolutionizes travel discovery using **Computer Vision** and **personalized recommendations**. Users can upload images to instantly recognize landmarks and receive tailored suggestions based on their interests.

<div align="center">
  <img src="https://img.shields.io/badge/🧠-AI%20Powered-60A5FA?style=for-the-badge&logo=brain&logoColor=white" />
  <img src="https://img.shields.io/badge/📸-Computer%20Vision-3B82F6?style=for-the-badge&logo=camera&logoColor=white" />
  <img src="https://img.shields.io/badge/🎯-Personalized%20Recs-1E40AF?style=for-the-badge&logo=recommendations&logoColor=white" />
</div>

<div align="center">
  graph TB
    A[📱 Flutter App] --> B[⚡ Node.js API]
    B --> C[🗄️ MySQL DB]
    A --> D[🔐 Firebase Auth]
    A --> E[💾 Firebase Storage]
    B --> F[🧠 TensorFlow CV]
    
    style A fill:#2563EB
    style B fill:#1E40AF
    style C fill:#0F766E
    style D fill:#EF4444
    style E fill:#F59E0B
    style F fill:#7C3AED
</div>


## ✨ **Key Features**


Feature

Description

🖼️ Image Recognition


Upload photo → Instant landmark detection (92% accuracy)


📂 Smart Categories


Ancient, Modern, Nature, Religious, Museums


❤️ Favorites


Save places for later exploration


⭐ Dynamic Rating


Community-driven place ratings


🔍 Smart Search


Instant place discovery


📍 Detailed Info


Location, description, ratings, maps


System Architecture


Flutter Mobile App

    ↓ HTTP Requests

    
Node.js REST API (Express)


    ↓ SQL Queries

    
MySQL Database (Places/Users)


    ↓ Auth/Storage

    
Firebase (Authentication + Images)


    ↑ TensorFlow CV Processing

    
Database Schema


  -- Main Places Table

  
CREATE TABLE places (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255),
    category ENUM('Ancient','Modern','Nature','Religious','Museums'),
    description TEXT,
    long_description TEXT,
    city VARCHAR(100),
    locationString VARCHAR(255),
    link_location TEXT,
    image_url VARCHAR(500),
    rating DECIMAL(3,2) DEFAULT 0.00
);


🎥 Live Demo



http://drive.google.com/file/d/1LlLcHk0bCRQxL1OPqWUj2jqHRk1t63z3/view

 Quick Start

 
 # 1. Clone the repository
git clone https://github.com/Nourhanmohamed12/Graduation-project.git
cd Graduation-project


# 2. Backend Setup
cd backend
npm install
cp .env.example .env

# Edit .env with your DB credentials
npm start


# 3. Frontend Setup (New Terminal)
cd frontend
flutter pub get
flutter run

Environment Variables 


DB_HOST=localhost
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=tourism
PORT=5000


Performance Metrics

Metric

Value

CV Accuracy

92%

API Response

< 200ms

Image Upload

< 3s

Recommendation

Personalized

Database

1k+ Places

👩‍💻 Author


<div align="center"> <a href="https://linkedin.com/in/nour-mohammed-614753278"> <img src="https://img.shields.io/badge/Nourhan%20Mohammed-1E40AF?style=for-the-badge&logo=linkedin&logoColor=white" /> </a> <img src="https://img.shields.io/badge/B.Sc.%20Data%20Science-3B82F6?style=for-the-badge&logo=university&logoColor=white" /> </div>


🌟 Future Enhancements


🤖 ML Recommendations (Collaborative Filtering)
⚡ Real-time Tracking (Geolocation)
🧠 Advanced CV (Multi-landmark detection)
☁️ Cloud Deployment (AWS/Docker)
📱 AR Features (Augmented Reality)


❤️ Acknowledgments
<div align="center"> <img src="https://img.shields.io/badge/🎓-Graduation%20Project-60A5FA?style=for-the-badge&logo=graduation-cap&logoColor=white" /> <br> <sub>Built with ❤️ for academic excellence | Data Science & Mobile Development</sub> </div> <div align="center"> <img src="https://img.shields.io/github/stars/Nourhanmohamed12/Graduation-project?style=social" /> <img src="https://img.shields.io/badge/License-MIT-1E40AF?style=for-the-badge&logo=legal&logoColor=white" /> </div> ```
