import { cleanupStorage, deleteAccounts, response, ServerAPI, workerAuthorized } from "../_shared/server.ts";

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return response({ code: "method" }, 405);
  if (!workerAuthorized(req)) return response({ code: "unauthorized" }, 401);
  try {
    const api = new ServerAPI();
    const storage = await cleanupStorage(api);
    const accounts = await deleteAccounts(api);
    const health = await api.rpc("maintain_private_operations", {});
    return response({ storage, accounts, health });
  } catch (_) { return response({ code: "temporarily_unavailable" }, 503); }
});
