// Default to Android emulator localhost mapping;
// override with --dart-define=BASE_URL=http://localhost:3000 for iOS simulator
const String baseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'https://vessel-catfish-unstopped.ngrok-free.dev',
);
