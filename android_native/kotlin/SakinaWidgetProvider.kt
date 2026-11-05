package {{PKG}}

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.SystemClock
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * ويدجت سكينة: الصلاة القادمة + العدّ التنازلي + مواقيت الصلوات الخمس + التاريخ الهجري.
 * البيانات تأتي من التطبيق (قائمة مواقيت ٥ أيام) فيعمل الويدجت دون إنترنت وبدون فتح التطبيق.
 */
class SakinaWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val raw = widgetData.getString("upcoming", "") ?: ""
        val entries = raw.split(";").mapNotNull { e ->
            val p = e.split(",")
            val t = if (p.size == 2) p[1].toLongOrNull() else null
            if (t != null) Pair(p[0], t) else null
        }
        val now = System.currentTimeMillis()
        val idx = entries.indexOfFirst { it.second > now }
        val fmt = SimpleDateFormat("h:mm a", Locale("ar", "EG")).apply {
            timeZone = TimeZone.getTimeZone("Africa/Cairo")
        }
        val nameIds = intArrayOf(R.id.w_n0, R.id.w_n1, R.id.w_n2, R.id.w_n3, R.id.w_n4)
        val timeIds = intArrayOf(R.id.w_t0, R.id.w_t1, R.id.w_t2, R.id.w_t3, R.id.w_t4)

        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.sakina_widget)
            views.setTextViewText(R.id.w_hijri, widgetData.getString("hijri", "") ?: "")
            views.setTextViewText(R.id.w_city, widgetData.getString("city", "") ?: "")

            if (idx >= 0) {
                val next = entries[idx]
                views.setTextViewText(R.id.w_next_name, "الصلاة القادمة: " + next.first)
                val base = SystemClock.elapsedRealtime() + (next.second - now)
                views.setChronometer(R.id.w_chrono, base, null, true)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    views.setChronometerCountDown(R.id.w_chrono, true)
                }
                val dayStart = (idx / 5) * 5
                for (k in 0 until 5) {
                    val e = entries.getOrNull(dayStart + k)
                    if (e != null) {
                        views.setTextViewText(nameIds[k], e.first)
                        views.setTextViewText(timeIds[k], fmt.format(Date(e.second)))
                    }
                }
                scheduleRefresh(context, appWidgetIds, next.second + 2000)
            } else {
                views.setTextViewText(R.id.w_next_name, "افتح سكينة لتحديث المواقيت")
            }

            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launch != null) {
                val pi = PendingIntent.getActivity(
                    context, 0, launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.w_root, pi)
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    /** يحدّث الويدجت لحظة دخول الصلاة القادمة ليظهر الموعد التالي. */
    private fun scheduleRefresh(context: Context, ids: IntArray, at: Long) {
        try {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val i = Intent(context, SakinaWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            val pi = PendingIntent.getBroadcast(
                context, 1, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setAndAllowWhileIdle(AlarmManager.RTC, at, pi)
            } else {
                am.set(AlarmManager.RTC, at, pi)
            }
        } catch (_: Exception) {
        }
    }
}
