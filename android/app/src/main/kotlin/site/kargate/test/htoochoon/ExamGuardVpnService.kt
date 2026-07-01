package site.kargate.test.htoochoon

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat
import java.io.FileInputStream

/**
 * Local "network guard" for proctored exams.
 *
 * When active it establishes a device VPN tunnel that routes ALL traffic into
 * itself and simply drops it — EXCEPT this app, which is added as a disallowed
 * application so the exam keeps working normally. The net effect: while the
 * exam is running, no *other* app (browser, AI assistant, messaging, …) can
 * reach the internet, so the student can't look up answers. If the student
 * disables the VPN to regain internet, [onRevoke] fires and we report the
 * downtime to the teacher/admin.
 *
 * This is a deliberately simple, robust "block everything else" design (no
 * userspace TCP stack / DNS forwarding needed). Domain-level allow/deny is a
 * future enhancement.
 */
class ExamGuardVpnService : VpnService() {

    companion object {
        const val ACTION_START = "site.kargate.test.htoochoon.VPN_START"
        const val ACTION_STOP = "site.kargate.test.htoochoon.VPN_STOP"

        @Volatile
        var isRunning: Boolean = false
            private set

        /** Bridged to the Flutter EventChannel by MainActivity. */
        var stateListener: ((String) -> Unit)? = null

        private fun emit(state: String) {
            stateListener?.invoke(state)
        }
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var worker: Thread? = null

    // De-dupe domain hits so we don't spam the same host every packet. Maps a
    // domain to the last time (ms) we reported it.
    private val seen = HashMap<String, Long>()
    private val dedupeWindowMs = 10_000L

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopGuard()
            return START_NOT_STICKY
        }
        startGuard()
        return START_STICKY
    }

    private fun startGuard() {
        if (isRunning) return
        startForegroundSafe()
        try {
            val builder = Builder()
                .setSession("Exam Network Guard")
                .addAddress("10.111.222.1", 32)
                .setMtu(1500)
            try { builder.addRoute("0.0.0.0", 0) } catch (_: Exception) {}
            try { builder.addRoute("::", 0) } catch (_: Exception) {}

            // CRITICAL: exclude our own app so the exam keeps working. If this
            // fails we must NOT blackhole everything (that would block the
            // exam's own submission) — bail out instead.
            try {
                builder.addDisallowedApplication(packageName)
            } catch (e: Exception) {
                emit("error")
                stopSelf()
                return
            }

            val fd = builder.establish()
            if (fd == null) {
                emit("error")
                stopSelf()
                return
            }
            vpnInterface = fd
            isRunning = true
            emit("connected")
            startDrain(fd)
        } catch (e: Exception) {
            emit("error")
            stopSelf()
        }
    }

    /**
     * Drains captured packets so other apps get no connectivity, AND inspects
     * each one to recover the destination host (DNS query name / TLS SNI). This
     * gives the proctor a REAL log of which sites the student tried to reach
     * during the exam, with timestamps — not a static guess. Packets are still
     * dropped (block-all); we only read the headers, we never forward.
     */
    private fun startDrain(fd: ParcelFileDescriptor) {
        worker = Thread {
            val input = FileInputStream(fd.fileDescriptor)
            val buffer = ByteArray(32767)
            try {
                while (isRunning) {
                    val n = input.read(buffer)
                    if (n < 0) break
                    try {
                        inspect(buffer, n)
                    } catch (_: Exception) {
                        // Never let a malformed packet kill the drain loop.
                    }
                    // Payload intentionally dropped — no forwarding.
                }
            } catch (_: Exception) {
                // Closed interface / revoked — exit quietly.
            }
        }.apply { isDaemon = true; start() }
    }

    // ── packet inspection ──────────────────────────────────────────────────────

    /** Report a destination host once per dedupe window. */
    private fun report(host: String) {
        if (host.isBlank() || host.length > 253 || !host.contains('.')) return
        val now = System.currentTimeMillis()
        val last = seen[host]
        if (last != null && now - last < dedupeWindowMs) return
        seen[host] = now
        emit("hit:$host")
    }

    private fun u8(b: ByteArray, i: Int): Int = b[i].toInt() and 0xFF

    /** Parse an IP packet → locate the L4 payload → extract DNS/SNI host. */
    private fun inspect(p: ByteArray, len: Int) {
        if (len < 20) return
        val version = u8(p, 0) ushr 4
        val proto: Int
        val l4: Int
        when (version) {
            4 -> {
                val ihl = (u8(p, 0) and 0x0F) * 4
                if (ihl < 20 || len < ihl + 4) return
                proto = u8(p, 9)
                l4 = ihl
            }
            6 -> {
                if (len < 40) return
                proto = u8(p, 6) // next header (ignore extension headers — rare here)
                l4 = 40
            }
            else -> return
        }

        val dstPort: Int
        val payload: Int
        when (proto) {
            17 -> { // UDP
                if (len < l4 + 8) return
                dstPort = (u8(p, l4 + 2) shl 8) or u8(p, l4 + 3)
                payload = l4 + 8
            }
            6 -> { // TCP
                if (len < l4 + 20) return
                dstPort = (u8(p, l4 + 2) shl 8) or u8(p, l4 + 3)
                val dataOff = (u8(p, l4 + 12) ushr 4) * 4
                payload = l4 + dataOff
            }
            else -> return
        }
        if (payload >= len) return

        when (dstPort) {
            53 -> parseDnsQuery(p, payload, len)
            443 -> parseTlsSni(p, payload, len)
            // port 80 plaintext HTTP could be parsed for Host: but ~all traffic
            // is HTTPS now; SNI on 443 covers it.
        }
    }

    /** DNS query: skip the 12-byte header, decode the QNAME labels. */
    private fun parseDnsQuery(p: ByteArray, start: Int, len: Int) {
        var i = start + 12
        if (i >= len) return
        val sb = StringBuilder()
        while (i < len) {
            val labelLen = u8(p, i)
            if (labelLen == 0) break
            if (labelLen and 0xC0 != 0) return // compression pointer — bail
            i++
            if (i + labelLen > len) return
            if (sb.isNotEmpty()) sb.append('.')
            for (k in 0 until labelLen) sb.append((p[i + k].toInt() and 0xFF).toChar())
            i += labelLen
        }
        report(sb.toString().lowercase())
    }

    /**
     * TLS ClientHello: walk to the server_name extension and read the SNI host.
     * All offsets bounds-checked; bail silently on anything unexpected.
     */
    private fun parseTlsSni(p: ByteArray, start: Int, len: Int) {
        var i = start
        if (i + 5 > len) return
        if (u8(p, i) != 0x16) return // not a handshake record
        i += 5 // skip TLS record header
        if (i + 4 > len) return
        if (u8(p, i) != 0x01) return // not ClientHello
        i += 4 // handshake type(1) + length(3)
        i += 2 // client_version
        i += 32 // random
        if (i >= len) return
        val sidLen = u8(p, i); i += 1 + sidLen // session id
        if (i + 2 > len) return
        val csLen = (u8(p, i) shl 8) or u8(p, i + 1); i += 2 + csLen // cipher suites
        if (i >= len) return
        val compLen = u8(p, i); i += 1 + compLen // compression methods
        if (i + 2 > len) return
        var extEnd = i + 2 + ((u8(p, i) shl 8) or u8(p, i + 1)); i += 2
        if (extEnd > len) extEnd = len
        while (i + 4 <= extEnd) {
            val type = (u8(p, i) shl 8) or u8(p, i + 1)
            val extLen = (u8(p, i + 2) shl 8) or u8(p, i + 3)
            i += 4
            if (type == 0x00) { // server_name
                if (i + 5 > extEnd) return
                val nameLen = (u8(p, i + 3) shl 8) or u8(p, i + 4)
                val ns = i + 5
                if (ns + nameLen > extEnd) return
                val sb = StringBuilder()
                for (k in 0 until nameLen) sb.append((p[ns + k].toInt() and 0xFF).toChar())
                report(sb.toString().lowercase())
                return
            }
            i += extLen
        }
    }

    override fun onRevoke() {
        // Fired when the user turns the VPN off in system settings or another
        // VPN replaces ours. This is the key "network protection went off" signal.
        emit("revoked")
        stopGuard()
        super.onRevoke()
    }

    private fun stopGuard() {
        isRunning = false
        try { vpnInterface?.close() } catch (_: Exception) {}
        vpnInterface = null
        worker = null
        emit("stopped")
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        } catch (_: Exception) {}
        stopSelf()
    }

    override fun onDestroy() {
        stopGuard()
        super.onDestroy()
    }

    private fun startForegroundSafe() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    "exam_network_guard",
                    "Exam network guard",
                    NotificationManager.IMPORTANCE_LOW,
                )
                getSystemService(NotificationManager::class.java)
                    ?.createNotificationChannel(channel)
            }
            val notification: Notification =
                NotificationCompat.Builder(this, "exam_network_guard")
                    .setContentTitle("Exam in progress")
                    .setContentText("Network protection is active during your exam")
                    .setSmallIcon(android.R.drawable.ic_lock_lock)
                    .setOngoing(true)
                    .build()

            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(
                    7,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
                )
            } else {
                startForeground(7, notification)
            }
        } catch (_: Exception) {
            // If foreground promotion fails, the VPN still establishes while the
            // exam app is in the foreground.
        }
    }
}
