package config

import "os"

func envOrDefault(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
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
