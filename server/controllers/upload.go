package controllers

import (
	"MOOCHUB-server/storage"
	"crypto/rand"
	"encoding/hex"
	"path/filepath"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
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
