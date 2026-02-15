package cache

import (
	"context"
	"encoding/json"
	"errors"
	"hash/fnv"
	"time"
)

const (
	defaultLockTTL      = 8 * time.Second
	defaultWaitAttempts = 6
	defaultWaitStep     = 50 * time.Millisecond
)

type CacheLoadOptions struct {
	TTL      time.Duration
	StaleTTL time.Duration
	LockTTL  time.Duration
}

func FillJSONWithHotKey(ctx context.Context, key string, out interface{}, loader func(context.Context) (interface{}, error), opts CacheLoadOptions) (hit bool, stale bool, err error) {
	data, hit, stale, err := GetOrLoadBytes(ctx, key, opts, func(loadCtx context.Context) ([]byte, error) {
		v, loadErr := loader(loadCtx)
		if loadErr != nil {
			return nil, loadErr
		}
		return json.Marshal(v)
	})
	if err != nil {
		return false, false, err
	}
	if err := json.Unmarshal(data, out); err != nil {
		return false, false, err
	}
	return hit, stale, nil
}

func GetOrLoadBytes(ctx context.Context, key string, opts CacheLoadOptions, loader func(context.Context) ([]byte, error)) (data []byte, hit bool, stale bool, err error) {
	if key == "" {
		return nil, false, false, errors.New("cache key is empty")
	}
	c := Client()
	if c == nil {
		data, err = loader(ctx)
		return data, false, false, err
	}

	ttl := opts.TTL
	if ttl <= 0 {
		ttl = 2 * time.Minute
	}
	staleTTL := opts.StaleTTL
	if staleTTL <= ttl {
		staleTTL = ttl + 8*time.Minute
	}
	lockTTL := opts.LockTTL
	if lockTTL <= 0 {
		lockTTL = defaultLockTTL
	}

	// 1) 主缓存命中
	if cached, getErr := c.Get(ctx, key).Bytes(); getErr == nil && len(cached) > 0 {
		return cached, true, false, nil
	}

	staleKey := key + ":stale"
	staleData, hasStale := c.Get(ctx, staleKey).Bytes()

	lockKey := key + ":lock"
	locked, lockErr := c.SetNX(ctx, lockKey, "1", lockTTL).Result()
	if lockErr == nil && locked {
		defer c.Del(context.Background(), lockKey)
		data, err = loader(ctx)
		if err != nil {
			if hasStale == nil && len(staleData) > 0 {
				return staleData, true, true, nil
			}
			return nil, false, false, err
		}
		mainTTL := addJitter(ttl, key)
		staleTTLWithJitter := addJitter(staleTTL, staleKey)
		_ = c.Set(ctx, key, data, mainTTL).Err()
		_ = c.Set(ctx, staleKey, data, staleTTLWithJitter).Err()
		return data, false, false, nil
	}

	// 2) 热点等待（有别的请求在构建缓存）
	for i := 0; i < defaultWaitAttempts; i++ {
		select {
		case <-ctx.Done():
			break
		case <-time.After(defaultWaitStep):
		}
		if cached, getErr := c.Get(ctx, key).Bytes(); getErr == nil && len(cached) > 0 {
			return cached, true, false, nil
		}
	}

	// 3) 使用旧值兜底，避免缓存击穿打到数据库
	if hasStale == nil && len(staleData) > 0 {
		return staleData, true, true, nil
	}

	// 4) 极端场景兜底直查
	data, err = loader(ctx)
	return data, false, false, err
}

func DeleteByPattern(ctx context.Context, pattern string, batch int64) error {
	c := Client()
	if c == nil {
		return nil
	}
	if batch <= 0 {
		batch = 100
	}
	iter := c.Scan(ctx, 0, pattern, batch).Iterator()
	for iter.Next(ctx) {
		if delErr := c.Del(ctx, iter.Val()).Err(); delErr != nil {
			return delErr
		}
	}
	return iter.Err()
}

func addJitter(ttl time.Duration, key string) time.Duration {
	if ttl <= 0 {
		return ttl
	}
	// 基于 key 的稳定抖动，范围 0~20%
	h := fnv.New32a()
	_, _ = h.Write([]byte(key))
	pct := time.Duration(h.Sum32() % 21)
	return ttl + (ttl*pct)/100
}
