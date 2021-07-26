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
python update_translations.py
```

### Build Appbundle

`flutter build appbundle`
