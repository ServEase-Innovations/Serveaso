import { integrationSecrets } from "./config.mjs";

export function internalAuthHeaders() {
  const secret = integrationSecrets.internalSecret;
  return secret ? { "X-Internal-Secret": secret } : {};
}
