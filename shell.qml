import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick

// ─── Entry point — state only, no visual rubbish in here ─────────────────────
ShellRoot {
    id: root

    // ── Design tokens ──────────────────────────────────────────────────────────
    readonly property real squircleRadius: 12
    readonly property real panelRadius:    30
    readonly property real pillRadius:     8

    // ── Animation constants ────────────────────────────────────────────────────
    readonly property real slideDir:       barEdge === "bottom" ? 1 : -1
    readonly property real slideDistance:  18
    readonly property var  popupBezierIn:  [0.2, 0.8, 0.2, 1.0]
    readonly property var  popupBezierOut: [0.4, 0.0, 1.0, 1.0]

    // ── Persisted settings ─────────────────────────────────────────────────────
    property string barEdge:         "bottom"
    property string weatherLocation: "Singapore"
    property string iconTheme:       ""
    property var    iconThemeList:   []
    property string homeDir:         ""

    Process {
        command: ["bash", "-c", "echo $HOME"]
        running: true
        stdout: SplitParser {
            onRead: (line) => { if (line.trim().length > 0) root.homeDir = line.trim() }
        }
    }

    Process {
        id: settingsReadProc
        command: ["bash", "-c", "cat ~/.config/mango/bar-settings.conf 2>/dev/null || true"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                var kv  = line.trim().split("=")
                if (kv.length < 2) return
                var key = kv[0].trim()
                var val = kv.slice(1).join("=").trim()
                if (key === "barEdge"         && ["top","bottom"].indexOf(val) !== -1) root.barEdge         = val
                if (key === "weatherLocation" && val.length > 0)                       root.weatherLocation = val
                if (key === "iconTheme"       && val.length > 0)                       root.iconTheme       = val
            }
        }
    }

    Process {
        id: iconThemeListProc
        command: [
            "bash", "-c",
            "for d in ~/.local/share/icons/*/; do " +
            "  name=$(basename \"$d\"); " +
            "  [ -f \"$d/index.theme\" ] && echo \"$name\"; " +
            "done 2>/dev/null || true"
        ]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                var name = line.trim()
                if (name.length === 0) return
                var list = root.iconThemeList.slice()
                list.push(name)
                root.iconThemeList = list
            }
        }
    }

    Process { id: settingsWriteProc;  running: false }
    Process { id: iconThemeApplyProc; running: false }

    function saveSettings() {
        var loc   = root.weatherLocation.replace(/['"\\]/g, "")
        var edge  = root.barEdge
        var theme = root.iconTheme.replace(/['"\\]/g, "")
        var cmd   = "mkdir -p ~/.config/mango && printf 'barEdge=%s\\nweatherLocation=%s\\niconTheme=%s\\n' "
                  + "'" + edge  + "' "
                  + "'" + loc   + "' "
                  + "'" + theme + "' "
                  + "> ~/.config/mango/bar-settings.conf"
        settingsWriteProc.command = ["bash", "-c", cmd]
        settingsWriteProc.running = true
    }

    function applyIconTheme(theme) {
        root.iconTheme = theme
        saveSettings()
        var t   = theme.replace(/['\\]/g, "")
        var cmd = theme.length > 0
            ? "gsettings set org.gnome.desktop.interface icon-theme '" + t + "' 2>/dev/null || true; "
              + "echo 'export QT_QPA_ICON_THEME=" + t + "' > ~/.config/mango/env"
            : "gsettings set org.gnome.desktop.interface icon-theme hicolor 2>/dev/null || true; "
              + "rm -f ~/.config/mango/env"
        iconThemeApplyProc.command = ["bash", "-c", cmd]
        iconThemeApplyProc.running = true
    }

    // ── Workspaces ─────────────────────────────────────────────────────────────
    function switchWorkspace(num) { Hyprland.dispatch("workspace " + num) }

    // ── Clock ──────────────────────────────────────────────────────────────────
    property string clockTime: Qt.formatTime(new Date(), "HH:mm")
    property string clockDate: Qt.formatDate(new Date(), "ddd d MMM")

    SystemClock {
        precision: SystemClock.Minutes
        onDateChanged: {
            root.clockTime = Qt.formatTime(date, "HH:mm")
            root.clockDate = Qt.formatDate(date, "ddd d MMM")
        }
    }

    // ── Battery ────────────────────────────────────────────────────────────────
    property int    batCapacity: 100
    property string batStatus:   "Unknown"
    property bool   batCharging: batStatus === "Charging" || batStatus === "Full"
    property color  batColor:    batCharging ? "#32d74b" : batCapacity <= 20 ? "#ff453a" : "#ffffff"

    Process {
        command: [
            "bash", "-c",
            "while true; do cat /sys/class/power_supply/BAT1/capacity 2>/dev/null || echo 0; " +
            "cat /sys/class/power_supply/BAT1/status 2>/dev/null || echo Unknown; sleep 30; done"
        ]
        running: true
        stdout: SplitParser {
            property bool nextIsStatus: false
            onRead: (line) => {
                if (!nextIsStatus) { root.batCapacity = parseInt(line.trim()); nextIsStatus = true }
                else               { root.batStatus   = line.trim();           nextIsStatus = false }
            }
        }
    }

    // ── Weather ────────────────────────────────────────────────────────────────
    property string weatherTemp:     "--°C"
    property string weatherIcon:     "🌡️"
    property var    chartData:       []
    property string currentTemp:     "--°C"
    property string currentDesc:     "—"
    property string todayLow:        "--°"
    property string todayHigh:       "--°"
    property string currentEmoji:    "🌡️"
    property var    lastWeatherFetch: null
    property bool   weatherLoading:  false

    // Resolved coordinates — cached alongside forecast so geocoding only
    // happens once per location change, not on every startup
    property real   weatherLat:       0.0
    property real   weatherLon:       0.0
    property bool   _coordsResolved:  false

    readonly property string _weatherCache: "/tmp/mango-weather.json"

    // WMO weather code → emoji (Open-Meteo uses WMO codes directly)
    function codeToEmoji(code) {
        var c = parseInt(code)
        if (c === 0)             return "☀️"
        if (c === 1)             return "🌤️"
        if (c === 2)             return "⛅"
        if (c === 3)             return "☁️"
        if (c >= 45 && c <= 48) return "🌫️"
        if (c >= 51 && c <= 67) return "🌧️"
        if (c >= 71 && c <= 77) return "🌨️"
        if (c >= 80 && c <= 82) return "🌧️"
        if (c >= 85 && c <= 86) return "🌨️"
        if (c >= 95 && c <= 99) return "⛈️"
        return "🌤️"
    }

    // WMO code → short description
    function codeToDesc(code) {
        var c = parseInt(code)
        if (c === 0)             return "Clear sky"
        if (c === 1)             return "Mainly clear"
        if (c === 2)             return "Partly cloudy"
        if (c === 3)             return "Overcast"
        if (c >= 45 && c <= 48) return "Foggy"
        if (c >= 51 && c <= 55) return "Drizzle"
        if (c >= 56 && c <= 57) return "Freezing drizzle"
        if (c >= 61 && c <= 65) return "Rain"
        if (c >= 66 && c <= 67) return "Freezing rain"
        if (c >= 71 && c <= 75) return "Snow"
        if (c === 77)            return "Snow grains"
        if (c >= 80 && c <= 82) return "Rain showers"
        if (c >= 85 && c <= 86) return "Snow showers"
        if (c >= 95 && c <= 99) return "Thunderstorm"
        return "Unknown"
    }

    function weatherNeedsRefresh() {
        if (root.lastWeatherFetch === null) return true
        return (new Date() - root.lastWeatherFetch) > 3600000
    }

    // Apply a parsed Open-Meteo forecast JSON to all weather properties
    function _applyOpenMeteo(json) {
        try {
            var cur   = json.current
            var daily = json.daily

            root.currentTemp  = Math.round(cur.temperature_2m) + "°C"
            root.currentDesc  = root.codeToDesc(cur.weather_code)
            root.currentEmoji = root.codeToEmoji(cur.weather_code)
            root.weatherIcon  = root.codeToEmoji(cur.weather_code)
            root.weatherTemp  = Math.round(cur.temperature_2m) + "°C"
            root.todayLow     = Math.round(daily.temperature_2m_min[0]) + "°"
            root.todayHigh    = Math.round(daily.temperature_2m_max[0]) + "°"

            var hourly  = json.hourly
            var nowUnix = Math.floor(Date.now() / 1000)
            var slots   = []

            for (var i = 0; i < hourly.time.length && slots.length < 9; i++) {
                var t     = hourly.time[i]
                var isNow = (t <= nowUnix && t + 3600 > nowUnix)
                if (t < nowUnix && !isNow) continue
                var d = new Date(t * 1000)
                slots.push({
                    label:     isNow ? "Now" : d.getHours().toString().padStart(2,"0") + ":00",
                    emoji:     root.codeToEmoji(hourly.weather_code[i]),
                    temp:      Math.round(hourly.temperature_2m[i]),
                    tempLabel: Math.round(hourly.temperature_2m[i]) + "°",
                    normY:     0
                })
            }

            if (slots.length > 0) {
                var temps = slots.map(function(s) { return s.temp })
                var minT  = Math.min.apply(null, temps)
                var maxT  = Math.max.apply(null, temps)
                var rng   = maxT - minT || 1
                for (var j = 0; j < slots.length; j++)
                    slots[j].normY = 1.0 - (slots[j].temp - minT) / rng
            }

            root.chartData        = slots.length > 0 ? slots : [{ label: "No data", emoji: "🤷", temp: 0, tempLabel: "--°", normY: 0.5 }]
            root.lastWeatherFetch = new Date()
            return true
        } catch(e) { return false }
    }

    // ── Cache read — fires immediately on startup ──────────────────────────
    property string _cacheBuf: ""

    Process {
        id: weatherCacheProc
        running: false
        stdout: SplitParser { onRead: (line) => { root._cacheBuf += line } }
        onRunningChanged: {
            if (running) return
            var raw = root._cacheBuf.trim()
            root._cacheBuf = ""
            if (raw.length > 0) {
                try {
                    var obj = JSON.parse(raw)
                    // Cache envelope: { lat, lon, forecast: <open-meteo JSON> }
                    if (obj.lat && obj.lon && obj.forecast) {
                        root.weatherLat      = obj.lat
                        root.weatherLon      = obj.lon
                        root._coordsResolved = true
                        root._applyOpenMeteo(obj.forecast)
                    }
                } catch(e) {}
            }
            root.fetchWeatherFull()
        }
    }

    // ── Geocoding — city name → lat/lon via Open-Meteo geocoding API ───────
    property string _geoBuf: ""

    Process {
        id: geoProc
        running: false
        stdout: SplitParser { onRead: (line) => { root._geoBuf += line } }
        onRunningChanged: {
            if (running) return
            var raw = root._geoBuf.trim()
            root._geoBuf = ""
            if (raw.length === 0) {
                root.weatherLoading = false
                root.chartData = [{ label: "No location", emoji: "📍", temp: 0, tempLabel: "--°", normY: 0.5 }]
                return
            }
            try {
                var json = JSON.parse(raw)
                if (!json.results || json.results.length === 0) {
                    root.weatherLoading = false
                    root.chartData = [{ label: "Not found", emoji: "📍", temp: 0, tempLabel: "--°", normY: 0.5 }]
                    return
                }
                root.weatherLat      = json.results[0].latitude
                root.weatherLon      = json.results[0].longitude
                root._coordsResolved = true
                root._doForecastFetch()
            } catch(e) {
                root.weatherLoading = false
                root.chartData = [{ label: "Geo error", emoji: "⚠️", temp: 0, tempLabel: "--°", normY: 0.5 }]
            }
        }
    }

    // ── Forecast fetch ─────────────────────────────────────────────────────
    property string _forecastBuf: ""

    Process {
        id: forecastProc
        running: false
        stdout: SplitParser { onRead: (line) => { root._forecastBuf += line } }
        onRunningChanged: {
            if (running) return
            root.weatherLoading = false
            var raw = root._forecastBuf.trim()
            root._forecastBuf = ""

            if (raw.length === 0) {
                if (root.chartData.length === 0)
                    root.chartData = [{ label: "No data", emoji: "⚠️", temp: 0, tempLabel: "--°", normY: 0.5 }]
                return
            }

            try {
                var json = JSON.parse(raw)
                if (!root._applyOpenMeteo(json)) {
                    if (root.chartData.length === 0)
                        root.chartData = [{ label: "Parse error", emoji: "⚠️", temp: 0, tempLabel: "--°", normY: 0.5 }]
                    return
                }
                // Write cache atomically: envelope with coords + raw forecast
                var envelope = JSON.stringify({ lat: root.weatherLat, lon: root.weatherLon, forecast: json })
                weatherCacheWriteProc.command = [
                    "bash", "-c",
                    "printf '%s' " + JSON.stringify(envelope) +
                    " > " + root._weatherCache + ".tmp && " +
                    "mv " + root._weatherCache + ".tmp " + root._weatherCache
                ]
                weatherCacheWriteProc.running = true
            } catch(e) {
                if (root.chartData.length === 0)
                    root.chartData = [{ label: "Parse error", emoji: "⚠️", temp: 0, tempLabel: "--°", normY: 0.5 }]
            }
        }
    }

    Process { id: weatherCacheWriteProc; running: false }

    function _doForecastFetch() {
        var url = "https://api.open-meteo.com/v1/forecast" +
                  "?latitude="   + root.weatherLat  +
                  "&longitude="  + root.weatherLon  +
                  "&current=temperature_2m,weather_code" +
                  "&hourly=temperature_2m,weather_code" +
                  "&daily=temperature_2m_min,temperature_2m_max" +
                  "&forecast_days=2&timeformat=unixtime&timezone=auto"
        root._forecastBuf = ""
        forecastProc.command = ["bash", "-c",
            "curl -sf --connect-timeout 5 --max-time 10 '" + url + "'"]
        forecastProc.running = true
    }

    function fetchWeatherFull() {
        if (root.weatherLoading) return
        root.weatherLoading = true
        // Coords already known — skip geocoding entirely
        if (root._coordsResolved) { root._doForecastFetch(); return }
        // Otherwise resolve city name first
        var city = root.weatherLocation.replace(/'/g, "")
        root._geoBuf = ""
        geoProc.command = ["bash", "-c",
            "curl -sf --connect-timeout 5 --max-time 10 " +
            "'https://geocoding-api.open-meteo.com/v1/search" +
            "?name=" + encodeURIComponent(city) + "&count=1&language=en&format=json'"]
        geoProc.running = true
    }

    // On startup: read cache instantly, then fetch live straight after
    Component.onCompleted: {
        weatherCacheProc.command = ["bash", "-c",
            "cat " + root._weatherCache + " 2>/dev/null || true"]
        weatherCacheProc.running = true
    }

    // Refresh every 15 minutes; skip if already fresh
    Timer { interval: 900000; running: true; repeat: true
        onTriggered: { if (root.weatherNeedsRefresh()) root.fetchWeatherFull() } }

    // ── Calendar ───────────────────────────────────────────────────────────────
    property int calYear:  new Date().getFullYear()
    property int calMonth: new Date().getMonth()

    readonly property var monthNames: [
        "January","February","March","April","May","June",
        "July","August","September","October","November","December"
    ]
    readonly property var dayNames: ["Mo","Tu","We","Th","Fr","Sa","Su"]

    function calendarCells() {
        var today       = new Date()
        var firstDay    = new Date(root.calYear, root.calMonth, 1)
        var startDow    = (firstDay.getDay() + 6) % 7
        var daysInMonth = new Date(root.calYear, root.calMonth + 1, 0).getDate()
        var daysInPrev  = new Date(root.calYear, root.calMonth, 0).getDate()
        var cells       = []

        for (var p = startDow - 1; p >= 0; p--)
            cells.push({ day: daysInPrev - p, isCurrentMonth: false, isToday: false })
        for (var d = 1; d <= daysInMonth; d++)
            cells.push({ day: d, isCurrentMonth: true,
                isToday: (d === today.getDate() && root.calMonth === today.getMonth() && root.calYear === today.getFullYear()) })
        var remaining = (7 - cells.length % 7) % 7
        for (var n = 1; n <= remaining; n++)
            cells.push({ day: n, isCurrentMonth: false, isToday: false })

        return cells
    }

    // ── Music / MPRIS ──────────────────────────────────────────────────────────
    property string musicTitle:    "Nothing playing"
    property string musicArtist:   "—"
    property string musicAlbum:    ""
    property string musicArtUrl:   ""
    property string musicStatus:   "Stopped"
    property int    musicPosition: 0
    property int    musicLength:   0
    property real   musicProgress: 0.0
    property string musicPlayer:   ""

    // Popup visibility — two-phase show/hide to allow close animation
    property bool musicPopupVisible:    false
    property bool _musicActualVisible:  false
    property bool _musicCloseRequested: false
    onMusicPopupVisibleChanged: { if (musicPopupVisible) _musicActualVisible = true }
    function requestCloseMusic() {
        if (!_musicActualVisible) return
        musicPopupVisible      = false
        _musicCloseRequested   = true
    }

    Process { id: musicPlayPause; running: false }
    Process { id: musicNext;      running: false }
    Process { id: musicPrev;      running: false }

    function musicTogglePlay() { musicPlayPause.command = ["playerctl", "play-pause"]; musicPlayPause.running = true }
    function musicNextTrack()  { musicNext.command      = ["playerctl", "next"];        musicNext.running      = true }
    function musicPrevTrack()  { musicPrev.command      = ["playerctl", "previous"];    musicPrev.running      = true }

    Process {
        id: mprisProc
        command: [
            "bash", "-c",
            "while true; do " +
            "  if playerctl status >/dev/null 2>&1; then " +
            "    fmt='{{title}}\n{{artist}}\n{{album}}\n{{mpris:artUrl}}\n{{status}}\n{{position}}\n{{mpris:length}}\n{{playerName}}\n---END---'; " +
            "    playerctl metadata --format \"$fmt\" 2>/dev/null || printf '\n\n\n\nStopped\n0\n0\n\n---END---\n'; " +
            "  else printf '\n\n\n\nStopped\n0\n0\n\n---END---\n'; fi; sleep 1; done"
        ]
        running: true
        stdout: SplitParser {
            property var buf: []
            onRead: (line) => {
                if (line.trim() === "---END---") {
                    if (buf.length >= 8) {
                        var title  = buf[0].trim(); var artist = buf[1].trim()
                        var album  = buf[2].trim(); var artUrl = buf[3].trim()
                        var status = buf[4].trim(); var pos    = parseInt(buf[5]) || 0
                        var len    = parseInt(buf[6]) || 0; var player = buf[7].trim()

                        if (status === "Stopped" || title.length === 0) {
                            root.musicTitle = "Nothing playing"; root.musicArtist = "—"
                            root.musicAlbum = ""; root.musicArtUrl = ""
                            root.musicProgress = 0; root.musicStatus = "Stopped"
                            root.musicPlayer = player
                        } else {
                            root.musicTitle    = title.length  > 0 ? title  : "Unknown Title"
                            root.musicArtist   = artist.length > 0 ? artist : "Unknown Artist"
                            root.musicAlbum    = album; root.musicArtUrl   = artUrl
                            root.musicStatus   = status; root.musicPosition = pos
                            root.musicLength   = len; root.musicPlayer    = player
                            root.musicProgress = len > 0 ? Math.min(1.0, pos / len) : 0.0
                        }
                    }
                    buf = []
                } else { buf.push(line) }
            }
        }
    }

    // ── Cava ───────────────────────────────────────────────────────────────────
    property var    cavaHeights:    [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    property string cavaConfigPath: ""
    property bool   cavaAvailable:  false

    Process {
        id: cavaCheckProc
        command: ["bash", "-c", "command -v cava && echo yes || echo no"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                root.cavaAvailable = line.trim() === "yes" || line.trim().endsWith("cava")
                if (root.cavaAvailable) writeCavaConfig.running = true
            }
        }
    }

    Process {
        id: writeCavaConfig
        command: [
            "bash", "-c",
            "mkdir -p /tmp/mango-cava && cat > /tmp/mango-cava/config << 'EOF'\n" +
            "[general]\nbars = 20\nframerate = 30\n[output]\nmethod = raw\n" +
            "raw_target = /tmp/mango-cava/fifo\ndata_format = ascii\nascii_max_range = 100\n" +
            "bar_delimiter = 59\n[input]\nmethod = pulse\nEOF\n" +
            "mkfifo /tmp/mango-cava/fifo 2>/dev/null || true\necho /tmp/mango-cava/config"
        ]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                root.cavaConfigPath = line.trim()
                if (root.cavaConfigPath.length > 0) cavaProc.running = true
            }
        }
    }

    Process {
        id: cavaProc
        command: ["bash", "-c", "cava -p /tmp/mango-cava/config 2>/dev/null & cat /tmp/mango-cava/fifo"]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                var parts = line.trim().replace(/;$/, "").split(";")
                var bars  = []
                for (var i = 0; i < 20; i++) {
                    var raw = i < parts.length ? parseInt(parts[i]) : 0
                    bars.push(Math.max(0, Math.min(1, (isNaN(raw) ? 0 : raw) / 100)))
                }
                root.cavaHeights = bars
            }
        }
    }

    Timer {
        id: fakeCavaTimer
        interval: 80; running: !root.cavaAvailable; repeat: true
        property real phase: 0
        onTriggered: {
            phase += 0.18
            var bars    = []
            var playing = root.musicStatus === "Playing"
            for (var i = 0; i < 20; i++) {
                bars.push(!playing ? 0 : Math.max(0, Math.min(1,
                    0.45 + 0.45 * Math.sin(phase + i * 0.55) + 0.10 * Math.sin(phase * 1.7 + i * 1.1))))
            }
            root.cavaHeights = bars
        }
    }

    // ── WiFi ───────────────────────────────────────────────────────────────────
    property bool   wifiPopupVisible:    false
    property bool   _wifiActualVisible:  false
    property bool   _wifiCloseRequested: false
    onWifiPopupVisibleChanged: { if (wifiPopupVisible) _wifiActualVisible = true }
    function requestCloseWifi() {
        if (!_wifiActualVisible) return
        wifiPopupVisible     = false
        _wifiCloseRequested  = true
    }

    property string wifiSsid:          ""
    property int    wifiSignal:        0
    property var    wifiNetworks:      []
    property bool   wifiScanning:      false
    property string wifiConnectMsg:    ""
    property string wifiExpandedSsid:  ""
    property string wifiPasswordInput: ""

    Process {
        id: wifiStatusProc
        command: [
            "bash", "-c",
            "while true; do " +
            "  info=$(iwctl station wlp3s0 show 2>/dev/null); " +
            "  ssid=$(echo \"$info\" | grep 'Connected network' | sed 's/.*Connected network\\s*//' | xargs); " +
            "  rssi=$(echo \"$info\" | grep 'RSSI' | grep -o '\\-[0-9]*' | head -1); " +
            "  echo \"${ssid:-}\"; " +
            "  if [ -n \"$rssi\" ]; then " +
            "    sig=$(awk \"BEGIN{v=($rssi+90)/40*100; if(v<0)v=0; if(v>100)v=100; print int(v)}\"); echo \"$sig\"; " +
            "  else echo '0'; fi; sleep 3; done"
        ]
        running: true
        stdout: SplitParser {
            property bool nextIsSignal: false
            onRead: (line) => {
                if (!nextIsSignal) { root.wifiSsid   = line.trim();               nextIsSignal = true  }
                else               { root.wifiSignal = parseInt(line.trim()) || 0; nextIsSignal = false }
            }
        }
    }

    Process {
        id: wifiScanProc
        running: false
        stdout: SplitParser {
            property var buf: []
            onRead: (line) => {
                var clean = line.replace(/\x1b\[[0-9;]*m/g, "").trim()
                if (!clean || clean.indexOf("Network name") !== -1 ||
                    clean.indexOf("----") !== -1 || clean.indexOf("Available networks") !== -1) return
                var connected = clean.charAt(0) === ">"
                if (connected) clean = clean.substring(1).trim()
                var parts = clean.split(/\s{2,}/)
                if (parts.length < 3 || !parts[0].trim()) return
                var sig = Math.round((parts[2].trim().replace(/[^*]/g, "").length / 4) * 100)
                buf.push({ ssid: parts[0].trim(), signal: sig,
                    security: parts[1].trim() === "open" ? "" : "WPA2",
                    connected: connected, icon: "\uf1eb" })
            }
        }
        onRunningChanged: {
            if (!running) {
                if (stdout.buf.length > 0) root.wifiNetworks = stdout.buf.slice()
                stdout.buf = []; root.wifiScanning = false
            }
        }
    }

    Timer {
        id: wifiAutoRefreshTimer
        interval: 15000; repeat: true
        running: root._wifiActualVisible && !wifiScanProc.running
        onTriggered: root.wifiStartScan(true)
    }

    function wifiStartScan(silent) {
        root.wifiScanning = true
        if (!silent) {
            root.wifiConnectMsg = ""
            root.wifiExpandedSsid = ""
            root.wifiPasswordInput = ""
        }
        wifiScanProc.command = ["bash", "-c",
            "iwctl station wlp3s0 scan 2>/dev/null; sleep 3; iwctl station wlp3s0 get-networks 2>/dev/null"]
        wifiScanProc.running = true
    }

    Process {
        id: wifiConnectProc
        property string pendingSsid: ""
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                var clean = line.replace(/\x1b\[[0-9;]*m/g, "").trim()
                if (!clean) return
                var low = clean.toLowerCase()
                if (low.indexOf("connected") !== -1)
                    root.wifiConnectMsg = "✓  Connected to " + wifiConnectProc.pendingSsid
                else if (low.indexOf("error") !== -1 || low.indexOf("failed") !== -1 ||
                         low.indexOf("not found") !== -1 || low.indexOf("incorrect") !== -1)
                    root.wifiConnectMsg = "✕  " + (
                        low.indexOf("incorrect") !== -1 || low.indexOf("psk") !== -1 ? "Wrong password" :
                        low.indexOf("not found") !== -1 ? "Network not found" : "Connection failed")
            }
        }
        stderr: SplitParser {
            onRead: (line) => {
                var low = line.replace(/\x1b\[[0-9;]*m/g, "").trim().toLowerCase()
                if (low.indexOf("error") !== -1 || low.indexOf("failed") !== -1)
                    root.wifiConnectMsg = "✕  Connection failed"
            }
        }
        onRunningChanged: {
            if (!running) {
                if (root.wifiConnectMsg.indexOf("Connecting") !== -1)
                    root.wifiConnectMsg = "✕  Connection timed out"
                wifiStatusProc.running = false; wifiStatusProc.running = true
                root.wifiStartScan()
            }
        }
    }

    function wifiConnect(ssid, password) {
        wifiConnectProc.pendingSsid = ssid
        root.wifiConnectMsg   = "Connecting to " + ssid + "…"
        root.wifiExpandedSsid = ""
        var s   = ssid.replace(/'/g, "")
        var p   = (password || "").replace(/'/g, "")
        var cmd = p.length > 0
            ? "iwctl --passphrase '" + p + "' station wlp3s0 connect '" + s + "' 2>&1"
            : "iwctl station wlp3s0 connect '" + s + "' 2>&1"
        wifiConnectProc.command = ["bash", "-c", cmd]
        wifiConnectProc.running = true
    }

    // ── Visual components ──────────────────────────────────────────────────────
    Bar {}
    MusicPopup {}
    WifiPopup {}
}
