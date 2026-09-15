portable_sed_i() {
    if sed v </dev/null 2> /dev/null; then
        sed -i "$@"
    else
        sed -i '' "$@"
    fi
}

apply_patches() {
    local srcdir=$(realpath "$1")
    local targetdir=$(realpath "$2")
    local exclude_re="${3:-}"
    local patches=$(find "$srcdir" -type f | sort)

    pushd "$targetdir"

    for patch in $patches; do
        if [ -n "$exclude_re" ] && [[ "$(basename "$patch")" =~ $exclude_re ]]; then
            echo "[*] Skipping patch $(basename "$patch")"
            continue
        fi
        patch -p1 < "$patch"
    done

    popd
}

# Alle Manifeste (Haupt-App und Addons) auf eine eigene sharedUserId setzen
set_shared_user_id() {
    local targetdir="$1"
    local shared_id="$2"

    find "$targetdir" -type f -name AndroidManifest.xml -path '*/src/main/*' | while read -r file; do
        if grep -q 'android:sharedUserId=' "$file"; then
            echo "[*] Setting sharedUserId=\"$shared_id\" in $file"
            portable_sed_i -e "s|android:sharedUserId=\"[^\"]*\"|android:sharedUserId=\"$shared_id\"|g" "$file"
        fi
    done
}

replace_termux_name() {
    if [[ "$TERMUX_APP__PACKAGE_NAME" == "com.termux" ]]; then
        return
    fi
    local targetdir="$1"
    local replacement_name="$2"
    local replacement_name_underscore="$(echo "$replacement_name" | tr . _)"
    local replacement_name_slash="$(echo "$replacement_name" | tr . /)"

    pushd "$targetdir"
    
    # Nur Textdateien bearbeiten, um Fehler zu vermeiden
    local file
    find . -type f -exec file {} + | grep "text" | cut -d: -f1 | while read -r file; do
        portable_sed_i -e "s|>Termux<|>$replacement_name<|g" \
                       -e "s|\"Termux\"|\"$replacement_name\"|g" \
                       -e "s|Termux:|$replacement_name:|g" \
                       -e "s|com\.termux|$replacement_name|g" \
                       -e "s|com_termux|$replacement_name_underscore|g" \
                       -e '/http/!s|com/termux|'$replacement_name_slash'|g' "$file"
    done

    popd
}

# Funktion, um Ordner zu migrieren
migrate_termux_folder() {
    if [[ "$TERMUX_APP__PACKAGE_NAME" == "com.termux" ]]; then
        return
    fi
    local parentdir="$(dirname "$(dirname "$1")")"
    local replacement_name="$2"
    local destination="${parentdir}/$(echo "$replacement_name" | tr . /)/"

    echo "Migrating folder:"
    echo "- ${parentdir}/com/termux/"
    echo "to"
    echo "+ ${destination}"
    mkdir -p "${destination}"
    mv "${parentdir}/com/termux/"* "${destination}"
    rm -r "${parentdir}/com/termux/"
}

migrate_termux_folder_tree() {
    if [[ "$TERMUX_APP__PACKAGE_NAME" == "com.termux" ]]; then
        return
    fi
    local targetdir="$1"
    local replacement_name="$2"

    pushd "$targetdir"

    # Vollständig macOS-kompatible Variante für Verzeichnismigration
    local dir
    find "$(pwd)" -type d -name termux | grep -v -e 'shared/termux' -e 'settings/termux' | while read -r dir; do
        migrate_termux_folder "$dir" "$replacement_name"
    done

    popd
}
