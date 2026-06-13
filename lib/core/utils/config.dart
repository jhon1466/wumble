class AppConfig {
  // Secrets are injected at build time via --dart-define / --dart-define-from-file.
  // See dart_defines.example.json. Never hardcode keys (this repo is public).
  static const String giphyApiKey =
      String.fromEnvironment('GIPHY_API_KEY', defaultValue: '');
  static const String cloudinaryCloudName =
      String.fromEnvironment('CLOUDINARY_CLOUD_NAME', defaultValue: 'dsub6ipzt');
}
