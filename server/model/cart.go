package model

import (
	"errors"
	"strconv"
	"time"

	"github.com/DreamZhongJu/next-shop/dao"
)

type Cart struct {
	ID        int       `gorm:"column:id;primaryKey;autoIncrement" json:"id"`
	UserID    int       `gorm:"column:user_id" json:"user_id"`
	ProductID int       `gorm:"column:product_id" json:"product_id"`
	Quantity  int       `gorm:"column:quantity" json:"quantity"`
	CreatedAt time.Time `gorm:"column:created_at;autoCreateTime" json:"created_at"`
	UpdatedAt time.Time `gorm:"column:updated_at;autoUpdateTime" json:"updated_at"`
}

func (Cart) TableName() string {
	return "cart_items"
}

func AddCart(uid string, pid string, quantity string) (Cart, error) {
	userID, _ := strconv.Atoi(uid)
	productID, _ := strconv.Atoi(pid)
	qty, _ := strconv.Atoi(quantity)

	cart := Cart{
		UserID:    userID,
		ProductID: productID,
		Quantity:  qty,
	}
	return cart, dao.GetDB().Create(&cart).Error
}

func UpdateCart(uid string, pid string, quantity string) error {
	userID, _ := strconv.Atoi(uid)
	productID, _ := strconv.Atoi(pid)
	qty, _ := strconv.Atoi(quantity)

	return dao.GetDB().Model(&Cart{}).
		Where("user_id = ? AND product_id = ?", userID, productID).
		Update("quantity", qty).Error
}

func DeleteCart(uid string, pid string) error {
	userID, _ := strconv.Atoi(uid)
	productID, _ := strconv.Atoi(pid)

	result := dao.GetDB().Where("user_id = ? AND product_id = ?", userID, productID).Delete(&Cart{})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return errors.New("未找到对应记录")
	}
	return nil
}

func GetAllCart(uid string) ([]Cart, error) {
	userID, _ := strconv.Atoi(uid)
	var carts []Cart
	err := dao.GetDB().Where("user_id = ?", userID).Find(&carts).Error
	return carts, err
}
