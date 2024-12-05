## InvenTree App Development

For developers looking to contribute to the project, we use Flutter for app development. The project has been tested in Android Studio (on both Windows and Mac) and also VSCode.

## Prerequisites

To build the app from source, you will need the following tools installed on your system:

- Android Studio (with Flutter and Dart plugins)

### iOS Development

For iOS development, you will need a Mac system with XCode installed.

### Java Version

Some versions of Android Studio ship with a built-in version of the Java JDK. However, the InvenTree app requires [JDK 17](https://www.oracle.com/java/technologies/javase/jdk17-archive-downloads.html) to be installed.

If you see any errors related to JDK version mismatch, download and install the correct version of the JDK (from the link above) and update your Android Studio settings to point to the correct JDK location:

```bash
flutter config --jdk-dir /path/to/jdk
```

## Invoke Tasks

We use the [invoke](https://www.pyinvoke.org) to run some core tasks - you will need python and invoke installed on your local system.

## Getting Started

Initial project setup (after you have installed all required dev tools) is as follows:

Generate initial translation files:

```
invoke translate
```

Install required flutter packages:
```
flutter pub get
```

You should now be ready to debug on a connected or emulated device!

## Building Release Versions

Building release versions for target platforms (either android or iOS) is simplified using invoke:

### Android

Build Android release:

```
invoke android
```

### iOS

Build iOS release:

```
invoke ios
```
