import { deleteAccounts, limitedJson, response, ServerAPI, ServerFailure } from "../_shared/server.ts";

const uuid = /^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/;
Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return response({ code: "method" }, 405);
  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) return response({ code: "unauthorized" }, 401);
  try {
    const api = new ServerAPI();
    const bearer = authorization.substring(7);
    // Live GoTrue validation, rather than trusting decoded claims or a UID body.
    const user = await api.request("/auth/v1/user", "GET", undefined, bearer) as { id: string; email: string };
    if (!uuid.test(user.id) || typeof user.email !== "string") return response({ code: "unauthorized" }, 401);
    const body = await limitedJson(req);
    if (Object.keys(body).some(key => !["password", "confirmation", "request_id", "delete_owned_lists"].includes(key)) ||
      body.confirmation !== "ELIMINAR" || body.delete_owned_lists !== true ||
      typeof body.request_id !== "string" || !uuid.test(body.request_id) ||
      typeof body.password !== "string" || !body.password || body.password.length > 256) {
      return response({ code: "invalid" }, 400);
    }
    let verified;
    try {
      verified = await api.request("/auth/v1/token?grant_type=password", "POST",
        { email: user.email, password: body.password }, bearer) as { user: { id: string }; access_token: string };
    } catch (error) {
      if (error instanceof ServerFailure && [400, 401, 422].includes(error.status)) {
        return response({ code: "reauthentication" }, 403);
      }
      throw error;
    }
    if (verified.user?.id !== user.id) return response({ code: "unauthorized" }, 401);
    try {
      await api.rpc("begin_account_deletion", {
        p_actor_id: user.id, p_request_id: body.request_id, p_delete_owned_lists: true,
      });
    } catch (error) {
      // A rejected transaction must not leave the temporary reauthentication
      // session alive. The user's original session remains available to retry.
      try { await api.request("/auth/v1/logout?scope=local", "POST", {}, verified.access_token); } catch (_) {}
      throw error;
    }
    // Acceptance has committed. Any subsequent interruption is recovered by
    // the worker; a network retry cannot withdraw another user's data.
    try { await api.request("/auth/v1/logout?scope=global", "POST", {}, verified.access_token); } catch (_) {}
    try { await api.request("/auth/v1/admin/users/" + user.id, "PUT", { ban_duration: "8760h" }); } catch (_) {}
    // No physical files: finish now. Files: worker owns their fenced lifecycle.
    try { await deleteAccounts(api); } catch (_) {}
    return response({ accepted: true, request_id: body.request_id, message: "Eliminación aceptada; los archivos se retiran mediante el trabajador." }, 202);
  } catch (error) {
    const status = error instanceof ServerFailure && [400, 401, 413].includes(error.status) ? error.status : 503;
    return response({ code: status === 401 ? "unauthorized" : status === 503 ? "temporarily_unavailable" : "invalid" }, status);
  }
});
