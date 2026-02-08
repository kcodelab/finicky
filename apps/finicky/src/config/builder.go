package config

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"finicky/util"
)

type GeneratedRoute struct {
	Patterns []string `json:"patterns"`
	Browser  string   `json:"browser"`
	Profile  string   `json:"profile"`
}

type GeneratedConfigRequest struct {
	DefaultBrowser string           `json:"defaultBrowser"`
	Routes         []GeneratedRoute `json:"routes"`
}

type SaveGeneratedConfigResult struct {
	Ok         bool   `json:"ok"`
	ConfigPath string `json:"configPath"`
	BackupPath string `json:"backupPath"`
	Message    string `json:"message"`
}

type PreviewGeneratedConfigResult struct {
	Ok      bool   `json:"ok"`
	Content string `json:"content"`
}

func (cfw *ConfigFileWatcher) SaveGeneratedConfig(request GeneratedConfigRequest) (*SaveGeneratedConfigResult, error) {
	if strings.TrimSpace(request.DefaultBrowser) == "" {
		return nil, fmt.Errorf("default browser is required")
	}

	homeDir, err := util.UserHomeDir()
	if err != nil {
		return nil, err
	}

	configPath := cfw.getExistingConfigPathRaw()
	if configPath == "" {
		configPath = cfw.preferredConfigPath(homeDir)
	}

	content := BuildGeneratedConfigContent(request)
	backupPath, err := backupIfFileExists(configPath)
	if err != nil {
		return nil, err
	}

	if err := os.MkdirAll(filepath.Dir(configPath), 0755); err != nil {
		return nil, fmt.Errorf("failed creating config directory: %w", err)
	}

	if err := os.WriteFile(configPath, []byte(content), 0644); err != nil {
		return nil, fmt.Errorf("failed writing config: %w", err)
	}

	cfw.cache.Clear()
	select {
	case cfw.configChangeNotify <- struct{}{}:
	default:
	}

	return &SaveGeneratedConfigResult{
		Ok:         true,
		ConfigPath: configPath,
		BackupPath: backupPath,
		Message:    "Config generated successfully",
	}, nil
}

func BuildGeneratedConfigContent(request GeneratedConfigRequest) string {
	builder := strings.Builder{}
	builder.WriteString("export default {\n")
	builder.WriteString(fmt.Sprintf("  defaultBrowser: %s,\n", quoteJS(request.DefaultBrowser)))
	builder.WriteString("  handlers: [\n")

	for _, route := range request.Routes {
		patterns := normalizePatterns(route.Patterns)
		if len(patterns) == 0 || strings.TrimSpace(route.Browser) == "" {
			continue
		}

		browserValue := strings.TrimSpace(route.Browser)
		profileValue := strings.TrimSpace(route.Profile)

		builder.WriteString("    {\n")
		builder.WriteString("      match: [\n")
		for _, pattern := range patterns {
			builder.WriteString(fmt.Sprintf("        %s,\n", quoteJS(pattern)))
		}
		builder.WriteString("      ],\n")
		if profileValue != "" {
			builder.WriteString("      browser: {\n")
			builder.WriteString(fmt.Sprintf("        name: %s,\n", quoteJS(browserValue)))
			builder.WriteString(fmt.Sprintf("        profile: %s,\n", quoteJS(profileValue)))
			builder.WriteString("      },\n")
		} else {
			builder.WriteString(fmt.Sprintf("      browser: %s,\n", quoteJS(browserValue)))
		}
		builder.WriteString("    },\n")
	}

	builder.WriteString("  ],\n")
	builder.WriteString("};\n")
	return builder.String()
}

func normalizePatterns(patterns []string) []string {
	seen := make(map[string]bool)
	result := make([]string, 0, len(patterns))

	for _, pattern := range patterns {
		trimmed := sanitizePattern(pattern)
		if trimmed == "" || seen[trimmed] {
			continue
		}
		seen[trimmed] = true
		result = append(result, trimmed)
	}

	sort.Strings(result)
	return result
}

func quoteJS(value string) string {
	escaped := strings.ReplaceAll(value, "\\", "\\\\")
	escaped = strings.ReplaceAll(escaped, "\"", "\\\"")
	return "\"" + escaped + "\""
}

func sanitizePattern(value string) string {
	trimmed := strings.TrimSpace(value)
	trimmed = strings.TrimSuffix(trimmed, ",")
	if len(trimmed) >= 2 {
		if strings.HasPrefix(trimmed, "\"") && strings.HasSuffix(trimmed, "\"") {
			trimmed = trimmed[1 : len(trimmed)-1]
		}
		if strings.HasPrefix(trimmed, "'") && strings.HasSuffix(trimmed, "'") {
			trimmed = trimmed[1 : len(trimmed)-1]
		}
	}
	return strings.TrimSpace(trimmed)
}

func backupIfFileExists(path string) (string, error) {
	return backupConfigFile(path, "builder")
}
