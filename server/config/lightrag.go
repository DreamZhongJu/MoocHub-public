package config

import (
	"strconv"
	"strings"
	"time"
)

func LightRAGSyncURL() string {
	return envOrDefault("LIGHTRAG_SYNC_URL", "")
}

func LightRAGQueryURL() string {
	return envOrDefault("LIGHTRAG_QUERY_URL", "")
}

func LightRAGSyncToken() string {
	return envOrDefault("LIGHTRAG_SYNC_TOKEN", "")
}

func LightRAGQueryToken() string {
	return envOrDefault("LIGHTRAG_QUERY_TOKEN", "")
}

func LightRAGSyncTimeout() time.Duration {
	v := strings.TrimSpace(envOrDefault("LIGHTRAG_SYNC_TIMEOUT_MS", "5000"))
	ms, err := strconv.Atoi(v)
	if err != nil || ms <= 0 {
		return 5 * time.Second
	}
	return time.Duration(ms) * time.Millisecond
}

func LightRAGQueryTimeout() time.Duration {
	v := strings.TrimSpace(envOrDefault("LIGHTRAG_QUERY_TIMEOUT_MS", "120000"))
	ms, err := strconv.Atoi(v)
	if err != nil || ms <= 0 {
		return 120 * time.Second
	}
	return time.Duration(ms) * time.Millisecond
}

func LightRAGSyncMaxRetry() int {
	v := strings.TrimSpace(envOrDefault("LIGHTRAG_SYNC_MAX_RETRY", "3"))
	n, err := strconv.Atoi(v)
	if err != nil || n < 0 {
		return 3
	}
	return n
}
