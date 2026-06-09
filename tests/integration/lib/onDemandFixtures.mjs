import { serviceUrls } from "./config.mjs";
import { httpJson } from "./http.mjs";
import { internalAuthHeaders } from "./auth.mjs";

/** Default probe point — DEV COOK providers near this location. Override via env if needed. */
export const ON_DEMAND_TEST_LAT = Number(
  process.env.INTEGRATION_ON_DEMAND_LAT || "12.90340704464175"
);
export const ON_DEMAND_TEST_LNG = Number(
  process.env.INTEGRATION_ON_DEMAND_LNG || "77.57114047718073"
);

export function onDemandLocationFields() {
  return {
    latitude: ON_DEMAND_TEST_LAT,
    longitude: ON_DEMAND_TEST_LNG,
  };
}

export async function getOnDemandAvailability({
  serviceType = "COOK",
  startDate,
  startTime = "09:00",
  durationMinutes = 60,
  latitude = ON_DEMAND_TEST_LAT,
  longitude = ON_DEMAND_TEST_LNG,
} = {}) {
  const params = new URLSearchParams({
    lat: String(latitude),
    lng: String(longitude),
    service_type: serviceType,
    start_date: startDate,
    start_time: startTime,
    duration_minutes: String(durationMinutes),
  });
  const url = `${serviceUrls.payments}/api/v2/createEngagements/on-demand-availability?${params}`;
  return httpJson("GET", url, { headers: internalAuthHeaders() });
}

/**
 * Skip the current test when DEV has no on-demand providers at the probe coordinates.
 * @returns {Promise<boolean>} true when providers are available and the test should continue
 */
export async function skipUnlessOnDemandProvidersAvailable(t, opts) {
  const { status, json } = await getOnDemandAvailability(opts);
  if (status !== 200) {
    t.skip(`on-demand availability probe failed (HTTP ${status})`);
    return false;
  }
  if (!json?.available) {
    t.skip(
      `no on-demand providers in DEV at test coordinates (${json?.code ?? "unavailable"}); ` +
        "set INTEGRATION_ON_DEMAND_LAT and INTEGRATION_ON_DEMAND_LNG near an active provider to run create tests"
    );
    return false;
  }
  return true;
}
