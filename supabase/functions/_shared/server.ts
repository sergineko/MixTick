// Server credentials stay in the Edge runtime environment, never in Flutter.
export class ServerFailure extends Error {
  constructor(public code: string, public status = 503) { super(code); }
}
export function response(data: unknown, status = 200): Response {
  return Response.json(data, { status, headers: { "Cache-Control": "no-store" } });
}
export class ServerAPI {
  readonly url = Deno.env.get("SUPABASE_URL") ?? "";
  readonly secret = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  readonly publicKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  constructor() {
    if (!this.url || !this.secret || !this.publicKey) throw new ServerFailure("configuration");
  }
  async request(path: string, method = "GET", body?: unknown, bearer = this.secret): Promise<unknown> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 10000);
    try {
      const result = await fetch(this.url + path, { method, signal: controller.signal,
        headers: { apikey: bearer === this.secret ? this.secret : this.publicKey,
          Authorization: "Bearer " + bearer, "Content-Type": "application/json" },
        body: body === undefined ? undefined : JSON.stringify(body) });
      if (!result.ok) throw new ServerFailure("upstream", result.status);
      if (result.status === 204) return null;
      const text = await result.text();
      return text ? JSON.parse(text) : null;
    } catch (error) {
      if (error instanceof ServerFailure) throw error;
      throw new ServerFailure("upstream");
    } finally { clearTimeout(timer); }
  }
  rpc(name: string, params: unknown): Promise<unknown> {
    return this.request("/rest/v1/rpc/" + name, "POST", params);
  }
}
type CleanupClaim = { id: string; claim_id: string; bucket: string; path: string };
export async function cleanupStorage(api: ServerAPI, limit = 5): Promise<{ removed: number; retried: number }> {
  const jobs = await api.rpc("claim_storage_cleanup", { p_limit: limit }) as CleanupClaim[];
  let removed = 0, retried = 0;
  for (const job of jobs) {
    const claim = { p_id: job.id, p_claim_id: job.claim_id };
    try {
      if (await api.rpc("validate_storage_cleanup", claim) !== true) {
        await api.rpc("finish_storage_cleanup", { ...claim, p_removed: false });
        retried++;
        continue;
      }
      // Physical removal through Storage API; SQL metadata DELETE is never used.
      await api.request("/storage/v1/object/" + encodeURIComponent(job.bucket), "DELETE", { prefixes: [job.path] });
      await api.rpc("finish_storage_cleanup", { ...claim, p_removed: true });
      removed++;
    } catch (_) {
      // Fixed category only. No upstream body, path, UID, password or token log.
      await api.rpc("finish_storage_cleanup", { ...claim, p_removed: false });
      retried++;
    }
  }
  return { removed, retried };
}
export function workerAuthorized(req: Request): boolean {
  const expected = Deno.env.get("MIXTICK_WORKER_SECRET") ?? "";
  const provided = req.headers.get("x-mixtick-worker") ?? "";
  if (expected.length < 32 || expected.length !== provided.length) return false;
  let difference = 0;
  for (let i = 0; i < expected.length; i++) difference |= expected.charCodeAt(i) ^ provided.charCodeAt(i);
  return difference === 0;
}

type AccountClaim = { id: string; actor_id: string; claim_id: string };
export async function deleteAccounts(api: ServerAPI): Promise<{ completed: number; retried: number }> {
  const claims = await api.rpc("claim_account_deletions", { p_limit: 3 }) as AccountClaim[];
  let completed = 0, retried = 0;
  for (const claim of claims) {
    try {
      await api.request("/auth/v1/admin/users/" + encodeURIComponent(claim.actor_id), "DELETE", { should_soft_delete: false });
    } catch (_) { /* Database verification below reconciles an already removed identity. */ }
    const done = await api.rpc("finish_account_deletion", { p_id: claim.id, p_claim_id: claim.claim_id });
    if (done === true) completed++; else retried++;
  }
  return { completed, retried };
}

export async function limitedJson(req: Request): Promise<Record<string, unknown>> {
  const reader = req.body?.getReader();
  if (!reader) throw new ServerFailure("invalid", 400);
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const part = await reader.read();
      if (part.done) break;
      size += part.value.byteLength;
      if (size > 4096) throw new ServerFailure("invalid", 413);
      chunks.push(part.value);
    }
  } finally { await reader.cancel(); reader.releaseLock(); }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  try {
    const value = JSON.parse(new TextDecoder().decode(bytes));
    if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error();
    return value;
  } catch (_) { throw new ServerFailure("invalid", 400); }
}
