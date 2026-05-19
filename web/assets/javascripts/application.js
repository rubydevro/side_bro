// SideBro — main application JS
document.addEventListener('DOMContentLoaded', function() {
  // Bulk checkbox select-all
  const selectAll = document.getElementById('select-all');
  if (selectAll) {
    selectAll.addEventListener('change', function() {
      document.querySelectorAll('input[name="key[]"]').forEach(function(cb) {
        cb.checked = selectAll.checked;
      });
    });
  }
});
