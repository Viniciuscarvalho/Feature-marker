interface TauriCore {
  invoke: <T>(cmd: string, args?: Record<string, unknown>) => Promise<T>;
}

interface TauriEvent {
  listen: (event: string, callback: (payload: { payload: unknown }) => void) => Promise<() => void>;
}

interface OpenDialogOptions {
  directory?: boolean;
  multiple?: boolean;
  title?: string;
  defaultPath?: string;
  filters?: { name: string; extensions: string[] }[];
}

interface TauriDialog {
  open: (options?: OpenDialogOptions) => Promise<string | string[] | null>;
}

interface TauriWindow {
  hide: () => Promise<void>;
  show: () => Promise<void>;
  close: () => Promise<void>;
  setFocus: () => Promise<void>;
}

interface TauriWindowModule {
  getCurrentWindow: () => TauriWindow;
}

interface TauriApi {
  core: TauriCore;
  event: TauriEvent;
  dialog: TauriDialog;
  window: TauriWindowModule;
}

interface Window {
  __TAURI__: TauriApi;
}
