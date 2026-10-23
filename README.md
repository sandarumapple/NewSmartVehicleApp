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

## Community notifications

Likes and comments save an inbox notification for the post's owner in the same
Firestore batch. Reactions to your own posts do not notify you. The dashboard
bell shows the unread count; opening a notification marks it as read. Marketplace
hearts remain private saved listings and do not notify sellers.

When notification permission is allowed, the app presents the latest unread
community activity when it receives it while active, including after sign-in.
Already announced events are remembered separately for each account.

Background remote delivery additionally requires the function in `functions/index.js`
to be deployed on a Firebase Blaze project, an APNs key configured in Firebase
Cloud Messaging, and the Push Notifications capability enabled for the app.
Inbox delivery does not require a Cloud Function or APNs.

To test the Firestore notification rules without real accounts or production data,
install Firebase CLI and Java 21 or newer, then run from the project directory:

```sh
firebase emulators:exec --only firestore --project demo-smartvehicle 'node --test functions/tests/community-notifications.test.js'
```

The tests cover cross-account likes and comments, unlike/re-like, read permissions,
forged notifications, and rollback when one write in a batch fails.

## Project folders

- `SmartVehicleApp/Models` - data models
- `SmartVehicleApp/ViewModels` - view-related calculations and validation
- `SmartVehicleApp/Services` - app data, Firebase and iOS services
- `SmartVehicleApp/Views` - SwiftUI screens
- `SmartVehicleWidget` - home screen widget

## Notes

Some device features such as Face ID, notifications, document scanning and widgets may work differently in the simulator. A physical device and the correct Apple capabilities are needed to test all of them.

The app stores a local copy of vehicle data and synchronizes it with Firestore when Firebase is available.
