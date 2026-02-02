package main

import (
	"MOOCHUB-server/db"
	"MOOCHUB-server/global"
	"MOOCHUB-server/router"
	"os"

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

	// 配置日志（按级别拆分）
	encoderConfig := zap.NewProductionEncoderConfig()
	encoderConfig.EncodeTime = zapcore.ISO8601TimeEncoder
	encoder := zapcore.NewJSONEncoder(encoderConfig)

	infoFile, err := os.OpenFile("logs/app.log", os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		panic("无法初始化日志文件: " + err.Error())
	}
	errorFile, err := os.OpenFile("logs/error.log", os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		panic("无法初始化错误日志文件: " + err.Error())
	}

	infoLevel := zap.LevelEnablerFunc(func(lvl zapcore.Level) bool {
		return lvl < zapcore.ErrorLevel
	})
	errorLevel := zap.LevelEnablerFunc(func(lvl zapcore.Level) bool {
		return lvl >= zapcore.ErrorLevel
	})

	core := zapcore.NewTee(
		zapcore.NewCore(encoder, zapcore.AddSync(infoFile), infoLevel),
		zapcore.NewCore(encoder, zapcore.AddSync(os.Stdout), infoLevel),
		zapcore.NewCore(encoder, zapcore.AddSync(errorFile), errorLevel),
		zapcore.NewCore(encoder, zapcore.AddSync(os.Stderr), errorLevel),
	)

	logger := zap.New(core, zap.AddCaller())
	defer logger.Sync()

	global.Log = logger
	global.Log.Info("日志系统已初始化")

	if err := db.InitMySQL(); err != nil {
		global.Log.Fatal("MySQL init failed", zap.Error(err))
	}
	if err := db.InitMongo(); err != nil {
		global.Log.Fatal("MongoDB init failed", zap.Error(err))
	}
	defer db.CloseMongo()

	r := router.Router()
	r.Run("0.0.0.0:3000")
}
