# Set It Up Security

Please report security issues privately to the repository owner instead of opening a public issue.

Codex execution defaults to read-only. Treat voice input as untrusted, because speech can be misheard or replayed by nearby audio.

OpenAI API keys are stored in the macOS Keychain. Local AI mode accepts only a
loopback endpoint. The app locks when the Mac session becomes inactive.

Never commit Codex credentials, OpenAI API keys, access tokens, recordings, transcripts, or personal workspace paths.
