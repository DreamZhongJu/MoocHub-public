// 选择数据库
use knowhub;

// 1) comments
// 建议开启 validator，MVP 阶段如果嫌麻烦可以后面用 collMod 再加
db.createCollection("comments", {
    validator: {
        $jsonSchema: {
            bsonType: "object",
            required: ["target_type", "target_id", "user_id", "content", "like_count", "status", "created_at"],
            properties: {
                target_type: { enum: ["course", "video"] },
                target_id: { bsonType: ["int", "long", "string"] },   // MySQL ID，按你实际存储类型选
                user_id: { bsonType: ["int", "long", "string"] },     // MySQL users.id
                content: { bsonType: "string", minLength: 1, maxLength: 5000 },
                like_count: { bsonType: "int", minimum: 0 },
                status: { bsonType: "string" },                       // 例如 normal/hidden/deleted，具体枚举你也可再收紧
                created_at: { bsonType: "date" },
                parent_id: { bsonType: ["objectId", "null"] }         // 回复用，可空
            }
        }
    }
});

// 索引： (target_type, target_id, created_at) 与 user_id
db.comments.createIndex(
    { target_type: 1, target_id: 1, created_at: -1 },
    { name: "idx_target_createdAt" }
);

db.comments.createIndex(
    { user_id: 1 },
    { name: "idx_user_id" }
);

// 2) video_thumbnails
db.createCollection("video_thumbnails", {
    validator: {
        $jsonSchema: {
            bsonType: "object",
            required: ["video_id", "url", "width", "height", "format", "size_bytes", "created_at"],
            properties: {
                video_id: { bsonType: ["int", "long", "string"] },    // MySQL videos.id
                url: { bsonType: "string", minLength: 1, maxLength: 2048 },
                width: { bsonType: "int", minimum: 1 },
                height: { bsonType: "int", minimum: 1 },
                format: { bsonType: "string" },                       // jpg/png/webp 等
                size_bytes: { bsonType: ["int", "long"], minimum: 0 },
                created_at: { bsonType: "date" }
            }
        }
    }
});

// 索引：video_id 唯一
db.video_thumbnails.createIndex(
    { video_id: 1 },
    { unique: true, name: "uniq_video_id" }
);

// 3) recommend_events（后期扩展）
db.createCollection("recommend_events", {
    validator: {
        $jsonSchema: {
            bsonType: "object",
            required: ["user_id", "video_id", "event_type", "created_at"],
            properties: {
                user_id: { bsonType: ["int", "long", "string"] },
                video_id: { bsonType: ["int", "long", "string"] },
                event_type: { enum: ["exposure", "click", "play"] },
                created_at: { bsonType: "date" }
            }
        }
    }
});

// 索引：(user_id, created_at)，(video_id, created_at)
db.recommend_events.createIndex(
    { user_id: 1, created_at: -1 },
    { name: "idx_user_createdAt" }
);

db.recommend_events.createIndex(
    { video_id: 1, created_at: -1 },
    { name: "idx_video_createdAt" }
);

// 示例数据（少量）
// comments
db.comments.insertMany([
    {
        target_type: "course",
        target_id: 101,
        user_id: 1,
        content: "这门课的章节安排很清晰，建议加点练习题。",
        like_count: 3,
        status: "normal",
        created_at: new Date(),
        parent_id: null
    },
    {
        target_type: "video",
        target_id: 2001,
        user_id: 2,
        content: "这一节讲得很细，收藏了。",
        like_count: 8,
        status: "normal",
        created_at: new Date(),
        parent_id: null
    }
]);

// video_thumbnails
db.video_thumbnails.insertMany([
    {
        video_id: 2001,
        url: "https://cdn.example.com/thumbs/2001_480w.webp",
        width: 480,
        height: 270,
        format: "webp",
        size_bytes: 34567,
        created_at: new Date()
    }
]);

// recommend_events
db.recommend_events.insertMany([
    { user_id: 1, video_id: 2001, event_type: "exposure", created_at: new Date() },
    { user_id: 1, video_id: 2001, event_type: "click", created_at: new Date() }
]);

// 查看索引是否创建成功
db.comments.getIndexes();
db.video_thumbnails.getIndexes();
db.recommend_events.getIndexes();
