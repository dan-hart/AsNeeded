# Contributing to AsNeeded

Thank you for your interest in contributing to AsNeeded! We welcome contributions from the community and are excited to work with you.

## Code of Conduct

By participating in this project, you agree to be respectful and constructive in all interactions. We're building a health app that helps people, and we want our community to reflect that positive mission.

## How to Contribute

### Reporting Bugs

Before creating a bug report, please check existing issues to avoid duplicates. When creating a bug report, include:

- **Clear title and description**: Explain what happened vs. what you expected
- **Steps to reproduce**: List the exact steps to trigger the bug
- **Environment details**: iOS version, device model, Xcode version
- **Screenshots/videos**: If applicable, add visual evidence
- **Crash logs**: Include relevant logs from Xcode console

### Suggesting Features

We love feature suggestions! When proposing a new feature:

- **Check existing issues**: Someone might have already suggested it
- **Explain the use case**: Why would this feature help users?
- **Consider privacy**: How does this align with our privacy-first approach?
- **Be specific**: Provide mockups or detailed descriptions if possible

### Pull Request Process

1. **Fork the repository** and create your branch from `develop`
2. **Follow the code style**:
   - Use tabs for indentation
   - Keep lines under ~120 characters
   - Use `// MARK: -` comments to organize code sections
   - Always use SFSafeSymbols for SF Symbols
   - Use `.accentColor` instead of `.blue` for interactive elements
3. **Write tests** for new functionality using Swift Testing framework
4. **Update documentation** if you're changing behavior
5. **Ensure the build passes**: Run `xcodebuild -scheme AsNeeded build`
6. **Create a Pull Request** with a clear title and description

### Development Setup

```bash
# Clone your fork
git clone git@github.com:your-username/AsNeeded.git
cd AsNeeded

# Add upstream remote
git remote add upstream git@github.com:dan-hart/AsNeeded.git

# Install security hooks (required)
./scripts/install-hooks.sh

# Optional but recommended: install git-secrets for extra local scanning
brew install git-secrets

# Create a feature branch
git checkout -b feature/your-feature-name

# Make your changes and commit
git add .
git commit -m "Add your feature"

# Push to your fork
git push origin feature/your-feature-name
```

### Commit Messages

- Use present tense ("Add feature" not "Added feature")
- Use imperative mood ("Fix bug" not "Fixes bug")
- Keep the first line under 50 characters
- Reference issues and pull requests when relevant

Examples:
- `Add medication interaction warnings`
- `Fix dose logging crash on iPad`
- `Update RxNorm search algorithm`
- `Refactor notification scheduling logic`

### Testing Guidelines

- Write tests for all new business logic
- Use Swift Testing framework (`@Test`, `#expect`)
- Focus on domain models, services, and view models
- No UI or snapshot tests needed
- Aim for 80%+ coverage on new code

Example test:
```swift
@Test func calculatesNextDoseCorrectly() {
    let medication = ANMedicationConcept(
        name: "Ibuprofen",
        minimumInterval: 6 * 3600 // 6 hours
    )
    let lastDose = Date.now.addingTimeInterval(-3600) // 1 hour ago
    let nextAvailable = medication.nextDoseAvailable(after: lastDose)
    #expect(nextAvailable.timeIntervalSince(lastDose) == 5 * 3600)
}
```

### Architecture Guidelines

- **Domain Layer**: Keep models pure with no UI or persistence code
- **Services**: Use protocols for dependency injection
- **Views**: Small, focused SwiftUI views in separate files
- **Packages**: No SwiftUI imports in ANModelKit or SwiftRxNorm
- **Concurrency**: Use async/await for asynchronous operations

### What We're Looking For

#### High Priority
- Bug fixes and stability improvements
- Performance optimizations
- Accessibility enhancements
- Test coverage improvements
- Documentation updates

#### Medium Priority
- New medication tracking features
- Data visualization improvements
- Apple Watch app enhancements
- Siri Shortcuts additions

#### Nice to Have
- Localization support
- Theme customization
- Widget implementations
- Advanced analytics

### Review Process

1. A maintainer will review your PR within 3-5 days
2. We may request changes or ask questions
3. Once approved, we'll merge your contribution
4. Your contribution will be included in the next release

### Recognition

Contributors are recognized in:
- Release notes
- GitHub contributors page
- In-app credits (for significant contributions)

## Questions?

Feel free to:
- Open a [Discussion](https://github.com/dan-hart/AsNeeded/discussions) for general questions
- Create an [Issue](https://github.com/dan-hart/AsNeeded/issues) for bugs or features
- Reach out to maintainers for clarification

Thank you for helping make AsNeeded better for everyone!
