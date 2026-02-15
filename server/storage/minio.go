package storage

import (
	"MOOCHUB-server/config"
	"MOOCHUB-server/resilience"
	"MOOCHUB-server/utils"
	"context"
	"fmt"
	"io"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

var (
	minioOnce    sync.Once
	minioClient  *minio.Client
	minioErr     error
	minioBreaker = resilience.NewCircuitBreaker(config.BreakerFailureThreshold(), config.BreakerOpenTimeout())
)

func getMinioClient() (*minio.Client, error) {
	minioOnce.Do(func() {
		minioClient, minioErr = minio.New(config.MinioEndpoint(), &minio.Options{
			Creds:  credentials.NewStaticV4(config.MinioAccessKey(), config.MinioSecretKey(), ""),
			Secure: config.MinioSecure(),
		})
	})
	return minioClient, minioErr
}

func parseObjectKey(raw string) (string, string) {
	if strings.HasPrefix(raw, "minio://") {
		u, err := url.Parse(raw)
		if err == nil {
			bucket := u.Host
			key := strings.TrimPrefix(u.Path, "/")
			if bucket != "" && key != "" {
				return bucket, key
			}
		}
	}
	return config.MinioBucket(), raw
}

func ResolveObjectURL(raw string) (string, error) {
	if raw == "" {
		return "", nil
	}
	if strings.HasPrefix(raw, "http://") || strings.HasPrefix(raw, "https://") {
		return raw, nil
	}
	bucket, key := parseObjectKey(raw)
	client, err := getMinioClient()
	if err != nil {
		return "", err
	}
	if !config.MinioUsePresign() {
		return fmt.Sprintf("%s/%s", bucket, key), nil
	}
	var signed string
	err = minioBreaker.Execute(func() error {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		return utils.Retry(ctx, 3, 120*time.Millisecond, 900*time.Millisecond, func(retryErr error) bool {
			return true
		}, func() error {
			u, presignErr := client.PresignedGetObject(ctx, bucket, key, time.Duration(config.MinioPresignExpireSeconds())*time.Second, url.Values{})
			if presignErr != nil {
				return presignErr
			}
			signed = u.String()
			return nil
		})
	})
	if err != nil {
		return "", err
	}
	return signed, nil
}

func PutObject(key string, reader io.Reader, size int64, contentType string) (string, string, error) {
	if key == "" {
		return "", "", fmt.Errorf("empty key")
	}
	client, err := getMinioClient()
	if err != nil {
		return "", "", err
	}
	if contentType == "" {
		contentType = "application/octet-stream"
	}
	err = minioBreaker.Execute(func() error {
		ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()
		_, putErr := client.PutObject(ctx, config.MinioBucket(), key, reader, size, minio.PutObjectOptions{
			ContentType: contentType,
		})
		return putErr
	})
	if err != nil {
		return "", "", err
	}
	url, err := ResolveObjectURL(key)
	if err != nil {
		return key, "", err
	}
	return key, url, nil
}
