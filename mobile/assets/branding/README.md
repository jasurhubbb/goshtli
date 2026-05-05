# Branding assets

Drop the source app icon here so flutter_launcher_icons can generate every platform-specific size from one file.

## Required file

| Path | Spec | Why |
|---|---|---|
| `app_icon.png` | **1024×1024 PNG, no transparency, no rounded corners, full bleed** | Source for all Android densities (mdpi → xxxhdpi) + iOS AppIcon.appiconset |

Apple/Google both apply rounded corners + safe-area masking themselves — supply a square, opaque image and let the platforms handle the masking.

## Generate icons

After dropping `app_icon.png` here:

```bash
cd mobile
flutter pub get
flutter pub run flutter_launcher_icons
```

This rewrites every file under `android/app/src/main/res/mipmap-*/` and `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.

## If you don't have an icon yet

Until you have one, builds use Flutter's default icon. Internal testing on Play Console accepts that. Production listing requires a real icon — Play Console rejects uploads with the default Flutter icon visible.

For a quick placeholder: any 1024×1024 PNG of a meat / butcher / market motif works. Free options: <https://www.flaticon.com>, <https://thenounproject.com> (need attribution), or generate one in a couple minutes via Figma / Canva / Photoshop.
