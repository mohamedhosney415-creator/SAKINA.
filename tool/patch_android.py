
#!/usr/bin/env python3
# SAKINA Android patch
# Sets compileSdk 36 for the app AND all Android subprojects/plugins.
# Preserves manifest, audio service, notifications, widget and adhan resources.

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


# ---------------------------------------------------------
# 0) Verify generated Android project and SAKINA resources
# ---------------------------------------------------------

if not os.path.isdir(MAIN):
    fail("مجلد android غير موجود. يجب تشغيل flutter create أولاً.")

native_dir = os.path.join(ROOT, "android_native")
widget_source = os.path.join(
    native_dir, "kotlin", "SakinaWidgetProvider.kt"
)
native_res = os.path.join(native_dir, "res")

if not os.path.isfile(widget_source):
    fail("الملف android_native/kotlin/SakinaWidgetProvider.kt غير موجود.")

if not os.path.isdir(native_res):
    fail("المجلد android_native/res غير موجود.")

app_gradle = find_one([
    os.path.join(APP, "build.gradle.kts"),
    os.path.join(APP, "build.gradle"),
])

root_gradle = find_one([
    os.path.join(ANDROID, "build.gradle"),
    os.path.join(ANDROID, "build.gradle.kts"),
])

if not app_gradle:
    fail("لم أجد build.gradle أو build.gradle.kts داخل android/app.")

if not root_gradle:
    fail("لم أجد ملف Gradle الرئيسي داخل android.")


# ---------------------------------------------------------
# 1) AndroidManifest: permissions, audio, notifications, widget
# ---------------------------------------------------------

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
        + "".join(
            '    <uses-permission android:name="android.permission.'
            + permission + '"/>\n'
            for permission in permissions
        )
    )

    if "<application" not in content:
        fail("لم أجد application داخل AndroidManifest.xml.")

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
        fail("لم أجد نهاية application داخل AndroidManifest.xml.")

    content = content.replace(
        "</application>",
        components + "\n    </application>",
        1
    )

    write(manifest, content)
    print("OK: AndroidManifest patched.")
else:
    print("OK: AndroidManifest already patched.")


# ---------------------------------------------------------
# 2) MainActivity and widget provider
# ---------------------------------------------------------

main_files = glob.glob(
    os.path.join(MAIN, "kotlin", "**", "MainActivity.kt"),
    recursive=True
)

if not main_files:
    fail("MainActivity.kt غير موجود.")

main_activity = main_files[0]
main_content = read(main_activity)

package_match = re.search(
    r"^\s*package\s+([\w.]+)",
    main_content,
    re.MULTILINE
)

if not package_match:
    fail("تعذر تحديد package داخل MainActivity.kt.")

package_name = package_match.group(1)

write(
    main_activity,
    "package " + package_name + "\n\n"
    "import com.ryanheise.audioservice.AudioServiceActivity\n\n"
    "class MainActivity : AudioServiceActivity()\n"
)

provider_content = read(widget_source).replace(
    "{{PKG}}",
    package_name
)

provider_destination = os.path.join(
    os.path.dirname(main_activity),
    "SakinaWidgetProvider.kt"
)

write(provider_destination, provider_content)

print("OK: MainActivity and widget provider configured.")


# ---------------------------------------------------------
# 3) Copy widget resources
# ---------------------------------------------------------

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

print("OK: Android widget resources copied.")


# ---------------------------------------------------------
# 4) Copy adhan audio files into Android res/raw
# ---------------------------------------------------------

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
            print("WARNING: Invalid Android audio filename:", filename)
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

print("OK: Adhan audio copied:", copied_audio or "No audio files found.")


# ---------------------------------------------------------
# 5) Set app compileSdk to 36 and enable desugaring
# ---------------------------------------------------------

is_kts = app_gradle.endswith(".kts")
gradle_content = read(app_gradle)

# Update the app compileSdk without changing minSdk or targetSdk.
compile_pattern = re.compile(
    r"(?m)^(\s*)compileSdk(?:Version)?\s*(?:=\s*)?[^;\n]+"
)

if compile_pattern.search(gradle_content):
    replacement = (
        r"\g<1>compileSdk = 36"
        if is_kts
        else r"\g<1>compileSdk 36"
    )

    gradle_content = compile_pattern.sub(
        replacement,
        gradle_content,
        count=1
    )
else:
    fail("تعذر العثور على compileSdk داخل ملف Gradle الخاص بالتطبيق.")

# Enable core library desugaring.
if "isCoreLibraryDesugaringEnabled" not in gradle_content and \
        "coreLibraryDesugaringEnabled" not in gradle_content:

    if is_kts:
        gradle_content, count = re.subn(
            r"(compileOptions\s*\{)",
            r"\1\n        isCoreLibraryDesugaringEnabled = true",
            gradle_content,
            count=1
        )

        if count == 0:
            fail("لم أجد compileOptions داخل build.gradle.kts.")

        gradle_content += (
            "\n\n// " + DESUGARING_MARK + "\n"
            "dependencies {\n"
            '    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n'
            "}\n"
        )

    else:
        gradle_content, count = re.subn(
            r"(compileOptions\s*\{)",
            r"\1\n        coreLibraryDesugaringEnabled true",
            gradle_content,
            count=1
        )

        if count == 0:
            fail("لم أجد compileOptions داخل build.gradle.")

        gradle_content += (
            "\n\n// " + DESUGARING_MARK + "\n"
            "dependencies {\n"
            "    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n"
            "}\n"
        )

write(app_gradle, gradle_content)

print("OK: App compileSdk set to 36.")
print("OK: Core library desugaring configured.")


# ---------------------------------------------------------
# 6) IMPORTANT: Set compileSdk 36 for ALL Android plugins
# ---------------------------------------------------------

root_content = read(root_gradle)

if ROOT_GRADLE_MARK not in root_content:

    if root_gradle.endswith(".kts"):
        global_compile_sdk = """

// SAKINA_COMPILE_SDK_36
// Apply API 36 to every Android app/library module,
// including Flutter plugin modules such as file_picker.
subprojects {
    afterEvaluate {
        val androidExtension = extensions.findByName("android")

        if (androidExtension != null) {
            val compileSdkMethod = androidExtension.javaClass.methods.firstOrNull {
                it.name == "compileSdkVersion" &&
                it.parameterCount == 1 &&
                it.parameterTypes[0] == Int::class.javaPrimitiveType
            }

            if (compileSdkMethod != null) {
                compileSdkMethod.invoke(androidExtension, 36)
            } else {
                val compileSdkSetter = androidExtension.javaClass.methods.firstOrNull {
                    it.name == "setCompileSdk" && it.parameterCount == 1
                }

                compileSdkSetter?.invoke(androidExtension, 36)
            }
        }
    }
}
"""
    else:
        global_compile_sdk = """

// SAKINA_COMPILE_SDK_36
// Apply API 36 to every Android app/library module,
// including Flutter plugin modules such as file_picker.
subprojects {
    afterEvaluate { subproject ->
        def androidExtension = subproject.extensions.findByName("android")

        if (androidExtension != null) {
            try {
                androidExtension.compileSdkVersion(36)
            } catch (Exception ignored) {
                try {
                    androidExtension.compileSdk = 36
                } catch (Exception secondError) {
                    throw new GradleException(
                        "SAKINA: Could not set compileSdk 36 for " +
                        subproject.path,
                        secondError
                    )
                }
            }
        }
    }
}
"""

    root_content += global_compile_sdk
    write(root_gradle, root_content)

    print("OK: Global compileSdk 36 rule added to Android subprojects.")
else:
    print("OK: Global compileSdk 36 rule already exists.")


# ---------------------------------------------------------
# 7) Finish
# ---------------------------------------------------------

print("")
print("========================================")
print("SAKINA ANDROID PATCH COMPLETED")
print("App compileSdk: 36")
print("Android plugin modules: compileSdk 36")
print("minSdk: unchanged")
print("targetSdk: unchanged")
print("Audio, notifications and widget: preserved")
print("========================================")
