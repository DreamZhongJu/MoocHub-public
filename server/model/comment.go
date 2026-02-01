package model

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
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

//测试接口
// // GetCommentsLatestN 获取最新 N 条评论（你的“获取10个评论测试接口”就调用它）
// func GetCommentsLatestN(n int64) ([]Comment, error) {
// 	coll := db.GetCollection("comments")

// 	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
// 	defer cancel()

// 	opts := options.Find().
// 		SetLimit(n).
// 		SetSort(bson.D{{Key: "created_at", Value: -1}})

// 	cur, err := coll.Find(ctx, bson.D{}, opts)
// 	if err != nil {
// 		return nil, err
// 	}
// 	defer cur.Close(ctx)

// 	res := make([]Comment, 0, n)
// 	if err := cur.All(ctx, &res); err != nil {
// 		return nil, err
// 	}
// 	return res, nil
// }

// // GetCommentsPaginated 获取分页评论列表 + 总数
// // page 从 1 开始；pageSize 建议 10/20/50
// func GetCommentsPaginated(page int64, pageSize int64) ([]Comment, int64, error) {
// 	coll := db.GetCollection("comments")

// 	if page < 1 {
// 		page = 1
// 	}
// 	if pageSize < 1 {
// 		pageSize = 10
// 	}

// 	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
// 	defer cancel()

// 	filter := bson.D{} // 如需加过滤条件可在这里扩展

// 	total, err := coll.CountDocuments(ctx, filter)
// 	if err != nil {
// 		return nil, 0, err
// 	}

// 	skip := (page - 1) * pageSize
// 	opts := options.Find().
// 		SetSkip(skip).
// 		SetLimit(pageSize).
// 		SetSort(bson.D{{Key: "created_at", Value: -1}})

// 	cur, err := coll.Find(ctx, filter, opts)
// 	if err != nil {
// 		return nil, 0, err
// 	}
// 	defer cur.Close(ctx)

// 	res := make([]Comment, 0, pageSize)
// 	if err := cur.All(ctx, &res); err != nil {
// 		return nil, 0, err
// 	}

// 	return res, total, nil
// }
