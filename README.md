SoundImplosion App

## Firebase Hosting

This repository is configured to publish the Flutter web app with Firebase Hosting.

Build the site:

```bash
flutter build web
```

Deploy only Hosting:

```bash
firebase deploy --only hosting
```

The hosting configuration serves `build/web` and rewrites all routes to `index.html`, which is required for Flutter web navigation.