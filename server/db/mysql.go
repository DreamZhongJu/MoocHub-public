package db

import (
	"MOOCHUB-server/config"
	"fmt"
	"time"

	"gorm.io/driver/mysql"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

var db *gorm.DB

func InitMySQL() error {
	return InitSQL()
}

func InitSQL() error {
	driver := config.DBDriver()
	var (
		conn *gorm.DB
		err  error
	)

	switch driver {
	case "mysql":
		conn, err = gorm.Open(mysql.Open(config.MysqlDSN()), &gorm.Config{})
	case "postgres", "postgresql":
		conn, err = gorm.Open(postgres.Open(config.PostgresDSN()), &gorm.Config{})
	default:
		return fmt.Errorf("unsupported DB_DRIVER %q", driver)
	}
	if err != nil {
		return fmt.Errorf("%s connect failed: %w", driver, err)
	}

	sqlDB, err := conn.DB()
	if err != nil {
		return fmt.Errorf("%s db init failed: %w", driver, err)
	}

	sqlDB.SetMaxIdleConns(10)
	sqlDB.SetMaxOpenConns(100)
	sqlDB.SetConnMaxLifetime(time.Hour)

	db = conn
	return nil
}

func Dialect() string {
	if db == nil {
		return ""
	}
	return db.Dialector.Name()
}

func GetDB() *gorm.DB {
	return db
}
