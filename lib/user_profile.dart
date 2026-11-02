import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:sembast/sembast.dart";

import "package:inventree/auth/session_store.dart";
import "package:inventree/helpers.dart";
import "package:inventree/preferences.dart";

class UserProfile {
  UserProfile({
    this.key,
    this.name = "",
    this.server = "",
    this.username = "",
    this.selected = false,
    this.trustedCertificate = false,
  });

  factory UserProfile.fromJson(
    int key,
    Map<String, dynamic> json,
    bool isSelected,
  ) => UserProfile(
    key: key,
    name: (json["name"] ?? "") as String,
    server: (json["server"] ?? "") as String,
    username: (json["username"] ?? "") as String,
    selected: isSelected,
    trustedCertificate: (json["trustedCertificate"] ?? false) as bool,
  );

  // ID of the profile
  int? key;

  // Name of the user profile
  String name = "";

  // Base address of the InvenTree server
  String server = "";

  // Username (or email) used for the last successful login - pre-fills the login form.
  // Kept on logout. The password is never stored
  String username = "";

  // Does this profile have a stored session (populated from secure storage
  // by UserProfileDBManager). The session itself is never held on the profile
  bool hasSession = false;

  bool selected = false;

  // Whether the user has explicitly chosen to trust this server's TLS
  // certificate despite it failing validation (e.g. self-signed)
  bool trustedCertificate = false;

  // User ID (will be provided by the server on log-in)
  int user_id = -1;

  Map<String, dynamic> toJson() => {
    "name": name,
    "server": server,
    "username": username,
    "trustedCertificate": trustedCertificate,
  };

  @override
  String toString() {
    return "<${key}> ${name} : ${server}";
  }
}

/*
 * Class for storing and managing user (server) profiles
 */
class UserProfileDBManager {
  final store = StoreRef("profiles");

  // Session cookies are only accessible on this device (not synced or restored to another device):
  // - iOS: keychain item, "this device only" and not synchronizable
  // - Android: AES-GCM, with the key wrapped by a non-exportable KeyStore key.
  //   The storage files are excluded from backup (see res/xml/*_rules.xml)
  static const _secureStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<Database> get _db async => InvenTreePreferencesDB.instance.database;

  // Key used to store a profile's session cookies in secure storage
  String _sessionStorageKey(int key) => "profile_session_${key}";

  // Key used to store a profile's API token (legacy - removed by migrateLegacyTokens)
  String _legacyTokenStorageKey(int key) => "profile_token_${key}";

  /*
   * Load the stored session cookies for the provided profile
   */
  Future<SessionStore> loadSession(UserProfile profile) async {
    final int? key = profile.key;

    if (key == null) {
      return SessionStore(server: profile.server);
    }

    String? data;

    try {
      data = await _secureStorage.read(key: _sessionStorageKey(key));
    } catch (error) {
      debug("loadSession() : Error reading secure storage - ${error}");
    }

    final SessionStore session = SessionStore.fromJson(profile.server, data);

    // Stored cookies belong to a different server address - remove them
    if (session.rejected) {
      debug(
        "loadSession() : Stored session discarded - server address changed",
      );
      await clearSession(profile);
    }

    return session;
  }

  /*
   * Persist the session cookies for the provided profile.
   * The cookies are only ever stored in secure storage, never in the profile record.
   */
  Future<bool> saveSession(UserProfile profile, SessionStore session) async {
    final int? key = profile.key;

    // Profile is not stored - so there is nowhere to store the session
    if (key == null) {
      return false;
    }

    // Cookies being written - taken before the (asynchronous) write,
    // in case the jar changes in the meantime
    final snapshot = session.snapshot();

    try {
      if (session.isEmpty) {
        await _secureStorage.delete(key: _sessionStorageKey(key));
      } else {
        await _secureStorage.write(
          key: _sessionStorageKey(key),
          value: session.toJson(),
        );
      }
    } catch (error) {
      debug("saveSession() : Error writing secure storage - ${error}");
      return false;
    }

    session.markPersisted(snapshot);

    return true;
  }

  /*
   * Remove all stored session cookies for the provided profile.
   * Returns false if the stored cookies could not be removed.
   */
  Future<bool> clearSession(UserProfile profile) async {
    final int? key = profile.key;

    if (key == null) {
      return true;
    }

    try {
      await _secureStorage.delete(key: _sessionStorageKey(key));
    } catch (error) {
      debug("clearSession() : Error writing secure storage - ${error}");
      return false;
    }

    return true;
  }

  /*
   * Remove the session (and CSRF) cookies from storage for the provided profile.
   * Other cookies (e.g. MFA "trusted device") are retained where possible.
   *
   * Returns false if a stored session may remain - the caller must not report
   * the session as removed (e.g. on logout).
   */
  Future<bool> removeStoredSession(
    UserProfile profile,
    SessionStore session,
  ) async {
    session.clearAuthCookies();

    if (await saveSession(profile, session)) {
      return true;
    }

    // Could not update the stored cookies - remove them all instead
    return clearSession(profile);
  }

  // Populate the "hasSession" flag for the provided profile
  Future<UserProfile> _loadSessionState(UserProfile profile) async {
    profile.hasSession = (await loadSession(profile)).hasSession;
    return profile;
  }

  /*
   * One-time removal of API tokens stored by earlier versions of the app,
   * which used token authentication (now replaced by session authentication).
   * Tokens are removed from secure storage, and any (older) plaintext
   * token is stripped from the profile record.
   */
  Future<void> migrateLegacyTokens() async {
    const String MIGRATION_KEY = "legacy_tokens_removed";

    if (await InvenTreeSettingsManager().getBool(MIGRATION_KEY, false)) {
      return;
    }

    final db = await _db;
    final records = await store.find(db);

    // Only mark the migration as complete if every token was removed
    bool complete = true;

    for (final record in records) {
      if (record.key is! int) {
        continue;
      }

      final int key = record.key! as int;

      try {
        await _secureStorage.delete(key: _legacyTokenStorageKey(key));
      } catch (error) {
        debug(
          "migrateLegacyTokens() : Error writing secure storage - ${error}",
        );

        // Continue with the remaining profiles - but retry on next startup
        complete = false;
      }

      final value = record.value;

      if (value is Map<String, dynamic> && value.containsKey("token")) {
        // put() (full replace) rather than update() (merge), so the field is removed
        await store
            .record(key)
            .put(db, UserProfile.fromJson(key, value, false).toJson());
      }
    }

    if (!complete) {
      debug("migrateLegacyTokens() : Incomplete - will retry on next startup");
      return;
    }

    await InvenTreeSettingsManager().setValue(MIGRATION_KEY, true);
  }

  /*
   * Remove any secure storage entries which do not belong to an existing profile.
   *
   * Secure storage can outlive the profile database - e.g. iOS keychain items
   * survive an app uninstall. Profile keys restart after a reinstall, so a new
   * profile could otherwise inherit the session of an old (unrelated) profile.
   * Legacy API tokens are also removed (for any profile).
   * Must be called before any profiles are created on startup.
   */
  Future<void> removeOrphanedSessions() async {
    final db = await _db;
    final Set<int> profileKeys = (await store.findKeys(
      db,
    )).whereType<int>().toSet();

    // Session (and legacy token) entries - see _sessionStorageKey()
    final RegExp keyPattern = RegExp(r"^profile_(session|token)_(\d+)$");

    List<String> names = [];

    try {
      names = (await _secureStorage.readAll()).keys.toList();
    } catch (error) {
      debug(
        "removeOrphanedSessions() : Error accessing secure storage - ${error}",
      );
    }

    for (final String name in names) {
      final match = keyPattern.firstMatch(name);

      if (match == null) {
        continue;
      }

      // Legacy API tokens are never used, so are always removed (even if
      // migrateLegacyTokens() could not remove them for an existing profile)
      final bool legacyToken = match.group(1) == "token";

      if (!legacyToken && profileKeys.contains(int.tryParse(match.group(2)!))) {
        continue;
      }

      // Each entry is removed separately, so one failure does not prevent the rest
      try {
        await _secureStorage.delete(key: name);
      } catch (error) {
        debug(
          "removeOrphanedSessions() : Error writing secure storage - ${error}",
        );
      }
    }
  }

  /*
   * Check if a profile with the specified name exists in the database
   */
  Future<bool> profileNameExists(String name) async {
    final profiles = await getAllProfiles();

    for (var prf in profiles) {
      if (name == prf.name) {
        return true;
      }
    }

    // No match found!
    return false;
  }

  /*
   * Add a new UserProfile to the profiles database.
   */
  Future<bool> addProfile(UserProfile profile) async {
    if (profile.name.isEmpty) {
      debug(
        "addProfile() : Profile missing required values - not adding to database",
      );
      return false;
    }

    // Check if a profile already exists with the name
    final bool exists = await profileNameExists(profile.name);

    if (exists) {
      debug("addProfile() : UserProfile '${profile.name}' already exists");
      return true;
    } else {
      debug("Adding new profile: '${profile.name}'");
    }

    int? key = await store.add(await _db, profile.toJson()) as int?;

    // Record the key
    profile.key = key;

    return true;
  }

  /*
   * Update the selected profile in the database.
   * The unique integer <key> is used to determine if the profile already exists.
   */
  Future<bool> updateProfile(UserProfile profile) async {
    // Prevent invalid profile data from being updated
    if (profile.name.isEmpty) {
      debug("updateProfile() : Profile missing required values - not updating");
      return false;
    }

    if (profile.key == null) {
      bool result = await addProfile(profile);
      return result;
    }

    // put() (full replace) rather than update() (merge), so that any stale
    // fields (e.g. a legacy "token") do not survive a write
    await store.record(profile.key).put(await _db, profile.toJson());

    return true;
  }

  /*
   * Remove a user profile from the database
   */
  Future<void> deleteProfile(UserProfile profile) async {
    debug("deleteProfile: ${profile.name}");

    await store.record(profile.key).delete(await _db);

    await clearSession(profile);
  }

  /*
   * Return the currently selected profile.
   * The key of the UserProfile should match the "selected" property
   */
  Future<UserProfile?> getSelectedProfile() async {
    final selected = await store.record("selected").get(await _db);

    final profiles = await store.find(await _db);

    debug(
      "getSelectedProfile() : ${profiles.length} profiles available - selected = ${selected}",
    );

    for (int idx = 0; idx < profiles.length; idx++) {
      if (profiles[idx].key is int && profiles[idx].key == selected) {
        final profile = UserProfile.fromJson(
          profiles[idx].key! as int,
          profiles[idx].value! as Map<String, dynamic>,
          profiles[idx].key == selected,
        );

        return _loadSessionState(profile);
      }
    }

    return null;
  }

  /*
   * Return all user profile objects
   */
  Future<List<UserProfile>> getAllProfiles() async {
    final selected = await store.record("selected").get(await _db);

    final profiles = await store.find(await _db);

    List<UserProfile> profileList = [];

    for (int idx = 0; idx < profiles.length; idx++) {
      if (profiles[idx].key is int) {
        final profile = UserProfile.fromJson(
          profiles[idx].key! as int,
          profiles[idx].value! as Map<String, dynamic>,
          profiles[idx].key == selected,
        );

        profileList.add(await _loadSessionState(profile));
      }
    }

    return profileList;
  }

  /*
   * Seed a demo server profile, if this is the first time the app has been
   * run with zero profiles configured. Explicit (called once from app
   * startup) rather than a side effect of reading the profile list.
   */
  Future<void> seedDemoProfileIfNeeded() async {
    final profiles = await getAllProfiles();

    if (profiles.isNotEmpty) {
      return;
    }

    bool added = await InvenTreeSettingsManager().getBool(
      "demo_profile_added",
      false,
    );

    // Don't add a new profile if we have added it previously
    if (added) {
      return;
    }

    await InvenTreeSettingsManager().setValue("demo_profile_added", true);

    UserProfile demoProfile = UserProfile(
      name: "InvenTree Demo",
      server: "https://demo.inventree.org",
    );

    await addProfile(demoProfile);
  }

  /*
   * Retrieve a profile by key (or null if no match exists)
   */
  Future<UserProfile?> getProfileByKey(int key) async {
    final profiles = await getAllProfiles();

    UserProfile? prf;

    for (UserProfile profile in profiles) {
      if (profile.key == key) {
        prf = profile;
        break;
      }
    }

    return prf;
  }

  /*
   * Retrieve a profile by name (or null if no match exists)
   */
  Future<UserProfile?> getProfileByName(String name) async {
    final profiles = await getAllProfiles();

    UserProfile? prf;

    for (UserProfile profile in profiles) {
      if (profile.name == name) {
        prf = profile;
        break;
      }
    }

    return prf;
  }

  /*
   * Mark the particular profile as selected
   */
  Future<void> selectProfile(int key) async {
    await store.record("selected").put(await _db, key);
  }

  /*
   * Look-up and select a profile by name.
   * Return true if the profile was selected
   */
  Future<bool> selectProfileByName(String name) async {
    var profiles = await getAllProfiles();

    for (var prf in profiles) {
      if (prf.name == name) {
        int key = prf.key ?? -1;

        if (key >= 0) {
          await selectProfile(key);
          return true;
        }
      }
    }

    return false;
  }
}
