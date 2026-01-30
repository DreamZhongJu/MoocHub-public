package model

import (
	"time"

	"github.com/DreamZhongJu/next-shop/dao"
	"gorm.io/gorm"
)

type User struct {
	UserID    int       `gorm:"primaryKey;column:user_id;autoIncrement"`
	Username  string    `gorm:"unique;not null"`
	Password  string    `gorm:"not null"`
	Role      string    `gorm:"default:'common'"`
	CreatedAt time.Time `gorm:"type:datetime;default:CURRENT_TIMESTAMP"`
}

func GetUsersPaginated(page, pageSize int) ([]User, int64, error) {
	var users []User
	var total int64

	offset := (page - 1) * pageSize
	result := dao.GetDB().Offset(offset).Limit(pageSize).Find(&users)
	if result.Error != nil {
		return nil, 0, result.Error
	}

	dao.GetDB().Model(&User{}).Count(&total)
	return users, total, nil
}

func UpdateUserRole(id int, role string) error {
	result := dao.GetDB().Model(&User{}).Where("user_id = ?", id).Update("role", role)
	return result.Error
}

func DeleteUser(id int) error {
	result := dao.GetDB().Delete(&User{}, id)
	return result.Error
}

// Login 执行登录逻辑，返回用户信息或错误
func Login(username string, password string) (*User, error) {
	var user User

	// 查询 username 对应的记录
	err := dao.GetDB().Where("username = ?", username).First(&user).Error
	if err != nil {
		return nil, err
	}

	// 验证密码
	if user.Password != password {
		return nil, gorm.ErrRecordNotFound
	}

	return &user, nil
}

func Sign(username string, password string) (*User, error) {
	// 用户名重复校验
	var existing User
	if err := dao.GetDB().Where("username = ?", username).First(&existing).Error; err == nil {
		return nil, gorm.ErrDuplicatedKey
	}

	user := User{
		Username: username,
		Password: password,
		Role:     "common", // 默认角色
	}

	// 插入数据库
	err := dao.GetDB().Create(&user).Error
	if err != nil {
		return nil, err
	}

	return &user, nil
}

func AllUserCount() (int64, error) {
	var count int64
	err := dao.GetDB().Table("users").Count(&count).Error
	return count, err
}
