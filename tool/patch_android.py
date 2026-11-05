
#!/usr/bin/env python3

import glob
import json
import os
import re
import shutil
import sys

ROOT = os.path.abspath(os.getcwd())
ANDROID = os.path.join(ROOT, "android")
APP = os.path.join(ANDROID, "app")
MAIN = os.path.join(APP, "src", "main")

MANIFEST_MARK = "SAKINA_PATCHED"
ROOT_GRADLE_MARK = "SAKINA_COMPILE_SDK_36"


def fail(message):
    print("ERROR:", message)
    sys.exit(1)


def read(path):
    with open(path, "r", encoding="utf-8") as file:
        return file.read()


def write(path, content):
    with open(path, "w", encoding="utf-8", newline="\n") as file:
        file.write(content)


def find_one(paths):
    for path in paths:
        if os.path.isfile(path):
            return path
    return None


def set_compile_sdk(content, is_kts, description):
    """
    Replace an existing compileSdk declaration without changing
    minSdk or targetSdk.
    Supports common Groovy and Kotlin Gradle syntax.
    """
    lines = content.splitlines()
    changed = False

    pattern = re.compile(
        r"^(\s*)(compileSdkVersion|compileSdk)"
        r"\s*(?:=\s*)?(?:\([^()\r\n]*\)|[^;\r\n]+?)"
        r"\s*(;?\s*(?://.*)?)$"
    )

    for index, line in enumerate(lines):
        match = pattern.match(line)
        if not match:
            continue

        indent, name, ending = match.groups()

        if is_kts:
            lines[index] = f"{indent}{name} = 36{ending}"
        else:
            lines[index] = f"{indent}{name} 36{ending}"

        changed = True
        break

    if not changed:
        return content, False

    return "\n".join(lines) + ("\n" if content.endswith("\n") else ""), True


def patch_plugin_compile_sdk(plugin_path, plugin_name):
    android_dir = os.path.join(plugin_path, "android")

    if not os.path.isdir(android_dir):
        return False

    gradle_files = [
        os.path.join(android_dir, "build.gradle.kts"),
        os.path.join(android_dir, "build.gradle"),
    ]

    gradle_file = find_one(gradle_files)

    if not gradle_file:
        return False

    content = read(gradle_file)
    is_kts = gradle_file.endswith(".kts")

    updated, changed = set_compile_sdk(
        content,
        is_kts,
        f"plugin {plugin_name}"
    )

    if changed:
        write(gradle_file, updated)
        print(f"OK: {plugin_name} compileSdk set to 36")
        return True

    # Some plugins use a variable or omit compileSdk.
    # Insert the override at the beginning of their android block.
    android_block = re.search(r"(?m)^(\s*)android\s*\{", content)

    if android_block:
        insertion = (
            f"{android_block.group(1)}android {{\n"
            f"{android_block.group(1)}    "
            f"{'compileSdk = 36' if is_kts else 'compileSdk 36'}"
        )

        updated = (
            content[:android_block.start()]
            + insertion
            + content[android_block.end():]
        )

        write(gradle_file, updated)
        print(f"OK: {plugin_name} compileSdk override inserted")
        return True

    print(f"WARNING: No Android Gradle block found for {plugin_name}")
    return False


def patch_all_android_plugins():
    plugins_file = os.path.join(ROOT, ".flutter-plugins-dependencies")

    if not os.path.isfile(plugins_file):
        fail(
            ".flutter-plugins-dependencies not found. "
            "Run flutter pub get before this script."
        )

    try:
        data = json.loads(read(plugins_file))
    except Exception as error:
        fail(f"Could not read Flutter plugin metadata: {error}")

    android_plugins = data.get("plugins", {}).get("android", [])

    if not android_plugins:
        fail("No Android plugins were found in Flutter plugin metadata.")

    patched_names = []

    for plugin in android_plugins:
        name = plugin.get("name", "unknown")
        plugin_path = plugin.get("path", "")

        if not plugin_path:
            print(f"WARNING: Missing path for plugin {name}")
            continue

        if not os.path.isabs(plugin_path):
            plugin_path = os.path.abspath(
                os.path.join(ROOT, plugin_path)
            )

        if not os.path.isdir(plugin_path):
            print(f"WARNING: Plugin directory not found: {name}")
            continue

        if patch_plugin_compile_sdk(plugin_path, name):
            patched_names.append(name)

    if "file_picker" not in patched_names:
        fail(
            "Could not patch file_picker compileSdk. "
            "Check the Flutter plugin metadata and file_picker Gradle file."
        )

    print(
        "OK: Android plugin compileSdk patching completed. "
        f"Patched {len(patched_names)} plugin(s)."
    )


# =========================================================
# 0. Verify generated Android project and native resources
# =========================================================

if not os.path.isdir(MAIN):
    fail("Android project not found. Run flutter create first.")

native_dir = os.path.join(ROOT, "android_native")
widget_source = os.path.join(
    native_dir, "kotlin", "SakinaWidgetProvider.kt"
)
native_res = os.path.join(native_dir, "res")

if not os.path.isfile(widget_source):
    fail("Missing android_native/kotlin/SakinaWidgetProvider.kt")

if not os.path.isdir(native_res):
    fail("Missing android_native/res directory.")

app_gradle = find_one([
    os.path.join(APP, "build.gradle.kts"),
    os.path.join(APP, "build.gradle"),
])

root_gradle = find_one([
    os.path.join(ANDROID, "build.gradle.kts"),
    os.path.join(ANDROID, "build.gradle"),
])

if not app_gradle:
    fail("App Gradle file not found.")

if not root_gradle:
    fail("Root Gradle file not found.")


# =========================================================
# 1. Android Manifest
# =========================================================

manifest = os.path.join(MAIN, "AndroidManifest.xml")

if not os.path.isfile(manifest):
    fail("AndroidManifest.xml not found.")

content = read(manifest)

if MANIFEST_MARK not in content:
    permissions = [
        "INTERNET",
        "POST_NOTIFICATIONS",
        "SCHEDULE_EXACT_ALARM",
        "RECEIVE_BOOT_COMPLETED",
        "VIBRATE",
        "WAKE_LOCK",
        "FOREGROUND_SERVICE",
        "FOREGROUND_SERVICE_MEDIA_PLAYBACK",
    ]

    permission_xml = f"    <!-- {MANIFEST_MARK} -->\n"

    for permission in permissions:
        permission_xml += (
            '    <uses-permission android:name="android.permission.'
            + permission
            + '"/>\n'
        )

    if "<application" not in content:
        fail("AndroidManifest.xml has no application element.")

    content = content.replace(
        "<application",
        permission_xml + "    <application",
        1
    )

    content = re.sub(
        r'android:label="[^"]*"',
        'android:label="سكينة"',
        content,
        count=1
    )

    components = """
        <service
            android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService"/>
            </intent-filter>
        </service>

        <receiver
            android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON"/>
            </intent-filter>
        </receiver>

        <receiver
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"
            android:exported="false"/>

        <receiver
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
            android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>

        <receiver
            android:name=".SakinaWidgetProvider"
            android:label="سكينة - المواقيت"
            android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/sakina_widget_info"/>
        </receiver>
"""

    if "</application>" not in content:
        fail("AndroidManifest.xml has no closing application element.")

    content = content.replace(
        "</application>",
        components + "\n    </application>",
        1
    )

    write(manifest, content)
    print("OK: Android Manifest configured.")
else:
    print("OK: Android Manifest already configured.")


# =========================================================
# 2. MainActivity
# =========================================================

main_files = glob.glob(
    os.path.join(MAIN, "kotlin", "**", "MainActivity.kt"),
    recursive=True
)

if not main_files:
    fail("MainActivity.kt not found.")

main_activity = main_files[0]
main_content = read(main_activity)

package_match = re.search(
    r"^\s*package\s+([\w.]+)",
    main_content,
    re.MULTILINE
)

if not package_match:
    fail("Could not detect MainActivity package.")

package_name = package_match.group(1)

main_activity_content = (
    f"package {package_name}\n\n"
    "import com.ryanheise.audioservice.AudioServiceActivity\n\n"
    "class MainActivity : AudioServiceActivity()\n"
)

write(main_activity, main_activity_content)
print("OK: MainActivity configured.")


# =========================================================
# 3. Widget Provider
# =========================================================

provider_content = read(widget_source)
provider_content = provider_content.replace(
    "{{PKG}}",
    package_name
)

provider_destination = os.path.join(
    os.path.dirname(main_activity),
    "SakinaWidgetProvider.kt"
)

write(provider_destination, provider_content)
print("OK: Widget provider copied.")


# =========================================================
# 4. Copy Android resources
# =========================================================

destination_res = os.path.join(MAIN, "res")
os.makedirs(destination_res, exist_ok=True)

for directory, _, filenames in os.walk(native_res):
    relative = os.path.relpath(directory, native_res)
    output_directory = os.path.join(destination_res, relative)

    os.makedirs(output_directory, exist_ok=True)

    for filename in filenames:
        source = os.path.join(directory, filename)
        destination = os.path.join(output_directory, filename)
        shutil.copy2(source, destination)

print("OK: Widget resources copied.")


# =========================================================
# 5. Copy Adhan audio files
# =========================================================

adhan_source = os.path.join(ROOT, "assets", "adhan")

raw_directory = os.path.join(destination_res, "raw")
copied_audio = []

if os.path.isdir(adhan_source):
    os.makedirs(raw_directory, exist_ok=True)

    for filename in sorted(os.listdir(adhan_source)):
        base, extension = os.path.splitext(filename)

        if extension.lower() not in (".mp3", ".ogg", ".wav"):
            continue

        if not re.fullmatch(r"[a-z][a-z0-9_]*", base):
            print("WARNING: Invalid audio filename:", filename)
            continue

        destination = os.path.join(
            raw_directory,
            base + extension.lower()
        )

        shutil.copy2(
            os.path.join(adhan_source, filename),
            destination
        )

        copied_audio.append(filename)

print("OK: Adhan audio:", copied_audio or "No audio files found.")


# =========================================================
# 6. Set app compileSdk to 36
# =========================================================

is_kts = app_gradle.endswith(".kts")
gradle_content = read(app_gradle)

gradle_content, app_sdk_changed = set_compile_sdk(
    gradle_content,
    is_kts,
    "app"
)

if not app_sdk_changed:
    fail("Could not find compileSdk declaration in app Gradle file.")

print("OK: App compileSdk set to 36.")


# =========================================================
# 7. Configure core library desugaring
# =========================================================

if (
    "isCoreLibraryDesugaringEnabled" not in gradle_content
    and "coreLibraryDesugaringEnabled" not in gradle_content
):
    if is_kts:
        gradle_content, count = re.subn(
            r"(compileOptions\s*\{)",
            r"\1\n        isCoreLibraryDesugaringEnabled = true",
            gradle_content,
            count=1
        )
    else:
        gradle_content, count = re.subn(
            r"(compileOptions\s*\{)",
            r"\1\n        coreLibraryDesugaringEnabled true",
            gradle_content,
            count=1
        )

    if count == 0:
        fail("compileOptions not found in app Gradle file.")

if "com.android.tools:desugar_jdk_libs" not in gradle_content:
    if is_kts:
        gradle_content += """

dependencies {
    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.1.4"
    )
}
"""
    else:
        gradle_content += """

dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'
}
"""

write(app_gradle, gradle_content)
print("OK: Core library desugaring configured.")


# =========================================================
# 8. Remove the old late global compileSdk modification
# =========================================================

root_content = read(root_gradle)

if ROOT_GRADLE_MARK in root_content:
    root_content = root_content.split(
        f"// {ROOT_GRADLE_MARK}",
        1
    )[0].rstrip() + "\n"

    write(root_gradle, root_content)
    print("OK: Removed old late compileSdk Gradle hook.")
else:
    print("OK: No old global compileSdk hook found.")


# =========================================================
# 9. Patch Android plugin Gradle files BEFORE Gradle build
# =========================================================

patch_all_android_plugins()


# =========================================================
# 10. Final verification
# =========================================================

print("")
print("==========================================")
print("SAKINA ANDROID PATCH COMPLETED")
print("==========================================")
print("App compileSdk: 36")
print("Android plugin compileSdk: patched before Gradle build")
print("minSdk: unchanged")
print("targetSdk: unchanged")
print("Audio service: preserved")
print("Notifications: preserved")
print("Widget: preserved")
print("Adhan resources: copied")
print("No projectsEvaluated compileSdk modification")
print("==========================================")
