package storage

import (
	"MOOCHUB-server/config"
	"MOOCHUB-server/resilience"
	"MOOCHUB-server/utils"
	"context"
	"fmt"
	"io"
	"net"
	"net/url"
	"strconv"
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

type ObjectReadResult struct {
	Reader      io.ReadCloser
	Size        int64
	TotalSize   int64
	ContentType string
	Start       int64
	End         int64
	Partial     bool
}

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

func ResolveClientObjectURL(raw string) (string, error) {
	if raw == "" {
		return "", nil
	}
	if strings.HasPrefix(raw, "minio://") {
		_, key := parseObjectKey(raw)
		if key == "" {
			return "", nil
		}
		return "/uploads/" + strings.TrimLeft(key, "/"), nil
	}
	if strings.HasPrefix(raw, "/uploads/") {
		return raw, nil
	}
	if strings.HasPrefix(raw, "uploads/") {
		return "/" + raw, nil
	}
	if strings.HasPrefix(raw, "http://") || strings.HasPrefix(raw, "https://") {
		u, err := url.Parse(raw)
		if err != nil {
			return raw, nil
		}
		path := strings.TrimPrefix(u.Path, "/")
		bucket := config.MinioBucket()
		if strings.HasPrefix(path, bucket+"/") {
			key := strings.TrimPrefix(path, bucket+"/")
			return "/uploads/" + strings.TrimLeft(key, "/"), nil
		}
		if strings.HasPrefix(u.Path, "/uploads/") {
			return u.Path, nil
		}
		return raw, nil
	}
	return "/uploads/" + strings.TrimLeft(raw, "/"), nil
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
		return buildMinioObjectURL(bucket, key), nil
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

func OpenObjectForRead(raw string, rangeHeader string) (*ObjectReadResult, error) {
	if raw == "" {
		return nil, fmt.Errorf("empty object key")
	}
	bucket, key := parseObjectKey(raw)
	client, err := getMinioClient()
	if err != nil {
		return nil, err
	}

	statCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	info, err := client.StatObject(statCtx, bucket, key, minio.StatObjectOptions{})
	if err != nil {
		return nil, err
	}

	start, end, partial, err := parseHTTPRange(rangeHeader, info.Size)
	if err != nil {
		return nil, err
	}

	opts := minio.GetObjectOptions{}
	if partial {
		if err := opts.SetRange(start, end); err != nil {
			return nil, err
		}
	}

	obj, err := client.GetObject(context.Background(), bucket, key, opts)
	if err != nil {
		return nil, err
	}

	readSize := info.Size
	if partial {
		readSize = end - start + 1
	} else {
		start = 0
		end = info.Size - 1
	}
	contentType := info.ContentType
	if contentType == "" {
		contentType = "application/octet-stream"
	}
	return &ObjectReadResult{
		Reader:      obj,
		Size:        readSize,
		TotalSize:   info.Size,
		ContentType: contentType,
		Start:       start,
		End:         end,
		Partial:     partial,
	}, nil
}

func parseHTTPRange(header string, size int64) (int64, int64, bool, error) {
	header = strings.TrimSpace(header)
	if header == "" {
		return 0, size - 1, false, nil
	}
	if size <= 0 {
		return 0, 0, false, fmt.Errorf("invalid object size")
	}
	if !strings.HasPrefix(header, "bytes=") {
		return 0, size - 1, false, nil
	}
	spec := strings.TrimSpace(strings.TrimPrefix(header, "bytes="))
	if strings.Contains(spec, ",") {
		spec = strings.TrimSpace(strings.Split(spec, ",")[0])
	}
	parts := strings.SplitN(spec, "-", 2)
	if len(parts) != 2 {
		return 0, 0, false, fmt.Errorf("invalid range")
	}

	var start, end int64
	var err error
	if parts[0] == "" {
		suffix, parseErr := strconv.ParseInt(parts[1], 10, 64)
		if parseErr != nil || suffix <= 0 {
			return 0, 0, false, fmt.Errorf("invalid suffix range")
		}
		if suffix > size {
			suffix = size
		}
		start = size - suffix
		end = size - 1
		return start, end, true, nil
	}

	start, err = strconv.ParseInt(parts[0], 10, 64)
	if err != nil || start < 0 {
		return 0, 0, false, fmt.Errorf("invalid range start")
	}
	if parts[1] == "" {
		end = size - 1
	} else {
		end, err = strconv.ParseInt(parts[1], 10, 64)
		if err != nil {
			return 0, 0, false, fmt.Errorf("invalid range end")
		}
	}
	if start >= size {
		return 0, 0, false, fmt.Errorf("range start out of bounds")
	}
	if end >= size {
		end = size - 1
	}
	if end < start {
		return 0, 0, false, fmt.Errorf("invalid range order")
	}
	return start, end, true, nil
}

func buildMinioObjectURL(bucket, key string) string {
	endpoint := strings.TrimSpace(config.MinioEndpoint())
	if endpoint == "" {
		return fmt.Sprintf("/%s/%s", bucket, key)
	}
	if strings.HasPrefix(endpoint, "http://") || strings.HasPrefix(endpoint, "https://") {
		return strings.TrimRight(endpoint, "/") + "/" + bucket + "/" + strings.TrimLeft(key, "/")
	}
	scheme := "http"
	if config.MinioSecure() {
		scheme = "https"
	}
	hostPort := endpoint
	if host, _, err := net.SplitHostPort(endpoint); err == nil && (host == "" || host == "0.0.0.0") {
		hostPort = "127.0.0.1:" + strings.Split(endpoint, ":")[1]
	}
	return scheme + "://" + strings.TrimRight(hostPort, "/") + "/" + bucket + "/" + strings.TrimLeft(key, "/")
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
	clientURL, _ := ResolveClientObjectURL(key)
	return key, clientURL, nil
}
