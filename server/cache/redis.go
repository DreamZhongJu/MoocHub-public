package cache

import (
	"MOOCHUB-server/config"
	"context"
	"time"

	"github.com/redis/go-redis/v9"
)

var client *redis.Client

func InitRedis() error {
	client = redis.NewClient(&redis.Options{
		Addr:     config.RedisAddr(),
		Password: config.RedisPassword(),
		DB:       config.RedisDB(),
	})

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	return client.Ping(ctx).Err()
}

func Client() *redis.Client {
	return client
}

func CloseRedis() error {
	if client == nil {
		return nil
	}
	return client.Close()
}
