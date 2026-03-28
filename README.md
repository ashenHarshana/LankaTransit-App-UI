# 🚌 LankaTransit - Public Transport Management System

LankaTransit is a comprehensive, full-stack public transport management solution designed to streamline bus scheduling, route management, and digital ticketing in Sri Lanka. The system features a cross-platform mobile application and a robust backend API, providing dedicated interfaces for Admins, Bus Owners, Drivers, and Passengers.

## 🌟 Key Features

* **Role-Based Access Control (RBAC):** Distinct dashboards and functionalities for Admin, Owner, Driver, and Passenger roles.
* **Live Location Tracking:** Real-time bus tracking on Google Maps using Firebase integration.
* **QR-Based Digital Ticketing:** Seamless e-ticket generation for passengers and in-app QR code verification for drivers using `mobile_scanner`.
* **Dynamic Route & Halt Management:** Interactive map interfaces to plot routes and add strategic halts with distance calculations.
* **Secure Document Management:** Built-in system for uploading and verifying vehicle and owner documents.
* **Offline Caching:** Saves recent ticket data locally using `shared_preferences` for quick access.

## 💻 Tech Stack

### Frontend (Mobile App)
* **Framework:** Flutter (Dart)
* **Mapping:** Google Maps (`Maps_flutter`), OSRM API for routing
* **Features:** QR Flutter, Mobile Scanner, HTTP
* **State Management & Caching:** Shared Preferences

### Backend (Server & API)
* **Framework:** Java Spring Boot
* **Database:** PostgreSQL (Relational Data Management)
* **Security:** Spring Security with JWT (JSON Web Tokens) Authentication
* **Real-time Services:** Firebase

---

## 🚀 Getting Started

Follow these instructions to set up the project locally on your machine.

### Prerequisites
* [Flutter SDK](https://flutter.dev/docs/get-started/install) (Version 3.10+)
* [Java Development Kit (JDK)](https://www.oracle.com/java/technologies/javase-downloads.html) (Version 17 or higher)
* [PostgreSQL](https://www.postgresql.org/download/)
* [Maven](https://maven.apache.org/download.cgi)

### 1. Backend Setup (Spring Boot)
1. Navigate to the backend directory:
   ```bash
   cd lankatransit
