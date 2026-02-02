package model

import (
	"MOOCHUB-server/db"
	"errors"
	"time"

	"gorm.io/gorm"
)

// 数据库的全表，最好不要直接使用这个结构，可能会泄露消息
type Users struct {
	ID           uint
	Username     string
	PasswordHash string
	Role         string
	Nickname     string
	AvatarURL    string
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

// 示例接口，获取分页用户列表
// func GetUsersPaginated(page int, pageSize int) ([]Users, int64, error) {
// 	var users []Users
// 	var total int64

// 	offset := (page - 1) * pageSize
// 	result := db.GetDB().Offset(offset).Limit(pageSize).Find(&users)
// 	if result.Error != nil {
// 		return nil, 0, result.Error
// 	}

//		db.GetDB().Model(&Users{}).Count(&total)
//		return users, total, nil
//	}
func UsersRegister(username, password, nickname, role string) (Users, error) {
	var existing Users
	err := db.GetDB().Where("username = ?", username).First(&existing).Error
	if err == nil {
		return Users{}, errors.New("用户名已存在")
	}
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return Users{}, err
	}

	user := Users{
		Username:     username,
		PasswordHash: password,
		Nickname:     nickname,
		Role:         role,
	}
	result := db.GetDB().Create(&user)
	if result.Error != nil {
		return Users{}, result.Error
	}
	return user, nil
}
