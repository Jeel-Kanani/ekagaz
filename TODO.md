# TODO: Fix Family Avatar Storage and Migrate Existing DPs

- [x] Update bucket name in `famvault/lib/family/family_avatar_uploader.dart` from 'avatars' to 'family-avatars'
- [x] Update bucket name in `famvault/lib/family/create_family_screen.dart` from 'avatars' to 'family-avatars'
- [x] Update bucket name in `famvault/lib/family/family_service.dart` in `updateFamilyDp` method from 'documents' to 'family-avatars'
- [ ] Add migration method in `family_service.dart` to update existing dp_urls from 'documents' to 'family-avatars'
- [ ] Ensure 'family-avatars' bucket is created in Supabase as public
- [ ] Run migration to fix broken links
