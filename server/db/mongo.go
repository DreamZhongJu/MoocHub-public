package db

import (
	"MOOCHUB-server/config"
	"context"
	"log"
	"time"

	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

var (
	MongoClient *mongo.Client
	MongoDB     *mongo.Database
)

// TAG 什么时候开启和关闭MongoDB的逻辑不完整，现在只能跑通
// InitMongo 建议在 main.go 里显式调用，避免 init 顺序问题
func init() {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	clientOptions := options.Client().ApplyURI(config.Mongodb)

	client, err := mongo.Connect(ctx, clientOptions)
	if err != nil {
		log.Fatalf("InitMongo failed: %v", err)
	}

	// 验证连通性
	if err := client.Ping(ctx, nil); err != nil {
		_ = client.Disconnect(context.Background())
		log.Fatalf("InitMongo failed: %v", err)
	}

	MongoClient = client
	MongoDB = MongoClient.Database("knowhub")

	log.Println("MongoDB connected")
}

func CloseMongo() {
	if MongoClient == nil {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := MongoClient.Disconnect(ctx); err != nil {
		log.Println("MongoDB disconnect error:", err)
		return
	}
	log.Println("MongoDB disconnected")
}

func GetMongoDB() *mongo.Database {
	return MongoDB
}

func GetCollection(name string) *mongo.Collection {
	return MongoDB.Collection(name)
}
