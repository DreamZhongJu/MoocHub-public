package controllers

import (
	"strconv"

	"github.com/DreamZhongJu/next-shop/model"
	"github.com/gin-gonic/gin"
)

type CategoryController struct{}

// List returns all categories without authentication.
func (cc CategoryController) List(c *gin.Context) {
	categories, err := model.GetAllLevel1Categories()
	if err != nil {
		ReturnError(c, 500, "获取一级分类失败: "+err.Error())
		return
	}
	ReturnSuccess(c, 0, "获取一级分类成功", categories, int64(len(categories)))
}

// Products returns products under a category id without authentication.
func (cc CategoryController) Products(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("level2_id"))
	if err != nil {
		ReturnError(c, 400, "二级分类ID格式错误")
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	if page < 1 {
		page = 1
	}
	pageSize := 8
	sort := c.DefaultQuery("sort", "default")

	products, total, err := model.GetPaginatedProductsByCategoryID(id, page, pageSize, sort)
	if err != nil {
		ReturnError(c, 404, "获取分类商品失败: "+err.Error())
		return
	}

	ReturnSuccess(c, 0, "获取分类商品成功", products, total)
}

// ListLevel2 returns all level-2 categories (existing categories table) without authentication.
func (cc CategoryController) ListLevel2(c *gin.Context) {
	level1ID, err := strconv.Atoi(c.Param("level1_id"))
	if err != nil {
		ReturnError(c, 400, "一级分类ID格式错误")
		return
	}

	categories, err := model.GetLevel2ByLevel1ID(level1ID)
	if err != nil {
		ReturnError(c, 500, "获取二级分类失败: "+err.Error())
		return
	}

	ReturnSuccess(c, 0, "获取二级分类成功", categories, int64(len(categories)))
}
