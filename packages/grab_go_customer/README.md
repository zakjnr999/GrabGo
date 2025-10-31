# GrabGo - Food Delivery App

A Flutter-based food delivery application with Google Sign-In authentication.

## Features

- 🔐 Google Sign-In Authentication
- 🍔 Food Ordering System
- 🛒 Shopping Cart
- 💳 Payment Integration (Paystack)
- 📍 Location Services
- 🌓 Dark/Light Theme Support
- 📱 Responsive UI

---

## Project Structure

```
lib/
├── auth/           # Authentication screens
├── core/           # Core utilities and models
├── pages/          # Main app screens
├── services/       # Business logic and API services
├── utils/          # Helper functions and constants
└── widgets/        # Reusable UI components
```

## Security Notes

**NEVER commit these files to git:**
- `*.jks` / `*.keystore` - Your signing keys
- `android/key.properties` - Contains passwords
- `android/app/google-services.json` - API credentials

These are already in `.gitignore`.

---

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Google Sign-In Package](https://pub.dev/packages/google_sign_in)
- [Firebase Console](https://console.firebase.google.com/)
- [Google Cloud Console](https://console.cloud.google.com/)

## License

This project is private and proprietary.