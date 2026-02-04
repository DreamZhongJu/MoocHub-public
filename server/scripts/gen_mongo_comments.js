const fs = require("fs");
const path = require("path");

// Usage:
// node scripts/gen_mongo_comments.js mongo_seed_comments.csv

const courseIds = [
  ...Array.from({ length: 9 }, (_, i) => i + 1),
  ...Array.from({ length: 500 }, (_, i) => 1000 + i),
];
const videoIds = [
  ...Array.from({ length: 4 }, (_, i) => i + 1),
  ...Array.from({ length: 996 }, (_, i) => 10000 + i),
];
const userIds = [1, 2, 3, 4, 5, 6];

const commentsPerCourse = 6;
const commentsPerVideo = 4;

let userIndex = 0;
const commentTemplates = [
  "这节课讲得很清楚，重点很明确。",
  "案例很贴近实际，学完能直接上手。",
  "节奏刚好，建议再补充一点练习题。",
  "讲师讲解很细，适合零基础。",
  "重点知识点总结得不错，复习方便。",
  "内容有深度但不晦涩，体验很好。",
  "课程结构清晰，学习路线明了。",
  "如果能加配套资料就更好了。",
  "实例讲解很实用，收藏了。",
  "希望后续更新更多进阶内容。",
];
function nextUserId() {
  const id = userIds[userIndex % userIds.length];
  userIndex += 1;
  return id;
}

function makeComment(targetType, targetId, index) {
  const userId = nextUserId();
  const likeCount = Math.floor(Math.random() * 8);
  const createdAt = new Date(Date.now() - Math.floor(Math.random() * 14) * 86400000);
  const template = commentTemplates[Math.floor(Math.random() * commentTemplates.length)];
  const content = `${targetType}#${targetId} 评论 ${index + 1}：${template}`;
  return {
    target_type: targetType,
    target_id: `NumberLong("${targetId}")`,
    user_id: `NumberLong("${userId}")`,
    content,
    like_count: `NumberLong("${likeCount}")`,
    status: "normal",
    created_at: `ISODate("${createdAt.toISOString()}")`,
    parent_id: null,
  };
}

const docs = [];
courseIds.forEach((id) => {
  for (let i = 0; i < commentsPerCourse; i += 1) {
    docs.push(makeComment("course", id, i));
  }
});
videoIds.forEach((id) => {
  for (let i = 0; i < commentsPerVideo; i += 1) {
    docs.push(makeComment("video", id, i));
  }
});

function renderDoc(doc) {
  return `{
  target_type: "${doc.target_type}",
  target_id: ${doc.target_id},
  user_id: ${doc.user_id},
  content: "${doc.content}",
  like_count: ${doc.like_count},
  status: "${doc.status}",
  created_at: ${doc.created_at},
  parent_id: null
}`;
}

const outPath = process.argv[2];
const csvHeader = [
  "target_type",
  "target_id",
  "user_id",
  "content",
  "like_count",
  "status",
  "created_at",
  "parent_id",
].join(",");

function csvEscape(value) {
  const str = value == null ? "" : String(value);
  if (str.includes('"') || str.includes(",") || str.includes("\n")) {
    return `"${str.replace(/"/g, '""')}"`;
  }
  return str;
}

const rows = docs.map((d) =>
  [
    d.target_type,
    d.target_id.replace(/NumberLong\("(\d+)"\)/, "$1"),
    d.user_id.replace(/NumberLong\("(\d+)"\)/, "$1"),
    d.content,
    d.like_count.replace(/NumberLong\("(\d+)"\)/, "$1"),
    d.status,
    d.created_at.replace(/ISODate\("([^"]+)"\)/, "$1"),
    "",
  ]
    .map(csvEscape)
    .join(",")
);

const content = [csvHeader, ...rows].join("\n");

if (!outPath) {
  process.stdout.write("Please provide output path, e.g. mongo_seed_comments.csv\n");
  process.exit(1);
}

fs.writeFileSync(outPath, content, { encoding: "utf8" });
process.stdout.write(`Wrote ${docs.length} comments to ${outPath}\n`);
