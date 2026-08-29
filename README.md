# FireStation

BFP (Bureau of Fire Protection) fire dispatcher app for Panabo City. Companion
app to LifeGuard360 — receives and manages fire-only emergency reports
(`fire-report` in the shared Firebase Realtime Database) submitted by
LifeGuard360 users: fire incidents, fire hazards, and rescue operations
within BFP's scope.

## Features

- Real-time report feed (Firebase RTDB listeners), grouped by barangay
- Pending → Acknowledged → Resolved dispatch lifecycle, enforced server-side
- One active fire report per dispatcher at a time (transactional claim lock)
- Push notifications (FCM) for new fire reports
- Live map with barangay markers, dispatcher location, and status legend
- Dispatcher accounts (badge number, rank), profile editing, and
  online/offline presence tracking
