
import "package:sembast/sembast.dart";

import "package:inventree/helpers.dart";
import "package:inventree/preferences.dart";

class UserProfile {

  UserProfile({
    this.key,
    this.name = "",
    this.server = "",
    this.username = "",
    this.password = "",
    this.selected = false,
  });

  factory UserProfile.fromJson(int key, Map<String, dynamic> json, bool isSelected) => UserProfile(
    key: key,
    name: json["name"] as String,
    server: json["server"] as String,
    username: json["username"] as String,
    password: json["password"] as String,
    selected: isSelected,
  );

  // ID of the profile
  int? key;

  // Name of the user profile
  String name = "";

  // Base address of the InvenTree server
  String server = "";

  // Username
  String username = "";

  // Password
  String password = "";

  bool selected = false;

  // User ID (will be provided by the server on log-in)
  int user_id = -1;

  Map<String, dynamic> toJson() => {
    "name": name,
    "server": server,
    "username": username,
    "password": password,
  };

  @override
  String toString() {
    return "<${key}> ${name} : ${server} - ${username}:${password}";
  }
}

class UserProfileDBManager {

  final store = StoreRef("profiles");

  Future<Database> get _db async => InvenTreePreferencesDB.instance.database;

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

    if (profile.name.isEmpty || profile.username.isEmpty || profile.password.isEmpty) {
      debug("addProfile() : Profile missing required values - not adding to database");
      return false;
    }

    // Check if a profile already exists with the name
    final bool exists = await profileNameExists(profile.name);

    if (exists) {
      debug("addProfile() : UserProfile '${profile.name}' already exists");
      return false;
    }

    int key = await store.add(await _db, profile.toJson()) as int;

    // Record the key
    profile.key = key;

    return true;
  }

  /*
   * Mark the particular profile as selected
   */
  Future<void> selectProfile(int key) async {
    await store.record("selected").put(await _db, key);
  }

  /*
   * Update the selected profile in the database.
   * The unique integer <key> is used to determine if the profile already exists.
   */
  Future<bool> updateProfile(UserProfile profile) async {

    // Prevent invalid profile data from being updated
    if (profile.name.isEmpty || profile.username.isEmpty || profile.password.isEmpty) {
      debug("updateProfile() : Profile missing required values - not updating");
      return false;
    }

    if (profile.key == null) {
      bool result = await addProfile(profile);
      return result;
    }

    await store.record(profile.key).update(await _db, profile.toJson());

    return true;
  }

  /*
   * Remove a user profile from the database
   */
  Future<void> deleteProfile(UserProfile profile) async {
    await store.record(profile.key).delete(await _db);
  }

  /*
   * Return the currently selected profile.
   * The key of the UserProfile should match the "selected" property
   */
  Future<UserProfile?> getSelectedProfile() async {

    final selected = await store.record("selected").get(await _db);

    final profiles = await store.find(await _db);

    debug("getSelectedProfile() : ${profiles.length} profiles available - selected = ${selected}");

    for (int idx = 0; idx < profiles.length; idx++) {

      debug("- Checking ${idx} - key = ${profiles[idx].key} - ${profiles[idx].value.toString()}");

      if (profiles[idx].key is int && profiles[idx].key == selected) {
        return UserProfile.fromJson(
          profiles[idx].key as int,
          profiles[idx].value as Map<String, dynamic>,
          profiles[idx].key == selected,
        );
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
        profileList.add(
          UserProfile.fromJson(
            profiles[idx].key as int,
            profiles[idx].value as Map<String, dynamic>,
            profiles[idx].key == selected,
          )
        );
      }
    }

    return profileList;
  }
}
