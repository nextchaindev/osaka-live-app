# Native social login setup

The WebView bridge and native login code are implemented, but Google Sign-In
also requires OAuth clients configured in the Google Cloud project that owns
the web client ID used by the Next.js backend.

## Google Android

Create Android OAuth clients for each package/signing certificate combination:

- `live.osaka`
- `live.osaka.dev`
- `live.osaka.staging`

Local debug certificate:

- SHA-1: `F6:37:25:E9:28:91:C1:C9:76:B5:0C:C4:9A:F1:74:08:D8:B8:F5:34`
- SHA-256: `3C:D0:63:5F:81:E7:EF:AC:B0:44:17:E3:06:58:DC:89:44:4B:D9:28:80:B0:C2:25:CC:C4:19:4B:B3:C6:66:49`

Current upload certificate:

- SHA-1: `10:94:3A:5F:86:86:7E:2C:4B:8D:0F:EA:C5:92:E9:C0:49:EB:7C:5A`
- SHA-256: `48:1A:FD:6F:B1:61:13:87:0E:CD:A4:BB:4D:CD:D4:25:27:FD:78:06:67:0E:8A:2E:6E:AF:8B:72:C5:8F:4B:99`

For Play Store builds, also register the Play App Signing certificate shown in
Play Console. It is different from the upload certificate.

Set `GOOGLE_SERVER_CLIENT_ID` in each ignored `lib/config/.env.*` file to the
same Web OAuth client ID configured as `GOOGLE_OAUTH_CLIENT_ID` in Next.js.

## Google iOS

Create an iOS OAuth client for every supported bundle ID. Download the updated
Google plist or copy these two values from the generated configuration:

- Set `GOOGLE_IOS_CLIENT_ID` in the matching `lib/config/.env.*` file to
  `CLIENT_ID`.
- Add `REVERSED_CLIENT_ID` as a URL scheme to the matching Runner Info.plist.

The current Google plist files do not contain `CLIENT_ID` or
`REVERSED_CLIENT_ID`, so Google login on iOS intentionally returns a
configuration error until these values are supplied.

## Apple iOS

- Enable Sign in with Apple for the `live.osaka` App ID in Apple Developer.
- The Flutter entitlements already include `com.apple.developer.applesignin`.
- Set `APPLE_IOS_CLIENT_ID=live.osaka` in the Next.js deployment environment if
  the production bundle ID changes. The backend defaults to `live.osaka`.
