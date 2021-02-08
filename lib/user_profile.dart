
/*
 * Class for InvenTree user / login details
 */
import 'package:sembast/sembast.dart';
import 'preferences.dart';

class UserProfile {

  UserProfile({
    this.key,
    this.name,
    this.server,
    this.username,
    this.password
  });

  // ID of the profile
  int key;

  // Name of the user profile
  String name;

  // Base address of the InvenTree server
  String server;

  // Username
  String username;

  // Password
  String password;

  // User ID (will be provided by the server on log-in)
  int user_id;

  factory UserProfile.fromJson(int key, Map<String, dynamic> json) => UserProfile(
    key: key,
    name: json['name'],
    server: json['server'],
    username: json['username'],
    password: json['password'],
  );

  Map<String, dynamic> toJson() => {
    "name": name,
    "server": server,
    "username": username,
    "password": password,
  };

  @override
  String toString() {
    return "${server} - ${username}:${password}";
  }
}

class UserProfileDBManager {

  static const String folder_name = "profiles";

  final _folder = intMapStoreFactory.store(folder_name);

  Future<Database> get _db async => await InvenTreePreferencesDB.instance.database;

  Future addProfile(UserProfile profile) async {

    UserProfile existingProfile = await getProfile(profile.name);

    if (existingProfile != null) {
      print("UserProfile '${profile.name}' already exists");
      return;
    }

    int key = await _folder.add(await _db, profile.toJson());

    print("Added user profile <${key}> - '${profile.name}'");

    // Record the key
    profile.key = key;
  }
  
  Future updateProfile(UserProfile profile) async {
    
    if (profile.key == null) {
      addProfile(profile);
      return;
    }

    final finder = Finder(filter: Filter.byKey(profile.key));
    await _folder.update(await _db, profile.toJson(), finder: finder);

    print("Updated user profile <%{profile.key}> - '${profile.name}");
  }

  Future deleteProfile(UserProfile profile) async {
    final finder = Finder(filter: Filter.equals("name", profile.name));
    await _folder.delete(await _db, finder: finder);

    print("Deleted user profile <${profile.key}> - '${profile.name}'");
  }

  Future<UserProfile> getProfile(String name) async {
    // Lookup profile by name (or return null if does not exist)
    final finder = Finder(filter: Filter.equals("name", name));

    final profiles = await _folder.find(await _db, finder: finder);

    if (profiles.length == 0) {
      return null;
    }

    // Return the first matching profile object
    return UserProfile.fromJson(profiles[0].key, profiles[0].value);
  }

  /*
   * Return all user profile objects
   */
  Future<List<UserProfile>> getAllProfiles() async {
    final profiles = await _folder.find(await _db);

    List<UserProfile> profileList = new List<UserProfile>();

    for (int idx = 0; idx < profiles.length; idx++) {
      profileList.add(UserProfile.fromJson(profiles[idx].key, profiles[idx].value));
    }

    return profileList;
  }
}
