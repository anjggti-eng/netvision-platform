import type { UplinkSample } from "../metrics.js";
import type { Collector } from "./simulator.js";

interface MikrotikInterface {
  name: string;
  "rx-byte": string;
  "tx-byte": string;
  disabled?: string;
  type?: string;
}

export interface MikrotikConfig {
  host: string;
  user: string;
  password: string;
  /** interfaces consideradas uplink (default: todas não-desabilitadas) */
  interfaces?: string[];
}

/**
 * Coletor real: API REST do RouterOS (/rest/interface) com Basic Auth.
 * Lê contadores absolutos rx-byte/tx-byte — o gauge reflete o valor do device.
 */
export function createMikrotik(cfg: MikrotikConfig): Collector {
  const auth = "Basic " + Buffer.from(`${cfg.user}:${cfg.password}`).toString("base64");
  const base = cfg.host.startsWith("http") ? cfg.host : `http://${cfg.host}`;

  return {
    async read(): Promise<UplinkSample[]> {
      const res = await fetch(`${base}/rest/interface`, {
        headers: { Authorization: auth, Accept: "application/json" },
        signal: AbortSignal.timeout(5_000),
      });
      if (!res.ok) {
        throw new Error(`MikroTik REST ${res.status}: ${res.statusText}`);
      }
      const list = (await res.json()) as MikrotikInterface[];
      const wanted = cfg.interfaces?.length
        ? list.filter((i) => cfg.interfaces!.includes(i.name))
        : list.filter((i) => i.disabled !== "true");

      return wanted.map((i) => ({
        name: i.name,
        inBytes: Number(i["rx-byte"] ?? 0),
        outBytes: Number(i["tx-byte"] ?? 0),
        up: i.disabled !== "true",
      }));
    },
  };
}
