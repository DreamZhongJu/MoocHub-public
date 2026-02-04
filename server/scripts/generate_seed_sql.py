import argparse
import random
from datetime import datetime, timedelta
from pathlib import Path
from typing import List, Optional, Tuple


DEFAULT_COVER_URL = "http://127.0.0.1:3000/uploads/thumbs/demo.png"
DEFAULT_VIDEO_URL = "http://127.0.0.1:3000/uploads/videos/demo.mp4"
DEFAULT_THUMB_URL = "http://127.0.0.1:3000/uploads/thumbs/demo.png"

LEVELS = ["初级", "中级", "高级"]
TITLE_MODIFIERS = ["入门", "进阶", "实战", "精讲", "速成", "深度"]
TOPICS = [
    "Python",
    "Java",
    "Go",
    "JavaScript",
    "Flutter",
    "Spring Boot",
    "Gin",
    "算法",
    "数据结构",
    "数据库",
    "前端工程化",
    "后端架构",
    "机器学习",
    "深度学习",
    "AI 应用",
    "网络基础",
    "Linux 运维",
]
INSTRUCTOR_PREFIXES = ["讲师", "导师", "老师", "Professor", "Instructor"]
INSTRUCTOR_NAMES = [
    "Alex",
    "Mia",
    "Leo",
    "Nina",
    "Kai",
    "Ivy",
    "Liam",
    "Zoe",
    "Evan",
    "Sora",
    "Yuki",
    "Noah",
    "Aria",
]
SUMMARY_TEMPLATES = [
    "围绕 {topic} 构建知识体系，覆盖 {focus1} 与 {focus2}。",
    "系统讲解 {topic}，从 {focus1} 到 {focus2}，循序渐进。",
    "以真实案例带你掌握 {topic}，重点突破 {focus1} 与 {focus2}。",
    "{topic} 核心路线课程，强调 {focus1}、{focus2} 的实践。",
    "用最短路径理解 {topic}，聚焦 {focus1} 与 {focus2}。",
]
FOCUS_AREAS = [
    "基础语法",
    "核心概念",
    "工程实践",
    "性能优化",
    "项目实战",
    "常见模式",
    "架构设计",
    "调试技巧",
    "开发工具",
    "部署流程",
]


def sql_escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace("'", "''")


def parse_int_list(text: str) -> List[int]:
    return [int(x.strip()) for x in text.split(",") if x.strip()]


def parse_range(text: str) -> Tuple[int, int]:
    parts = [p.strip() for p in text.split("-")]
    if len(parts) != 2:
        raise ValueError("Range must be in MIN-MAX format.")
    min_value, max_value = int(parts[0]), int(parts[1])
    if min_value > max_value:
        raise ValueError("Range MIN must be <= MAX.")
    return min_value, max_value


def random_summary(topic: str, rng: random.Random) -> str:
    focus1, focus2 = rng.sample(FOCUS_AREAS, 2)
    template = rng.choice(SUMMARY_TEMPLATES)
    return template.format(topic=topic, focus1=focus1, focus2=focus2)


def random_instructor(rng: random.Random) -> str:
    prefix = rng.choice(INSTRUCTOR_PREFIXES)
    name = rng.choice(INSTRUCTOR_NAMES)
    suffix = rng.randint(1, 99)
    return f"{prefix}{name}{suffix}"


def random_title(topic: str, index: int, rng: random.Random) -> str:
    modifier = rng.choice(TITLE_MODIFIERS)
    return f"{topic} {modifier} 第{index}期"


def random_video_title(topic: str, order: int) -> str:
    return f"第{order}讲 {topic}"


def random_datetime(base: datetime, rng: random.Random) -> datetime:
    delta_days = rng.randint(0, 365)
    delta_seconds = rng.randint(0, 24 * 3600 - 1)
    return base - timedelta(days=delta_days, seconds=delta_seconds)


def build_courses(
    count: int,
    category_ids: List[int],
    course_id_start: int,
    cover_url: str,
    rng: random.Random,
) -> List[dict]:
    courses = []
    base_time = datetime.now()
    for i in range(count):
        topic = rng.choice(TOPICS)
        course_id = course_id_start + i
        level = rng.choice(LEVELS)
        view_count = rng.randint(0, 50000)
        favorite_count = rng.randint(0, max(0, view_count // 10))
        created_at = random_datetime(base_time, rng)
        updated_at = created_at + timedelta(minutes=rng.randint(0, 1200))
        courses.append(
            {
                "id": course_id,
                "category_id": rng.choice(category_ids),
                "title": random_title(topic, course_id, rng),
                "summary": random_summary(topic, rng),
                "cover_url": cover_url,
                "instructor_name": random_instructor(rng),
                "level": level,
                "status": "published",
                "view_count": view_count,
                "favorite_count": favorite_count,
                "created_at": created_at,
                "updated_at": updated_at,
                "topic": topic,
            }
        )
    return courses


def build_videos(
    courses: List[dict],
    video_id_start: int,
    videos_per_course: Optional[int],
    videos_per_course_range: Optional[Tuple[int, int]],
    video_url: str,
    thumb_url: str,
    rng: random.Random,
) -> List[dict]:
    videos = []
    current_video_id = video_id_start
    for course in courses:
        if videos_per_course is not None:
            count = videos_per_course
        else:
            min_count, max_count = videos_per_course_range or (3, 8)
            count = rng.randint(min_count, max_count)
        for order in range(1, count + 1):
            duration_sec = rng.randint(300, 3600)
            created_at = random_datetime(datetime.now(), rng)
            videos.append(
                {
                    "id": current_video_id,
                    "course_id": course["id"],
                    "title": random_video_title(course["topic"], order),
                    "description": random_summary(course["topic"], rng),
                    "duration_sec": duration_sec,
                    "video_url": video_url,
                    "thumb_url": thumb_url,
                    "sort_order": order,
                    "created_at": created_at,
                }
            )
            current_video_id += 1
    return videos


def format_datetime(value: datetime) -> str:
    return value.strftime("%Y-%m-%d %H:%M:%S")


def write_sql(
    output_path: Path,
    courses: list[dict],
    videos: list[dict],
    include_timestamps: bool,
) -> None:
    lines: List[str] = []
    lines.append("SET NAMES utf8mb4;")
    lines.append("SET FOREIGN_KEY_CHECKS = 0;")
    lines.append("")

    if courses:
        course_columns = [
            "id",
            "category_id",
            "title",
            "summary",
            "cover_url",
            "instructor_name",
            "level",
            "status",
            "view_count",
            "favorite_count",
        ]
        if include_timestamps:
            course_columns.extend(["created_at", "updated_at"])
        columns_sql = ", ".join(course_columns)
        lines.append(f"INSERT INTO `courses` ({columns_sql}) VALUES")
        values_sql = []
        for course in courses:
            values = [
                str(course["id"]),
                str(course["category_id"]),
                f"'{sql_escape(course['title'])}'",
                f"'{sql_escape(course['summary'])}'",
                f"'{sql_escape(course['cover_url'])}'",
                f"'{sql_escape(course['instructor_name'])}'",
                f"'{sql_escape(course['level'])}'",
                f"'{sql_escape(course['status'])}'",
                str(course["view_count"]),
                str(course["favorite_count"]),
            ]
            if include_timestamps:
                values.append(f"'{format_datetime(course['created_at'])}'")
                values.append(f"'{format_datetime(course['updated_at'])}'")
            values_sql.append(f"({', '.join(values)})")
        lines.append(",\n".join(values_sql) + ";")
        lines.append("")

    if videos:
        video_columns = [
            "id",
            "course_id",
            "title",
            "description",
            "duration_sec",
            "video_url",
            "thumb_url",
            "sort_order",
        ]
        if include_timestamps:
            video_columns.append("created_at")
        columns_sql = ", ".join(video_columns)
        lines.append(f"INSERT INTO `videos` ({columns_sql}) VALUES")
        values_sql = []
        for video in videos:
            values = [
                str(video["id"]),
                str(video["course_id"]),
                f"'{sql_escape(video['title'])}'",
                f"'{sql_escape(video['description'])}'",
                str(video["duration_sec"]),
                f"'{sql_escape(video['video_url'])}'",
                f"'{sql_escape(video['thumb_url'])}'",
                str(video["sort_order"]),
            ]
            if include_timestamps:
                values.append(f"'{format_datetime(video['created_at'])}'")
            values_sql.append(f"({', '.join(values)})")
        lines.append(",\n".join(values_sql) + ";")
        lines.append("")

    lines.append("SET FOREIGN_KEY_CHECKS = 1;")
    output_path.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate seed SQL for courses and videos tables."
    )
    parser.add_argument("--courses", type=int, default=100, help="Number of courses.")
    parser.add_argument(
        "--category-ids",
        type=str,
        default="1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17",
        help="Comma-separated list of category ids.",
    )
    parser.add_argument(
        "--course-id-start",
        type=int,
        default=1000,
        help="Starting course id to avoid collisions.",
    )
    parser.add_argument(
        "--video-id-start",
        type=int,
        default=10000,
        help="Starting video id to avoid collisions.",
    )
    parser.add_argument(
        "--videos-per-course",
        type=int,
        default=None,
        help="Fixed number of videos per course (overrides range).",
    )
    parser.add_argument(
        "--videos-per-course-range",
        type=str,
        default="3-8",
        help="Range for videos per course, format MIN-MAX.",
    )
    parser.add_argument(
        "--cover-url",
        type=str,
        default=DEFAULT_COVER_URL,
        help="Cover image URL for courses.",
    )
    parser.add_argument(
        "--video-url",
        type=str,
        default=DEFAULT_VIDEO_URL,
        help="Video URL for videos.",
    )
    parser.add_argument(
        "--thumb-url",
        type=str,
        default=DEFAULT_THUMB_URL,
        help="Thumbnail URL for videos.",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=42,
        help="Random seed for reproducible output.",
    )
    parser.add_argument(
        "--include-timestamps",
        action="store_true",
        help="Include created_at / updated_at fields in SQL.",
    )
    parser.add_argument(
        "--output",
        type=str,
        default="server/scripts/seed_courses_videos.sql",
        help="Output SQL file path.",
    )

    args = parser.parse_args()
    rng = random.Random(args.seed)
    category_ids = parse_int_list(args.category_ids)
    if not category_ids:
        raise ValueError("category-ids cannot be empty.")
    videos_range = parse_range(args.videos_per_course_range)
    output_path = Path(args.output)

    courses = build_courses(
        count=args.courses,
        category_ids=category_ids,
        course_id_start=args.course_id_start,
        cover_url=args.cover_url,
        rng=rng,
    )
    videos = build_videos(
        courses=courses,
        video_id_start=args.video_id_start,
        videos_per_course=args.videos_per_course,
        videos_per_course_range=videos_range,
        video_url=args.video_url,
        thumb_url=args.thumb_url,
        rng=rng,
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    write_sql(output_path, courses, videos, args.include_timestamps)


if __name__ == "__main__":
    main()
