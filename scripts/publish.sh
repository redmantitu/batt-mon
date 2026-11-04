#!/bin/zsh
# One-shot publish: build universal zip -> make repo public -> tag + GitHub release
# -> generate cask -> create/update the Homebrew tap.
# Re-runnable: bump CFBundleShortVersionString in Info.plist, then run again for a new version.
# Usage: scripts/publish.sh [-y]   (-y skips the confirmation prompt)
set -euo pipefail
cd "$(dirname "$0")/.."

OWNER=redmantitu
REPO=batt-mon
TAP=homebrew-tap
CASK=screen-on-time
TAP_DIR="$(cd .. && pwd)/$TAP"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
TAG="v$VERSION"

command -v gh >/dev/null || { echo "gh CLI required"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "run: gh auth login"; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "Commit your changes first (working tree is dirty)."; exit 1; }

echo "This will, for $OWNER/$REPO $TAG:"
echo "  - make $OWNER/$REPO PUBLIC"
echo "  - publish a GitHub release with the built zip"
echo "  - create/update the PUBLIC tap $OWNER/$TAP with the $CASK cask"
if [[ "${1:-}" != "-y" ]]; then
  read "?Continue? [y/N] " ans; [[ "$ans" == [yY] ]] || { echo "Aborted."; exit 1; }
fi

echo "==> Building release zip"
OUT=$(scripts/release.sh)
ZIP=$(echo "$OUT" | sed -n '1p')
SHA=$(echo "$OUT" | sed -n '2p' | awk '{print $1}')
echo "    $ZIP  sha256=$SHA"

echo "==> Making repo public"
gh repo edit "$OWNER/$REPO" --visibility public --accept-visibility-change-consequences \
  --description "macOS menu bar app showing screen-on time since you unplugged" >/dev/null
git push -q origin main

echo "==> Tagging and releasing $TAG"
git rev-parse "$TAG" >/dev/null 2>&1 || git tag "$TAG"
git push -q origin "$TAG"
if gh release view "$TAG" --repo "$OWNER/$REPO" >/dev/null 2>&1; then
  gh release upload "$TAG" "$ZIP" --repo "$OWNER/$REPO" --clobber
else
  gh release create "$TAG" "$ZIP" --repo "$OWNER/$REPO" --title "$TAG" \
    --notes "Universal binary (Apple Silicon + Intel), macOS 13+."
fi

echo "==> Generating cask"
mkdir -p "$TAP_DIR/Casks"
cat > "$TAP_DIR/Casks/$CASK.rb" <<CASKEOF
cask "$CASK" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://github.com/$OWNER/$REPO/releases/download/v#{version}/ScreenOnTime-#{version}.zip"
  name "Screen On Time"
  desc "Menu bar app showing screen-on time since you unplugged"
  homepage "https://github.com/$OWNER/$REPO"

  depends_on macos: ">= :ventura"

  app "ScreenOnTime.app"

  # App is ad-hoc signed, not notarized: clear quarantine so it opens.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/ScreenOnTime.app"]
  end

  zap trash: "~/Library/Preferences/com.costinrosu.screenontime.plist"
end
CASKEOF
ruby -c "$TAP_DIR/Casks/$CASK.rb" >/dev/null

echo "==> Publishing tap"
cd "$TAP_DIR"
[[ -d .git ]] || git init -q -b main
git add -A
git diff --cached --quiet || git commit -q -m "$CASK $VERSION"
if gh repo view "$OWNER/$TAP" >/dev/null 2>&1; then
  git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/$OWNER/$TAP.git"
  git push -q -u origin main
else
  gh repo create "$OWNER/$TAP" --public --source=. --remote=origin --push \
    --description "Homebrew tap for $OWNER" >/dev/null
fi

echo
echo "Done. Install with:"
echo "  brew install --cask $OWNER/tap/$CASK"
