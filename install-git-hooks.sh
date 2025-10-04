#!/bin/bash

# Installation script for AsNeeded git hooks
# Run this script to install pre-push hook that auto-increments build numbers

set -e

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo "❌ Error: Not in a git repository"
    echo "Please run this script from the AsNeeded project root"
    exit 1
fi

echo "📦 Installing AsNeeded git hooks..."

# Create hooks directory if it doesn't exist
mkdir -p .git/hooks

# Install pre-push hook
cat > .git/hooks/pre-push << 'EOF'
#!/bin/bash

# Git pre-push hook to automatically increment build numbers
# This ensures build numbers are always bumped before pushing

PROJECT_FILE="AsNeeded.xcodeproj/project.pbxproj"

# Check if working directory is clean
if [ -n "$(git status --porcelain)" ]; then
    echo "Error: Working directory has uncommitted changes."
    echo "Please commit or stash changes before pushing."
    exit 1
fi

# Check if project file exists
if [ ! -f "$PROJECT_FILE" ]; then
    echo "Error: Could not find $PROJECT_FILE"
    exit 1
fi

echo "🔨 Auto-incrementing build numbers..."

# Get current build numbers
MAIN_BUILD=$(grep "CURRENT_PROJECT_VERSION = " "$PROJECT_FILE" | head -1 | sed 's/.*= \([0-9]*\);/\1/')
TEST_BUILD=$(grep "CURRENT_PROJECT_VERSION = " "$PROJECT_FILE" | tail -1 | sed 's/.*= \([0-9]*\);/\1/')

# Increment build numbers
NEW_MAIN_BUILD=$((MAIN_BUILD + 1))
NEW_TEST_BUILD=$((TEST_BUILD + 1))

echo "📈 Main targets: $MAIN_BUILD → $NEW_MAIN_BUILD"
echo "📈 Test target: $TEST_BUILD → $NEW_TEST_BUILD"

# Update all build numbers in project.pbxproj
# First update the main targets (first 4 occurrences)
sed -i '' "1,/CURRENT_PROJECT_VERSION = $MAIN_BUILD;/s/CURRENT_PROJECT_VERSION = $MAIN_BUILD;/CURRENT_PROJECT_VERSION = $NEW_MAIN_BUILD;/" "$PROJECT_FILE"
sed -i '' "1,/CURRENT_PROJECT_VERSION = $MAIN_BUILD;/s/CURRENT_PROJECT_VERSION = $MAIN_BUILD;/CURRENT_PROJECT_VERSION = $NEW_MAIN_BUILD;/" "$PROJECT_FILE"
sed -i '' "1,/CURRENT_PROJECT_VERSION = $MAIN_BUILD;/s/CURRENT_PROJECT_VERSION = $MAIN_BUILD;/CURRENT_PROJECT_VERSION = $NEW_MAIN_BUILD;/" "$PROJECT_FILE"
sed -i '' "1,/CURRENT_PROJECT_VERSION = $MAIN_BUILD;/s/CURRENT_PROJECT_VERSION = $MAIN_BUILD;/CURRENT_PROJECT_VERSION = $NEW_MAIN_BUILD;/" "$PROJECT_FILE"

# Then update the test target (remaining occurrences)
sed -i '' "s/CURRENT_PROJECT_VERSION = $TEST_BUILD;/CURRENT_PROJECT_VERSION = $NEW_TEST_BUILD;/g" "$PROJECT_FILE"

# Create Build Bump commit
git add "$PROJECT_FILE"
git commit -m "Build Bump"

echo "✅ Build numbers incremented and committed!"
echo "🚀 Proceeding with push..."

# Exit successfully to allow push to continue
exit 0
EOF

# Make the hook executable
chmod +x .git/hooks/pre-push

echo "✅ Pre-push hook installed successfully!"
echo ""
echo "This hook will automatically:"
echo "  • Increment build numbers before each push"
echo "  • Create a 'Build Bump' commit"
echo "  • Ensure working directory is clean before pushing"
echo ""
echo "🚀 You're all set! Try running 'git push' to see it in action."
