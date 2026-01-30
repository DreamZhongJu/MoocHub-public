package main

import (
	"os"

	"github.com/DreamZhongJu/next-shop/global"
	"github.com/DreamZhongJu/next-shop/router"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

func main() {
	// 创建logs目录
	if err := os.MkdirAll("logs", 0755); err != nil {
		panic("无法创建logs目录: " + err.Error())
	}
	// fmt.Println("当前服务器时间：", time.Now())
	// fmt.Println("当前时间戳：", time.Now().Unix())

	// 配置日志
	config := zap.NewProductionConfig()
	config.EncoderConfig.EncodeTime = zapcore.ISO8601TimeEncoder
	config.OutputPaths = []string{"logs/app.log", "stdout"} // 同时输出到文件和控制台
	config.ErrorOutputPaths = []string{"logs/error.log", "stderr"}

	logger, err := config.Build()
	if err != nil {
		panic("无法初始化日志: " + err.Error())
	}
	defer logger.Sync()

	global.Log = logger
	global.Log.Info("日志系统已初始化")

	r := router.Router()
	r.Run("0.0.0.0:8080")
}
