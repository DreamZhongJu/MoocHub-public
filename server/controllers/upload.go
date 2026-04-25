package controllers

import (
	"MOOCHUB-server/config"
	"MOOCHUB-server/global"
	"MOOCHUB-server/storage"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

type UploadController struct{}

func (uc UploadController) Upload(c *gin.Context) {
	file, err := c.FormFile("file")
	if err != nil {
		ReturnError(c, 400, "缺少文件")
		return
	}

	dir := strings.TrimSpace(c.DefaultPostForm("dir", "articles"))
	if dir == "" {
		dir = "articles"
	}
	dir = strings.Trim(dir, "/")

	if isVideoDir(dir) {
		role := strings.ToLower(strings.TrimSpace(c.GetString("user_role")))
		if role != "admin" && role != "teacher" {
			ReturnError(c, 403, "only teacher/admin can upload video files")
			return
		}
	}

	ext := filepath.Ext(file.Filename)
	if ext == "" {
		ext = ".bin"
	}

	key := buildObjectKey(dir, ext)
	src, err := file.Open()
	if err != nil {
		ReturnError(c, 500, "读取文件失败："+err.Error())
		return
	}
	defer src.Close()

	contentType := file.Header.Get("Content-Type")
	_, url, err := storage.PutObject(key, src, file.Size, contentType)
	if err != nil {
		ReturnError(c, 500, "上传失败："+err.Error())
		return
	}

	ReturnSuccess(c, 200, "上传成功", gin.H{
		"key": key,
		"url": url,
	}, 0)
}

func buildObjectKey(dir, ext string) string {
	now := time.Now()
	buf := make([]byte, 6)
	_, _ = rand.Read(buf)
	suffix := hex.EncodeToString(buf)
	return strings.Trim(dir, "/") + "/" + now.Format("20060102") + "/" + now.Format("150405") + "_" + suffix + ext
}

func isVideoDir(dir string) bool {
	return dir == "videos" || strings.HasPrefix(dir, "videos/")
}

// ServeUpload 优先读取本地 uploads 目录；不存在时回退到 MinIO 对象。
func (uc UploadController) ServeUpload(c *gin.Context) {
	objectPath := strings.TrimPrefix(c.Param("filepath"), "/")
	if objectPath == "" {
		c.Status(404)
		return
	}

	localPath := filepath.Join("uploads", filepath.FromSlash(objectPath))
	if stat, err := os.Stat(localPath); err == nil && !stat.IsDir() {
		c.File(localPath)
		return
	}

	if dataDir := strings.TrimSpace(config.MinioDataDir()); dataDir != "" {
		minioDiskPath := filepath.Join(dataDir, config.MinioBucket(), filepath.FromSlash(objectPath))
		if stat, err := os.Stat(minioDiskPath); err == nil && !stat.IsDir() {
			c.File(minioDiskPath)
			return
		}
	}

	obj, err := storage.OpenObjectForRead(objectPath, c.GetHeader("Range"))
	if err == nil && obj != nil {
		defer obj.Reader.Close()
		headers := map[string]string{
			"Accept-Ranges": "bytes",
		}
		status := http.StatusOK
		if obj.Partial {
			status = http.StatusPartialContent
			headers["Content-Range"] = fmt.Sprintf("bytes %d-%d/%d", obj.Start, obj.End, obj.TotalSize)
		}
		c.DataFromReader(status, obj.Size, obj.ContentType, obj.Reader, headers)
		return
	}
	if err != nil {
		global.Log.Warn("ServeUpload: read MinIO object failed", zap.String("path", objectPath), zap.Error(err))
	}

	url, resolveErr := storage.ResolveObjectURL(objectPath)
	if resolveErr != nil || strings.TrimSpace(url) == "" {
		if resolveErr != nil {
			global.Log.Warn("ServeUpload: resolve object URL failed", zap.String("path", objectPath), zap.Error(resolveErr))
		}
		c.Status(404)
		return
	}
	c.Redirect(302, url)
}
