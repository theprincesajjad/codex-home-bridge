# Contributing

Issues and pull requests are welcome.

Please keep changes focused, preserve the read-only default, and include tests for wake-phrase or command-routing changes.

Before opening a pull request:

```bash
swift test
./scripts/build-app.sh
```

Do not add analytics, remote logging, or a new credential store without a separate design discussion.
