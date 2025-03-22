class LocalMembersStore {
  static final Map<String, List<String>> _store = {};

  static void setMembers(String eventId, List<String> members) {
    _store[eventId] = members;
  }

  static List<String>? getMembers(String eventId) {
    return _store[eventId];
  }
}
