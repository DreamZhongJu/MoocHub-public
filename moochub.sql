/*
 Navicat Premium Dump SQL

 Source Server         : root
 Source Server Type    : MySQL
 Source Server Version : 80038 (8.0.38)
 Source Host           : localhost:3306
 Source Schema         : moochub

 Target Server Type    : MySQL
 Target Server Version : 80038 (8.0.38)
 File Encoding         : 65001

 Date: 31/01/2026 14:56:29
*/

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- Table structure for course_categories
-- ----------------------------
DROP TABLE IF EXISTS `course_categories`;
CREATE TABLE `course_categories`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `parent_id` bigint UNSIGNED NULL DEFAULT NULL,
  `sort_order` int NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_course_categories_parent_id`(`parent_id` ASC) USING BTREE,
  CONSTRAINT `fk_course_categories_parent` FOREIGN KEY (`parent_id`) REFERENCES `course_categories` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 18 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of course_categories
-- ----------------------------
INSERT INTO `course_categories` VALUES (1, '计算机基础', NULL, 1);
INSERT INTO `course_categories` VALUES (2, '编程语言', NULL, 2);
INSERT INTO `course_categories` VALUES (3, '前端开发', NULL, 3);
INSERT INTO `course_categories` VALUES (4, '后端开发', NULL, 4);
INSERT INTO `course_categories` VALUES (5, '人工智能', NULL, 5);
INSERT INTO `course_categories` VALUES (6, '数据结构与算法', 1, 1);
INSERT INTO `course_categories` VALUES (7, '操作系统', 1, 2);
INSERT INTO `course_categories` VALUES (8, 'Python', 2, 1);
INSERT INTO `course_categories` VALUES (9, 'Java', 2, 2);
INSERT INTO `course_categories` VALUES (10, 'Go', 2, 3);
INSERT INTO `course_categories` VALUES (11, 'HTML/CSS', 3, 1);
INSERT INTO `course_categories` VALUES (12, 'JavaScript', 3, 2);
INSERT INTO `course_categories` VALUES (13, 'Flutter', 3, 3);
INSERT INTO `course_categories` VALUES (14, 'Spring Boot', 4, 1);
INSERT INTO `course_categories` VALUES (15, 'Gin', 4, 2);
INSERT INTO `course_categories` VALUES (16, '机器学习', 5, 1);
INSERT INTO `course_categories` VALUES (17, '深度学习', 5, 2);

-- ----------------------------
-- Table structure for courses
-- ----------------------------
DROP TABLE IF EXISTS `courses`;
CREATE TABLE `courses`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `category_id` bigint UNSIGNED NOT NULL,
  `title` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `summary` varchar(1024) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `cover_url` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `instructor_name` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `level` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `status` enum('draft','published') CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT 'draft',
  `view_count` bigint UNSIGNED NOT NULL DEFAULT 0,
  `favorite_count` bigint UNSIGNED NOT NULL DEFAULT 0,
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_courses_category_id`(`category_id` ASC) USING BTREE,
  INDEX `idx_courses_status_created_at`(`status` ASC, `created_at` ASC) USING BTREE,
  CONSTRAINT `fk_courses_category` FOREIGN KEY (`category_id`) REFERENCES `course_categories` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 10 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of courses
-- ----------------------------
INSERT INTO `courses` VALUES (1, 3, 'Python 编程基础', '从零开始掌握 Python 基础语法与编程思想', 'https://cdn.example.com/covers/python_basic.png', '张老师', '初级', 'published', 1250, 210, '2026-01-31 14:55:55.167', '2026-01-31 14:55:55.167');
INSERT INTO `courses` VALUES (2, 4, 'Java 核心技术与面向对象', '系统掌握 Java 语言与面向对象思想', 'https://cdn.example.com/covers/java_core.png', '李老师', '初级', 'published', 980, 165, '2026-01-31 14:55:55.167', '2026-01-31 14:55:55.167');
INSERT INTO `courses` VALUES (3, 5, 'Go 语言并发编程实战', '深入理解 Goroutine 与 Channel', 'https://cdn.example.com/covers/go_concurrency.png', '王老师', '中级', 'published', 760, 132, '2026-01-31 14:55:55.167', '2026-01-31 14:55:55.167');
INSERT INTO `courses` VALUES (4, 7, 'JavaScript 从入门到实战', '涵盖 ES6+、DOM、异步编程等核心内容', 'https://cdn.example.com/covers/js_full.png', '陈老师', '初级', 'published', 1430, 260, '2026-01-31 14:55:55.167', '2026-01-31 14:55:55.167');
INSERT INTO `courses` VALUES (5, 8, 'Flutter 跨平台应用开发', '一套代码，多端运行，完整项目实战', 'https://cdn.example.com/covers/flutter.png', '刘老师', '中级', 'published', 890, 190, '2026-01-31 14:55:55.167', '2026-01-31 14:55:55.167');
INSERT INTO `courses` VALUES (6, 9, 'Spring Boot 企业级开发', '构建可扩展的后端服务架构', 'https://cdn.example.com/covers/springboot.png', '周老师', '中级', 'published', 1020, 225, '2026-01-31 14:55:55.167', '2026-01-31 14:55:55.167');
INSERT INTO `courses` VALUES (7, 10, 'Gin + Go Web 开发', '轻量级高性能 Go Web 框架实战', 'https://cdn.example.com/covers/gin.png', '王老师', '中级', 'published', 640, 118, '2026-01-31 14:55:55.167', '2026-01-31 14:55:55.167');
INSERT INTO `courses` VALUES (8, 11, '机器学习基础', '理解经典机器学习算法与建模流程', 'https://cdn.example.com/covers/ml.png', '赵老师', '初级', 'published', 1580, 310, '2026-01-31 14:55:55.167', '2026-01-31 14:55:55.167');
INSERT INTO `courses` VALUES (9, 12, '深度学习与 PyTorch', '从神经网络到深度模型实战', 'https://cdn.example.com/covers/dl.png', '孙老师', '高级', 'published', 870, 205, '2026-01-31 14:55:55.167', '2026-01-31 14:55:55.167');

-- ----------------------------
-- Table structure for favorite_courses
-- ----------------------------
DROP TABLE IF EXISTS `favorite_courses`;
CREATE TABLE `favorite_courses`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` bigint UNSIGNED NOT NULL,
  `course_id` bigint UNSIGNED NOT NULL,
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_fav_courses_user_course`(`user_id` ASC, `course_id` ASC) USING BTREE,
  INDEX `idx_fav_courses_course_id`(`course_id` ASC) USING BTREE,
  CONSTRAINT `fk_fav_courses_course` FOREIGN KEY (`course_id`) REFERENCES `courses` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_fav_courses_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 9 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of favorite_courses
-- ----------------------------
INSERT INTO `favorite_courses` VALUES (1, 2, 1, '2026-01-31 14:55:55.171');
INSERT INTO `favorite_courses` VALUES (2, 2, 4, '2026-01-31 14:55:55.171');
INSERT INTO `favorite_courses` VALUES (3, 3, 1, '2026-01-31 14:55:55.171');
INSERT INTO `favorite_courses` VALUES (4, 3, 6, '2026-01-31 14:55:55.171');
INSERT INTO `favorite_courses` VALUES (5, 4, 8, '2026-01-31 14:55:55.171');
INSERT INTO `favorite_courses` VALUES (6, 5, 9, '2026-01-31 14:55:55.171');
INSERT INTO `favorite_courses` VALUES (7, 6, 1, '2026-01-31 14:55:55.171');
INSERT INTO `favorite_courses` VALUES (8, 6, 5, '2026-01-31 14:55:55.171');

-- ----------------------------
-- Table structure for favorite_videos
-- ----------------------------
DROP TABLE IF EXISTS `favorite_videos`;
CREATE TABLE `favorite_videos`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` bigint UNSIGNED NOT NULL,
  `video_id` bigint UNSIGNED NOT NULL,
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_fav_videos_user_video`(`user_id` ASC, `video_id` ASC) USING BTREE,
  INDEX `idx_fav_videos_video_id`(`video_id` ASC) USING BTREE,
  CONSTRAINT `fk_fav_videos_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_fav_videos_video` FOREIGN KEY (`video_id`) REFERENCES `videos` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 7 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of favorite_videos
-- ----------------------------
INSERT INTO `favorite_videos` VALUES (1, 2, 1, '2026-01-31 14:55:55.173');
INSERT INTO `favorite_videos` VALUES (2, 2, 3, '2026-01-31 14:55:55.173');
INSERT INTO `favorite_videos` VALUES (3, 3, 2, '2026-01-31 14:55:55.173');
INSERT INTO `favorite_videos` VALUES (4, 4, 4, '2026-01-31 14:55:55.173');
INSERT INTO `favorite_videos` VALUES (5, 5, 1, '2026-01-31 14:55:55.173');
INSERT INTO `favorite_videos` VALUES (6, 6, 3, '2026-01-31 14:55:55.173');

-- ----------------------------
-- Table structure for learning_progress
-- ----------------------------
DROP TABLE IF EXISTS `learning_progress`;
CREATE TABLE `learning_progress`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` bigint UNSIGNED NOT NULL,
  `video_id` bigint UNSIGNED NOT NULL,
  `last_position_sec` int UNSIGNED NOT NULL DEFAULT 0,
  `progress_percent` decimal(5, 2) NOT NULL DEFAULT 0.00,
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_progress_user_video`(`user_id` ASC, `video_id` ASC) USING BTREE,
  INDEX `idx_progress_video_id`(`video_id` ASC) USING BTREE,
  CONSTRAINT `fk_progress_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_progress_video` FOREIGN KEY (`video_id`) REFERENCES `videos` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 7 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of learning_progress
-- ----------------------------
INSERT INTO `learning_progress` VALUES (1, 2, 1, 420, 100.00, '2026-01-31 14:55:55.175');
INSERT INTO `learning_progress` VALUES (2, 2, 2, 300, 44.12, '2026-01-31 14:55:55.175');
INSERT INTO `learning_progress` VALUES (3, 3, 1, 210, 50.00, '2026-01-31 14:55:55.175');
INSERT INTO `learning_progress` VALUES (4, 3, 3, 600, 66.67, '2026-01-31 14:55:55.175');
INSERT INTO `learning_progress` VALUES (5, 4, 4, 200, 18.18, '2026-01-31 14:55:55.175');
INSERT INTO `learning_progress` VALUES (6, 5, 2, 680, 100.00, '2026-01-31 14:55:55.175');

-- ----------------------------
-- Table structure for users
-- ----------------------------
DROP TABLE IF EXISTS `users`;
CREATE TABLE `users`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `username` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `password_hash` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `role` enum('student','admin') CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT 'student',
  `nickname` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `avatar_url` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_users_username`(`username` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 7 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of users
-- ----------------------------
INSERT INTO `users` VALUES (1, 'admin', '$2b$10$adminhash', 'admin', '系统管理员', 'https://cdn.example.com/avatar/admin.png', '2026-01-31 14:55:55.156', '2026-01-31 14:55:55.156');
INSERT INTO `users` VALUES (2, 'alice', '$2b$10$hash1', 'student', 'Alice', 'https://cdn.example.com/avatar/a1.png', '2026-01-31 14:55:55.156', '2026-01-31 14:55:55.156');
INSERT INTO `users` VALUES (3, 'bob', '$2b$10$hash2', 'student', 'Bob', 'https://cdn.example.com/avatar/b1.png', '2026-01-31 14:55:55.156', '2026-01-31 14:55:55.156');
INSERT INTO `users` VALUES (4, 'carol', '$2b$10$hash3', 'student', 'Carol', 'https://cdn.example.com/avatar/c1.png', '2026-01-31 14:55:55.156', '2026-01-31 14:55:55.156');
INSERT INTO `users` VALUES (5, 'dave', '$2b$10$hash4', 'student', 'Dave', 'https://cdn.example.com/avatar/d1.png', '2026-01-31 14:55:55.156', '2026-01-31 14:55:55.156');
INSERT INTO `users` VALUES (6, 'erin', '$2b$10$hash5', 'student', 'Erin', 'https://cdn.example.com/avatar/e1.png', '2026-01-31 14:55:55.156', '2026-01-31 14:55:55.156');

-- ----------------------------
-- Table structure for videos
-- ----------------------------
DROP TABLE IF EXISTS `videos`;
CREATE TABLE `videos`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `course_id` bigint UNSIGNED NOT NULL,
  `title` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `description` varchar(1024) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `duration_sec` int UNSIGNED NOT NULL DEFAULT 0,
  `video_url` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `thumb_url` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `sort_order` int NOT NULL DEFAULT 0,
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_videos_course_id_sort`(`course_id` ASC, `sort_order` ASC, `id` ASC) USING BTREE,
  CONSTRAINT `fk_videos_course` FOREIGN KEY (`course_id`) REFERENCES `courses` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 5 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of videos
-- ----------------------------
INSERT INTO `videos` VALUES (1, 1, '课程介绍与学习方法', '课程整体结构与学习建议', 420, 'https://cdn.example.com/videos/python/01.mp4', 'https://cdn.example.com/thumbs/python/01.png', 1, '2026-01-31 14:55:55.169');
INSERT INTO `videos` VALUES (2, 1, 'Python 开发环境搭建', '安装 Python 与 IDE', 680, 'https://cdn.example.com/videos/python/02.mp4', 'https://cdn.example.com/thumbs/python/02.png', 2, '2026-01-31 14:55:55.169');
INSERT INTO `videos` VALUES (3, 1, '变量与数据类型', '数值、字符串、布尔类型', 900, 'https://cdn.example.com/videos/python/03.mp4', 'https://cdn.example.com/thumbs/python/03.png', 3, '2026-01-31 14:55:55.169');
INSERT INTO `videos` VALUES (4, 1, '条件判断与循环', 'if / for / while 语法详解', 1100, 'https://cdn.example.com/videos/python/04.mp4', 'https://cdn.example.com/thumbs/python/04.png', 4, '2026-01-31 14:55:55.169');

SET FOREIGN_KEY_CHECKS = 1;
