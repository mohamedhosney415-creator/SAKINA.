
#!/usr/bin/env python3

import glob
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
DESUGARING_MARK = "SAKINA_DESUGARING"


def fail(message):
    print("ERROR:", message)
    sys.exit(1)


def read(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def write(path, content):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)


def find_one(paths):
    for path in paths:
        if os.path.isfile(path):
            return path
    return None


# =========================================================
# 0. Verify Android project
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

    permission_xml = (
        "    <!-- " + MANIFEST_MARK + " -->\n"
    )

    for permission in permissions:
        permission_xml += (
            '    <uses-permission android:name="android.permission.'
            + permission + '"/>\n'
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

    print("OK: Manifest configured.")

else:
    print("OK: Manifest already configured.")


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
    "package " + package_name + "\n\n"
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

    output_directory = os.path.join(
        destination_res,
        relative
    )

    os.makedirs(output_directory, exist_ok=True)

    for filename in filenames:

        source = os.path.join(directory, filename)

        destination = os.path.join(
            output_directory,
            filename
        )

        shutil.copy2(source, destination)

print("OK: Widget resources copied.")


# =========================================================
# 5. Copy Adhan audio files
# =========================================================

adhan_source = os.path.join(ROOT, "assets", "adhan")

raw_directory = os.path.join(
    destination_res,
    "raw"
)

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
# 6. App compileSdk 36
# =========================================================

is_kts = app_gradle.endswith(".kts")

gradle_content = read(app_gradle)

compile_pattern = re.compile(
    r"(?m)^(\s*)compileSdk(?:Version)?\s*(?:=\s*)?[^;\n]+"
)

if compile_pattern.search(gradle_content):

    if is_kts:
        replacement = r"\g<1>compileSdk = 36"
    else:
        replacement = r"\g<1>compileSdk 36"

    gradle_content = compile_pattern.sub(
        replacement,
        gradle_content,
        count=1
    )

else:
    fail("Could not find compileSdk in app Gradle file.")


# =========================================================
# 7. Core library desugaring
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

        if count == 0:
            fail("compileOptions not found in app Gradle file.")

        gradle_content += """

// SAKINA_DESUGARING
dependencies {
    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.1.4"
    )
}
"""

    else:

        gradle_content, count = re.subn(
            r"(compileOptions\s*\{)",
            r"\1\n        coreLibraryDesugaringEnabled true",
            gradle_content,
            count=1
        )

        if count == 0:
            fail("compileOptions not found in app Gradle file.")

        gradle_content += """

// SAKINA_DESUGARING
dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'
}
"""

write(app_gradle, gradle_content)

print("OK: App compileSdk set to 36.")
print("OK: Desugaring configured.")


# =========================================================
# 8. Global compileSdk 36
#    FIX: No Project.afterEvaluate()
# =========================================================

root_content = read(root_gradle)

# Remove the previous SAKINA block, if present.
if ROOT_GRADLE_MARK in root_content:

    root_content = re.sub(
        r"\n// SAKINA_COMPILE_SDK_36.*",
        "",
        root_content,
        flags=re.DOTALL
    )


if root_gradle.endswith(".kts"):

    global_compile_sdk = """

// SAKINA_COMPILE_SDK_36
// Set compileSdk 36 after all Gradle projects are evaluated.
// This avoids calling afterEvaluate on an already evaluated project.

gradle.projectsEvaluated {
    gradle.rootProject.subprojects.forEach { subproject ->

        val androidExtension =
            subproject.extensions.findByName("android")

        if (androidExtension != null) {

            val setter = androidExtension.javaClass.methods.firstOrNull {
                it.name == "compileSdkVersion" &&
                it.parameterCount == 1 &&
                it.parameterTypes[0] == Int::class.javaPrimitiveType
            }

            if (setter != null) {

                setter.invoke(androidExtension, 36)

                println(
                    "SAKINA: compileSdk 36 -> ${subproject.path}"
                )

            } else {

                throw GradleException(
                    "SAKINA: compileSdkVersion setter not found in " +
                    subproject.path
                )
            }
        }
    }
}
"""

else:

    global_compile_sdk = """

// SAKINA_COMPILE_SDK_36
// Set compileSdk 36 after all Gradle projects are evaluated.
// This avoids calling afterEvaluate on an already evaluated project.

gradle.projectsEvaluated {
    gradle.rootProject.subprojects.each { subproject ->

        def androidExtension =
            subproject.extensions.findByName("android")

        if (androidExtension != null) {

            def setter = androidExtension.class.methods.find {
                it.name == "compileSdkVersion" &&
                it.parameterCount == 1 &&
                it.parameterTypes[0] == Integer.TYPE
            }

            if (setter != null) {

                setter.invoke(androidExtension, 36)

                println(
                    "SAKINA: compileSdk 36 -> ${subproject.path}"
                )

            } else {

                throw new GradleException(
                    "SAKINA: compileSdkVersion setter not found in " +
                    subproject.path
                )
            }
        }
    }
}
"""

root_content += global_compile_sdk

write(root_gradle, root_content)

print("OK: Global compileSdk 36 rule configured.")


# =========================================================
# 9. Final verification
# =========================================================

print("")
print("==========================================")
print("SAKINA ANDROID PATCH COMPLETED")
print("==========================================")
print("App compileSdk: 36")
print("Android plugin modules: compileSdk 36")
print("minSdk: unchanged")
print("targetSdk: unchanged")
print("Audio service: preserved")
print("Notifications: preserved")
print("Widget: preserved")
print("Adhan resources: copied")
print("==========================================")
