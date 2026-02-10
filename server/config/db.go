package config

import (
	"os"
	"strings"
)

func envOrDefault(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return strings.TrimSpace(value)
	}
	return fallback
}

func MysqlDSN() string {
	return envOrDefault("MYSQL_DSN", "root:root@tcp(127.0.0.1:3306)/moochub?parseTime=true")
}

func MongoURI() string {
	return envOrDefault("MONGODB_URI", "mongodb://localhost:27017")
}

func MongoDBName() string {
	return envOrDefault("MONGODB_DB", "moochub")
}

func MinioEndpoint() string {
	return envOrDefault("MINIO_ENDPOINT", "127.0.0.1:9000")
}

func MinioAccessKey() string {
	return envOrDefault("MINIO_ACCESS_KEY", "appuser")
}

func MinioSecretKey() string {
	return envOrDefault("MINIO_SECRET_KEY", "<your_minio_secret_key>")
}

func MinioBucket() string {
	return envOrDefault("MINIO_BUCKET", "moochub-video")
}

func MinioSecure() bool {
	return envOrDefault("MINIO_SECURE", "false") == "true"
}

func MinioPresignExpireSeconds() int64 {
	if v := envOrDefault("MINIO_PRESIGN_EXPIRE", "3600"); v != "" {
		var secs int64
		for _, r := range v {
			if r < '0' || r > '9' {
				return 3600
			}
		}
		for _, r := range v {
			secs = secs*10 + int64(r-'0')
		}
		if secs <= 0 {
			return 3600
		}
		return secs
	}
	return 3600
}

func MinioUsePresign() bool {
	return envOrDefault("MINIO_USE_PRESIGN", "true") == "true"
}

func RedisAddr() string {
	return envOrDefault("REDIS_ADDR", "127.0.0.1:16379")
}

func RedisPassword() string {
	return envOrDefault("REDIS_PASSWORD", "")
}

func RedisDB() int {
	v := envOrDefault("REDIS_DB", "0")
	var n int
	for _, r := range v {
		if r < '0' || r > '9' {
			return 0
		}
		n = n*10 + int(r-'0')
	}
	return n
}

func RabbitMQURL() string {
	return envOrDefault("RABBITMQ_URL", "amqp://guest:guest@127.0.0.1:5672/")
}

func InternalToken() string {
	return envOrDefault("INTERNAL_TOKEN", "moochub-internal")
}

func QQAppID() string {
	return envOrDefault("QQ_APP_ID", "")
}

func QQAppKey() string {
	return envOrDefault("QQ_APP_KEY", "")
}

func QQRedirectURI() string {
	return envOrDefault("QQ_REDIRECT_URI", "http://127.0.0.1:3000/api/v1/auth/qq/callback")
}

func QQState() string {
	return envOrDefault("QQ_STATE", "moochub")
}
