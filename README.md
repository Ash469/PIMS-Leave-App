# PIMS - Prasad Institute of Medical Sciences App

PIMS is a comprehensive leave management system designed for the Prasad Institute of Medical Sciences. The app facilitates seamless leave tracking and approval workflows for students, parents, wardens, and guards, ensuring efficient communication and management.

## Key Features

- **Role-based Access**: Tailored interfaces for students, parents, wardens, and guards.
- **Leave Request Management**: Students can create, view, and track leave requests.
- **Approval Workflow**: Two-step approval process (parent → warden).
- **File Attachments**: Upload supporting documents like medical certificates.
- **QR Code Generation**: Approved leaves generate QR codes for gate verification.
- **Notifications**: Real-time in-app notifications for leave updates.
- **Data Persistence**: Offline access with local storage.
- **Raise Concerns**: Guards can raise concerns with optional document attachments.

## Tech Highlights

- **Frontend**: Flutter for cross-platform mobile app development.
- **Backend**: Node.js API hosted on Render.
- **Database**: MongoDB for efficient data storage.
- **Authentication**: Firebase Authentication with Google Sign-In.
- **Push Notifications**: Firebase Cloud Messaging (FCM) for real-time updates.

## Project Structure

```
lib/
├── main.dart                  # App entry point
├── models/
│   └── data_models.dart       # Data models for users, leave requests, etc.
├── screens/
│   ├── role_selection_screen.dart    # Initial role selection screen
│   ├── login_screen.dart             # Login screen for all roles
│   ├── student_dashboard_screen.dart # Student main screen
│   ├── parent_dashboard_screen.dart  # Parent main screen
│   ├── warden_dashboard_screen.dart  # Warden main screen
│   ├── guard_dashboard_screen.dart   # Guard main screen
│   ├── leave_request_screen.dart     # Leave request form
│   ├── notifications_screen.dart     # Notifications screen
│   └── raise_concern_screen.dart     # Raise concern form
├── services/
│   ├── auth_service.dart             # Authentication services
│   ├── leave_service.dart            # Leave management services
│   ├── parent_service.dart           # Parent-specific services
│   ├── guard_service.dart            # Guard-specific services
│   ├── concern_service.dart          # Concern management services
│   └── fcm_service.dart              # Firebase Cloud Messaging services
└── firebase_options.dart             # Firebase configuration
```

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/your-repo/pims_app.git
   cd pims_app
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure Firebase:
   - Add your `google-services.json` file to `android/app/`.
   - Add your `GoogleService-Info.plist` file to `ios/Runner/`.

4. Run the app:
   ```bash
   flutter run
   ```

## Screenshots

| Role Selection Screen | Student Dashboard | Leave Request Form |
|------------------------|-------------------|--------------------|
| ![Role Selection](assets/screenshots/role_selection.png) | ![Student Dashboard](assets/screenshots/student_dashboard.png) | ![Leave Request](assets/screenshots/leave_request.png) |

## Authentication

Login is exclusively available via **Google Sign-In** for authorized students, parents, wardens, and guards. Ensure your email is registered with the institution to access the app.

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository.
2. Create a new branch:
   ```bash
   git checkout -b feature-name
   ```
3. Commit your changes:
   ```bash
   git commit -m "Add feature-name"
   ```
4. Push to the branch:
   ```bash
   git push origin feature-name
   ```
5. Open a pull request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgements

- Prasad Institute of Medical Sciences, Lucknow for the opportunity to develop this application
- Flutter team for the amazing framework

