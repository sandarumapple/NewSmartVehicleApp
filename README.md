# Smart Garage

Smart Garage is my iOS coursework project built with SwiftUI. It helps users manage vehicles, maintenance, fuel, expenses and documents. It also includes community posts, a marketplace, nearby services, analytics and PDF reports.

The app supports iPhone and iPad.

## Requirements

- A Mac with Xcode 26.2 or newer
- iOS 17 or newer
- An internet connection
- The Firebase configuration file supplied privately for marking

## How to Run the App

1. Clone the repository:

   ```bash
   git clone https://github.com/sandarumapple/NewSmartVehicleApp.git
   cd NewSmartVehicleApp
   ```

2. Copy the privately supplied `GoogleService-Info.plist` file into the `SmartVehicleApp` folder.

3. Open `SmartVehicle.xcodeproj` in Xcode.

4. Wait for Xcode to download the package dependencies.

5. Select the `SmartVehicle` scheme and an iPhone or iPad simulator.

6. Press `Command + R` to build and run.

To run on a physical device, select your Apple Developer team under Signing & Capabilities. The app and widget targets need matching App Group settings.

Without the Firebase configuration file, local demo mode is available. Demo mode does not connect to the Firebase backend.

## Backend Access for Markers

The app uses Firebase Authentication for accounts and Cloud Firestore for online data. There is no separate server to start. The Firebase configuration file connects the app to the correct backend.

I will provide these through the university's private submission channel:

- `GoogleService-Info.plist`
- A test account email and password
- A second test account for checking community interactions

These details are not stored in this public repository. If they are missing, please contact me through the university submission system.

### Checking the Backend

1. Run the app with the supplied Firebase configuration.
2. Sign in using the test account.
3. Add a vehicle and a fuel, maintenance or expense record.
4. Sign out and sign back in to check that the saved data loads.

To check community notifications:

1. Create a post using the first account.
2. Sign in using the second account and like or comment on that post.
3. Sign back into the first account and open the notification inbox.

Markers can use the backend through the app without Firebase Console access. Firestore rules restrict private records to their owner.

The repository includes `firestore.rules`, `firestore.indexes.json` and `firebase.json` for reviewing the backend configuration.

## Notifications and Device Features

Community likes and comments create in-app notifications. Marketplace hearts are private bookmarks and do not notify the seller.

Background push delivery needs additional Cloud Functions and Apple push notification configuration. It is not enabled in the current marking setup.

Document camera scanning requires a supported physical device. Document photos can be imported in the simulator. Face ID requires a compatible device or an enrolled simulator biometric setup.

## Running Tests

1. Select the `SmartVehicle` scheme and a simulator in Xcode.
2. Press `Command + U` to run the tests.
3. Press `Command + 6` to view the Test Navigator.

There are 16 Swift Testing unit tests covering:

- Authentication validation
- Analytics calculations
- Vehicle model logic
- Marketplace data handling
- Community search and filtering

All 16 passed in the verified iPhone 17 simulator test run.

There are also six Firestore Emulator tests for notification behaviour and access rules. These run locally without changing production data.

With Node.js 20, Firebase CLI and Java 21 or newer installed, run:

```bash
firebase emulators:exec --only firestore --project demo-smartvehicle 'node --test functions/tests/community-notifications.test.js'
```

## Security

Do not commit passwords, API keys, tokens or service-account credentials.

The Firebase configuration file and local Firebase logs are excluded through `.gitignore`. Test credentials and configuration are shared privately for marking.

Firestore security rules control access to backend data.