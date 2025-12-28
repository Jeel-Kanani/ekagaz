Join Family & QR

This folder contains utilities for joining families via QR/invite codes.

Screens:
- `JoinFamilyScreen`: Tabbed UI (Scan / Enter Code) to join a family. Scan uses `mobile_scanner`. Enter code accepts either a family id or an invite link (e.g., `famvault://join/family_123`).
- `FamilyInviteCard`: A small widget that renders a Pretty QR code (using `pretty_qr_code`) for an invite link. Use in Family Details to show your family's QR.

Notes for developers:
- Add `assets/logo.png` and include it in `pubspec.yaml` if you want the QR to display the app logo in the center (see `PrettyQr` docs).
- Ensure your Supabase schema has `families` and `family_members` tables (or adjust `FamilyService` accordingly).
- The `joinFamily` method in `lib/family/family_service.dart` inserts into `family_members`. It may need RLS policy adjustments to allow inserts by authenticated users.

Testing:
- Use the `JoinFamilyScreen` Scan tab and point device camera at a QR (or use a screenshot of the invite link) to test.
