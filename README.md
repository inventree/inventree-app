# InvenTree Mobile App

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![Android](https://github.com/inventree/inventree-app/actions/workflows/android.yaml/badge.svg)
![iOS](https://github.com/inventree/inventree-app/actions/workflows/ios.yaml/badge.svg)
[![Coverage Status](https://coveralls.io/repos/github/inventree/inventree-app/badge.svg?branch=master)](https://coveralls.io/github/inventree/inventree-app?branch=master)

The InvenTree mobile / tablet application is a companion app for the [InvenTree stock management system](https://github.com/inventree/InvenTree).

Written in the [Flutter](https://flutter.dev/) environment, the app provides native support for Android and iOS devices.

## User Documentation

User documentation for the InvenTree mobile app can be found [within the InvenTree documentation](https://inventree.readthedocs.io/en/latest/app/app/).

## Developer Documentation

For developers looking to contribute to the project, we use Flutter for app development. The project has been tested in Android Studio (on both Windows and Mac) and also VSCode.

### Invoke Tasks

We use the [invoke](https://www.pyinvoke.org) to run some core tasks - you will need python and invoke installed on your local system.

### Getting Started

Initial project setup (after you have installed all required dev tools) is as follows:

Install required flutter packages:
```
flutter pub get
```

Generate initial translation files:

```
invoke translate
```

You should now be ready to debug on a connected or emulated device!

### Building Release Versions

Building release versions for target platforms (either android or iOS) is simplified using invoke:

Build Android release:

```
invoke android
```

Build iOS release:

```
invoke ios
```