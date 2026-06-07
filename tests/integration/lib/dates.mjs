/** Far-future YYYY-MM-DD to avoid colliding with real bookings. */
export function futureYmd(yearsAhead = 2) {
  const d = new Date();
  d.setFullYear(d.getFullYear() + yearsAhead);
  return d.toISOString().slice(0, 10);
}

/** End date one month after start (calendar month approximation). */
export function monthAfterYmd(startYmd) {
  const [y, m, d] = startYmd.split("-").map(Number);
  const end = new Date(y, m, d);
  end.setMonth(end.getMonth() + 1);
  return end.toISOString().slice(0, 10);
}
