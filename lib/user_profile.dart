import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:sembast/sembast.dart";

import "package:inventree/helpers.dart";
import "package:inventree/preferences.dart";

class UserProfile {
  UserProfile({
    this.key,
    this.name = "",
    this.server = "",
    this.token = "",
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
    // Legacy field - profiles saved before the token moved to secure storage
    // may still have it here. UserProfileDBManager migrates this on read.
    token: (json["token"] ?? "") as String,
    selected: isSelected,
    trustedCertificate: (json["trustedCertificate"] ?? false) as bool,
  );

  // Return true if this profile has a token
  bool get hasToken => token.isNotEmpty;

  // ID of the profile
  int? key;

  // Name of the user profile
  String name = "";

  // Base address of the InvenTree server
  String server = "";

  // API token - held in memory only; persisted separately in secure storage
  // (see UserProfileDBManager), never written to the plain profile record
  String token = "";

  bool selected = false;

  // Whether the user has explicitly chosen to trust this server's TLS
  // certificate despite it failing validation (e.g. self-signed)
  bool trustedCertificate = false;

  // User ID (will be provided by the server on log-in)
  int user_id = -1;

  Map<String, dynamic> toJson() => {
    "name": name,
    "server": server,
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

  static const _secureStorage = FlutterSecureStorage();

  Future<Database> get _db async => InvenTreePreferencesDB.instance.database;

  // Key used to store a profile's API token in secure storage
  String _tokenStorageKey(int key) => "profile_token_${key}";

  /*
   * Persist (or clear) a profile's token in secure storage, keyed by its
   * database record id. The token never lives in the plain Sembast record.
   */
  Future<void> _saveToken(int key, String token) async {
    if (token.isEmpty) {
      await _secureStorage.delete(key: _tokenStorageKey(key));
    } else {
      await _secureStorage.write(key: _tokenStorageKey(key), value: token);
    }
  }

  /*
   * Populate a profile's in-memory token from secure storage.
   * If secure storage has nothing for this profile, but the (legacy)
   * Sembast record still has a plaintext token from before this migration,
   * adopt it once and move it into secure storage.
   */
  Future<UserProfile> _loadToken(UserProfile profile) async {
    final int? key = profile.key;

    if (key == null) {
      return profile;
    }

    final String? secureToken = await _secureStorage.read(
      key: _tokenStorageKey(key),
    );

    if (secureToken != null) {
      profile.token = secureToken;
    } else if (profile.token.isNotEmpty) {
      // Legacy profile - migrate its plaintext token into secure storage,
      // and strip it from the Sembast record on next write
      await _saveToken(key, profile.token);
      await store.record(key).update(await _db, profile.toJson());
    }

    return profile;
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

    if (key != null) {
      await _saveToken(key, profile.token);
    }

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

    await store.record(profile.key).update(await _db, profile.toJson());
    await _saveToken(profile.key!, profile.token);

    return true;
  }

  /*
   * Remove a user profile from the database
   */
  Future<void> deleteProfile(UserProfile profile) async {
    debug("deleteProfile: ${profile.name}");

    await store.record(profile.key).delete(await _db);

    if (profile.key != null) {
      await _secureStorage.delete(key: _tokenStorageKey(profile.key!));
    }
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

        return _loadToken(profile);
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

        profileList.add(await _loadToken(profile));
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
