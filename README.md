# Smart Vehicle Maintenance App

This is an iOS application made for managing personal vehicle information. It was built with SwiftUI as a coursework project.

The main purpose of the app is to keep vehicle details, maintenance records, expenses and documents in one place. It also has a small marketplace and community section for vehicle owners.

## Main features

- Add and manage vehicles
- Save maintenance and fuel records
- Track vehicle expenses
- Store document details and scan documents
- View spending charts and reports
- Maintenance and document reminders
- Marketplace and community posts
- Nearby vehicle-related locations
- Home screen widget
- Firebase email and Google sign-in

## Requirements

- Xcode 26.2 or newer
- iOS 17 or newer
- A Firebase project for online features

## Running the project

1. Open `SmartVehicle.xcodeproj` in Xcode.
2. Select the `SmartVehicle` scheme.
3. Choose an iPhone simulator or a connected device.
4. Press Run.

The widget is included as a separate target. Running it on a physical device requires the same Apple Developer team and App Group to be selected for both targets.

## Firebase setup

The local `GoogleService-Info.plist` file is not included in Git. To use Firebase, download this file from the Firebase Console and place it inside the `SmartVehicleApp` folder.

Firebase Authentication and Firestore are used for accounts and shared data. The Firestore rules and indexes used by the project are included in:

- `firestore.rules`
- `firestore.indexes.json`
- `firebase.json`

If Firebase is not configured, the app can still be opened with local demo data.

## Project folders

- `SmartVehicleApp/Models` - data models
- `SmartVehicleApp/ViewModels` - view-related calculations and validation
- `SmartVehicleApp/Services` - app data, Firebase and iOS services
- `SmartVehicleApp/Views` - SwiftUI screens
- `SmartVehicleWidget` - home screen widget

## Notes

Some device features such as Face ID, notifications, document scanning and widgets may work differently in the simulator. A physical device and the correct Apple capabilities are needed to test all of them.

The app stores a local copy of vehicle data and synchronizes it with Firestore when Firebase is available.
