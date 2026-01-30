package controllers

import (
	"github.com/DreamZhongJu/next-shop/model"
	"github.com/gin-gonic/gin"
)

type DashboardController struct{}

func (d DashboardController) GetDashboardData(c *gin.Context) {
	// Get product count
	productCount, err := model.GetProductCount()
	if err != nil {
		ReturnError(c, 500, "获取商品总数失败")
		return
	}

	// Get total stock
	totalStock, err := model.GetTotalStock()
	if err != nil {
		ReturnError(c, 500, "获取总库存失败")
		return
	}

	// Get user count
	userCount, err := model.AllUserCount()
	if err != nil {
		ReturnError(c, 500, "获取用户总数失败")
		return
	}

	ReturnSuccess(c, 0, "获取仪表盘数据成功", gin.H{
		"productCount": productCount,
		"totalStock":   totalStock,
		"userCount":    userCount,
	}, 0)
}
