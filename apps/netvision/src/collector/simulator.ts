import type { UplinkSample } from "../metrics.js";

export interface Collector {
  read(): Promise<UplinkSample[]>;
}

interface SimulatedLink {
  name: string;
  inBytes: number;
  outBytes: number;
}

/**
 * Coletor simulado: random-walk estável para demo/CI.
 * Usado quando SIMULATE=1 (default) ou MIKROTIK_HOST não definido.
 */
export function createSimulator(
  interfaces: string[] = ["ether1-wan"],
): Collector {
  const links: SimulatedLink[] = interfaces.map((name) => ({
    name,
    inBytes: 1_000_000 + Math.floor(Math.random() * 1_000_000),
    outBytes: 500_000 + Math.floor(Math.random() * 500_000),
  }));

  return {
    async read(): Promise<UplinkSample[]> {
      return links.map((l) => {
        // tráfego plausível: 200KB–2MB por intervalo
        l.inBytes += 200_000 + Math.floor(Math.random() * 1_800_000);
        l.outBytes += 100_000 + Math.floor(Math.random() * 900_000);
        return { name: l.name, inBytes: l.inBytes, outBytes: l.outBytes, up: true };
      });
    },
  };
}
