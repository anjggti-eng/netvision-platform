import { describe, expect, it } from "vitest";
import { buildApp } from "../src/server.js";

describe("netvision app", () => {
  it("responde /healthz com 200 e status ok", async () => {
    const { app, stop } = await buildApp({ tickMs: 60_000 });
    try {
      const res = await app.inject({ url: "/healthz" });
      expect(res.statusCode).toBe(200);
      expect(res.json()).toMatchObject({ status: "ok" });
    } finally {
      stop();
    }
  });

  it("expõe nv_uplink_in_bytes / nv_uplink_out_bytes após o primeiro tick", async () => {
    const { app, stop } = await buildApp({ tickMs: 60_000 });
    try {
      const res = await app.inject({ url: "/metrics" });
      expect(res.statusCode).toBe(200);
      expect(res.body).toContain("nv_uplink_in_bytes");
      expect(res.body).toContain("nv_uplink_out_bytes");
      expect(res.body).toContain("nv_collector_ticks_total");
      // valor numérico presente (não só o nome da série)
      expect(res.body).toMatch(/nv_uplink_in_bytes\{[^}]*\} \d/);
    } finally {
      stop();
    }
  });

  it("coletor em modo simulado nunca derruba o serviço", async () => {
    const { app, stop } = await buildApp({ tickMs: 10, simulate: true });
    try {
      await new Promise((r) => setTimeout(r, 120));
      const res = await app.inject({ url: "/healthz" });
      expect(res.statusCode).toBe(200);
    } finally {
      stop();
    }
  });
});
