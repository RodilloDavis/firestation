import 'package:firebase_database/firebase_database.dart';

/// Tracks a logged-in BFP dispatcher's online/offline status in Realtime
/// Database so other dispatchers (and future admin views) can see who's
/// actively watching the board. Writes OnlineStatus/LastSeen at
/// /BFPAccounts/{uid} and arms an onDisconnect() hook on Firebase's own
/// server, so status flips to Offline automatically if the connection
/// drops without a clean logout.
class DispatcherPresence {
  static Future<void> initialize(String uid, String node) async {
    final db = FirebaseDatabase.instance;
    final ref = db.ref('$node/$uid');

    db.ref('.info/connected').onValue.listen((event) {
      final connected = event.snapshot.value as bool? ?? false;

      if (connected) {
        ref.onDisconnect().update({
          'OnlineStatus': 'Offline',
          'LastSeen': ServerValue.timestamp,
        });

        ref.update({
          'OnlineStatus': 'Online',
          'LastSeen': ServerValue.timestamp,
        });
      }
    });
  }
}
