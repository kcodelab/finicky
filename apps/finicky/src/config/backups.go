package config

import (
	"crypto/sha1"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"finicky/util"
)

const maxBackupFilesPerConfig = 10

func backupConfigFile(configPath string, reason string) (string, error) {
	if _, err := os.Lstat(configPath); err != nil {
		if os.IsNotExist(err) {
			return "", nil
		}
		return "", err
	}

	backupDir, err := getBackupDir()
	if err != nil {
		return "", err
	}

	prefix := backupPrefix(configPath)
	base := filepath.Base(configPath)
	ext := filepath.Ext(base)
	name := strings.TrimSuffix(base, ext)
	timestamp := time.Now().Format("20060102150405")

	backupName := fmt.Sprintf("%s.%s.%s.%s%s", prefix, sanitizeBackupName(name), sanitizeBackupName(reason), timestamp, ext)
	backupPath := filepath.Join(backupDir, backupName)

	if err := os.Rename(configPath, backupPath); err != nil {
		return "", fmt.Errorf("failed backing up config: %w", err)
	}

	pruneBackups(configPath, maxBackupFilesPerConfig)
	return backupPath, nil
}

func latestConfigBackupPath(configPath string) string {
	backupDir, err := getBackupDir()
	if err != nil {
		return ""
	}

	prefix := backupPrefix(configPath) + "."
	entries, err := os.ReadDir(backupDir)
	if err != nil {
		return ""
	}

	var matches []string
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		if strings.HasPrefix(entry.Name(), prefix) {
			matches = append(matches, filepath.Join(backupDir, entry.Name()))
		}
	}

	if len(matches) == 0 {
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

func pruneBackups(configPath string, keep int) {
	if keep <= 0 {
		return
	}

	backupDir, err := getBackupDir()
	if err != nil {
		return
	}

	prefix := backupPrefix(configPath) + "."
	entries, err := os.ReadDir(backupDir)
	if err != nil {
		return
	}

	var paths []string
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		if strings.HasPrefix(entry.Name(), prefix) {
			paths = append(paths, filepath.Join(backupDir, entry.Name()))
		}
	}

	if len(paths) <= keep {
		return
	}

	sort.Slice(paths, func(i, j int) bool {
		left, leftErr := os.Stat(paths[i])
		right, rightErr := os.Stat(paths[j])
		if leftErr != nil || rightErr != nil {
			return paths[i] > paths[j]
		}
		return left.ModTime().After(right.ModTime())
	})

	for i := keep; i < len(paths); i++ {
		_ = os.Remove(paths[i])
	}
}

func getBackupDir() (string, error) {
	homeDir, err := util.UserHomeDir()
	if err != nil {
		return "", err
	}
	backupDir := filepath.Join(homeDir, "finicky", "backups")
	if err := os.MkdirAll(backupDir, 0755); err != nil {
		return "", err
	}
	return backupDir, nil
}

func backupPrefix(configPath string) string {
	sum := sha1.Sum([]byte(configPath))
	return fmt.Sprintf("cfg-%x", sum[:6])
}

func sanitizeBackupName(input string) string {
	if input == "" {
		return "config"
	}
	replacer := strings.NewReplacer("/", "_", "\\", "_", " ", "-", ":", "-", "..", ".")
	return replacer.Replace(input)
}
