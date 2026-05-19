// SideBro Dashboard — SVG charts + live polling
(function () {
  var pollSlider = document.getElementById("pollSlider");
  var pollValue = document.getElementById("pollValue");
  var liveInterval = document.getElementById("liveInterval");
  var pollPill = document.getElementById("pollPill");
  var liveToggle = document.getElementById("liveToggle");
  var pollTimer = null;
  var isLive = true;

  function getInterval() {
    return pollSlider ? parseInt(pollSlider.value, 10) : 5;
  }

  if (pollSlider) {
    pollSlider.addEventListener("input", function (e) {
      var v = parseInt(e.target.value, 10);
      if (pollValue) pollValue.textContent = v + " sec";
      if (liveInterval) liveInterval.textContent = v + "s";
      if (pollPill) pollPill.textContent = v + "s POLL";
      restartTimer();
    });
  }

  if (liveToggle) {
    liveToggle.addEventListener("click", function (e) {
      e.currentTarget.classList.toggle("off");
      isLive = !e.currentTarget.classList.contains("off");
      var span = e.currentTarget.querySelector("span:last-child");
      if (!isLive) {
        span.innerHTML = "Paused";
        if (pollTimer) { clearInterval(pollTimer); pollTimer = null; }
      } else {
        var v = getInterval();
        span.innerHTML = "Live · <span class=\"mono\" id=\"liveInterval\">" + v + "s</span>";
        liveInterval = document.getElementById("liveInterval");
        restartTimer();
      }
    });
  }

  var N = 60;
  var seriesProcessed = new Array(N).fill(0);
  var seriesFailed = new Array(N).fill(0);

  // ---- live chart ----
  function renderLiveChart() {
    var svg = document.getElementById("liveChart");
    if (!svg) return;
    var W = 800, H = 280, PAD_L = 44, PAD_R = 16, PAD_T = 18, PAD_B = 28;
    var cw = W - PAD_L - PAD_R, ch = H - PAD_T - PAD_B;
    var all = seriesProcessed.concat(seriesFailed);
    var maxY = Math.max(12, Math.ceil(Math.max.apply(null, all)));
    var x = function (i) { return PAD_L + (i / (N - 1)) * cw; };
    var y = function (v) { return PAD_T + (1 - v / maxY) * ch; };

    function makePath(s) {
      var d = "";
      s.forEach(function (v, i) { d += (i === 0 ? "M" : "L") + x(i).toFixed(1) + "," + y(v).toFixed(1) + " "; });
      return d;
    }
    function makeArea(s) {
      var d = "M" + x(0) + "," + y(0) + " ";
      s.forEach(function (v, i) { d += "L" + x(i).toFixed(1) + "," + y(v).toFixed(1) + " "; });
      d += "L" + x(N - 1) + "," + y(0) + " Z";
      return d;
    }

    var grid = "";
    for (var i = 0; i <= 4; i++) {
      var yy = PAD_T + (i / 4) * ch;
      var val = Math.round(maxY - (i / 4) * maxY);
      grid += "<line x1=\"" + PAD_L + "\" y1=\"" + yy + "\" x2=\"" + (W - PAD_R) + "\" y2=\"" + yy + "\" stroke=\"#1f1638\" stroke-dasharray=\"3 4\"/>";
      grid += "<text x=\"" + (PAD_L - 8) + "\" y=\"" + (yy + 4) + "\" font-size=\"10\" fill=\"#6a5f8a\" text-anchor=\"end\" font-family=\"JetBrains Mono\">" + val + "</text>";
    }
    var xLabels = "";
    for (var j = 0; j <= 4; j++) {
      var xx = PAD_L + (j / 4) * cw;
      var sec = 60 - Math.round((j / 4) * 60);
      xLabels += "<text x=\"" + xx + "\" y=\"" + (H - 8) + "\" font-size=\"10\" fill=\"#6a5f8a\" text-anchor=\"middle\" font-family=\"JetBrains Mono\">" + (sec === 0 ? "now" : "-" + sec + "s") + "</text>";
    }

    svg.innerHTML =
      "<defs>" +
        "<linearGradient id=\"gradProc\" x1=\"0\" x2=\"0\" y1=\"0\" y2=\"1\">" +
          "<stop offset=\"0%\" stop-color=\"#4be3ff\" stop-opacity=\"0.45\"/>" +
          "<stop offset=\"100%\" stop-color=\"#4be3ff\" stop-opacity=\"0\"/>" +
        "</linearGradient>" +
        "<filter id=\"glow\"><feGaussianBlur stdDeviation=\"2\"/></filter>" +
      "</defs>" +
      grid + xLabels +
      "<path d=\"" + makeArea(seriesProcessed) + "\" fill=\"url(#gradProc)\"/>" +
      "<path d=\"" + makePath(seriesProcessed) + "\" stroke=\"#4be3ff\" stroke-width=\"2\" fill=\"none\" filter=\"url(#glow)\" opacity=\"0.6\"/>" +
      "<path d=\"" + makePath(seriesProcessed) + "\" stroke=\"#4be3ff\" stroke-width=\"2\" fill=\"none\"/>" +
      "<path d=\"" + makePath(seriesFailed) + "\" stroke=\"#ff5470\" stroke-width=\"2\" fill=\"none\"/>" +
      "<circle cx=\"" + x(N - 1) + "\" cy=\"" + y(seriesProcessed[N - 1]) + "\" r=\"4\" fill=\"#4be3ff\"/>" +
      "<circle cx=\"" + x(N - 1) + "\" cy=\"" + y(seriesProcessed[N - 1]) + "\" r=\"8\" fill=\"#4be3ff\" opacity=\"0.25\"/>";

    var tip = document.getElementById("chartTip");
    svg.onmousemove = function (e) {
      var rect = svg.getBoundingClientRect();
      var px = (e.clientX - rect.left) / rect.width * W;
      var idx = Math.max(0, Math.min(N - 1, Math.round(((px - PAD_L) / cw) * (N - 1))));
      document.getElementById("tipProc").textContent = seriesProcessed[idx].toFixed(1);
      document.getElementById("tipFail").textContent = seriesFailed[idx].toFixed(1);
      document.getElementById("tipTime").textContent = (60 - idx) + "s ago";
      tip.style.display = "block";
      tip.style.left = (e.clientX - rect.left + 12) + "px";
      tip.style.top = (e.clientY - rect.top + 12) + "px";
    };
    svg.onmouseleave = function () { tip.style.display = "none"; };
  }

  // ---- history chart ----
  var currentRange = "month";

  function renderHistoryChart() {
    var svg = document.getElementById("historyChart");
    if (!svg) return;
    var W = 1200, H = 320, PAD_L = 60, PAD_R = 30, PAD_T = 20, PAD_B = 40;
    var cw = W - PAD_L - PAD_R, ch = H - PAD_T - PAD_B;

    var histData = window.HISTORY_DATA;
    if (!histData) return;

    // select subset based on range
    var allPoints = histData.processed;
    var allFailed = histData.failed;
    var allLabels = histData.labels;
    var total = allPoints.length;

    var sliceLen = total;
    if (currentRange === "week") sliceLen = Math.min(7, total);
    else if (currentRange === "month") sliceLen = Math.min(30, total);
    else if (currentRange === "3m") sliceLen = Math.min(90, total);
    else if (currentRange === "6m") sliceLen = Math.min(180, total);

    var points = allPoints.slice(0, sliceLen);
    var failed = allFailed.slice(0, sliceLen);
    var labels = allLabels.slice(0, sliceLen);
    if (points.length === 0) return;

    var maxY = Math.max(1, Math.max.apply(null, points.concat(failed)));
    var x = function (i) { return PAD_L + (i / Math.max(points.length - 1, 1)) * cw; };
    var y = function (v) { return PAD_T + (1 - v / maxY) * ch; };

    var line = "", area = "M" + x(0) + "," + y(0) + " ";
    var failLine = "", failArea = "M" + x(0) + "," + y(0) + " ";
    points.forEach(function (v, i) {
      line += (i === 0 ? "M" : "L") + x(i).toFixed(1) + "," + y(v).toFixed(1) + " ";
      area += "L" + x(i).toFixed(1) + "," + y(v).toFixed(1) + " ";
    });
    area += "L" + x(points.length - 1) + "," + y(0) + " Z";
    failed.forEach(function (v, i) {
      failLine += (i === 0 ? "M" : "L") + x(i).toFixed(1) + "," + y(v).toFixed(1) + " ";
      failArea += "L" + x(i).toFixed(1) + "," + y(v).toFixed(1) + " ";
    });
    failArea += "L" + x(failed.length - 1) + "," + y(0) + " Z";

    var grid = "";
    for (var i = 0; i <= 4; i++) {
      var yy = PAD_T + (i / 4) * ch;
      var val = Math.round((maxY - (i / 4) * maxY) / 100) * 100;
      grid += "<line x1=\"" + PAD_L + "\" y1=\"" + yy + "\" x2=\"" + (W - PAD_R) + "\" y2=\"" + yy + "\" stroke=\"#1f1638\" stroke-dasharray=\"2 4\"/>";
      if (i > 0) grid += "<text x=\"" + (PAD_L - 10) + "\" y=\"" + (yy + 4) + "\" font-size=\"11\" fill=\"#6a5f8a\" text-anchor=\"end\" font-family=\"JetBrains Mono\">" + val + "K</text>";
    }

    // label thinning
    var labelStep = Math.max(1, Math.floor(labels.length / 6));
    var xLabels = "";
    labels.forEach(function (l, i) {
      if (i % labelStep !== 0 && i !== labels.length - 1) return;
      var xx = x(i);
      xLabels += "<line x1=\"" + xx + "\" y1=\"" + PAD_T + "\" x2=\"" + xx + "\" y2=\"" + (H - PAD_B) + "\" stroke=\"#1f1638\" stroke-dasharray=\"2 4\"/>";
      xLabels += "<text x=\"" + xx + "\" y=\"" + (H - 14) + "\" font-size=\"12\" fill=\"#a98cff\" text-anchor=\"middle\" font-family=\"JetBrains Mono\">" + l + "</text>";
    });

    svg.innerHTML =
      "<defs>" +
        "<linearGradient id=\"gradHist\" x1=\"0\" x2=\"0\" y1=\"0\" y2=\"1\">" +
          "<stop offset=\"0%\" stop-color=\"#a98cff\" stop-opacity=\"0.35\"/>" +
          "<stop offset=\"60%\" stop-color=\"#a98cff\" stop-opacity=\"0.05\"/>" +
          "<stop offset=\"100%\" stop-color=\"#a98cff\" stop-opacity=\"0\"/>" +
        "</linearGradient>" +
        "<linearGradient id=\"gradHistLine\" x1=\"0\" x2=\"1\" y1=\"0\" y2=\"0\">" +
          "<stop offset=\"0%\" stop-color=\"#a98cff\"/>" +
          "<stop offset=\"60%\" stop-color=\"#ff5cd6\"/>" +
          "<stop offset=\"100%\" stop-color=\"#7a3dff\"/>" +
        "</linearGradient>" +
        "<linearGradient id=\"gradFail\" x1=\"0\" x2=\"0\" y1=\"0\" y2=\"1\">" +
          "<stop offset=\"0%\" stop-color=\"#ff5470\" stop-opacity=\"0.25\"/>" +
          "<stop offset=\"100%\" stop-color=\"#ff5470\" stop-opacity=\"0\"/>" +
        "</linearGradient>" +
      "</defs>" +
      grid + xLabels +
      "<path d=\"" + area + "\" fill=\"url(#gradHist)\"/>" +
      "<path d=\"" + failArea + "\" fill=\"url(#gradFail)\"/>" +
      "<path d=\"" + line + "\" stroke=\"url(#gradHistLine)\" stroke-width=\"2.4\" fill=\"none\" stroke-linejoin=\"round\" stroke-linecap=\"round\"/>" +
      "<path d=\"" + failLine + "\" stroke=\"#ff5470\" stroke-width=\"1.6\" fill=\"none\" stroke-linejoin=\"round\" stroke-linecap=\"round\"/>" +
      points.map(function (v, i) {
        return "<circle cx=\"" + x(i).toFixed(1) + "\" cy=\"" + y(v).toFixed(1) + "\" r=\"2.4\" fill=\"#170f29\" stroke=\"#a98cff\" stroke-width=\"1.5\"/>";
      }).join("");
  }

  // ---- live polling via fetch ----
  function fetchStats() {
    if (!isLive) return;
    var root = window.SIDE_BRO_ROOT || "/";
    fetch(root + "stats")
      .then(function (r) { return r.json(); })
      .then(function (data) {
        seriesProcessed.shift(); seriesProcessed.push(Math.max(0, data.processed || 0));
        seriesFailed.shift(); seriesFailed.push(Math.max(0, data.failed || 0));
        renderLiveChart();
      })
      .catch(function () {
        renderLiveChart();
      });
  }

  function restartTimer() {
    if (pollTimer) clearInterval(pollTimer);
    if (!isLive) return;
    pollTimer = setInterval(fetchStats, getInterval() * 1000);
  }

  // ---- history tabs ----
  document.querySelectorAll("#historyTabs .chip").forEach(function (c) {
    c.addEventListener("click", function () {
      document.querySelectorAll("#historyTabs .chip").forEach(function (x) { x.classList.remove("active"); });
      c.classList.add("active");
      currentRange = c.dataset.range;
      renderHistoryChart();
    });
  });

  // ---- init ----
  var chartTime = document.getElementById("chartTime");
  if (chartTime) chartTime.textContent = new Date().toUTCString().replace(" GMT", "") + " UTC";

  renderLiveChart();
  renderHistoryChart();
  restartTimer();
})();
