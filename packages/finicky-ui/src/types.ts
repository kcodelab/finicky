export interface LogEntry {
  level: string;
  msg: string;
  time: string;
  error?: string;
  [key: string]: any; // Allow for additional dynamic fields
}

declare global {
  interface Window {
    finicky: {
      sendMessage: (msg: any) => void;
      receiveMessage: (msg: any) => void;
    };
    webkit?: {
      messageHandlers?: {
        finicky?: {
          postMessage: (msg: string) => void;
        };
      };
    };
  }
}

export interface UpdateInfo {
  version: string;
  hasUpdate: boolean;
  updateCheckEnabled: boolean;
  downloadUrl: string;
  releaseUrl: string;
}

export interface ConfigOptions {
  keepRunning: boolean;
  hideIcon: boolean;
  logRequests: boolean;
  checkForUpdates: boolean;
}

export interface ConfigInfo {
  configPath: string;
  handlers?: number;
  rewrites?: number;
  defaultBrowser?: string;
  options?: {
    keepRunning?: boolean;
    hideIcon?: boolean;
    logRequests?: boolean;
    checkForUpdates?: boolean;
  };
}

export interface CloudSyncResult {
  ok: boolean;
  provider?: string;
  configPath?: string;
  cloudPath?: string;
  backupPath?: string;
  message?: string;
  error?: string;
}

export interface CloudSyncStatus {
  enabled: boolean;
  provider?: string;
  configPath?: string;
  cloudPath?: string;
  error?: string;
}

export interface ChromiumProfile {
  name: string;
  path: string;
}

export interface ChromiumProfileGroup {
  id: string;
  appName: string;
  profiles: ChromiumProfile[];
}

export interface BrowserOption {
  id: string;
  appName: string;
  type: string;
  supportsProfiles: boolean;
}

export interface ConfigRouteDraft {
  id: string;
  patterns: string;
  browserName: string;
  profile: string;
}

export interface SaveGeneratedConfigResult {
  ok: boolean;
  configPath?: string;
  backupPath?: string;
  message?: string;
  error?: string;
}

export interface PreviewGeneratedConfigResult {
  ok: boolean;
  content?: string;
  error?: string;
}

export interface ConfigBuilderDraftRoute {
  patterns: string[];
  browser: string;
  profile: string;
}

export interface ConfigBuilderDraft {
  defaultBrowser: string;
  routes: ConfigBuilderDraftRoute[];
}
