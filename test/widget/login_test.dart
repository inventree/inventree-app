/*
 * Widget tests for the login and MFA screens, handleAuthResult(),
 * and opening the login screen when the session expires.
 *
 * Network requests go to an in-process fake server (see fake_server.dart),
 * so any interaction which sends a request runs inside tester.runAsync()
 */

import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:flutter_test/flutter_test.dart";
import "package:one_context/one_context.dart";

import "package:inventree/api.dart";
import "package:inventree/auth/auth_manager.dart";
import "package:inventree/auth/auth_method.dart";
import "package:inventree/auth/auth_result.dart";
import "package:inventree/l10.dart";
import "package:inventree/settings/login.dart";
import "package:inventree/settings/login_mfa.dart";
import "package:inventree/user_profile.dart";
import "package:inventree/widget/dialogs.dart";

import "../fake_server.dart";
import "../setup.dart";

const String profileName = "Login Widget Test";
const String homeText = "Home screen";

late FakeInvenTreeServer server;

late GlobalKey<NavigatorState> navigatorKey;

InvenTreeAPI get api => InvenTreeAPI();

UserProfileDBManager get manager => UserProfileDBManager();

/*
 * Create a profile pointing at the fake server
 */
Future<UserProfile> fakeProfile() async {
  final UserProfile? existing = await manager.getProfileByName(profileName);

  if (existing != null) {
    await manager.deleteProfile(existing);
  }

  await manager.addProfile(UserProfile(name: profileName, server: server.url));

  return (await manager.getProfileByName(profileName))!;
}

/*
 * Show the home screen, and optionally push [screen] on top of it
 * (so that returning "home" can be checked)
 */
Future<void> pumpApp(WidgetTester tester, {Widget? screen}) async {
  // Tall enough to show the whole login form
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      builder: OneContext().builder,
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text(homeText)),
    ),
  );

  if (screen != null) {
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (context) => screen),
    );
    await tester.pumpAndSettle();
  }
}

/*
 * Perform [action] with real async (network) operations,
 * waiting until [done] (or a timeout), then rebuild the widget tree
 */
Future<void> runAndWait(
  WidgetTester tester,
  Future<void> Function() action, {
  required bool Function() done,
}) async {
  await tester.runAsync(() async {
    await action();

    for (int i = 0; i < 100 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    // Allow any work following the condition to complete (e.g. navigation)
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });

  await tester.pumpAndSettle();
}

Finder get usernameField => find.widgetWithText(TextFormField, L10().username);

Finder get passwordField => find.widgetWithText(TextFormField, L10().password);

Finder get loginButton => find.byIcon(TablerIcons.login);

Finder get mfaSubmitButton => find.byIcon(TablerIcons.transition_right);

Finder codeField(String label) => find.widgetWithText(TextFormField, label);

EditableText editable(WidgetTester tester, Finder field) =>
    tester.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );

void main() {
  setupTestEnv();

  setUp(() async {
    server = await FakeInvenTreeServer.start();
    // As in the app - OneContext (used to resolve colors) uses this navigator.
    // A new key for each test, so no state carries over
    OneContext().key = GlobalKey<NavigatorState>();
    navigatorKey = OneContext().key;
  });

  tearDown(() async {
    api.testNavigatorKey = null;
    api.disconnectFromServer();

    final UserProfile? profile = await manager.getProfileByName(profileName);

    if (profile != null) {
      await manager.deleteProfile(profile);
    }

    await server.close();
  });

  group("Login screen:", () {
    testWidgets("Empty fields fail validation without sending a request", (
      tester,
    ) async {
      await pumpApp(
        tester,
        screen: InvenTreeLoginWidget(
          UserProfile(name: profileName, server: server.url),
        ),
      );

      // Whitespace is not a username
      await tester.enterText(usernameField, "   ");

      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      expect(find.text(L10().usernameEmpty), findsOneWidget);
      expect(find.text(L10().passwordEmpty), findsOneWidget);
      expect(server.requests, isEmpty);

      // Still on the login screen
      expect(find.byType(InvenTreeLoginWidget), findsOneWidget);
    });

    testWidgets("Username is pre-filled, with focus on the password", (
      tester,
    ) async {
      await pumpApp(
        tester,
        screen: InvenTreeLoginWidget(
          UserProfile(name: profileName, server: server.url, username: "bob"),
        ),
      );

      expect(editable(tester, usernameField).controller.text, equals("bob"));
      expect(editable(tester, passwordField).controller.text, isEmpty);

      expect(editable(tester, passwordField).focusNode.hasFocus, isTrue);
      expect(editable(tester, usernameField).focusNode.hasFocus, isFalse);
    });

    testWidgets("Focus starts on the username when none is stored", (
      tester,
    ) async {
      await pumpApp(
        tester,
        screen: InvenTreeLoginWidget(
          UserProfile(name: profileName, server: server.url),
        ),
      );

      expect(editable(tester, usernameField).controller.text, isEmpty);
      expect(editable(tester, usernameField).focusNode.hasFocus, isTrue);
      expect(editable(tester, passwordField).focusNode.hasFocus, isFalse);
    });

    testWidgets("Insecure connection warning is only shown for HTTP", (
      tester,
    ) async {
      await pumpApp(
        tester,
        screen: InvenTreeLoginWidget(
          UserProfile(name: profileName, server: "http://example.com/"),
        ),
      );

      expect(find.text(L10().insecureConnection), findsOneWidget);
      expect(find.text("http://example.com/"), findsOneWidget);

      await pumpApp(
        tester,
        screen: InvenTreeLoginWidget(
          UserProfile(name: profileName, server: "https://example.com/"),
        ),
      );

      expect(find.text(L10().insecureConnection), findsNothing);
      expect(find.text("https://example.com/"), findsOneWidget);
    });

    testWidgets("Password visibility can be toggled", (tester) async {
      await pumpApp(
        tester,
        screen: InvenTreeLoginWidget(
          UserProfile(name: profileName, server: server.url),
        ),
      );

      expect(editable(tester, passwordField).obscureText, isTrue);

      await tester.tap(find.byIcon(TablerIcons.eye));
      await tester.pump();

      expect(editable(tester, passwordField).obscureText, isFalse);

      await tester.tap(find.byIcon(TablerIcons.eye_off));
      await tester.pump();

      expect(editable(tester, passwordField).obscureText, isTrue);
    });

    testWidgets("Login error is displayed", (tester) async {
      final profile = (await tester.runAsync(fakeProfile))!;

      await pumpApp(tester, screen: InvenTreeLoginWidget(profile));

      await tester.enterText(usernameField, "user");
      await tester.enterText(passwordField, "wrong");

      await runAndWait(
        tester,
        () => tester.tap(loginButton),
        done: () =>
            server.received("POST", "api/auth/v1/auth/login").isNotEmpty,
      );

      expect(find.text(L10().error), findsOneWidget);
      expect(
        find.text(
          "The username and/or password you specified are not correct.",
        ),
        findsOneWidget,
      );

      expect(find.byType(InvenTreeLoginWidget), findsOneWidget);
      expect(api.isConnected(), isFalse);
      expect(profile.hasSession, isFalse);
    });

    testWidgets("Keyboard 'done' on the password field logs in", (
      tester,
    ) async {
      final profile = (await tester.runAsync(fakeProfile))!;

      await pumpApp(tester, screen: InvenTreeLoginWidget(profile));

      await tester.enterText(usernameField, "user");
      await tester.enterText(passwordField, "password");

      await runAndWait(
        tester,
        () => tester.testTextInput.receiveAction(TextInputAction.done),
        done: () => api.isConnected(),
      );

      expect(api.isConnected(), isTrue);
      expect(find.byType(InvenTreeLoginWidget), findsNothing);
      expect(find.text(homeText), findsOneWidget);
    });
  });

  group("MFA screen:", () {
    AuthFlow mfaFlow(List<String> types) =>
        AuthFlow(id: FLOW_MFA_AUTHENTICATE, isPending: true, types: types);

    Future<void> pumpMfa(WidgetTester tester, List<String> types) => pumpApp(
      tester,
      screen: InvenTreeMfaWidget(
        UserProfile(name: profileName, server: server.url),
        mfaFlow(types),
      ),
    );

    testWidgets(
      "Recovery code switch is offered with TOTP and recovery codes",
      (tester) async {
        await pumpMfa(tester, [MFA_TYPE_TOTP, MFA_TYPE_RECOVERY_CODES]);

        expect(find.text(L10().mfaEnterCode), findsOneWidget);
        expect(codeField(L10().mfaCode), findsOneWidget);
        expect(
          editable(tester, codeField(L10().mfaCode)).keyboardType,
          equals(TextInputType.number),
        );

        await tester.tap(find.text(L10().mfaUseRecoveryCode));
        await tester.pumpAndSettle();

        expect(find.text(L10().mfaEnterRecoveryCode), findsOneWidget);
        expect(codeField(L10().mfaRecoveryCode), findsOneWidget);
        expect(codeField(L10().mfaCode), findsNothing);
        expect(
          editable(tester, codeField(L10().mfaRecoveryCode)).keyboardType,
          equals(TextInputType.visiblePassword),
        );

        // ...and back again
        await tester.tap(find.text(L10().mfaUseRecoveryCode));
        await tester.pumpAndSettle();

        expect(codeField(L10().mfaCode), findsOneWidget);
      },
    );

    testWidgets("No recovery code switch with TOTP only", (tester) async {
      await pumpMfa(tester, [MFA_TYPE_TOTP]);

      expect(find.text(L10().mfaUseRecoveryCode), findsNothing);
      expect(codeField(L10().mfaCode), findsOneWidget);
    });

    testWidgets("Recovery codes only asks for a recovery code", (tester) async {
      await pumpMfa(tester, [MFA_TYPE_RECOVERY_CODES]);

      expect(find.text(L10().mfaUseRecoveryCode), findsNothing);
      expect(find.text(L10().mfaEnterRecoveryCode), findsOneWidget);
      expect(codeField(L10().mfaRecoveryCode), findsOneWidget);
    });

    testWidgets("TOTP code accepts digits only", (tester) async {
      await pumpMfa(tester, [MFA_TYPE_TOTP, MFA_TYPE_RECOVERY_CODES]);

      await tester.enterText(codeField(L10().mfaCode), "12ab34");

      expect(
        editable(tester, codeField(L10().mfaCode)).controller.text,
        equals("1234"),
      );

      // Recovery codes are not restricted
      await tester.tap(find.text(L10().mfaUseRecoveryCode));
      await tester.pumpAndSettle();

      await tester.enterText(codeField(L10().mfaRecoveryCode), "ab12-cd34");

      expect(
        editable(tester, codeField(L10().mfaRecoveryCode)).controller.text,
        equals("ab12-cd34"),
      );
    });

    testWidgets("Empty code fails validation without sending a request", (
      tester,
    ) async {
      await pumpMfa(tester, [MFA_TYPE_TOTP]);

      await tester.tap(mfaSubmitButton);
      await tester.pumpAndSettle();

      expect(find.text(L10().mfaCodeEmpty), findsOneWidget);

      // Whitespace is not a code
      await pumpMfa(tester, [MFA_TYPE_RECOVERY_CODES]);

      await tester.enterText(codeField(L10().mfaRecoveryCode), "   ");
      await tester.tap(mfaSubmitButton);
      await tester.pumpAndSettle();

      expect(find.text(L10().mfaCodeEmpty), findsOneWidget);
      expect(server.requests, isEmpty);
    });

    Future<UserProfile> beginMfaLogin(WidgetTester tester) async {
      final UserProfile profile = (await tester.runAsync(() async {
        final UserProfile profile = await fakeProfile();

        final AuthResult result = await InvenTreeAuth().beginLogin(
          profile,
          PasswordAuthMethod("mfa", "password"),
        );

        expect(result.status, equals(AuthStatus.flowPending));

        return profile;
      }))!;

      await pumpApp(
        tester,
        screen: InvenTreeMfaWidget(profile, mfaFlow(server.mfaTypes)),
      );

      return profile;
    }

    testWidgets("Incorrect code is displayed", (tester) async {
      await beginMfaLogin(tester);

      await tester.enterText(codeField(L10().mfaCode), "000000");

      await runAndWait(
        tester,
        () => tester.tap(mfaSubmitButton),
        done: () => server
            .received("POST", "api/auth/v1/auth/2fa/authenticate")
            .isNotEmpty,
      );

      expect(find.text("Incorrect code."), findsOneWidget);
      expect(find.byType(InvenTreeMfaWidget), findsOneWidget);
      expect(api.isConnected(), isFalse);
    });

    for (final bool trust in [true, false]) {
      testWidgets("Trust device checkbox is sent to the server (${trust})", (
        tester,
      ) async {
        server.offerTrust = true;

        final profile = await beginMfaLogin(tester);

        // Unchecked by default
        expect(
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          isFalse,
        );

        if (trust) {
          await tester.tap(find.text(L10().mfaTrustDevice));
          await tester.pump();

          expect(
            tester
                .widget<CheckboxListTile>(find.byType(CheckboxListTile))
                .value,
            isTrue,
          );
        }

        await tester.enterText(codeField(L10().mfaCode), server.validCode);

        await runAndWait(
          tester,
          () => tester.tap(mfaSubmitButton),
          done: () => api.isConnected(),
        );

        final requests = server.received("POST", "api/auth/v1/auth/2fa/trust");
        expect(requests.length, equals(1));
        expect(requests.single.json["trust"], equals(trust));

        expect(api.isConnected(), isTrue);
        expect(profile.hasSession, isTrue);
        expect(find.byType(InvenTreeMfaWidget), findsNothing);
        expect(find.text(homeText), findsOneWidget);
      });
    }
  });

  group("handleAuthResult:", () {
    testWidgets("Successful login connects and returns home", (tester) async {
      final profile = (await tester.runAsync(fakeProfile))!;

      await pumpApp(tester, screen: InvenTreeLoginWidget(profile));

      await tester.enterText(usernameField, "user");
      await tester.enterText(passwordField, "password");

      await runAndWait(
        tester,
        () => tester.tap(loginButton),
        done: () => api.isConnected(),
      );

      expect(api.isConnected(), isTrue);
      expect(profile.hasSession, isTrue);
      expect(profile.username, equals("user"));

      expect(find.byType(InvenTreeLoginWidget), findsNothing);
      expect(find.text(homeText), findsOneWidget);
    });

    testWidgets("MFA required opens the MFA screen, then returns home", (
      tester,
    ) async {
      final profile = (await tester.runAsync(fakeProfile))!;

      await pumpApp(tester, screen: InvenTreeLoginWidget(profile));

      await tester.enterText(usernameField, "mfa");
      await tester.enterText(passwordField, "password");

      await runAndWait(
        tester,
        () => tester.tap(loginButton),
        done: () =>
            server.received("POST", "api/auth/v1/auth/login").isNotEmpty,
      );

      expect(find.byType(InvenTreeMfaWidget), findsOneWidget);
      expect(api.isConnected(), isFalse);

      await tester.enterText(codeField(L10().mfaCode), server.validCode);

      await runAndWait(
        tester,
        () => tester.tap(mfaSubmitButton),
        done: () => api.isConnected(),
      );

      expect(api.isConnected(), isTrue);

      // Both the MFA and login screens are closed
      expect(find.byType(InvenTreeMfaWidget), findsNothing);
      expect(find.byType(InvenTreeLoginWidget), findsNothing);
      expect(find.text(homeText), findsOneWidget);
    });

    /*
     * Call handleAuthResult() directly from the login screen,
     * returning the reported errors
     */
    Future<List<String>> handle(WidgetTester tester, AuthResult result) async {
      final UserProfile profile = UserProfile(
        name: profileName,
        server: server.url,
      );

      await pumpApp(tester, screen: InvenTreeLoginWidget(profile));

      final List<String> errors = [];

      await handleAuthResult(
        tester.element(find.byType(InvenTreeLoginWidget)),
        profile,
        result,
        errors.add,
      );

      await tester.pumpAndSettle();

      // No navigation
      expect(find.byType(InvenTreeLoginWidget), findsOneWidget);
      expect(find.byType(InvenTreeMfaWidget), findsNothing);

      return errors;
    }

    AuthResult pending(String id, {List<String> types = const []}) =>
        AuthResult(
          status: AuthStatus.flowPending,
          statusCode: 401,
          pendingFlow: AuthFlow(id: id, isPending: true, types: types),
        );

    testWidgets("Unsupported MFA types show an error", (tester) async {
      final errors = await handle(
        tester,
        pending(FLOW_MFA_AUTHENTICATE, types: [MFA_TYPE_WEBAUTHN]),
      );

      expect(errors, equals([L10().mfaUnsupported]));
    });

    testWidgets("Unsupported flows show an error", (tester) async {
      final errors = await handle(tester, pending(FLOW_VERIFY_EMAIL));

      expect(
        errors,
        equals(["${L10().authFlowUnsupported} (${FLOW_VERIFY_EMAIL})"]),
      );
    });

    testWidgets("Failure shows the server error message", (tester) async {
      final errors = await handle(tester, AuthResult.failed("Bad things"));

      expect(errors, equals(["Bad things"]));
    });

    testWidgets("Failure without a message describes the status code", (
      tester,
    ) async {
      final errors = await handle(
        tester,
        AuthResult(status: AuthStatus.failed, statusCode: 429),
      );

      expect(errors, equals([statusCodeToString(429)]));
      expect(errors.single, isNotEmpty);
    });
  });

  group("Session expiry:", () {
    testWidgets("Expiry while connected opens the login screen", (
      tester,
    ) async {
      api.testNavigatorKey = navigatorKey;

      await pumpApp(tester);

      final profile = (await tester.runAsync(() async {
        final profile = await fakeProfile();

        await InvenTreeAuth().beginLogin(
          profile,
          PasswordAuthMethod("user", "password"),
        );

        expect(await api.connectToServer(profile), isTrue);

        return profile;
      }))!;

      expect(find.byType(InvenTreeLoginWidget), findsNothing);

      server.endAllSessions();

      await runAndWait(
        tester,
        () => api.get("part/", expectedStatusCode: null),
        done: () => !api.isConnected(),
      );

      // Login screen for the expired profile, with the username kept
      expect(find.byType(InvenTreeLoginWidget), findsOneWidget);
      expect(find.text(profile.server), findsOneWidget);
      expect(editable(tester, usernameField).controller.text, equals("user"));

      // Further rejected requests do not open a second login screen
      await runAndWait(
        tester,
        () => api.get("stock/", expectedStatusCode: null),
        done: () => server.received("GET", "api/stock/").isNotEmpty,
      );

      expect(find.byType(InvenTreeLoginWidget), findsOneWidget);

      // Login again, returning to the home screen
      await tester.enterText(passwordField, "password");

      await runAndWait(
        tester,
        () => tester.tap(loginButton),
        done: () => api.isConnected(),
      );

      expect(api.isConnected(), isTrue);
      expect(api.suppressServerErrors, isFalse);
      expect(find.byType(InvenTreeLoginWidget), findsNothing);
      expect(find.text(homeText), findsOneWidget);
    });

    testWidgets("Dismissed login screen opens again on the next rejection", (
      tester,
    ) async {
      api.testNavigatorKey = navigatorKey;

      await pumpApp(tester);

      await tester.runAsync(() async {
        final profile = await fakeProfile();

        await InvenTreeAuth().beginLogin(
          profile,
          PasswordAuthMethod("user", "password"),
        );

        expect(await api.connectToServer(profile), isTrue);
      });

      server.endAllSessions();

      await runAndWait(
        tester,
        () => api.get("part/", expectedStatusCode: null),
        done: () => !api.isConnected(),
      );

      expect(find.byType(InvenTreeLoginWidget), findsOneWidget);
      expect(api.suppressServerErrors, isTrue);

      // User goes back without logging in
      await tester.runAsync(() async {
        navigatorKey.currentState!.pop();
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();

      expect(find.byType(InvenTreeLoginWidget), findsNothing);
      expect(api.suppressServerErrors, isFalse);

      await runAndWait(
        tester,
        () => api.get("part/", expectedStatusCode: null),
        done: () => server.received("GET", "api/part/").length >= 2,
      );

      expect(find.byType(InvenTreeLoginWidget), findsOneWidget);
    });
  });
}
