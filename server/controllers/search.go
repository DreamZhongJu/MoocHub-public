package controllers

import (
	"strconv"

	"github.com/DreamZhongJu/next-shop/model"
	"github.com/gin-gonic/gin"
)

type UserSearch struct{}

func (s UserSearch) Search(c *gin.Context) {
	name := c.DefaultPostForm("name", "")
	products, err := model.SearchProduct(name)
	if err != nil {
		ReturnError(c, 402, "搜索失败："+err.Error())
	}
	ReturnSuccess(c, 0, "搜索成功", products, 0)
}

func (s UserSearch) SearchAll(c *gin.Context) {
	// Parse pagination parameters
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("pageSize", "10"))

	// Get paginated products
	products, total, err := model.GetPaginatedProducts(page, pageSize)
	if err != nil {
		ReturnError(c, 402, "获取商品信息失败"+err.Error())
		return
	}

	// Calculate total pages (convert pageSize to int64 for operations)
	totalPages := total / int64(pageSize)
	if total%int64(pageSize) != 0 {
		totalPages++
	}

	// Return response with pagination metadata
	ReturnSuccess(c, 0, "获取商品信息成功", gin.H{
		"data": products,
		"pagination": gin.H{
			"currentPage": page,
			"pageSize":    pageSize,
			"totalItems":  total,
			"totalPages":  totalPages,
		},
	}, 0)
}

func (s UserSearch) GetProductDetail(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.Atoi(idStr)
	if err != nil {
		ReturnError(c, 400, "商品ID格式错误")
		return
	}
	product, err := model.GetProductByID(id)
	if err != nil {
		ReturnError(c, 404, "商品不存在或已下架")
		return
	}
	ReturnSuccess(c, 0, "获取商品详情成功", product, 0)
}
