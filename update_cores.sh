
set -uo pipefail

for cmd in wget unzip; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: '$cmd' belum terinstall. Jalankan: pkg install $cmd -y"
        exit 1
    fi
done

cores=(
    "stella"
    "fceumm"
    "snes9x"
    "genesis_plus_gx"
    "gambatte"
    "mgba"
    "mupen64plus_next_gles3"
    "pcsx_rearmed"
    "ppsspp"
    "fbneo"
    "mame2003_plus"
    "prosystem"
    "handy"
    "mednafen_pce_fast"
    "dosbox_pure"
    "mednafen_ngp"
    "mednafen_wswan"
)

archs=("arm64-v8a")

delivery_install='<dist:install-time/>'

delivery_on_demand='
<dist:on-demand />
<dist:install-time>
    <dist:conditions>
        <dist:device-feature dist:name="android.software.leanback"/>
    </dist:conditions>
</dist:install-time>
'

declare -A chimeroid_core_names=(
    ["melondsds"]="melonds"
)

write_file() {
    local filepath="$1"
    local content="$2"
    mkdir -p "$(dirname "$filepath")"
    printf '%s\n' "$content" > "$filepath"
}

generate_gradle() {
    local core_name="$1"
    cat <<EOF
plugins {
    id("com.android.dynamic-feature")
    id("kotlin-android")
    id("kotlin-kapt")
}

android {
    namespace = "com.swordfish.chimeroid.core.${core_name}"
    defaultConfig {
        missingDimensionStrategy("opensource", "play")
        missingDimensionStrategy("cores", "dynamic")
    }
    packagingOptions {
        doNotStrip("*/*/*_libretro_android.so")
    }
}

dependencies {
    implementation(project(":chimeroid-app"))
    implementation(kotlin(deps.libs.kotlin.stdlib))
}
EOF
}

generate_manifest() {
    local core_name="$1"
    local install_time="$2"
    cat <<EOF
<manifest xmlns:dist="http://schemas.android.com/apk/distribution"
    xmlns:android="http://schemas.android.com/apk/res/android">

    <application
        android:hasCode="false"
        android:extractNativeLibs="true" />

    <dist:module dist:title="@string/core_name_${core_name}">
        <dist:delivery>
            ${install_time}
        </dist:delivery>
        <dist:fusing dist:include="true" />
    </dist:module>
</manifest>
EOF
}

if [ ${#cores[@]} -eq 0 ]; then
    echo "Tidak ada core yang di-uncomment di daftar \$cores. Edit dulu script-nya."
    exit 1
fi

for libretro_core_name in "${cores[@]}"; do
    chimeroid_core_name="${chimeroid_core_names[$libretro_core_name]:-$libretro_core_name}"

    core="${libretro_core_name}_libretro_android.so.zip"
    libretro_so_name="${libretro_core_name}_libretro_android.so"
    chimeroid_so_name="${chimeroid_core_name}_libretro_android.so"
    core_folder="chimeroid_core_${chimeroid_core_name}"

    # ganti ke "$delivery_install" kalau mau delivery install-time, bukan on-demand
    install_time="$delivery_on_demand"

    echo "=== Memproses core: $libretro_core_name ==="

    # rm -rf "$core_folder"   # <- uncomment kalau mau bersih total sebelum rebuild

    write_file "$core_folder/build.gradle.kts" "$(generate_gradle "$chimeroid_core_name")"
    write_file "$core_folder/src/main/AndroidManifest.xml" "$(generate_manifest "$chimeroid_core_name" "$install_time")"

    for arch in "${archs[@]}"; do
        lib_dir="$core_folder/src/main/jniLibs/$arch"

        echo "  -> Arsitektur: $arch"
        mkdir -p "$lib_dir"

        if ! wget -q "https://buildbot.libretro.com/nightly/android/latest/$arch/$core" -O "$lib_dir/$core"; then
            echo "     [GAGAL] Download $core untuk $arch, dilewati."
            rm -f "$lib_dir/$core"
            continue
        fi

        unzip -o -q "$lib_dir/$core" -d "$lib_dir"
        rm -f "$lib_dir/$core"
        mv -f "$lib_dir/$libretro_so_name" "$lib_dir/lib$chimeroid_so_name"

        echo "[OK] $arch selesai"
    done

    echo "Done: $libretro_core_name "
    echo
done

echo "All Done"
