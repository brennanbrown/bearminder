import { useEffect, useState } from "react";
import { invoke } from "@tauri-apps/api/core";
import "./App.css";

type SyncArgs = {
  since_hours: number;
  ignore_last_sync: boolean;
  dry_run: boolean;
};

function App() {
  const [dryRun, setDryRun] = useState(false);
  const [output, setOutput] = useState("Ready.");
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState<null | {
    last_sync?: string;
    value?: number;
    notes_count?: number;
    tags_count?: number;
    comment?: string;
    success?: boolean;
    dry_run?: boolean;
    error?: string;
  }>(null);
  const [env, setEnv] = useState<{
    beeminder_username?: string;
    beeminder_goal?: string;
    beeminder_token?: string;
  }>({});
  const [savingEnv, setSavingEnv] = useState(false);
  const [saveMsg, setSaveMsg] = useState<string | null>(null);
  const [bearDbPath, setBearDbPath] = useState<string | null>(null);
  const [showOnboarding, setShowOnboarding] = useState<boolean>(() => {
    try {
      const v = localStorage.getItem("bearminder_onboarding_dismissed");
      return v !== "1"; // show if not dismissed
    } catch {
      return true;
    }
  });

  useEffect(() => {
    (async () => {
      try {
        const p = await invoke<string | null>("detect_bear_db");
        setBearDbPath(p ?? null);
      } catch (e) {
        // ignore
      }
    })();
  }, []);

  function formatLocal(iso?: string) {
    if (!iso) return "-";
    try {
      const d = new Date(iso);
      return d.toLocaleString();
    } catch {
      return iso;
    }
  }

  async function refreshStatus() {
    try {
      const s = await invoke<string>("read_status");
      const json = JSON.parse(s);
      setStatus(json);
    } catch (e) {
      // status.json may not exist yet
      setStatus(null);
    }
  }

  useEffect(() => {
    refreshStatus();
    // Load ENV
    (async () => {
      try {
        const e = await invoke<any>("get_env");
        setEnv(e || {});
      } catch (_) {
        // ignore
      }
    })();
  }, []);

  async function runSync(args: SyncArgs) {
    try {
      setBusy(true);
      setOutput("Running sync...");
      const res = await invoke<string>("run_sync", { args });
      setOutput(res.trim());
      await refreshStatus();
    } catch (err: any) {
      setOutput(String(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="container">
      <header className="app-header">
        <h1>Bearminder</h1>
        <div className="subtle">Keep your writing synced to Beeminder with one click.</div>
      </header>

      {!bearDbPath && (
        <section className="card" style={{ borderColor: "#c93", background: "#c931000d" }}>
          <h3>Bear database not found</h3>
          <div className="subtle">
            Set <code>BEAR_DB_PATH</code> in your .env or open the Bear data folder to locate <code>database.sqlite</code>.
          </div>
          <div className="actions" style={{ marginTop: 8, justifyContent: "flex-start" }}>
            <button onClick={() => invoke("open_bear_db_folder").catch(() => {})}>Open Bear data folder</button>
            <button onClick={async () => {
              try {
                const paths = await invoke<any>("get_paths");
                await invoke("open_path", { path: paths.repo_root + "/.env" });
              } catch {}
            }}>Open .env</button>
          </div>
        </section>
      )}

      {showOnboarding && (
        <section className="hero card" aria-label="Getting started">
          <h1>Welcome</h1>
          <div className="subtle">A quick setup and you’re ready to sync.</div>
          <ol className="step-list">
            <li>Open the token page and copy your Beeminder API token.</li>
            <li>Enter your username, goal name, and token below, then Save settings.</li>
            <li>Click <em>Sync now</em> to post today’s words.</li>
          </ol>
          <div className="actions" style={{ marginTop: 12 }}>
            <button
              className="btn-primary"
              onClick={() => {
                // Scroll to setup card
                document.querySelector("#beeminder-setup")?.scrollIntoView({ behavior: "smooth" });
              }}
            >
              Get started
            </button>
            <button
              onClick={() => {
                setShowOnboarding(false);
                try { localStorage.setItem("bearminder_onboarding_dismissed", "1"); } catch {}
              }}
            >
              Skip for now
            </button>
          </div>
        </section>
      )}

      <div className="actions" style={{ marginBottom: 16 }}>
        <button
          className={`btn-primary ${busy ? "btn-loading" : ""}`}
          disabled={busy}
          aria-busy={busy}
          onClick={() =>
            runSync({ since_hours: 24, ignore_last_sync: false, dry_run: dryRun })
          }
        >
          <span className="btn-label">Sync now</span>
          {busy && (
            <span className="btn-spinner"><span className="spinner-sm" /></span>
          )}
        </button>
        <button
          className={busy ? "btn-loading" : ""}
          disabled={busy}
          aria-busy={busy}
          onClick={() => runSync({ since_hours: 1, ignore_last_sync: true, dry_run: dryRun })}
        >
          <span className="btn-label">Recount last hour</span>
          {busy && (
            <span className="btn-spinner"><span className="spinner-sm" /></span>
          )}
        </button>
        <button disabled={busy} onClick={() => setDryRun((v) => !v)}>
          {dryRun ? "Preview only (ON)" : "Preview only (OFF)"}
        </button>
      </div>

      <div className="grid" style={{ marginBottom: 16 }}>
        <section className="card">
          <h3>Current status</h3>
          {status ? (
            <div className="status-grid">
              <div><strong>Last sync</strong></div>
              <div>{formatLocal(status.last_sync)}</div>
              <div><strong>Words posted</strong></div>
              <div>{status.value ?? 0}</div>
              <div><strong>Notes scanned</strong></div>
              <div>{status.notes_count ?? 0}</div>
              <div><strong>Tags found</strong></div>
              <div>{status.tags_count ?? 0}</div>
              <div><strong>Result</strong></div>
              <div>
                <span className="pill">{status.success ? "Success" : "Error"}</span>
              </div>
            </div>
          ) : (
            <div className="subtle">No sync yet.</div>
          )}
          <div style={{ marginTop: 12 }}>
            <button
              className={busy ? "btn-loading" : ""}
              disabled={busy}
              aria-busy={busy}
              onClick={refreshStatus}
            >
              <span className="btn-label">Refresh</span>
              {busy && (
                <span className="btn-spinner"><span className="spinner-sm" /></span>
              )}
            </button>
          </div>
          {status?.error && (
            <div style={{ color: "#c33", marginTop: 8 }}><strong>Error:</strong> {status.error}</div>
          )}
          {status?.comment && (
            <div style={{ marginTop: 8 }}>
              <div style={{ fontSize: ".9rem", marginBottom: 4 }}><strong>Details</strong></div>
              <div style={{ whiteSpace: "pre-wrap", background: "#0001", padding: 8, borderRadius: 6 }}>{status.comment}</div>
            </div>
          )}
        </section>

        <section className="card">
          <h3>Beeminder setup</h3>
          <div className="narrow">
          <div className="field">
            <label>Username</label>
            <input
              type="text"
              placeholder="Your Beeminder username"
              value={env.beeminder_username ?? ""}
              onChange={(e) => setEnv({ ...env, beeminder_username: e.target.value })}
            />
          </div>
          <div className="field">
            <label>Goal name</label>
            <input
              type="text"
              placeholder="e.g. writing"
              value={env.beeminder_goal ?? ""}
              onChange={(e) => setEnv({ ...env, beeminder_goal: e.target.value })}
            />
          </div>
          <div className="field">
            <label>API token</label>
            <input
              type="password"
              placeholder="Paste your token"
              value={env.beeminder_token ?? ""}
              onChange={(e) => setEnv({ ...env, beeminder_token: e.target.value })}
            />
            <div className="subtle">Get it from the token page below.</div>
          </div>
          <div className="actions" style={{ justifyContent: "flex-start", marginTop: 8 }}>
            <button
              className={savingEnv ? "btn-loading" : ""}
              disabled={savingEnv}
              aria-busy={savingEnv}
              onClick={async () => {
                try {
                  setSavingEnv(true);
                  setSaveMsg(null);
                  await invoke("set_env", { settings: env });
                  setSaveMsg("Saved");
                } catch (e: any) {
                  setSaveMsg(String(e));
                } finally {
                  setSavingEnv(false);
                }
              }}
            >
              <span className="btn-label">Save settings</span>
              {savingEnv && (
                <span className="btn-spinner"><span className="spinner-sm" /></span>
              )}
            </button>
            <button
              onClick={() => invoke("open_url", { url: "https://www.beeminder.com/api/v1/auth_token.json" })}
            >
              Open token page
            </button>
            <button
              onClick={() => {
                const u = env.beeminder_username || "";
                const g = env.beeminder_goal || "";
                if (u && g) {
                  invoke("open_url", { url: `https://www.beeminder.com/${u}/goals/${g}` });
                } else {
                  setSaveMsg("Set username and goal first");
                }
              }}
            >
              Open goal page
            </button>
            {saveMsg && <span className="subtle">{saveMsg}</span>}
          </div>
          </div>
        </section>
      </div>

      <section className="card" style={{ marginBottom: 16 }}>
        <h3>Advanced</h3>
        <div className="actions" style={{ justifyContent: "flex-start" }}>
          <button
            onClick={async () => {
              try {
                const p = await invoke<any>("get_paths");
                await invoke("open_path", { path: p.config_path });
              } catch (e: any) {
                setSaveMsg(String(e));
              }
            }}
          >
            Open config.yaml
          </button>
          <button
            onClick={async () => {
              try {
                const p = await invoke<any>("get_paths");
                await invoke("open_path", { path: p.data_dir });
              } catch (e: any) {
                setSaveMsg(String(e));
              }
            }}
          >
            Open data folder
          </button>
        </div>
        <div style={{ marginTop: 12 }} className="subtle">Recent activity</div>
        <pre
          style={{
            textAlign: "left",
            whiteSpace: "pre-wrap",
            background: "#0001",
            padding: 12,
            borderRadius: 8,
          }}
        >
          {output}
        </pre>
      </section>
    </main>
  );
}

export default App;
