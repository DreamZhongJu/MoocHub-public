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

// InitMongo 建议在 main.go 里显式调用
func InitMongo() error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	clientOptions := options.Client().ApplyURI(config.MongoURI())

	client, err := mongo.Connect(ctx, clientOptions)
	if err != nil {
		return err
	}

	// 验证连通性
	if err := client.Ping(ctx, nil); err != nil {
		_ = client.Disconnect(context.Background())
		return err
	}

	MongoClient = client
	MongoDB = MongoClient.Database(config.MongoDBName())

	log.Println("MongoDB connected")
	return nil
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
