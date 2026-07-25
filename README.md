# Set It Up

Set It Up is an unofficial, open-source macOS menu-bar voice assistant. Say
“Set It Up,” ask for what you need, and hear the reply through the Mac’s current
audio output.

The app offers three assistant modes:

- **Local AI:** private chat through an Ollama model running on the same Mac.
- **OpenAI:** cloud chat through the customer’s own OpenAI API key.
- **Codex:** reasoning and workspace tasks through the signed-in Codex app.

Only Codex mode can act in a selected workspace. It starts read-only and exposes
workspace-write access as a separate choice.

## What is honest about the architecture

- The Mac microphone captures the wake phrase and request.
- Apple Speech handles transcription, on-device when macOS makes that available.
- macOS speaks the response through the current output device.
- A HomePod selected in macOS Sound or AirPlay can play the response.
- HomePod microphones are not exposed to third-party Mac apps as a general input.
- Mac owner authentication unlocks requests after launch and after session unlock.

The app never receives fingerprint data. macOS reports only whether owner
authentication succeeded.

## Requirements

- macOS 14 or later
- Xcode Command Line Tools
- Microphone and speech-recognition permission
- One assistant path:
  - Ollama plus an installed model,
  - an OpenAI API account, API key, and model available to that account, or
  - the Codex app or CLI with a signed-in account

A ChatGPT subscription and OpenAI API billing are separate. The OpenAI mode
requires an API key; a ChatGPT login is not used as an API credential.

## Build and install

```bash
swift test
./scripts/build-app.sh
./scripts/install-local.sh
```

The local development bundle is ad-hoc signed. A public binary release should be
Developer ID signed and notarized.

## First run

1. Open Set It Up and approve Mac owner authentication.
2. Allow microphone and speech-recognition access.
3. Choose Local AI, OpenAI, or Codex.
4. Complete the settings shown for that assistant and select **Check**.
5. Optionally select a HomePod under macOS Control Centre > Sound.
6. Say: “Set It Up, summarize my request.”

Typed requests are included for testing without microphone access.

## Provider notes

### Local AI

The default endpoint is `http://127.0.0.1:11434`. Set It Up permits only
loopback endpoints for this mode, so “local” cannot silently become a remote
server. Enter the exact name of a model installed in Ollama.

### OpenAI

Enter an API model available to the customer’s OpenAI API account. The API key
is stored in macOS Keychain with device-only accessibility. It is never written
to UserDefaults or committed to the repository.

### Codex

Codex mode uses the existing Codex sign-in on the Mac. Read-only is the default.
Workspace-write is scoped to the selected working directory. The app does not
expose an unrestricted system-access option.

## Security and privacy

- Set It Up starts locked.
- Screen sleep or an inactive Mac session locks it immediately.
- Voice recognition and speech stop when the app locks.
- Local AI requests stay on the Mac when Ollama and the selected model do.
- OpenAI requests go to the OpenAI API.
- Codex requests follow the selected Codex sandbox and account settings.
- No audio recordings are written by the app.

Voice commands can be misheard. Review important or destructive work in the
Codex app before allowing changes.

See [SECURITY.md](SECURITY.md) for responsible disclosure.

## $50 guided installation

The software is free under the MIT license. The commercial offer is a one-time
CAD $50 guided installation:

- install and launch configuration;
- one assistant path configured;
- microphone and audio-output setup;
- Mac authentication and first live request;
- a short handoff showing how to switch modes or remove the app.

Customer-owned model downloads, OpenAI API usage, ChatGPT subscriptions, and
third-party hardware are not included in the $50 fee.

## Status

Version `0.4.0` is a development build. The app and core tests are working.
Local AI and OpenAI live responses still require the customer’s own local model
or API credential. Codex mode can be tested with the signed-in Codex app.

The public launch-page source is included in [`site/`](site/).

## License

MIT. See [LICENSE](LICENSE).
