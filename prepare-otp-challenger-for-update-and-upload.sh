#!/bin/bash
# Prepare otp-challenger for clawhub upload
# Creates a clean copy without .git, tests, logs

SOURCE_DIR="/Volumes/T9/ryan-homedir/devel/otp-challenger"
DEST_DIR="/tmp/otp-challenger"

# Remove old dest if exists
rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"

# Copy only the core skill files (no .git, tests/, logs/, .serena/)
cp "$SOURCE_DIR"/*.sh "$DEST_DIR/"
cp "$SOURCE_DIR"/*.md "$DEST_DIR/"
cp "$SOURCE_DIR"/*.mjs "$DEST_DIR/"

# Copy examples directory
if [ -d "$SOURCE_DIR/examples" ]; then
  cp -r "$SOURCE_DIR/examples" "$DEST_DIR/"
fi

echo "Clean copy created at: $DEST_DIR"
echo ""
echo "Files included:"
ls -la "$DEST_DIR"
echo ""
echo "Files excluded: .git/, tests/, logs/, .serena/"
echo ""
echo "Ready for clawhub upload!"
