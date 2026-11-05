#!/usr/bin/env python3
"""
يجهّز مشروع الأندرويد الذي أنشأه `flutter create` ليعمل به SAKINA:
  1) الأذونات + خدمات الصوت + مستقبلات التنبيهات والويدجت في AndroidManifest
  2) MainActivity تعتمد AudioServiceActivity (تشغيل القرآن بالخلفية)
  3) نسخ ويدجت Kotlin والموارد والأيقونات
  4) نسخ ملفات الأذان من assets/adhan إلى res/raw (صوت الإشعار)
  5) تفعيل core library desugaring المطلوب لمكتبة الإشعارات
شغّله من جذر المشروع بعد flutter create.
"""
import glob
import os
import re
import shutil
import sys

ROOT = os.getcwd()
APP = os.path.join(ROOT, 'android', 'app')
MAIN = os.path.join(APP, 'src', 'main')
MARK = 'SAKINA_PATCHED'


def read(p):
    with open(p, encoding='utf-8') as f:
        return f.read()


def write(p, s):
    with open(p, 'w', encoding='utf-8') as f:
        f.write(s)


def fail(msg):
    print('ERROR:', msg)
    sys.exit(1)


if not os.path.isdir(MAIN):
    fail('android/ غير موجود. شغّل flutter create أولًا.')

# ---------------------------------------------------------------- 1) Manifest
mf = os.path.join(MAIN, 'AndroidManifest.xml')
s = read(mf)
if MARK not in s:
    perms = [
        'INTERNET', 'POST_NOTIFICATIONS', 'SCHEDULE_EXACT_ALARM', 'RECEIVE_BOOT_COMPLETED',
        'VIBRATE', 'WAKE_LOCK', 'FOREGROUND_SERVICE', 'FOREGROUND_SERVICE_MEDIA_PLAYBACK',
    ]
    perm_xml = '    <!-- %s -->\n' % MARK + ''.join(
        '    <uses-permission android:name="android.permission.%s"/>\n' % p for p in perms)
    s = s.replace('<application', perm_xml + '    <application', 1)
    s = re.sub(r'android:label="[^"]*"', 'android:label="سكينة"', s, count=1)

    components = '''
        <service android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService"/>
            </intent-filter>
        </service>
        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON"/>
            </intent-filter>
        </receiver>

        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>

        <receiver android:name=".SakinaWidgetProvider"
            android:label="سكينة - المواقيت"
            android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>
            </intent-filter>
            <meta-data android:name="android.appwidget.provider"
                android:resource="@xml/sakina_widget_info"/>
        </receiver>
'''
    s = s.replace('</application>', components + '    </application>', 1)
    write(mf, s)
    print('manifest patched')
else:
    print('manifest already patched')

# ---------------------------------------------------------------- 2) MainActivity + widget provider
kt_files = glob.glob(os.path.join(MAIN, 'kotlin', '**', 'MainActivity.kt'), recursive=True)
if not kt_files:
    fail('MainActivity.kt غير موجود (هل المشروع بلغة Kotlin؟)')
main_kt = kt_files[0]
pkg = re.search(r'^package\s+([\w.]+)', read(main_kt), re.M).group(1)
write(main_kt,
      'package %s\n\nimport com.ryanheise.audioservice.AudioServiceActivity\n\n'
      'class MainActivity : AudioServiceActivity()\n' % pkg)
provider = read(os.path.join(ROOT, 'android_native', 'kotlin', 'SakinaWidgetProvider.kt'))
write(os.path.join(os.path.dirname(main_kt), 'SakinaWidgetProvider.kt'),
      provider.replace('{{PKG}}', pkg))
print('MainActivity + widget provider written for package', pkg)

# ---------------------------------------------------------------- 3) Resources
src_res = os.path.join(ROOT, 'android_native', 'res')
dst_res = os.path.join(MAIN, 'res')
for dirpath, _, files in os.walk(src_res):
    rel = os.path.relpath(dirpath, src_res)
    out = os.path.join(dst_res, rel)
    os.makedirs(out, exist_ok=True)
    for f in files:
        shutil.copy2(os.path.join(dirpath, f), os.path.join(out, f))
print('resources copied')

# ---------------------------------------------------------------- 4) Adhan audio -> res/raw
raw_dir = os.path.join(dst_res, 'raw')
adhan_src = os.path.join(ROOT, 'assets', 'adhan')
copied = []
seen = {}
if os.path.isdir(adhan_src):
    for f in sorted(os.listdir(adhan_src)):
        base, ext = os.path.splitext(f)
        if ext.lower() not in ('.mp3', '.ogg', '.wav'):
            continue
        if not re.fullmatch(r'[a-z][a-z0-9_]*', base):
            print('WARNING: اسم الملف غير صالح لأندرويد (حروف إنجليزية صغيرة وأرقام و _ فقط):', f)
            continue
        if base in seen:
            print('WARNING: تكرار الاسم', base, '- تم تجاهل', f)
            continue
        seen[base] = f
        os.makedirs(raw_dir, exist_ok=True)
        shutil.copy2(os.path.join(adhan_src, f), os.path.join(raw_dir, base + ext.lower()))
        copied.append(f)
print('adhan files -> res/raw:', copied if copied else 'none (default notification sound will be used)')

# ---------------------------------------------------------------- 5) Gradle desugaring
kts = os.path.join(APP, 'build.gradle.kts')
groovy = os.path.join(APP, 'build.gradle')
if os.path.exists(kts):
    g = read(kts)
    if 'isCoreLibraryDesugaringEnabled' not in g:
        g, n = re.subn(r'(compileOptions\s*\{)', r'\1\n        isCoreLibraryDesugaringEnabled = true', g, count=1)
        if n == 0:
            fail('تعذر العثور على compileOptions في build.gradle.kts')
        g += '\n\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
        write(kts, g)
    print('gradle (kts) desugaring ok')
elif os.path.exists(groovy):
    g = read(groovy)
    if 'coreLibraryDesugaringEnabled' not in g:
        g, n = re.subn(r'(compileOptions\s*\{)', r'\1\n        coreLibraryDesugaringEnabled true', g, count=1)
        if n == 0:
            fail('تعذر العثور على compileOptions في build.gradle')
        g += "\n\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
        write(groovy, g)
    print('gradle (groovy) desugaring ok')
else:
    fail('لم أجد build.gradle(.kts) داخل android/app')

print('DONE')
