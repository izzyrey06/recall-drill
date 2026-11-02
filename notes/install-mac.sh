#!/bin/bash
# Recall Notes installer for macOS.
#
#   curl -fsSL https://izzyrey06.github.io/recall-drill/notes/install-mac.sh | bash
#
# Makes ~/Applications/Recall Notes.app, which opens Recall Notes in its own
# window (no tabs or address bar) using Chrome, Edge, Brave or Chromium.
# Your notes are stored by that browser, the same as when you use the site.
# If none of those browsers is installed, it opens Recall Notes in Safari and
# shows how to add it to the Dock instead.
#
# To remove it:  rm -rf ~/Applications/"Recall Notes.app"
set -euo pipefail

URL="https://izzyrey06.github.io/recall-drill/notes/"
ICON_URL="${URL}icon-512.png"
APP="$HOME/Applications/Recall Notes.app"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This installer is for macOS. On other computers, open $URL and use your browser's Install option."
  exit 1
fi

browser=""
for name in "Google Chrome" "Microsoft Edge" "Brave Browser" "Chromium"; do
  for dir in "/Applications" "$HOME/Applications"; do
    if [ -x "$dir/$name.app/Contents/MacOS/$name" ]; then
      browser="$dir/$name.app/Contents/MacOS/$name"
      browser_name="$name"
      break 2
    fi
  done
done

if [ -z "$browser" ]; then
  echo "Chrome, Edge or Brave isn't installed, so Recall Notes will use Safari."
  echo "Opening it in Safari now. Then choose File > Add to Dock to install it."
  open -a Safari "$URL"
  exit 0
fi

echo "Installing Recall Notes (opens with $browser_name)…"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Launcher: open the app in its own window and step aside
cat > "$APP/Contents/MacOS/RecallNotes" <<LAUNCH
#!/bin/bash
BROWSER="$browser"
if [ ! -x "\$BROWSER" ]; then
  open "$URL"
  exit 0
fi
nohup "\$BROWSER" --app="$URL" >/dev/null 2>&1 &
LAUNCH
chmod +x "$APP/Contents/MacOS/RecallNotes"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Recall Notes</string>
  <key>CFBundleDisplayName</key><string>Recall Notes</string>
  <key>CFBundleIdentifier</key><string>io.github.izzyrey06.recallnotes</string>
  <key>CFBundleExecutable</key><string>RecallNotes</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>10.13</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

# Icon: turn the app's PNG into a macOS .icns (skipped quietly if anything fails)
if curl -fsSL "$ICON_URL" -o "$tmp/icon.png"; then
  set +e
  mkdir -p "$tmp/AppIcon.iconset"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$tmp/icon.png" --out "$tmp/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null 2>&1
    d=$((s * 2))
    sips -z $d $d "$tmp/icon.png" --out "$tmp/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null 2>&1
  done
  iconutil -c icns "$tmp/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns" >/dev/null 2>&1
  set -e
fi

touch "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" >/dev/null 2>&1 || true

echo "Done. Recall Notes is in your Applications folder (~/Applications)."
echo "Opening it now. Find it later in Launchpad or Spotlight, or drag it from ~/Applications onto the Dock."
open "$APP"
