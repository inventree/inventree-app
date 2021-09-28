
/*
 * Class for InvenTree user / login details
 */
import "package:sembast/sembast.dart";
import "preferences.dart";

class UserProfile {

  UserProfile({
    this.key,
    this.name = "",
    this.server = "",
    this.username = "",
    this.password = "",
    this.selected = false,
  });

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

  factory UserProfile.fromJson(int key, Map<String, dynamic> json, bool isSelected) => UserProfile(
    key: key,
    name: json["name"] as String,
    server: json["server"] as String,
    username: json["username"] as String,
    password: json["password"] as String,
    selected: isSelected,
  );

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

  Future<Database> get _db async => await InvenTreePreferencesDB.instance.database;

  Future<bool> profileNameExists(String name) async {

    final finder = Finder(filter: Filter.equals("name", name));

    final profiles = await store.find(await _db, finder: finder);

    return profiles.isNotEmpty;
  }

  Future<void> addProfile(UserProfile profile) async {

    // Check if a profile already exists with the name
    final bool exists = await profileNameExists(profile.name);

    if (exists) {
      print("UserProfile '${profile.name}' already exists");
      return;
    }

    int key = await store.add(await _db, profile.toJson()) as int;

    print("Added user profile <${key}> - '${profile.name}'");

    // Record the key
    profile.key = key;
  }

  Future<void> selectProfile(int key) async {
    /*
     * Mark the particular profile as selected
     */

    final result = await store.record("selected").put(await _db, key);

    return result;
  }
  
  Future<void> updateProfile(UserProfile profile) async {
    
    if (profile.key == null) {
      await addProfile(profile);
      return;
    }

    final result = await store.record(profile.key).update(await _db, profile.toJson());

    print("Updated user profile <${profile.key}> - '${profile.name}'");

    return result;
  }

  Future<void> deleteProfile(UserProfile profile) async {
    await store.record(profile.key).delete(await _db);
    print("Deleted user profile <${profile.key}> - '${profile.name}'");
  }

  Future<UserProfile?> getSelectedProfile() async {
    /*
     * Return the currently selected profile.
     *
     * key should match the "selected" property
     */

    final selected = await store.record("selected").get(await _db);

    final profiles = await store.find(await _db);

    for (int idx = 0; idx < profiles.length; idx++) {

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
            ));
      }
    }

    return profileList;
  }
}
