#!/usr/bin/env bash
# Patches the pinned android-components submodule for the standalone (non
# mozilla-central) fork layout.
#
# The upstream android-components build files assume the mozilla-central
# monorepo layout, where the catalog lives N directories above the component.
# In Icefox the submodule sits at the repository root, so those relative paths
# must be rewritten (and `mobile/android/version.txt` collapsed to the root
# version.txt).
#
# Idempotent: running it multiple times is safe.
set -euo pipefail

AC_DIR="${1:-android-components}"

patch_file() {
    local file="$1"
    local from="$2"
    local to="$3"
    if [ ! -f "$file" ]; then
        echo "patch-android-components: missing $file" >&2
        exit 1
    fi
    if grep -qF "$to" "$file" && ! grep -qF "$from" "$file"; then
        return 0 # already patched
    fi
    sed -i "s|$(printf '%s' "$from" | sed 's/[&/\]/\\&/g')|$(printf '%s' "$to" | sed 's/[&/\]/\\&/g')|g" "$file"
    echo "patched: $file"
}

# 1. Version catalog paths -> repository root gradle/libs.versions.toml
patch_file "$AC_DIR/settings.gradle" \
    'from(files("../../../gradle/libs.versions.toml"))' \
    'from(files("../gradle/libs.versions.toml"))'

for sub in config dependencies publicsuffixlist; do
    patch_file "$AC_DIR/plugins/$sub/settings.gradle.kts" \
        'from(files("../../../../../gradle/libs.versions.toml"))' \
        'from(files("../../../gradle/libs.versions.toml"))'
done

# 2. version.txt location (mozilla-central: <root>/mobile/android/version.txt)
patch_file "$AC_DIR/plugins/config/src/main/java/ConfigPlugin.kt" \
    'Paths.get(topsrcdir, "mobile/android/version.txt")' \
    'Paths.get(topsrcdir, "version.txt")'

# 3. GeckoView 160 removed IPProtectionController.SERVICE_STATE_OPTED_OUT;
#    drop the mapping branch so engine-gecko compiles against GV 160+.
IPPROT_DELEGATE="$AC_DIR/components/browser/engine-gecko/src/main/java/mozilla/components/browser/engine/gecko/ipprotection/GeckoIPProtectionDelegate.kt"
if [ -f "$IPPROT_DELEGATE" ] && grep -qF 'SERVICE_STATE_OPTED_OUT' "$IPPROT_DELEGATE"; then
    sed -i '/SERVICE_STATE_OPTED_OUT/d' "$IPPROT_DELEGATE"
    echo "patched: GeckoIPProtectionDelegate.kt (removed SERVICE_STATE_OPTED_OUT branch)"
fi

echo "patch-android-components: done"
