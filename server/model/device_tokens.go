package model

import (
	"MOOCHUB-server/db"
	"errors"
	"time"

	"gorm.io/gorm"
)

// DeviceToken stores FCM tokens for push delivery.
type DeviceToken struct {
	ID        uint64    `gorm:"column:id;primaryKey" json:"id"`
	UserID    uint      `gorm:"column:user_id" json:"user_id"`
	Platform  string    `gorm:"column:platform" json:"platform"`
	Token     string    `gorm:"column:token" json:"token"`
	CreatedAt time.Time `gorm:"column:created_at" json:"created_at"`
	UpdatedAt time.Time `gorm:"column:updated_at" json:"updated_at"`
}

func (DeviceToken) TableName() string {
	return "device_tokens"
}

func UpsertDeviceToken(userID uint, platform, token string) error {
	if token == "" {
		return errors.New("token is required")
	}

	dbConn := db.GetDB()
	var existing DeviceToken
	err := dbConn.Where("token = ?", token).First(&existing).Error
	if err == nil {
		return dbConn.Model(&existing).Updates(map[string]any{
			"user_id":  userID,
			"platform": platform,
		}).Error
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return err
	}

	item := DeviceToken{
		UserID:   userID,
		Platform: platform,
		Token:    token,
	}
	return dbConn.Create(&item).Error
}

func GetDeviceTokensByUser(userID uint) ([]DeviceToken, error) {
	var items []DeviceToken
	if err := db.GetDB().Where("user_id = ?", userID).Find(&items).Error; err != nil {
		return nil, err
	}
	return items, nil
}
