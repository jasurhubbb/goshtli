# Go'sht Bozori Team App

Flutter work application for three platform-operated workflows:

- Internal catalog operators enter and manage the platform's listings and process orders.
- Qassobs manage their service profile, jobs, messages, and earnings.
- Couriers manage their delivery queue, active deliveries, history, and earnings.

Accounts are provisioned by the platform. There is no public supplier registration or supplier
self-service flow. For backend compatibility, the internal catalog account currently uses the
existing `SUPPLIER` role and owner-scoped listing/order endpoints; that role name is not presented
to app users.

## Development

From this directory:

```sh
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
```

The app imports shared networking, authentication, locale, user, and theme primitives from
`../packages/shared_core`.
