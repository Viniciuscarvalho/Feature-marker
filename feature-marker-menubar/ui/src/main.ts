/// <reference path="./tauri.d.ts" />

interface FeatureSummary {
  name: string;
  current_phase: number;
  total_phases: number;
  phase_status: string;
  last_updated: string;
  is_running: boolean;
  paused: boolean;
  has_error: boolean;
}

interface AppConfig {
  project_dir: string | null;
  feature_marker_path: string;
  notifications_enabled: boolean;
}

const PHASE_NAMES = [
  'Inputs Gate',
  'Analysis & Planning',
  'Implementation',
  'Tests & Validation',
  'Commit & PR'
];

class App {
  private features: FeatureSummary[] = [];
  private currentView: 'list' | 'start' | 'detail' | 'settings' = 'list';
  private selectedFeature: string | null = null;
  private outputLog: string[] = [];
  private config: AppConfig | null = null;

  async init() {
    await this.loadConfig();
    await this.loadFeatures();
    this.render();
    this.setupEventListeners();
    this.setupTauriListeners();
    this.setupWindowBehavior();
  }

  private setupWindowBehavior() {
    // Window behavior setup - use close button or Escape key to close
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        this.closeWindow();
      }
    });
  }

  private async closeWindow() {
    try {
      const { getCurrentWindow } = window.__TAURI__.window;
      await getCurrentWindow().hide();
    } catch (e) {
      console.error('Failed to close window:', e);
    }
  }

  private async loadConfig() {
    try {
      this.config = await window.__TAURI__.core.invoke<AppConfig>('get_app_config');
    } catch (e) {
      console.error('Failed to load config:', e);
    }
  }

  private async loadFeatures() {
    try {
      this.features = await window.__TAURI__.core.invoke<FeatureSummary[]>('get_features');
    } catch (e) {
      console.error('Failed to load features:', e);
      this.features = [];
    }
  }

  private setupTauriListeners() {
    const { listen } = window.__TAURI__.event;

    listen('feature-updated', () => {
      this.loadFeatures().then(() => this.render());
    });

    listen('feature-started', () => {
      this.loadFeatures().then(() => this.render());
    });

    listen('feature-completed', () => {
      this.loadFeatures().then(() => this.render());
    });

    listen('feature-error', () => {
      this.loadFeatures().then(() => this.render());
    });

    listen('feature-cancelled', () => {
      this.loadFeatures().then(() => this.render());
    });

    listen('feature-paused', () => {
      this.loadFeatures().then(() => this.render());
    });

    listen('output-line', (event: { payload: unknown }) => {
      const line = event.payload as string;
      this.outputLog.push(line);
      if (this.outputLog.length > 500) {
        this.outputLog.shift();
      }
      this.updateOutputLog();
    });

    listen('set-view-mode', (event: { payload: unknown }) => {
      const mode = event.payload as string;
      if (mode === 'start') {
        this.showStartView();
      } else if (mode === 'settings') {
        this.showSettingsView();
      } else if (mode === 'list' || mode === 'feature') {
        this.showListView();
      }
    });

    listen('select-feature', (event: { payload: unknown }) => {
      const feature = event.payload as string;
      this.showFeatureDetail(feature);
    });

    listen('resume-feature', (event: { payload: unknown }) => {
      const feature = event.payload as string;
      this.resumeFeature(feature);
    });
  }

  private setupEventListeners() {
    document.addEventListener('click', (e) => {
      const target = e.target as HTMLElement;

      if (target.closest('[data-action="close"]')) {
        this.closeWindow();
      } else if (target.closest('[data-action="start"]')) {
        this.showStartView();
      } else if (target.closest('[data-action="back"]')) {
        this.showListView();
      } else if (target.closest('[data-action="settings"]')) {
        this.showSettingsView();
      } else if (target.closest('[data-action="refresh"]')) {
        this.loadFeatures().then(() => this.render());
      } else if (target.closest('[data-action="start-feature"]')) {
        this.startFeature();
      } else if (target.closest('[data-action="pause"]')) {
        this.pauseFeature();
      } else if (target.closest('[data-action="cancel"]')) {
        this.cancelFeature();
      } else if (target.closest('[data-action="open-dir"]')) {
        this.openProjectDir();
      } else if (target.closest('[data-action="set-project"]')) {
        this.setProjectDir();
      } else if (target.closest('.feature-item')) {
        const featureName = target.closest('.feature-item')?.getAttribute('data-feature');
        if (featureName) {
          this.showFeatureDetail(featureName);
        }
      }
    });
  }

  private showListView() {
    this.currentView = 'list';
    this.selectedFeature = null;
    this.render();
  }

  private showStartView() {
    this.currentView = 'start';
    this.render();
  }

  private showSettingsView() {
    this.currentView = 'settings';
    this.render();
  }

  private showFeatureDetail(featureName: string) {
    this.currentView = 'detail';
    this.selectedFeature = featureName;
    this.render();
  }

  private async startFeature() {
    const nameInput = document.getElementById('feature-name') as HTMLInputElement;
    const modeSelect = document.getElementById('feature-mode') as HTMLSelectElement;

    const name = nameInput?.value?.trim();
    const mode = modeSelect?.value || 'full';

    if (!name) {
      alert('Please enter a feature name');
      return;
    }

    try {
      await window.__TAURI__.core.invoke('start_feature', { feature: name, mode });
      this.outputLog = [];
      this.showFeatureDetail(name);
    } catch (e) {
      console.error('Failed to start feature:', e);
      alert(`Failed to start feature: ${e}`);
    }
  }

  private async resumeFeature(featureName: string) {
    try {
      await window.__TAURI__.core.invoke('resume_feature', { feature: featureName });
      this.outputLog = [];
      this.showFeatureDetail(featureName);
    } catch (e) {
      console.error('Failed to resume feature:', e);
    }
  }

  private async pauseFeature() {
    try {
      await window.__TAURI__.core.invoke('pause_feature');
    } catch (e) {
      console.error('Failed to pause feature:', e);
    }
  }

  private async cancelFeature() {
    if (confirm('Are you sure you want to cancel the current feature?')) {
      try {
        await window.__TAURI__.core.invoke('cancel_feature');
        this.showListView();
      } catch (e) {
        console.error('Failed to cancel feature:', e);
      }
    }
  }

  private async openProjectDir() {
    try {
      await window.__TAURI__.core.invoke('open_project_dir');
    } catch (e) {
      console.error('Failed to open project dir:', e);
    }
  }

  private async setProjectDir() {
    try {
      // Use Tauri's native file dialog
      const { open } = window.__TAURI__.dialog;
      const selected = await open({
        directory: true,
        multiple: false,
        title: 'Select Project Directory'
      });

      if (selected && typeof selected === 'string') {
        await window.__TAURI__.core.invoke('set_project_dir', { path: selected });
        await this.loadConfig();
        await this.loadFeatures();
        this.render();
      }
    } catch (e) {
      console.error('Failed to set project directory:', e);
      alert(`Failed to set project directory: ${e}`);
    }
  }

  private updateOutputLog() {
    const logEl = document.getElementById('output-log');
    if (logEl) {
      const lastLines = this.outputLog.slice(-100);
      logEl.innerHTML = lastLines.map(line => {
        const cls = line.includes('[stderr]') ? 'error' : line.includes('\u2713') || line.includes('\u2705') ? 'success' : '';
        return `<div class="line ${cls}">${this.escapeHtml(line)}</div>`;
      }).join('');
      logEl.scrollTop = logEl.scrollHeight;
    }
  }

  private escapeHtml(text: string): string {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  private render() {
    const app = document.getElementById('app');
    if (!app) return;

    let content = '';

    switch (this.currentView) {
      case 'list':
        content = this.renderListView();
        break;
      case 'start':
        content = this.renderStartView();
        break;
      case 'detail':
        content = this.renderDetailView();
        break;
      case 'settings':
        content = this.renderSettingsView();
        break;
    }

    app.innerHTML = content;
  }

  private renderListView(): string {
    const featuresList = this.features.length === 0
      ? this.renderEmptyState()
      : this.features.map(f => this.renderFeatureItem(f)).join('');

    return `
      <div class="header">
        <h1>Feature-Marker</h1>
        <div class="header-actions">
          <button class="btn-icon" data-action="refresh" title="Refresh">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="23 4 23 10 17 10"></polyline>
              <polyline points="1 20 1 14 7 14"></polyline>
              <path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"></path>
            </svg>
          </button>
          <button class="btn-icon" data-action="settings" title="Settings">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <circle cx="12" cy="12" r="3"></circle>
              <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"></path>
            </svg>
          </button>
          <button class="btn-icon" data-action="close" title="Close">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <line x1="18" y1="6" x2="6" y2="18"></line>
              <line x1="6" y1="6" x2="18" y2="18"></line>
            </svg>
          </button>
        </div>
      </div>
      <div class="content">
        <div class="feature-list">
          ${featuresList}
        </div>
      </div>
      <div class="footer">
        <div class="footer-status">
          ${this.config?.project_dir ? this.truncatePath(this.config.project_dir) : 'No project set'}
        </div>
        <div class="footer-actions">
          <button class="btn btn-primary" data-action="start">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <line x1="12" y1="5" x2="12" y2="19"></line>
              <line x1="5" y1="12" x2="19" y2="12"></line>
            </svg>
            New Feature
          </button>
        </div>
      </div>
    `;
  }

  private renderEmptyState(): string {
    return `
      <div class="empty-state">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
          <polyline points="14 2 14 8 20 8"></polyline>
          <line x1="16" y1="13" x2="8" y2="13"></line>
          <line x1="16" y1="17" x2="8" y2="17"></line>
          <polyline points="10 9 9 9 8 9"></polyline>
        </svg>
        <h3>No features yet</h3>
        <p>Start a new feature workflow to begin</p>
        <button class="btn btn-primary" data-action="start">Start New Feature</button>
      </div>
    `;
  }

  private renderFeatureItem(feature: FeatureSummary): string {
    const progress = Math.round((feature.current_phase / feature.total_phases) * 100);
    const statusClass = feature.is_running ? 'running' : feature.has_error ? 'error' : feature.paused ? 'paused' : '';
    const statusText = feature.is_running ? 'Running' : feature.has_error ? 'Error' : feature.paused ? 'Paused' : 'Idle';

    return `
      <div class="feature-item ${statusClass}" data-feature="${feature.name}">
        <div class="feature-header">
          <span class="feature-name">${feature.name}</span>
          <span class="feature-status ${statusClass}">${statusText}</span>
        </div>
        <div class="progress-container">
          <div class="progress-bar">
            <div class="progress-fill ${statusClass}" style="width: ${progress}%"></div>
          </div>
          <span class="progress-text">Phase ${feature.current_phase}/${feature.total_phases}</span>
        </div>
        <div class="phase-indicator">
          ${PHASE_NAMES.map((phaseName, i) => {
            const cls = i < feature.current_phase ? 'completed' :
                       i === feature.current_phase ? (feature.has_error ? 'error' : 'current') : '';
            return `<div class="phase-dot ${cls}" title="${phaseName}"></div>`;
          }).join('')}
        </div>
      </div>
    `;
  }

  private renderStartView(): string {
    return `
      <div class="header">
        <button class="btn-icon" data-action="back" title="Back">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <line x1="19" y1="12" x2="5" y2="12"></line>
            <polyline points="12 19 5 12 12 5"></polyline>
          </svg>
        </button>
        <h1>New Feature</h1>
        <button class="btn-icon" data-action="close" title="Close">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <line x1="18" y1="6" x2="6" y2="18"></line>
            <line x1="6" y1="6" x2="18" y2="18"></line>
          </svg>
        </button>
      </div>
      <div class="content">
        <div class="start-form">
          <div class="form-group">
            <label class="form-label" for="feature-name">Feature Name (slug)</label>
            <input type="text" id="feature-name" class="form-input" placeholder="prd-user-authentication" />
          </div>
          <div class="form-group">
            <label class="form-label" for="feature-mode">Execution Mode</label>
            <select id="feature-mode" class="form-input form-select">
              <option value="full">Full Workflow</option>
              <option value="tasks-only">Tasks Only</option>
              <option value="ralph-loop">Ralph Loop (Autonomous)</option>
              <option value="spec-driven">Spec-Driven (Multi-agent)</option>
            </select>
          </div>
          <button class="btn btn-primary" style="width: 100%" data-action="start-feature">
            Start Feature
          </button>
        </div>
      </div>
    `;
  }

  private renderDetailView(): string {
    const feature = this.features.find(f => f.name === this.selectedFeature);
    if (!feature) {
      return this.renderListView();
    }

    const statusClass = feature.is_running ? 'running' : feature.has_error ? 'error' : feature.paused ? 'paused' : '';

    return `
      <div class="header">
        <button class="btn-icon" data-action="back" title="Back">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <line x1="19" y1="12" x2="5" y2="12"></line>
            <polyline points="12 19 5 12 12 5"></polyline>
          </svg>
        </button>
        <h1>${feature.name}</h1>
        <button class="btn-icon" data-action="close" title="Close">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <line x1="18" y1="6" x2="6" y2="18"></line>
            <line x1="6" y1="6" x2="18" y2="18"></line>
          </svg>
        </button>
      </div>
      <div class="content">
        <div class="feature-detail">
          <div class="feature-detail-header">
            <span class="feature-status ${statusClass}" style="margin-bottom: 8px">
              ${feature.is_running ? 'Running' : feature.has_error ? 'Error' : feature.paused ? 'Paused' : 'Idle'}
            </span>
            <div class="meta">Last updated: ${new Date(feature.last_updated).toLocaleString()}</div>
          </div>

          <div class="phase-list">
            ${PHASE_NAMES.map((name, i) => {
              const cls = i < feature.current_phase ? 'completed' :
                         i === feature.current_phase ? (feature.has_error ? 'error' : 'current') : '';
              const statusText = i < feature.current_phase ? 'Completed' :
                                i === feature.current_phase ? (feature.is_running ? 'In Progress' : feature.has_error ? 'Error' : 'Pending') : 'Pending';
              return `
                <div class="phase-item ${cls}">
                  <div class="phase-number">${i}</div>
                  <div class="phase-info">
                    <div class="phase-name">${name}</div>
                    <div class="phase-status-text">${statusText}</div>
                  </div>
                </div>
              `;
            }).join('')}
          </div>

          ${feature.is_running ? `
            <div class="action-buttons">
              <button class="btn btn-secondary" data-action="cancel">Stop</button>
            </div>
          ` : `
            <div class="action-buttons">
              <button class="btn btn-primary" data-action="resume-feature" data-feature="${feature.name}">
                Resume
              </button>
              <button class="btn btn-secondary" data-action="open-dir">
                Open Directory
              </button>
            </div>
          `}

          ${feature.is_running || this.outputLog.length > 0 ? `
            <h3 style="margin: 16px 0 8px; font-size: 12px; color: var(--text-secondary)">
              Output ${feature.is_running ? '<span class="running-indicator"></span>' : ''}
            </h3>
            <div class="output-log" id="output-log">
              ${this.outputLog.length > 0 ? this.outputLog.slice(-100).map(line => {
                const cls = line.includes('[stderr]') ? 'error' : line.includes('\u2713') || line.includes('\u2705') ? 'success' : '';
                return `<div class="line ${cls}">${this.escapeHtml(line)}</div>`;
              }).join('') : '<div class="line">Waiting for output...</div>'}
            </div>
          ` : ''}
        </div>
      </div>
    `;
  }

  private renderSettingsView(): string {
    return `
      <div class="header">
        <button class="btn-icon" data-action="back" title="Back">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <line x1="19" y1="12" x2="5" y2="12"></line>
            <polyline points="12 19 5 12 12 5"></polyline>
          </svg>
        </button>
        <h1>Settings</h1>
        <button class="btn-icon" data-action="close" title="Close">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <line x1="18" y1="6" x2="6" y2="18"></line>
            <line x1="6" y1="6" x2="18" y2="18"></line>
          </svg>
        </button>
      </div>
      <div class="content">
        <div class="settings-group">
          <h3>Project</h3>
          <div class="settings-item">
            <span class="settings-label">Project Directory</span>
            <span class="settings-value">${this.config?.project_dir || 'Not set'}</span>
          </div>
          <button class="btn btn-secondary" style="width: 100%; margin-top: 8px" data-action="set-project">
            Change Project Directory
          </button>
        </div>

        <div class="settings-group">
          <h3>Feature-Marker</h3>
          <div class="settings-item">
            <span class="settings-label">Installation Path</span>
            <span class="settings-value">${this.config?.feature_marker_path || 'Unknown'}</span>
          </div>
        </div>

        <div class="settings-group">
          <h3>About</h3>
          <div class="settings-item">
            <span class="settings-label">Version</span>
            <span class="settings-value">0.1.0</span>
          </div>
        </div>
      </div>
    `;
  }

  private truncatePath(path: string): string {
    if (path.length <= 30) return path;
    const parts = path.split('/');
    if (parts.length <= 3) return path;
    return `.../${parts.slice(-2).join('/')}`;
  }
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  const app = new App();
  app.init();
});

export {};
