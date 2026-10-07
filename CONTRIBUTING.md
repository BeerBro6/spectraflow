# Contributing to SpectraFlow

Thank you for your interest in contributing to SpectraFlow! We welcome contributions from developers, designers, and audiophiles alike.

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

## Getting Started

1. **Fork the repository** on GitHub.
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/<your-username>/spectraflow.git
   cd spectraflow
   ```
3. **Install dependencies**:
   ```bash
   flutter pub get
   ```
4. **Create a topic branch**:
   ```bash
   git checkout -b feature/my-new-feature
   ```

## Development Guidelines

- **Code Quality:** All code should adhere to Effective Dart conventions. Run `flutter analyze` before committing.
- **Testing:** Add unit or widget tests for new features and bug fixes. Verify existing tests pass with `flutter test`.
- **Performance:** Avoid heavy work on the main UI isolate. DSP filters and file I/O must remain non-blocking.
- **Privacy & Security:** Do not introduce telemetry, remote analytics, or hardcoded secrets.

## Submitting Pull Requests

1. Commit changes with clear, descriptive commit messages adhering to Conventional Commits (e.g. `feat: ...`, `fix: ...`).
2. Push your topic branch to your GitHub fork.
3. Open a Pull Request against the `main` branch.
