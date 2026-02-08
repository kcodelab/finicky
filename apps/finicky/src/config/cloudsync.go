package config

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"finicky/util"
)

const iCloudConfigDir = "Library/Mobile Documents/com~apple~CloudDocs"

const defaultConfigTemplate = `export default {
  defaultBrowser: "Safari",
  handlers: [],
};
`

type CloudSyncResult struct {
	Ok         bool   `json:"ok"`
	Provider   string `json:"provider"`
	ConfigPath string `json:"configPath"`
	CloudPath  string `json:"cloudPath"`
	BackupPath string `json:"backupPath"`
	Message    string `json:"message"`
}

type CloudSyncStatus struct {
	Enabled    bool   `json:"enabled"`
	Provider   string `json:"provider"`
	ConfigPath string `json:"configPath"`
	CloudPath  string `json:"cloudPath"`
}

func (cfw *ConfigFileWatcher) EnableICloudSync() (*CloudSyncResult, error) {
	homeDir, err := util.UserHomeDir()
	if err != nil {
		return nil, err
	}

	preferredPath := cfw.preferredConfigPath(homeDir)
	currentPath := cfw.getExistingConfigPathRaw()
	if currentPath == "" {
		currentPath = preferredPath
	}

	ext := filepath.Ext(currentPath)
	if ext != ".ts" {
		ext = ".js"
	}

	iCloudPath := filepath.Join(homeDir, iCloudConfigDir, ".finicky"+ext)
	if err := os.MkdirAll(filepath.Dir(iCloudPath), 0755); err != nil {
		return nil, fmt.Errorf("failed creating iCloud config directory: %w", err)
	}

	if err := ensureCloudConfig(iCloudPath, currentPath); err != nil {
		return nil, err
	}

	backupPath, err := replaceWithSymlink(currentPath, iCloudPath)
	if err != nil {
		return nil, err
	}

	cfw.cache.Clear()
	select {
	case cfw.configChangeNotify <- struct{}{}:
	default:
	}

	result := &CloudSyncResult{
		Ok:         true,
		Provider:   "iCloud",
		ConfigPath: currentPath,
		CloudPath:  iCloudPath,
		BackupPath: backupPath,
		Message:    "iCloud sync enabled",
	}

	if backupPath != "" {
		result.Message = "iCloud sync enabled, local config backed up"
	}

	return result, nil
}

func (cfw *ConfigFileWatcher) DisableICloudSync() (*CloudSyncResult, error) {
	homeDir, err := util.UserHomeDir()
	if err != nil {
		return nil, err
	}

	configPath := cfw.getExistingConfigPathRaw()
	if configPath == "" {
		configPath = cfw.preferredConfigPath(homeDir)
	}

	sourceInfo, err := os.Lstat(configPath)
	if err != nil {
		return nil, fmt.Errorf("failed checking config path: %w", err)
	}

	if sourceInfo.Mode()&os.ModeSymlink == 0 {
		return nil, fmt.Errorf("icloud sync is not enabled for this config path")
	}

	resolvedTarget, err := filepath.EvalSymlinks(configPath)
	if err != nil {
		return nil, fmt.Errorf("failed resolving config symlink: %w", err)
	}

	if !isInICloudDocs(resolvedTarget, homeDir) {
		return nil, fmt.Errorf("config symlink does not target iCloud")
	}

	if err := os.Remove(configPath); err != nil {
		return nil, fmt.Errorf("failed removing config symlink: %w", err)
	}

	backupPath := latestConfigBackupPath(configPath)
	if backupPath == "" {
		backupPath = latestLegacyBackupPath(configPath)
	}
	if backupPath != "" {
		if err := os.Rename(backupPath, configPath); err != nil {
			return nil, fmt.Errorf("failed restoring config backup: %w", err)
		}
	} else {
		data, err := os.ReadFile(resolvedTarget)
		if err != nil {
			return nil, fmt.Errorf("failed reading iCloud config: %w", err)
		}
		if err := os.WriteFile(configPath, data, 0644); err != nil {
			return nil, fmt.Errorf("failed restoring local config: %w", err)
		}
	}

	cfw.cache.Clear()
	select {
	case cfw.configChangeNotify <- struct{}{}:
	default:
	}

	return &CloudSyncResult{
		Ok:         true,
		Provider:   "iCloud",
		ConfigPath: configPath,
		CloudPath:  resolvedTarget,
		BackupPath: backupPath,
		Message:    "iCloud sync disabled",
	}, nil
}

func (cfw *ConfigFileWatcher) GetICloudSyncStatus() (*CloudSyncStatus, error) {
	homeDir, err := util.UserHomeDir()
	if err != nil {
		return nil, err
	}

	configPath := cfw.getExistingConfigPathRaw()
	if configPath == "" {
		configPath = cfw.preferredConfigPath(homeDir)
	}

	info, err := os.Lstat(configPath)
	if err != nil {
		if os.IsNotExist(err) {
			return &CloudSyncStatus{
				Enabled:    false,
				Provider:   "iCloud",
				ConfigPath: configPath,
			}, nil
		}
		return nil, err
	}

	if info.Mode()&os.ModeSymlink == 0 {
		return &CloudSyncStatus{
			Enabled:    false,
			Provider:   "iCloud",
			ConfigPath: configPath,
		}, nil
	}

	resolvedTarget, err := filepath.EvalSymlinks(configPath)
	if err != nil {
		return nil, err
	}

	enabled := isInICloudDocs(resolvedTarget, homeDir)
	return &CloudSyncStatus{
		Enabled:    enabled,
		Provider:   "iCloud",
		ConfigPath: configPath,
		CloudPath:  resolvedTarget,
	}, nil
}

func (cfw *ConfigFileWatcher) preferredConfigPath(homeDir string) string {
	configPaths := cfw.GetConfigPaths()
	if len(configPaths) > 0 {
		return configPaths[0]
	}
	return filepath.Join(homeDir, ".finicky.js")
}

func (cfw *ConfigFileWatcher) getExistingConfigPathRaw() string {
	for _, path := range cfw.GetConfigPaths() {
		if _, err := os.Lstat(path); err == nil {
			return path
		}
	}
	return ""
}

func ensureCloudConfig(iCloudPath string, sourcePath string) error {
	if _, err := os.Stat(iCloudPath); err == nil {
		return nil
	}

	if sourceInfo, err := os.Lstat(sourcePath); err == nil {
		if sourceInfo.Mode()&os.ModeSymlink != 0 {
			resolved, err := filepath.EvalSymlinks(sourcePath)
			if err == nil && resolved == iCloudPath {
				return nil
			}
		}

		data, err := os.ReadFile(sourcePath)
		if err != nil {
			return fmt.Errorf("failed reading existing config: %w", err)
		}
		if err := os.WriteFile(iCloudPath, data, 0644); err != nil {
			return fmt.Errorf("failed writing iCloud config: %w", err)
		}
		return nil
	}

	if err := os.WriteFile(iCloudPath, []byte(defaultConfigTemplate), 0644); err != nil {
		return fmt.Errorf("failed creating iCloud config: %w", err)
	}
	return nil
}

func replaceWithSymlink(sourcePath string, targetPath string) (string, error) {
	if sourcePath == targetPath {
		return "", nil
	}

	if info, err := os.Lstat(sourcePath); err == nil {
		if info.Mode()&os.ModeSymlink != 0 {
			resolved, err := filepath.EvalSymlinks(sourcePath)
			if err == nil && resolved == targetPath {
				return "", nil
			}
		}

		backupPath, err := backupConfigFile(sourcePath, "icloud")
		if err != nil {
			return "", fmt.Errorf("failed creating backup before enabling iCloud sync: %w", err)
		}

		if err := os.Symlink(targetPath, sourcePath); err != nil {
			_ = os.Rename(backupPath, sourcePath)
			return "", fmt.Errorf("failed creating config symlink: %w", err)
		}
		return backupPath, nil
	}

	if err := os.MkdirAll(filepath.Dir(sourcePath), 0755); err != nil {
		return "", fmt.Errorf("failed creating config directory: %w", err)
	}

	if err := os.Symlink(targetPath, sourcePath); err != nil {
		return "", fmt.Errorf("failed creating config symlink: %w", err)
	}

	return "", nil
}

func latestLegacyBackupPath(configPath string) string {
	matches, err := filepath.Glob(configPath + ".backup-*")
	if err != nil || len(matches) == 0 {
		return ""
	}

	sort.Slice(matches, func(i, j int) bool {
		left, leftErr := os.Stat(matches[i])
		right, rightErr := os.Stat(matches[j])
		if leftErr != nil || rightErr != nil {
			return matches[i] > matches[j]
		}
		return left.ModTime().After(right.ModTime())
	})

	return matches[0]
}

func isInICloudDocs(path string, homeDir string) bool {
	iCloudRoot := filepath.Join(homeDir, iCloudConfigDir)
	relPath, err := filepath.Rel(iCloudRoot, path)
	if err != nil {
		return false
	}
	if relPath == "." {
		return true
	}
	return relPath != "" && relPath != ".." && !strings.HasPrefix(relPath, ".."+string(filepath.Separator))
}
