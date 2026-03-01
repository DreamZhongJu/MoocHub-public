-- 为 users.role 增加 teacher 枚举值
-- 在 moochub 库执行
ALTER TABLE users
  MODIFY COLUMN role ENUM('student','teacher','admin') NOT NULL DEFAULT 'student';

