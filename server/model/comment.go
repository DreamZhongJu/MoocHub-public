package model

import (
	"MOOCHUB-server/db"
	"context"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo/options"
)

type Comment struct {
	ID         primitive.ObjectID  `bson:"_id,omitempty" json:"id"`
	TargetType string              `bson:"target_type" json:"target_type"`
	TargetID   int64               `bson:"target_id" json:"target_id"`
	UserID     int64               `bson:"user_id" json:"user_id"`
	Content    string              `bson:"content" json:"content"`
	LikeCount  int64               `bson:"like_count" json:"like_count"`
	Status     string              `bson:"status" json:"status"`
	CreatedAt  time.Time           `bson:"created_at" json:"created_at"`
	ParentID   *primitive.ObjectID `bson:"parent_id,omitempty" json:"parent_id,omitempty"`
}

func GetCommentsPaginated(targetType string, targetID int64, page int64, pageSize int64) ([]Comment, int64, error) {
	coll := db.GetCollection("comments")

	if page < 1 {
		page = 1
	}
	if pageSize < 1 {
		pageSize = 10
	}

	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
	defer cancel()

	filter := bson.D{
		{Key: "target_type", Value: targetType},
		{Key: "target_id", Value: targetID},
	}

	total, err := coll.CountDocuments(ctx, filter)
	if err != nil {
		return nil, 0, err
	}

	skip := (page - 1) * pageSize
	opts := options.Find().
		SetSkip(skip).
		SetLimit(pageSize).
		SetSort(bson.D{{Key: "created_at", Value: -1}})

	cur, err := coll.Find(ctx, filter, opts)
	if err != nil {
		return nil, 0, err
	}
	defer cur.Close(ctx)

	res := make([]Comment, 0, pageSize)
	if err := cur.All(ctx, &res); err != nil {
		return nil, 0, err
	}

	return res, total, nil
}

func CreateComment(targetType string, targetID int64, userID int64, content string) (Comment, error) {
	coll := db.GetCollection("comments")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	comment := Comment{
		ID:         primitive.NewObjectID(),
		TargetType: targetType,
		TargetID:   targetID,
		UserID:     userID,
		Content:    content,
		LikeCount:  0,
		Status:     "normal",
		CreatedAt:  time.Now(),
		ParentID:   nil,
	}

	_, err := coll.InsertOne(ctx, comment)
	if err != nil {
		return Comment{}, err
	}
	return comment, nil
}

func IncrementLike(commentID string) (int64, error) {
	coll := db.GetCollection("comments")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	oid, err := primitive.ObjectIDFromHex(commentID)
	if err != nil {
		return 0, err
	}

	res := coll.FindOneAndUpdate(
		ctx,
		bson.D{{Key: "_id", Value: oid}},
		bson.D{{Key: "$inc", Value: bson.D{{Key: "like_count", Value: 1}}}},
		options.FindOneAndUpdate().SetReturnDocument(options.After),
	)

	var updated Comment
	if err := res.Decode(&updated); err != nil {
		return 0, err
	}
	return updated.LikeCount, nil
}
