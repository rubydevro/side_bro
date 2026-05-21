// SideBro — main application JS
(function () {
  // Refresh button
  var refreshBtn = document.getElementById("refreshBtn");
  if (refreshBtn) {
    refreshBtn.addEventListener("click", function () { window.location.reload(); });
  }

  // Bulk checkbox select-all
  var selectAll = document.getElementById("select-all");
  if (selectAll) {
    selectAll.addEventListener("change", function () {
      document.querySelectorAll('input[name="key[]"]').forEach(function (cb) {
        cb.checked = selectAll.checked;
      });
    });
  }

  // Live toggle — owns button state; drives page auto-refresh on non-dashboard pages.
  // Dashboard overrides behaviour by setting window.SideBroLive.onToggle.
  var liveToggle = document.getElementById("liveToggle");
  var intervalSec = 5;
  var isLive = true;
  var onDashboard = !!document.getElementById("pollSlider");

  function updateLabel() {
    var span = liveToggle && liveToggle.querySelector("span:last-child");
    if (!span) return;
    if (!isLive) { span.textContent = "Paused"; return; }
    if (onDashboard) {
      span.innerHTML = "Live · <span class=\"mono\" id=\"liveInterval\">" + intervalSec + "s</span>";
    } else {
      span.textContent = "Live";
    }
  }

  updateLabel();

  if (liveToggle) {
    liveToggle.addEventListener("click", function () {
      liveToggle.classList.toggle("off");
      isLive = !liveToggle.classList.contains("off");
      updateLabel();
      if (window.SideBroLive && window.SideBroLive.onToggle) {
        window.SideBroLive.onToggle(isLive);
      }
    });
  }

  // Exposed API for dashboard.js to sync interval display and pause/resume polling
  window.SideBroLive = {
    onToggle: null,
    setInterval: function (sec) {
      intervalSec = sec;
      var el = document.getElementById("liveInterval");
      if (el) el.textContent = sec + "s";
      var pill = document.getElementById("pollPill");
      if (pill) pill.textContent = sec + "s POLL";
    },
    getIsLive: function () { return isLive; }
  };
})();
