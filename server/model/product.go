package model

import (
	"strings"
	"time"

	"github.com/DreamZhongJu/next-shop/dao"
)

// Product 表示商品实体，映射到数据库中的 products 表
type Product struct {
	ID          int       `gorm:"column:id;primaryKey;autoIncrement" json:"id"`
	Name        string    `gorm:"column:name;type:varchar(100);not null" json:"name"`
	Description string    `gorm:"column:description;type:text" json:"description"`
	Price       float64   `gorm:"column:price;type:decimal(10,2);not null" json:"price"`
	Stock       int       `gorm:"column:stock;default:0" json:"stock"`
	ImageURL    string    `gorm:"column:image_url;type:varchar(255)" json:"image_url"`
	Category    string    `gorm:"column:category;type:varchar(50)" json:"category"`
	CreatedAt   time.Time `gorm:"column:created_at;autoCreateTime" json:"created_at"`
	UpdatedAt   time.Time `gorm:"column:updated_at;autoUpdateTime" json:"updated_at"`
}

// TableName 设置表名为 products
func (Product) TableName() string {
	return "products"
}

// CreateProduct 添加商品
func CreateProduct(p *Product) error {
	return dao.GetDB().Create(p).Error
}

// GetAllProducts 获取所有商品
func GetAllProducts() ([]Product, error) {
	var products []Product
	err := dao.GetDB().Find(&products).Error
	return products, err
}

// GetPaginatedProducts 获取分页商品数据
func GetPaginatedProducts(page, pageSize int) ([]Product, int64, error) {
	var products []Product
	var total int64

	// Calculate offset
	offset := (page - 1) * pageSize

	// Get total count
	if err := dao.GetDB().Model(&Product{}).Count(&total).Error; err != nil {
		return nil, 0, err
	}

	// Get paginated results
	err := dao.GetDB().Offset(offset).Limit(pageSize).Find(&products).Error
	return products, total, err
}

// GetProductByID 根据 ID 获取商品
func GetProductByID(id int) (*Product, error) {
	var product Product
	err := dao.GetDB().First(&product, id).Error
	if err != nil {
		return nil, err
	}
	return &product, nil
}

// UpdateProduct 更新商品
func UpdateProduct(p *Product) error {
	return dao.GetDB().Save(p).Error
}

// DeleteProduct 删除商品
func DeleteProduct(id int) error {
	return dao.GetDB().Delete(&Product{}, id).Error
}

func SearchProduct(name string) ([]Product, error) {
	var products []Product

	// 使用 LIKE 做模糊搜索
	err := dao.GetDB().
		Where("name LIKE ?", "%"+name+"%").
		Find(&products).Error

	return products, err
}

// GetProductCount returns the total number of products
func GetProductCount() (int64, error) {
	var count int64
	err := dao.GetDB().Model(&Product{}).Count(&count).Error
	return count, err
}

// GetTotalStock returns the sum of all product stock
func GetTotalStock() (int, error) {
	var totalStock int
	err := dao.GetDB().Model(&Product{}).Select("COALESCE(SUM(stock), 0)").Scan(&totalStock).Error
	return totalStock, err
}

// GetProductsByCategoryID returns products under a given category id.
// Products store the category name string, so we resolve the name from categories first.
func GetProductsByCategoryID(categoryID int) ([]Product, error) {
	var category Category
	if err := dao.GetDB().First(&category, categoryID).Error; err != nil {
		return nil, err
	}

	var products []Product
	err := dao.GetDB().Where("category = ?", category.Name).Find(&products).Error
	return products, err
}

// GetPaginatedProductsByCategoryID returns paginated products under a given category id.
// sort can be: default, price_asc, price_desc, stock_asc, stock_desc.
func GetPaginatedProductsByCategoryID(categoryID int, page, pageSize int, sort string) ([]Product, int64, error) {
	var category Category
	if err := dao.GetDB().First(&category, categoryID).Error; err != nil {
		return nil, 0, err
	}

	sort = strings.ToLower(strings.TrimSpace(sort))
	orderClause := "id desc"
	switch sort {
	case "price_asc":
		orderClause = "price asc"
	case "price_desc":
		orderClause = "price desc"
	case "stock_asc":
		orderClause = "stock asc"
	case "stock_desc":
		orderClause = "stock desc"
	}

	var total int64
	if err := dao.GetDB().Model(&Product{}).Where("category = ?", category.Name).Count(&total).Error; err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * pageSize
	var products []Product
	err := dao.GetDB().Where("category = ?", category.Name).Order(orderClause).Offset(offset).Limit(pageSize).Find(&products).Error
	return products, total, err
}
