### Waseed (وصيد) - Comprehensive Cybersecurity Platform

## Introduction

<img width="2686" height="778" alt="image" src="https://github.com/user-attachments/assets/da5ffabc-8dd7-4e4b-b466-133fc7c0f9a1" />

Waseed is a comprehensive, user-friendly cybersecurity platform specifically designed for Arabic-speaking users with limited cybersecurity experience. The goal of this project is to bridge the critical gap between advanced cybersecurity capabilities and practical usability for Arabic-speaking users by consolidating multiple security services into a single, integrated mobile application, addressing the fragmented security ecosystem that currently exists in the MENA region.

## Technology Stack

### Frontend
- **Flutter** with Dart for cross-platform mobile development

### Backend
- **Node.js** with Express framework for RESTful API services
- **Python** service for AI component
- **MongoDB** for data persistence (user information and security events)
- **AWS** cloud infrastructure for AI model hosting

### Integrations
- **Have I Been Pwned API** for breach monitoring
- **VirusTotal API** for link and file scanning
- **Firebase** for real-time push notifications and threat alerts

## Installation & Setup

### Prerequisites
- Git installed and configured
- Node.js and npm
- Flutter SDK
- MongoDB instance
- **macOS users:** Xcode
- **Windows users:** Android Studio

### Backend Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   ```

2. **Navigate to the backend folder**
   ```bash
   cd backend
   ```

3. **Configure environment variables**
   - Create a `.env` file in the backend folder
   - Use `.env.example` as a template

4. **Install dependencies and run the backend**
   ```bash
   npm install
   npm run dev
   ```

### Mobile Application Setup

#### 1. Set up a simulator/emulator

**For macOS users:**
- Install and open Xcode
- Launch an iPhone simulator

**For Windows users:**
- Install and open Android Studio
- Launch an Android device emulator

#### 2. Run the application

1. **Navigate to the mobile folder**
   ```bash
   cd mobile
   ```

2. **Configure environment variables**
   - Create a `.env` file in the mobile folder
   - Use `.env.example` as a template
   - Since the backend runs locally, configure the URL based on your OS:
     - **iOS Simulator:** `http://localhost:<port>`
     - **Android Emulator:** `http://10.0.2.2:<port>`

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Run the application**
   ```bash
   flutter run
   ```



