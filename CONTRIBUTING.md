# Contributing to InvenTree App

Thank you for considering contributing to the InvenTree App! This document outlines some guidelines to ensure smooth collaboration.

## Code Style and Formatting

### Dart Formatting

We enforce consistent code formatting using Dart's built-in formatter. Before submitting a pull request:

1. Run the formatter on your code:
   ```bash
   fvm dart format .
   ```

2. Our CI pipeline will verify that all code follows the standard Flutter/Dart formatting rules. Pull requests with improper formatting will fail CI checks.

### General Guidelines

- Write clear, readable, and maintainable code
- Include comments where necessary
- Follow Flutter/Dart best practices
- Write tests for new features when applicable

## Pull Request Process

1. Fork the repository and create a feature branch
2. Make your changes
3. Ensure your code passes all tests and linting
4. Format your code using `invoke format`
5. Submit a pull request with a clear description of the changes
6. Address any review comments

## Development Setup

1. Ensure you have Flutter installed (we use Flutter Version Management)
2. Check the required Flutter version in the `.fvmrc` file
3. Install dependencies with `fvm flutter pub get`
4. Run tests with `fvm flutter test`

## Reporting Issues

When reporting issues, please include:
- Clear steps to reproduce the issue
- Expected behavior
- Actual behavior
- Screenshots if applicable
- Device/environment information

Thank you for contributing to the InvenTree App!
