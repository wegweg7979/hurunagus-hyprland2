#!/bin/bash
set -uo pipefail

LIST="/usr/share/ublue-os/flatpaks/system-flatpaks.list"
[[ -f "$LIST" ]] || exit 0

# Ensure the Flathub remote exists (idempotent), but keep going if it does not:
# an individual app failure should never abort the rest of the list.
if ! flatpak remote-add --system --if-not-exists flathub /etc/flatpak/remotes.d/flathub.flatpakrepo; then
    echo "warning: could not add the Flathub remote; flatpak installs may fail" >&2
fi

declare -A installed=()
while IFS= read -r app; do
    installed["$app"]=1
done < <(flatpak list --system --app --columns=application 2>/dev/null || true)

failed=()
while IFS= read -r app; do
    case "$app" in
        '' | \#*) continue ;;
    esac

    if [[ -n "${installed[$app]:-}" ]]; then
        continue
    fi

    echo "Installing missing flatpak: $app"
    if flatpak install --system -y flathub "$app"; then
        installed["$app"]=1
    else
        echo "warning: failed to install $app; continuing" >&2
        failed+=("$app")
    fi
done < "$LIST"

if (( ${#failed[@]} )); then
    echo "The following Flatpaks could not be installed:" >&2
    printf '  %s\n' "${failed[@]}" >&2
    echo "They will be retried on the next boot." >&2
fi

# Always succeed: one unavailable app must not fail the boot transaction.
exit 0
