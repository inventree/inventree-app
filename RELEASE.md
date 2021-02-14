# Release Process

## Android Play Store

[Reference](https://flutter.dev/docs/deployment/android#signing-the-app)

### Key File

Add a file `key.properties` under the android/ directory

### Increment Build Number

Make sure that the build number is incremented every time (or it will be rejected by Play Store).

### Build Appbundle

`flutter build appbundle`
