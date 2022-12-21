# Release Process

## Android Play Store

[Reference](https://flutter.dev/docs/deployment/android#signing-the-app)

### Key File

Add a file `key.properties` under the android/ directory

### Increment Build Number

Make sure that the build number is incremented every time (or it will be rejected by Play Store).

### Copy Translations

Ensure that the translation files have been updated, and copied into the correct directory!!

```
cd lib/l10n
python collect_translations.py
```

### Build Appbundle

`flutter build appbundle`

### Upload Appbundle

Upload the appbundle file to the Android developer website.

## Apple Store

Ref: https://flutter.dev/docs/deployment/ios

### Build ipa

```
flutter clean
flutter build ipa --release --no-tree-shake-icons
```

### Validate and Distribute

- Open `./build/ios/archive/Runner.xcarchive` in Xcode
- Run "Validate App"
- Run "Distribute App"