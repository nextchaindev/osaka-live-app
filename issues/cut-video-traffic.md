Cut video traffic: 11 MB average clips, downloaded in full on every session open

## Why this exists

Users reported burning through a lot of mobile data while using the app. #156 covers the API side of that — venue endpoints being refetched on every GPS fix. This issue covers the media side, which is the other half of the bill.

**The goal is not the checklist below. The goal is fewer bytes over a phone's mobile connection per minute of use.** The items here are the ones that turned up in a first pass over the video paths; they are a starting point, not the scope. If you find something cheaper or larger while working in here, that counts more than finishing the list as written. Please read the "Look wider" section at the bottom before deciding what to do first.

This is a travel app used on the street in Osaka, much of it by visitors on roaming or a limited prepaid eSIM. Data cost is a real user-facing constraint, not just an infra number.

## Measured data

From the production database. All 31 video posts are the same R2 objects as the 31 live-session short videos, so these numbers describe both.

| Metric                        | Value                          |
| ----------------------------- | ------------------------------ |
| Video posts                   | 31                             |
| Average size                  | **11 MB**                      |
| Median                        | 9.5 MB                         |
| Max                           | **39.7 MB** (41,662,649 bytes) |
| Total stored                  | 329 MB                         |
| Posts with a stored thumbnail | **0 of 31**                    |
| `duration` recorded           | 0 of 31 (all NULL)             |
| Chat media uploaded so far    | **0**                          |

Recording is capped at 30s (`_maxRecordingDuration` in `custom_camera_screen.dart`). At that cap, the largest clip works out to roughly **11 Mbps**, and the average to around 3 Mbps. Exact per-clip bitrate can't be confirmed because duration was never stored.

Serving host for all of it: `pub-<id>.r2.dev`.

## Findings by path

### 1. Upload — no compression anywhere

- `osaka-live-app` `lib/screens/camera/custom_camera_screen.dart:127` — `ResolutionPreset.high`, `enableAudio: true`, no bitrate control. Whatever the platform encoder defaults to is what ships.
- `src/services/video-post.service.ts` — `putVideoFile` sends `body: file` straight to the presigned R2 URL. No transcode, no re-encode, no downscale.
- `src/app/api/videos/presigned/route.ts` — no size limit at all. (Chat media has one; video posts do not.)

### 2. Playback — the full file downloads before anyone asks for it

- `src/views/session/session-view.tsx:1556` — `autoPlay` + `preload='auto'` + `poster={undefined}`. Opening a session page pulls the whole ~11 MB file immediately.
- A poster frame **is already being produced** and then thrown away: `capturePoster()` in `src/components/create-flow-modal/create-flow-modal.tsx:408` renders a frame to canvas as JPEG (q0.82) and uses it only for the local preview. It is never uploaded. The `video_posts.thumbnail` column exists and is empty for all 31 rows.
- Single flat MP4. No HLS/DASH, no second rendition, no poster image anywhere in the pipeline.

### 3. Looping — the loop itself is fine, re-entry is not

`loop` on the session video replays from the browser's buffer and does not refetch. The 60s `setInterval` at `session-view.tsx:871` is a clock tick for relative timestamps and does not touch the video element. No problem there.

The cost is **leaving and re-entering a session**, which recreates the element. Whether that re-downloads depends on caching, and caching looks absent:

- `src/lib/r2.ts` `PutObjectCommand` sets only `Bucket`, `Key`, `ContentType`. **No `CacheControl`.** Objects therefore carry no `Cache-Control` metadata.
- With no `Cache-Control`, browsers fall back to heuristic freshness (a fraction of the time since `Last-Modified`). For a recently uploaded object that is effectively zero, so every visit revalidates.

### 4. Chat upload — videos bypass compression entirely

`src/utils/chat-media.util.ts:41`:

```ts
file.type.startsWith("image/") ? compressImage(file) : Promise.resolve(file);
```

Images get downscaled to 1920px at q0.82. Videos pass through untouched. With `CHAT_MEDIA_LIMITS.video = 25 MB` and `CHAT_MEDIA_MAX_FILES = 5`, one send can be **125 MB**. The source is the gallery picker (`<input type="file" multiple accept=".jpg,.jpeg,.png,.webp,.mp4,.webm,.mov,.m4v">`), so the 30s recording cap does not apply — an arbitrarily long phone video can go straight up.

Nothing has been uploaded through this path in production yet, so it is latent rather than observed. Worth closing before the feature gets used.

## Please verify first (I could not)

The analysis environment's egress proxy blocks both `r2.dev` and Cloudflare's docs, so two things below are reasoned from the code rather than observed. Confirm them before building on them:

1. **What `Cache-Control` (if any) R2 actually returns.** A single `curl -I <video-url>` settles it.
2. **Whether `pub-*.r2.dev` is served through Cloudflare's CDN cache.** My understanding is that the `r2.dev` subdomain is rate-limited and documented as not for production use, with custom domains being the supported path for caching — but I did not read the current docs, so please check rather than take my word for it.

If it turns out caching already works, item 3 below shrinks a lot and the priority order changes. Measure before you build.

## Suggested work, roughly in value-per-effort order

1. **Store the poster frame and stop autoloading the video.** `capturePoster()` already generates one — upload it alongside the video, populate `video_posts.thumbnail`, set it as `poster` on the session video, and drop `preload` to `metadata`. Opening a session becomes a ~30 KB image instead of ~11 MB; the file downloads when someone presses play. Most of the wiring exists. Existing 31 posts need a backfill.
2. **Cap the recording bitrate.** Root cause of the 11 MB average. Either lower `ResolutionPreset`, or transcode after recording (`video_compress`, `ffmpeg_kit_flutter`, or the platform encoders). 720p at 1.5–2 Mbps puts a 30s clip at 5–7 MB. Check what the result actually looks like at the size it is displayed before picking a target.
3. **Set `CacheControl` on R2 uploads.** `public, max-age=31536000, immutable` in `src/lib/r2.ts` — keys are UUID-based so they never change content, which makes `immutable` safe. Existing objects need a copy-object backfill to pick up the new metadata.
4. **Move off `pub-*.r2.dev` to a custom domain** so the CDN can actually cache and the rate limit stops applying.
5. **Compress chat videos, or cap count/duration.** Mirror what `compressImage` does for images.
6. **Record `duration`, and add a server-side size cap for video posts.** Without duration we cannot compute bitrate or spot regressions.

## Look wider

Treat the list above as the part that was easy to find, and spend some of the time looking for what wasn't. A few directions worth a look, not exhaustive:

- **Measure before and after.** There is no traffic baseline today. Capturing bytes-per-session on a real device (Chrome DevTools over USB, or Charles/Proxyman against the WebView) would tell us which of these actually matters, and would catch the next regression without another manual audit. That instrumentation may be worth more than any single fix below it.
- **Audit the other media paths the same way.** Avatars, event images, venue request photos, and `venue-thumbnail` (which renders 640px sources with `unoptimized` into 100–350px slots) all go through similar code and none were examined here.
- **Look at repeat cost, not just first load.** A user who opens the app ten times a day pays whatever is not cacheable ten times. Cache headers, WebView cache behaviour, and what survives a cold start are worth a pass in their own right — the `osaka-live-app` WebView config is part of that surface.
- **Question whether a payload is needed at all**, not just whether it can be smaller. #156 has two examples: a 19.4 KB response answering a boolean, and 200 venue rows carrying `address`/`thumbnailUrl` that map pins never render.
- **Consider the upload direction too.** Posting a clip currently costs the poster 11 MB of their own data. That is as much a user cost as playback.
- **Check the cost side while you are here.** `/api/venues/google-place-photo` was re-running billed Places API calls on every scroll (fixed in #156). Other third-party calls may have the same shape.

If something here turns out to be a non-issue, say so on the issue and close it out — a measurement that disproves a hypothesis is a useful result, not a failed task.

## Related

- #156 — API-side data usage (venue refetch on every GPS fix). Same underlying goal, already partially fixed on `claude/app-data-usage-optimization-ppxfxd` in both repos.
- That branch already changed `preload='auto'` to `'metadata'` for videos used as still-frame thumbnails in post grids and chat. The session view's autoplaying video was deliberately left alone, since it needs a poster first — item 1 above.
