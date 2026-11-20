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

echo "patch-android-components: done"
