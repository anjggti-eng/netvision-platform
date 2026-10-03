import Fastify, { type FastifyInstance } from "fastify";
import {
  applySamples,
  collectorErrors,
  registry,
} from "./metrics.js";
import { createMikrotik } from "./collector/mikrotik.js";
import { createSimulator, type Collector } from "./collector/simulator.js";

export interface BuildOptions {
  /** intervalo entre coletas em ms (default 5000) */
  tickMs?: number;
  /** força modo simulado (default: true sem MIKROTIK_HOST) */
  simulate?: boolean;
  /** coletor customizado (testes) */
  collector?: Collector;
}

export interface BuiltApp {
  app: FastifyInstance;
  /** resolve quando o primeiro tick completo terminou */
  ready: Promise<void>;
  stop(): void;
}

export async function buildApp(opts: BuildOptions = {}): Promise<BuiltApp> {
  const app = Fastify({ logger: { level: process.env.LOG_LEVEL ?? "info" } });

  const host = process.env.MIKROTIK_HOST;
  const simulate = opts.simulate ?? !host;

  const collector: Collector =
    opts.collector ??
    (simulate
      ? createSimulator()
      : createMikrotik({
          host: host!,
          user: process.env.MIKROTIK_USER ?? "admin",
          password: process.env.MIKROTIK_PASS ?? "",
          interfaces: process.env.MIKROTIK_INTERFACES
            ?.split(",")
            .map((s) => s.trim()),
        }));

  const tickMs = opts.tickMs ?? Number(process.env.TICK_MS ?? 5_000);

  let timer: NodeJS.Timeout | undefined;
  let stopped = false;

  async function tick(): Promise<void> {
    try {
      applySamples(await collector.read());
    } catch (err) {
      collectorErrors.inc();
      app.log.error({ err }, "coletor falhou");
    }
  }

  app.get("/healthz", async () => ({ status: "ok", simulate, uptime: process.uptime() }));

  app.get("/metrics", async (_req, reply) => {
    reply.header("Content-Type", registry.contentType);
    return registry.metrics();
  });

  const ready = (async () => {
    await tick();
    if (!stopped) {
      timer = setInterval(() => void tick(), tickMs);
      timer.unref?.();
    }
  })();

  return {
    app,
    ready,
    stop() {
      stopped = true;
      if (timer) clearInterval(timer);
    },
  };
}

async function main(): Promise<void> {
  const port = Number(process.env.PORT ?? 8080);
  const { app, ready } = await buildApp();
  await ready;
  await app.listen({ port, host: "0.0.0.0" });
}

// roda apenas quando executado diretamente (não nos testes)
const isMain = process.argv[1] && import.meta.url.endsWith(process.argv[1].split("/").pop() ?? "");
if (isMain) {
  main().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
