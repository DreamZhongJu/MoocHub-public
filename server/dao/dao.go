package dao

import (
	"fmt"
	"time"

	"github.com/DreamZhongJu/next-shop/config"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

var (
	db  *gorm.DB
	err error
)

func init() {
	dsn := config.Mysqldb

	// 使用 = 而不是 :=
	db, err = gorm.Open(mysql.Open(dsn), &gorm.Config{})
	if err != nil {
		fmt.Println("数据库连接失败:", err)
		return
	}

	sqlDB, err := db.DB()
	if err != nil {
		fmt.Println("数据库启动失败:", err)
		return
	}

	sqlDB.SetMaxIdleConns(10)
	sqlDB.SetMaxOpenConns(100)
	sqlDB.SetConnMaxLifetime(time.Hour)
}

func GetDB() *gorm.DB {
	return db
}
