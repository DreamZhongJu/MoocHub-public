package main

import (
	"MOOCHUB-server/cache"
	"MOOCHUB-server/config"
	"MOOCHUB-server/db"
	"MOOCHUB-server/global"
	"MOOCHUB-server/mq"
	"MOOCHUB-server/router"
	"MOOCHUB-server/workers"
	"os"

	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

func main() {
	if err := os.MkdirAll("logs", 0755); err != nil {
		panic("无法创建logs目录: " + err.Error())
	}

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
	global.Log.Info("MinIO config loaded",
		zap.String("endpoint", config.MinioEndpoint()),
		zap.String("bucket", config.MinioBucket()),
		zap.Bool("secure", config.MinioSecure()),
		zap.Bool("use_presign", config.MinioUsePresign()),
		zap.Int64("presign_expire", config.MinioPresignExpireSeconds()),
	)
	global.Log.Info("Redis config loaded",
		zap.String("addr", config.RedisAddr()),
		zap.Int("db", config.RedisDB()),
	)
	global.Log.Info("RabbitMQ config loaded",
		zap.String("url", config.RabbitMQURL()),
	)

	if err := db.InitMySQL(); err != nil {
		global.Log.Fatal("MySQL init failed", zap.Error(err))
	}
	if err := db.InitMongo(); err != nil {
		global.Log.Fatal("MongoDB init failed", zap.Error(err))
	}
	defer db.CloseMongo()

	if err := cache.InitRedis(); err != nil {
		global.Log.Fatal("Redis init failed", zap.Error(err))
	}
	defer cache.CloseRedis()

	if err := mq.InitRabbitMQ(); err != nil {
		global.Log.Fatal("RabbitMQ init failed", zap.Error(err))
	}
	defer mq.CloseRabbitMQ()

	workers.StartProgressWorker()
	workers.StartPlayWorker()

	r := router.Router()
	r.Run("0.0.0.0:3000")
}
