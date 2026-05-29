package main

import (
	"MOOCHUB-server/cache"
	"MOOCHUB-server/config"
	"MOOCHUB-server/db"
	"MOOCHUB-server/global"
	"MOOCHUB-server/mq"
	"MOOCHUB-server/router"
	"MOOCHUB-server/workers"
	"flag"
	"os"

	"github.com/joho/godotenv"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

func main() {
	_ = godotenv.Load(".env", "secrets/qq.env")

	serviceAccount := flag.String("fcm-service-account", "", "path to FCM service account json")
	projectID := flag.String("fcm-project-id", "", "FCM project ID")
	flag.Parse()

	if *serviceAccount != "" {
		_ = os.Setenv("FCM_SERVICE_ACCOUNT", *serviceAccount)
	}
	if *projectID != "" {
		_ = os.Setenv("FCM_PROJECT_ID", *projectID)
	}

	if err := os.MkdirAll("logs", 0755); err != nil {
		panic("鏃犳硶鍒涘缓logs鐩綍: " + err.Error())
	}

	fileEncoderConfig := zap.NewProductionEncoderConfig()
	fileEncoderConfig.EncodeTime = zapcore.ISO8601TimeEncoder
	fileEncoder := zapcore.NewJSONEncoder(fileEncoderConfig)

	consoleEncoderConfig := zap.NewDevelopmentEncoderConfig()
	consoleEncoderConfig.EncodeTime = zapcore.ISO8601TimeEncoder
	consoleEncoderConfig.EncodeLevel = zapcore.CapitalColorLevelEncoder
	consoleEncoder := zapcore.NewConsoleEncoder(consoleEncoderConfig)

	infoFile, err := os.OpenFile("logs/app.log", os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		panic("鏃犳硶鍒濆鍖栨棩蹇楁枃浠? " + err.Error())
	}
	errorFile, err := os.OpenFile("logs/error.log", os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		panic("鏃犳硶鍒濆鍖栭敊璇棩蹇楁枃浠? " + err.Error())
	}

	infoLevel := zap.LevelEnablerFunc(func(lvl zapcore.Level) bool {
		return lvl < zapcore.ErrorLevel
	})
	errorLevel := zap.LevelEnablerFunc(func(lvl zapcore.Level) bool {
		return lvl >= zapcore.ErrorLevel
	})

	core := zapcore.NewTee(
		zapcore.NewCore(fileEncoder, zapcore.AddSync(infoFile), infoLevel),
		zapcore.NewCore(consoleEncoder, zapcore.AddSync(os.Stdout), infoLevel),
		zapcore.NewCore(fileEncoder, zapcore.AddSync(errorFile), errorLevel),
		zapcore.NewCore(consoleEncoder, zapcore.AddSync(os.Stderr), errorLevel),
	)

	logger := zap.New(core, zap.AddCaller())
	defer logger.Sync()

	global.Log = logger
	global.Log.Info("logger initialized",
		zap.Float64("access_sample_rate", config.LogAccessSampleRate()),
		zap.Duration("slow_threshold", config.LogSlowRequestThreshold()),
	)
	global.Log.Info("鏃ュ織绯荤粺宸插垵濮嬪寲")
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

	if err := db.InitSQL(); err != nil {
		global.Log.Fatal("SQL database init failed", zap.String("driver", config.DBDriver()), zap.Error(err))
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
	workers.StartEventAnalyticsWorker()
	workers.StartCacheWarmupWorker()
	workers.StartKnowledgeSyncWorker()

	r := router.Router()
	r.Run("0.0.0.0:3000")
}
