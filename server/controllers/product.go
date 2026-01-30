package controllers

import (
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"github.com/DreamZhongJu/next-shop/model"
	"github.com/DreamZhongJu/next-shop/utils"
	"github.com/gin-gonic/gin"
)

type ProductController struct{}

// CreateProduct 创建商品
func (pc *ProductController) CreateProduct(c *gin.Context) {
	var product model.Product
	if err := c.ShouldBindJSON(&product); err != nil {
		utils.RespondWithError(c, http.StatusBadRequest, "Invalid request payload")
		return
	}

	if err := model.CreateProduct(&product); err != nil {
		utils.RespondWithError(c, http.StatusInternalServerError, "Failed to create product")
		return
	}

	utils.RespondWithJSON(c, http.StatusCreated, product)
}

// UpdateProduct 更新商品
func (pc *ProductController) UpdateProduct(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.RespondWithError(c, http.StatusBadRequest, "Invalid product ID")
		return
	}

	var product model.Product
	if err := c.ShouldBindJSON(&product); err != nil {
		utils.RespondWithError(c, http.StatusBadRequest, "Invalid request payload")
		return
	}

	product.ID = id
	if err := model.UpdateProduct(&product); err != nil {
		utils.RespondWithError(c, http.StatusInternalServerError, "Failed to update product")
		return
	}

	utils.RespondWithJSON(c, http.StatusOK, product)
}

// GetProduct 获取单个商品
func (pc *ProductController) GetProduct(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.RespondWithError(c, http.StatusBadRequest, "Invalid product ID")
		return
	}

	product, err := model.GetProductByID(id)
	if err != nil {
		utils.RespondWithError(c, http.StatusNotFound, "Product not found")
		return
	}

	utils.RespondWithJSON(c, http.StatusOK, product)
}

// GetProducts 获取商品列表(分页)
func (pc *ProductController) GetProducts(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("pageSize", "10"))

	products, total, err := model.GetPaginatedProducts(page, pageSize)
	if err != nil {
		utils.RespondWithError(c, http.StatusInternalServerError, "Failed to get products")
		return
	}

	utils.RespondWithJSON(c, http.StatusOK, gin.H{
		"data": products,
		"pagination": gin.H{
			"currentPage": page,
			"pageSize":    pageSize,
			"totalItems":  total,
			"totalPages":  (total + int64(pageSize) - 1) / int64(pageSize),
		},
	})
}

// DeleteProduct 删除商品
func (pc *ProductController) DeleteProduct(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.RespondWithError(c, http.StatusBadRequest, "Invalid product ID")
		return
	}

	if err := model.DeleteProduct(id); err != nil {
		utils.RespondWithError(c, http.StatusInternalServerError, "Failed to delete product")
		return
	}

	utils.RespondWithJSON(c, http.StatusOK, gin.H{"message": "Product deleted successfully"})
}

// UploadImage 上传商品图片
func (pc *ProductController) UploadImage(c *gin.Context) {
	file, err := c.FormFile("file")
	if err != nil {
		utils.RespondWithError(c, http.StatusBadRequest, "Failed to get uploaded file")
		return
	}

	// 创建上传目录
	uploadDir := "./uploads"
	if _, err := os.Stat(uploadDir); os.IsNotExist(err) {
		os.Mkdir(uploadDir, 0755)
	}

	// 生成唯一文件名
	ext := filepath.Ext(file.Filename)
	newFilename := time.Now().Format("20060102150405") + ext
	filePath := filepath.Join(uploadDir, newFilename)

	// 保存文件
	if err := c.SaveUploadedFile(file, filePath); err != nil {
		utils.RespondWithError(c, http.StatusInternalServerError, "Failed to save file")
		return
	}

	// 返回文件URL
	utils.RespondWithJSON(c, http.StatusOK, gin.H{
		"url": "/uploads/" + newFilename,
	})
}
