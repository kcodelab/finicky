package browser

import (
	_ "embed"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"sort"
	"strings"

	"al.essio.dev/pkg/shellescape"
	"finicky/util"
)

//go:embed browsers.json
var browsersJsonData []byte

type BrowserResult struct {
	Browser BrowserConfig `json:"browser"`
	Error   string        `json:"error"`
}

type BrowserConfig struct {
	Name             string   `json:"name"`
	AppType          string   `json:"appType"`
	OpenInBackground *bool    `json:"openInBackground"`
	Profile          string   `json:"profile"`
	Args             []string `json:"args"`
	URL              string   `json:"url"`
}

type browserInfo struct {
	ConfigDirRelative string `json:"config_dir_relative"`
	ID                string `json:"id"`
	AppName           string `json:"app_name"`
	Type              string `json:"type"`
}

type BrowserProfile struct {
	Name string `json:"name"`
	Path string `json:"path"`
}

type BrowserProfileGroup struct {
	ID       string           `json:"id"`
	AppName  string           `json:"appName"`
	Profiles []BrowserProfile `json:"profiles"`
}

type BrowserOption struct {
	ID               string `json:"id"`
	AppName          string `json:"appName"`
	Type             string `json:"type"`
	SupportsProfiles bool   `json:"supportsProfiles"`
}

func LaunchBrowser(config BrowserConfig, dryRun bool, openInBackgroundByDefault bool) error {
	if config.AppType == "none" {
		slog.Info("AppType is 'none', not launching any browser")
		return nil
	}

	slog.Info("Starting browser", "name", config.Name, "url", config.URL)

	var openArgs []string

	if config.AppType == "bundleId" {
		openArgs = []string{"-b", config.Name}
	} else {
		openArgs = []string{"-a", config.Name}
	}

	var openInBackground bool = openInBackgroundByDefault

	if config.OpenInBackground != nil {
		openInBackground = *config.OpenInBackground
	}

	if openInBackground {
		openArgs = append(openArgs, "-g")
	}

	// Handle profile and custom args
	profileArgument, ok := resolveBrowserProfileArgument(config.Name, config.Profile)
	hasCustomArgs := len(config.Args) > 0

	// Add -n flag if profile is used (required for profile switching)
	if ok {
		openArgs = append(openArgs, "-n")
	}

	// Add --args if we have profile args or custom args
	if ok || hasCustomArgs {
		if !slices.Contains(config.Args, "--args") {
			openArgs = append(openArgs, "--args")
		}
		// Add profile argument first if present
		if ok {
			openArgs = append(openArgs, profileArgument)
		}

		// Add custom args or URL
		if hasCustomArgs {
			openArgs = append(openArgs, config.Args...)
		} else {
			openArgs = append(openArgs, config.URL)
		}
	} else {
		// No special args, just add the URL
		openArgs = append(openArgs, config.URL)
	}

	cmd := exec.Command("open", openArgs...)

	// Pretty print the command with proper escaping
	prettyCmd := formatCommand(cmd.Path, cmd.Args)

	if dryRun {
		slog.Debug("Would run command (dry run)", "command", prettyCmd)
		return nil
	} else {
		slog.Debug("Run command", "command", prettyCmd)
	}

	stderr, err := cmd.StderrPipe()
	if err != nil {
		return err
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return err
	}

	if err := cmd.Start(); err != nil {
		return err
	}

	stderrBytes, err := io.ReadAll(stderr)
	if err != nil {
		return fmt.Errorf("error reading stderr: %v", err)
	}

	stdoutBytes, err := io.ReadAll(stdout)
	if err != nil {
		return fmt.Errorf("error reading stdout: %v", err)
	}

	cmdErr := cmd.Wait()

	if len(stderrBytes) > 0 {
		slog.Error("Command returned error", "error", string(stderrBytes))
	}
	if len(stdoutBytes) > 0 {
		slog.Debug("Command returned output", "output", string(stdoutBytes))
	}

	if cmdErr != nil {
		return fmt.Errorf("command failed: %v", cmdErr)
	}

	return nil
}

func resolveBrowserProfileArgument(identifier string, profile string) (string, bool) {
	browsersJson, err := getBrowserInfo()
	if err != nil {
		slog.Info("Error parsing browsers.json", "error", err)
		return "", false
	}

	// Try to find matching browser by bundle ID
	var matchedBrowser *browserInfo
	for _, browser := range browsersJson {
		if browser.ID == identifier || browser.AppName == identifier {
			matchedBrowser = &browser
			break
		}
	}

	if matchedBrowser == nil {
		return "", false
	}

	slog.Debug("Browser found in browsers.json", "identifier", identifier, "type", matchedBrowser.Type)

	if profile != "" {
		switch matchedBrowser.Type {
		case "Chromium":
			homeDir, err := util.UserHomeDir()
			if err != nil {
				slog.Info("Error getting home directory", "error", err)
				return "", false
			}

			localStatePath := filepath.Join(homeDir, "Library/Application Support", matchedBrowser.ConfigDirRelative, "Local State")
			profilePath, ok := parseProfiles(localStatePath, profile)
			if ok {
				return "--profile-directory=" + profilePath, true
			}
		default:
			slog.Info("Browser is not a Chromium browser, skipping profile detection", "identifier", identifier)
		}
	}

	return "", false
}

func parseProfiles(localStatePath string, profile string) (string, bool) {
	infoCache, err := getInfoCache(localStatePath)
	if err != nil {
		slog.Info("Failed reading profile metadata", "path", localStatePath, "error", err)
		return "", false
	}

	// Prefer exact profile folder/path match (e.g. "Profile 1").
	for profilePath := range infoCache {
		if profilePath == profile {
			slog.Info("Found profile by folder", "path", profilePath)
			return profilePath, true
		}
	}

	// Look for the specified profile
	for profilePath, info := range infoCache {
		profileInfo, ok := info.(map[string]interface{})
		if !ok {
			continue
		}

		name, ok := profileInfo["name"].(string)
		if !ok {
			continue
		}

		if name == profile {
			slog.Warn("Found profile by name", "name", name, "path", profilePath, "suggestion", "Prefer using profile folder name")
			return profilePath, true
		}
	}

	var profileNames []string
	for _, info := range infoCache {
		profileInfo, ok := info.(map[string]interface{})
		if !ok {
			continue
		}

		name, ok := profileInfo["name"].(string)
		if !ok {
			continue
		}

		profileNames = append(profileNames, name)
	}
	slog.Warn("Could not find profile in browser profiles.", "Expected profile", profile, "Available profiles", strings.Join(profileNames, ", "))

	return "", false
}

func ScanChromiumProfiles() ([]BrowserProfileGroup, error) {
	browsersJson, err := getBrowserInfo()
	if err != nil {
		return nil, err
	}

	homeDir, err := util.UserHomeDir()
	if err != nil {
		return nil, err
	}

	var groups []BrowserProfileGroup

	for _, browser := range browsersJson {
		if browser.Type != "Chromium" {
			continue
		}

		localStatePath := filepath.Join(homeDir, "Library/Application Support", browser.ConfigDirRelative, "Local State")
		profiles, err := getProfilesFromLocalState(localStatePath)
		if err != nil || len(profiles) == 0 {
			continue
		}

		groups = append(groups, BrowserProfileGroup{
			ID:       browser.ID,
			AppName:  browser.AppName,
			Profiles: profiles,
		})
	}

	sort.Slice(groups, func(i, j int) bool {
		return groups[i].AppName < groups[j].AppName
	})

	return groups, nil
}

func getProfilesFromLocalState(localStatePath string) ([]BrowserProfile, error) {
	infoCache, err := getInfoCache(localStatePath)
	if err != nil {
		return nil, err
	}

	profiles := make([]BrowserProfile, 0, len(infoCache))
	for profilePath, info := range infoCache {
		profileInfo, ok := info.(map[string]interface{})
		if !ok {
			continue
		}

		name, ok := profileInfo["name"].(string)
		if !ok || name == "" {
			continue
		}

		profiles = append(profiles, BrowserProfile{Name: name, Path: profilePath})
	}

	sort.Slice(profiles, func(i, j int) bool {
		return profiles[i].Name < profiles[j].Name
	})

	return profiles, nil
}

func getInfoCache(localStatePath string) (map[string]interface{}, error) {
	data, err := os.ReadFile(localStatePath)
	if err != nil {
		return nil, err
	}

	var localState map[string]interface{}
	if err := json.Unmarshal(data, &localState); err != nil {
		return nil, err
	}

	profiles, ok := localState["profile"].(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("missing profile section")
	}

	infoCache, ok := profiles["info_cache"].(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("missing profile info_cache")
	}

	return infoCache, nil
}

func getBrowserInfo() ([]browserInfo, error) {
	var browsersJson []browserInfo
	if err := json.Unmarshal(browsersJsonData, &browsersJson); err != nil {
		return nil, err
	}
	return browsersJson, nil
}

func ListBrowserOptions() ([]BrowserOption, error) {
	browsersJson, err := getBrowserInfo()
	if err != nil {
		return nil, err
	}

	options := make([]BrowserOption, 0, len(browsersJson)+3)
	for _, browser := range browsersJson {
		options = append(options, BrowserOption{
			ID:               browser.ID,
			AppName:          browser.AppName,
			Type:             browser.Type,
			SupportsProfiles: browser.Type == "Chromium",
		})
	}

	// Add common non-Chromium defaults.
	options = append(options, BrowserOption{
		ID:               "com.apple.Safari",
		AppName:          "Safari",
		Type:             "Default",
		SupportsProfiles: false,
	})
	options = append(options, BrowserOption{
		ID:               "org.mozilla.firefox",
		AppName:          "Firefox",
		Type:             "Default",
		SupportsProfiles: false,
	})
	options = append(options, BrowserOption{
		ID:               "com.apple.SafariTechnologyPreview",
		AppName:          "Safari Technology Preview",
		Type:             "Default",
		SupportsProfiles: false,
	})

	sort.Slice(options, func(i, j int) bool {
		return options[i].AppName < options[j].AppName
	})

	deduped := make([]BrowserOption, 0, len(options))
	seen := make(map[string]bool)
	for _, option := range options {
		if seen[option.AppName] {
			continue
		}
		seen[option.AppName] = true
		deduped = append(deduped, option)
	}

	return deduped, nil
}

// formatCommand returns a properly shell-escaped string representation of the command
func formatCommand(path string, args []string) string {
	if len(args) == 0 {
		return shellescape.Quote(path)
	}

	quotedArgs := make([]string, len(args))
	for i, arg := range args {
		quotedArgs[i] = shellescape.Quote(arg)
	}

	return strings.Join(quotedArgs, " ")
}
