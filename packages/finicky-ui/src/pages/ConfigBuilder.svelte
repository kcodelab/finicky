<script lang="ts">
  import PageContainer from "../components/PageContainer.svelte";
  import type {
    BrowserOption,
    ConfigBuilderDraft,
    ChromiumProfileGroup,
    ConfigRouteDraft,
    PreviewGeneratedConfigResult,
    SaveGeneratedConfigResult,
  } from "../types";

  export let browserOptions: BrowserOption[] = [];
  export let chromiumProfiles: ChromiumProfileGroup[] = [];
  export let configBuilderConfigPath = "";
  export let configBuilderError = "";
  export let saveGeneratedConfigResult: SaveGeneratedConfigResult | null = null;
  export let previewGeneratedConfigResult: PreviewGeneratedConfigResult | null = null;
  export let configBuilderDraft: ConfigBuilderDraft = {
    defaultBrowser: "",
    routes: [],
  };

  let defaultBrowserName = "Safari";
  let saving = false;
  let formatting = false;
  let localError = "";
  let previewContent = "";
  let isDirty = false;
  let lastAppliedDraft = "";

  let routes: ConfigRouteDraft[] = [
    {
      id: String(Date.now()),
      patterns: "",
      browserName: "",
      profile: "",
    },
  ];

  $: if (saveGeneratedConfigResult) {
    saving = false;
    if (saveGeneratedConfigResult.ok) {
      isDirty = false;
    }
  }

  $: if (previewGeneratedConfigResult) {
    formatting = false;
    if (previewGeneratedConfigResult.ok) {
      previewContent = previewGeneratedConfigResult.content || "";
    } else if (previewGeneratedConfigResult.error) {
      localError = previewGeneratedConfigResult.error;
    }
  }

  $: {
    const nextDraftKey = JSON.stringify(configBuilderDraft || {});
    if (!isDirty && nextDraftKey !== lastAppliedDraft) {
      hydrateFromDraft(configBuilderDraft);
      lastAppliedDraft = nextDraftKey;
    }
  }

  function addRoute() {
    isDirty = true;
    routes = [
      ...routes,
      {
        id: `${Date.now()}-${Math.random()}`,
        patterns: "",
        browserName: "",
        profile: "",
      },
    ];
  }

  function removeRoute(id: string) {
    isDirty = true;
    routes = routes.filter((route) => route.id !== id);
    if (routes.length === 0) {
      addRoute();
    }
  }

  function updateRoute(id: string, patch: Partial<ConfigRouteDraft>) {
    isDirty = true;
    routes = routes.map((route) => {
      if (route.id !== id) return route;
      return { ...route, ...patch };
    });
  }

  function profilesForBrowser(browserName: string) {
    const group = chromiumProfiles.find((item) => item.appName === browserName);
    return group?.profiles || [];
  }

  function resolveDraftProfile(browserName: string, profile: string): string {
    const profiles = profilesForBrowser(browserName);
    if (!profile || profiles.length === 0) {
      return "";
    }

    const exactPath = profiles.find((item) => item.path === profile);
    if (exactPath) {
      return exactPath.path;
    }

    const byName = profiles.find((item) => item.name === profile);
    if (byName) {
      return byName.path;
    }

    return profile;
  }

  function supportsProfiles(browserName: string): boolean {
    const option = browserOptions.find((item) => item.appName === browserName);
    return option?.supportsProfiles || false;
  }

  function toPatterns(value: string): string[] {
    return value
      .split(/[,\n]/)
      .map((item) => sanitizePattern(item))
      .filter(Boolean);
  }

  function saveConfig() {
    const request = buildRequest();
    if (!request) return;

    saving = true;
    window.finicky.sendMessage({
      type: "saveGeneratedConfig",
      request,
    });
  }

  function formatConfig() {
    const request = buildRequest();
    if (!request) return;
    formatting = true;
    window.finicky.sendMessage({
      type: "previewGeneratedConfig",
      request,
    });
  }

  function hydrateFromDraft(draft: ConfigBuilderDraft) {
    defaultBrowserName = draft?.defaultBrowser || defaultBrowserName;
    const routeDrafts =
      draft?.routes?.map((route) => ({
        id: `${Date.now()}-${Math.random()}`,
        patterns: (route.patterns || []).join(", "),
        browserName: route.browser || "",
        profile: resolveDraftProfile(route.browser || "", route.profile || ""),
      })) || [];

    routes =
      routeDrafts.length > 0
        ? routeDrafts
        : [
            {
              id: String(Date.now()),
              patterns: "",
              browserName: "",
              profile: "",
            },
          ];
  }

  function buildRequest() {
    localError = "";

    if (!defaultBrowserName.trim()) {
      localError = "Default browser is required";
      return null;
    }

    const normalizedRoutes = routes
      .map((route) => ({
        patterns: toPatterns(route.patterns),
        browser: route.browserName.trim(),
        profile: route.profile.trim(),
      }))
      .filter((route) => route.patterns.length > 0 && route.browser);

    if (normalizedRoutes.length === 0) {
      localError = "Add at least one valid route rule";
      return null;
    }

    return {
      defaultBrowser: defaultBrowserName.trim(),
      routes: normalizedRoutes,
    };
  }

  function sanitizePattern(value: string): string {
    let normalized = value.trim().replace(/,$/, "");
    if (
      (normalized.startsWith('"') && normalized.endsWith('"')) ||
      (normalized.startsWith("'") && normalized.endsWith("'"))
    ) {
      normalized = normalized.slice(1, -1);
    }
    return normalized.trim();
  }
</script>

<PageContainer
  title="Config Builder"
  description="Create routing rules visually and generate a valid Finicky config file"
>
  <div class="builder-card">
    <div class="builder-row">
      <label>
        Default Browser
        <select bind:value={defaultBrowserName}>
          <option value="">Select default browser</option>
          {#each browserOptions as browser}
            <option value={browser.appName}>{browser.appName}</option>
          {/each}
        </select>
      </label>
      <div class="hint">
        Generated file path:
        <span>{configBuilderConfigPath || "(will create default config path)"}</span>
      </div>
    </div>

    <div class="route-list">
      {#each routes as route, index}
        <div class="route-card">
          <div class="route-header">
            <h4>Route {index + 1}</h4>
            <button class="ghost" on:click={() => removeRoute(route.id)}>
              Remove
            </button>
          </div>

          <label>
            Website Patterns (comma or newline separated)
            <textarea
              rows="3"
              placeholder="example.com/*, *.example.org/*"
              value={route.patterns}
              on:input={(event) =>
                updateRoute(route.id, {
                  patterns: (event.target as HTMLTextAreaElement).value,
                })}
            ></textarea>
          </label>

          <div class="browser-grid">
            <label>
              Browser
              <select
                value={route.browserName}
                on:change={(event) => {
                  const nextValue = (event.target as HTMLSelectElement).value;
                  if (supportsProfiles(nextValue)) {
                    window.finicky.sendMessage({ type: "getChromiumProfiles" });
                  }
                  updateRoute(route.id, {
                    browserName: nextValue,
                    profile: "",
                  });
                }}
              >
                <option value="">Select browser</option>
                {#each browserOptions as browser}
                  <option value={browser.appName}>{browser.appName}</option>
                {/each}
              </select>
            </label>

            {#if supportsProfiles(route.browserName)}
              <label>
                Profile
                <select
                  value={route.profile}
                  on:change={(event) =>
                    updateRoute(route.id, {
                      profile: (event.target as HTMLSelectElement).value,
                    })}
                >
                  <option value="">No profile</option>
                  {#each profilesForBrowser(route.browserName) as profile}
                    <option value={profile.path}>{profile.name} ({profile.path})</option>
                  {/each}
                </select>
              </label>
            {/if}
          </div>
        </div>
      {/each}
    </div>

    <div class="actions">
      <button class="secondary" on:click={addRoute}>Add Route</button>
      <div class="submit-actions">
        <button class="secondary" on:click={formatConfig} disabled={formatting}>
          {formatting ? "Formatting..." : "Format"}
        </button>
        <button class="primary" on:click={saveConfig} disabled={saving}>
          {saving ? "Saving..." : "Save and Activate"}
        </button>
      </div>
    </div>

    <label>
      Config Preview
      <textarea class="preview" readonly value={previewContent}></textarea>
    </label>

    {#if localError}
      <p class="error">{localError}</p>
    {/if}
    {#if configBuilderError}
      <p class="error">{configBuilderError}</p>
    {/if}
    {#if saveGeneratedConfigResult}
      {#if saveGeneratedConfigResult.ok}
        <p class="success">{saveGeneratedConfigResult.message}</p>
        {#if saveGeneratedConfigResult.backupPath}
          <p class="hint">Backup: <span>{saveGeneratedConfigResult.backupPath}</span></p>
        {/if}
      {:else}
        <p class="error">{saveGeneratedConfigResult.error}</p>
      {/if}
    {/if}
  </div>
</PageContainer>

<style>
  .builder-card {
    background: var(--card-bg);
    border: 1px solid var(--card-border);
    border-radius: 14px;
    padding: 18px;
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  .builder-row {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .builder-row label,
  .route-card label {
    color: var(--text-secondary);
    font-size: 0.9em;
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  select,
  textarea {
    border-radius: 10px;
    border: 1px solid var(--field-border);
    background: var(--field-bg);
    color: var(--text-primary);
    padding: 10px;
  }

  textarea {
    resize: vertical;
    min-height: 72px;
  }

  .hint {
    font-size: 0.85em;
    color: var(--text-secondary);
  }

  .hint span {
    font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  }

  .route-list {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .route-card {
    border: 1px solid var(--card-border);
    border-radius: 12px;
    padding: 12px;
    display: flex;
    flex-direction: column;
    gap: 10px;
    background: var(--panel-bg);
  }

  .route-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .route-header h4 {
    margin: 0;
    color: var(--text-primary);
    font-size: 0.95em;
  }

  .browser-grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 10px;
  }

  .actions {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 12px;
  }

  .submit-actions {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  button {
    border-radius: 10px;
    border: 1px solid var(--field-border);
    padding: 8px 12px;
    cursor: pointer;
    color: var(--text-primary);
  }

  button.primary {
    border-color: var(--accent-strong);
    background: var(--accent-soft);
  }

  button.secondary,
  button.ghost {
    background: var(--field-bg);
  }

  button.ghost {
    padding: 4px 8px;
    font-size: 0.85em;
  }

  .error {
    color: var(--log-error);
    font-size: 0.9em;
  }

  .success {
    color: var(--log-success);
    font-size: 0.9em;
  }

  .preview {
    min-height: 220px;
    font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
    font-size: 0.86rem;
  }

  @media (max-width: 980px) {
    .browser-grid {
      grid-template-columns: 1fr;
    }
  }
</style>
