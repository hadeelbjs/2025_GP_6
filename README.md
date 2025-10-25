### Waseed (وصيد) - Comprehensive Cybersecurity Platform

## Introduction
Waseed is a comprehensive, user-friendly cybersecurity platform specifically designed for Arabic-speaking users with limited cybersecurity experience. The goal of this project is to bridge the critical gap between advanced cybersecurity capabilities and practical usability for Arabic-speaking users by consolidating multiple security services into a single, integrated mobile application, addressing the fragmented security ecosystem that currently exists in the MENA region.

## Technology 
The platform uses Flutter for mobile development with Dart programming language. The backend consists of Node.js with Express framework for RESTful API services and a separate Python service for the AI component. Data persistence is handled through MongoDB database for storing user information and security events, while AWS cloud infrastructure hosts the AI model. The system integrates external security APIs including Have I Been Pwned for breach monitoring and VirusTotal for link and file scanning, with Firebase integration for real-time push notifications to enhance user experience and immediate threat alerts.

## Launching Instructions

For macOS Users:

1. Install and open Xcode
2. Launch an iPhone simulator

For Windows Users:

1. Install and open Android Studio
2. Launch an Android device simulator

Run the Application:

After cloning the repository, open your terminal and follow these steps:

```
cd mobile
flutter pub get
flutter run
```
