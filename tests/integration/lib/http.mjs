import { requestTimeoutMs } from "./config.mjs";

export async function httpJson(method, url, { headers = {}, body } = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), requestTimeoutMs);

  try {
    const init = {
      method,
      headers: { Accept: "application/json", ...headers },
      signal: controller.signal,
    };
    if (body !== undefined) {
      init.headers["Content-Type"] = "application/json";
      init.body = typeof body === "string" ? body : JSON.stringify(body);
    }

    const res = await fetch(url, init);
    const text = await res.text();
    let json = null;
    if (text) {
      try {
        json = JSON.parse(text);
      } catch {
        json = { _raw: text };
      }
    }
    return { status: res.status, json, text };
  } finally {
    clearTimeout(timer);
  }
}

export async function getHealth(serviceName, baseUrl) {
  return httpJson("GET", `${baseUrl}/health`);
}

export async function getReady(serviceName, baseUrl) {
  return httpJson("GET", `${baseUrl}/ready`);
}
