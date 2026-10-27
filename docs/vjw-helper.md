# Visit Japan Web helper

The helper opens the official Visit Japan Web site in a dedicated, isolated WebView. It is a focus-based input aid: the user selects a saved chip after focusing a field and remains responsible for reviewing and submitting the form.

## Privacy boundary

Saved values are stored only on the device in `SharedPreferences` under `vjw_helper_values_v1`. The app never stores or sends passport numbers, birth dates, MRZ data, passwords, login credentials, or QR codes. Analytics records feature actions and injection results, never the values.

## Storage and injection

Flight numbers are uppercased and whitespace is removed. Seven-digit postal codes are formatted with a hyphen. Phone values contain digits only with a leading Japan country code removed. Injection is limited to text inputs, textareas, and contenteditable elements; password, file, checkbox, radio, select, and unsupported elements are rejected. Native setter plus `input` and `change` events are used for controlled forms. Long-press copies a value to the clipboard.

## Failure modes and fallback

No focused editable field shows a localized prompt. Select and unsupported input types show a localized prompt, and clipboard copy is available through long press. Only `*.digital.go.jp` navigation remains in the helper WebView; unrelated links open in the external browser. Rollout is controlled by the web app's public `NEXT_PUBLIC_VJW_HELPER_ENABLED` environment flag, which defaults to disabled. Older app builds that do not acknowledge the bridge message receive an explicit web fallback dialog with a user-triggered link to the official VJW site.
