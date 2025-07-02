# SwiftUI Timetable App with JWT Authentication

This is a SwiftUI iOS app that authenticates users via a JWT token from a REST API, displays a schedule/timetable, and automatically refreshes the token by silently re-logging in before expiration.

---

## Features

- Login with username and password to get JWT access token
- JWT token decoded to extract user info (`Bakalari.PersonFullName`) and token expiration
- Display user full name and token expiry date in the UI
- Automatic token refresh by re-logging in with stored credentials when token is close to expiring
- Timetable displayed using a paged `TabView` with daily lessons loaded from API
- Logout functionality clears credentials and token

## Setup & Usage

1. Clone the repo

2. Open in Xcode 14+

3. Set your backend URLs in `TokenService` (currently uses `https://znamky.ggg.cz/api/login`)

4. Run the app on Simulator or device

5. Login with valid username and password

6. The app will load the timetable and show your full name and token expiration

7. Token automatically refreshes by re-logging in when close to expiry

## Security Notes

- Currently stores username/password and token in `UserDefaults` for simplicity — not secure for production
- For production, consider using Keychain to store credentials and token securely
- Consider adding proper error handling and user feedback on login failures

---

## License

This project is provided as-is for learning purposes.
