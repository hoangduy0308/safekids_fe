# SafeKids Flutter App

Ứng dụng di động SafeKids - Giám sát và bảo vệ trẻ em cho phụ huynh.

##  Tính Năng Hiện Tại

###  Đã Hoàn Thành (Day 0 - Scaffold)
- **Authentication**: Đăng ký, đăng nhập với JWT
- **Role-Based UI**: Giao diện riêng cho Parent và Child
- **State Management**: Provider pattern
- **Real-time Ready**: Socket.IO service đã setup
- **API Integration**: HTTP service với backend Node.js
- **Theme System**: Design System v2.0 với màu sắc chuẩn

###  Đang Phát Triển (Day 1-10)
- Location tracking & maps
- Geofencing
- SOS emergency button
- Screen time management
- Push notifications
- Parent-Child linking

##  Kiến Trúc

```
lib/
 config/           # API & Socket config
 constants/        # Colors, text styles, constants
 models/          # Data models (User, etc.)
 providers/       # State management (Provider)
 screens/         # UI screens
    auth/       # Login, Register
    parent_home_screen.dart
    child_home_screen.dart
 services/        # Business logic
    auth_service.dart
    socket_service.dart
 widgets/         # Reusable UI components
 main.dart       # App entry point
```

##  Cài Đặt & Chạy

### 1. Cài Dependencies
```bash
flutter pub get
```

### 2. Chạy Backend
Đảm bảo backend Node.js đang chạy trên `http://localhost:3000`

```bash
cd ../backend
npm run dev
```

### 3. Chạy App
```bash
flutter run
```

Hoặc chạy trên emulator cụ thể:
```bash
flutter run -d <device-id>
```

##  Configuration

### API Endpoint
File: `lib/config/api_config.dart`
```dart
static const String baseUrl = 'http://localhost:3000/api';
```

**Lưu ý**: 
- iOS Simulator: `http://localhost:3000`
- Android Emulator: `http://10.0.2.2:3000`
- Physical Device: `http://<your-ip>:3000`

### Colors & Theme
File: `lib/constants/app_constants.dart`
- Design System v2.0 colors
- SOS emergency red: `#E53935`
- Primary blue: `#2196F3`
- Safe green: `#4CAF50`

##  Dependencies

### Core
- `provider` - State management
- `http` - API calls
- `socket_io_client` - Real-time communication

### Storage
- `shared_preferences` - Simple data storage
- `flutter_secure_storage` - Secure token storage

### Location & Maps
- `geolocator` - Location tracking
- `google_maps_flutter` - Map display
- `geocoding` - Address lookup

### Firebase
- `firebase_core` - Firebase SDK
- `firebase_messaging` - Push notifications

### Background
- `flutter_background_service` - Background tasks
- `workmanager` - Scheduled tasks

### Utils
- `logger` - Logging
- `intl` - Internationalization
- `fl_chart` - Charts & graphs

##  Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

##  Build

### Android APK
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

##  Authentication Flow

1. User opens app  AuthGate checks authentication
2. Not logged in  LoginScreen
3. Login/Register  AuthService calls backend API
4. Success  Save JWT token  Connect Socket.IO
5. Route to ParentHomeScreen or ChildHomeScreen based on role

##  API Integration

### Endpoints
- `POST /api/auth/register` - Đăng ký
- `POST /api/auth/login` - Đăng nhập
- `GET /api/auth/me` - Profile
- `POST /api/auth/link` - Link parent-child
- `PUT /api/auth/fcm-token` - Update FCM token

### Real-time Events (Socket.IO)
- `locationUpdate` - Cập nhật vị trí
- `geofenceAlert` - Cảnh báo ra khỏi khu vực
- `sosAlert` - Cảnh báo khẩn cấp
- `screentimeWarning` - Cảnh báo thời gian

##  Design System

Theo **Design System v2.0** từ wireframes:
- Material Design 3
- Vietnamese language
- Parent: Blue theme
- Child: Green theme
- SOS: Red pulsing button

##  TODO - Day 1

- [ ] Implement location service
- [ ] Add Google Maps
- [ ] Create location tracking screen
- [ ] Test real-time location updates
- [ ] Add permission handlers

##  Troubleshooting

### "Connection refused"
 Kiểm tra backend đang chạy và URL đúng (localhost vs 10.0.2.2)

### "Socket not connected"
 Đảm bảo đã login thành công trước khi connect socket

### "Token expired"
 Login lại để nhận token mới

##  License

This is a student thesis project (Đồ án tốt nghiệp).

---

**Last Updated**: Day 0 - October 9, 2025  
**Status**: Scaffold Complete  - Ready for Day 1 Development