import {
  Counter,
  Gauge,
  Registry,
  collectDefaultMetrics,
} from "prom-client";

export const registry = new Registry();
collectDefaultMetrics({ register: registry });

export interface UplinkSample {
  name: string;
  inBytes: number;
  outBytes: number;
  up: boolean;
}

export const uplinkIn = new Gauge({
  name: "nv_uplink_in_bytes",
  help: "Bytes recebidos no uplink (contador absoluto lido do dispositivo)",
  labelNames: ["interface"],
  registers: [registry],
});

export const uplinkOut = new Gauge({
  name: "nv_uplink_out_bytes",
  help: "Bytes transmitidos no uplink (contador absoluto lido do dispositivo)",
  labelNames: ["interface"],
  registers: [registry],
});

export const uplinkStatus = new Gauge({
  name: "nv_uplink_status",
  help: "1 se o uplink está up, 0 caso contrário",
  labelNames: ["interface"],
  registers: [registry],
});

export const collectorTicks = new Counter({
  name: "nv_collector_ticks_total",
  help: "Total de ciclos do coletor de uplink",
  registers: [registry],
});

export const collectorErrors = new Counter({
  name: "nv_collector_errors_total",
  help: "Total de erros no coletor de uplink",
  registers: [registry],
});

/** Aplica amostras do coletor nos gauges. */
export function applySamples(samples: UplinkSample[]): void {
  for (const s of samples) {
    uplinkIn.set({ interface: s.name }, s.inBytes);
    uplinkOut.set({ interface: s.name }, s.outBytes);
    uplinkStatus.set({ interface: s.name }, s.up ? 1 : 0);
  }
  collectorTicks.inc();
}
