package config

import (
	"strconv"
	"strings"
	"time"
)

func DeepSeekAPIBaseURL() string {
	return envOrDefault("DEEPSEEK_API_BASE_URL", "https://api.deepseek.com/v1")
}

func DeepSeekAPIKey() string {
	return envOrDefault("DEEPSEEK_API_KEY", "")
}

func DeepSeekModel() string {
	return envOrDefault("DEEPSEEK_MODEL", "deepseek-chat")
}

func DeepSeekTimeout() time.Duration {
	v := strings.TrimSpace(envOrDefault("DEEPSEEK_TIMEOUT_MS", "120000"))
	ms, err := strconv.Atoi(v)
	if err != nil || ms <= 0 {
		return 120 * time.Second
	}
	return time.Duration(ms) * time.Millisecond
}
