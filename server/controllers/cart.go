package controllers

import (
	"github.com/DreamZhongJu/next-shop/model"
	"github.com/gin-gonic/gin"
)

type CartController struct{}

func (s CartController) Add(c *gin.Context) {
	uid := c.DefaultPostForm("uid", "")
	pid := c.DefaultPostForm("pid", "")
	quantity := c.DefaultPostForm("quantity", "")
	products, err := model.AddCart(uid, pid, quantity)
	if err != nil {
		ReturnError(c, 402, "添加商品失败:"+err.Error())
		return
	}
	ReturnSuccess(c, 0, "添加成功", products, 0)
}

func (s CartController) Update(c *gin.Context) {
	uid := c.DefaultPostForm("uid", "")
	pid := c.DefaultPostForm("pid", "")
	quantity := c.DefaultPostForm("quantity", "")
	err := model.UpdateCart(uid, pid, quantity)
	if err != nil {
		ReturnError(c, 402, "更新购物车失败:"+err.Error())
		return
	}
	ReturnSuccess(c, 0, "更新成功", nil, 0)
}

func (s CartController) Delete(c *gin.Context) {
	uid := c.DefaultPostForm("uid", "")
	pid := c.DefaultPostForm("pid", "")
	err := model.DeleteCart(uid, pid)
	if err != nil {
		ReturnError(c, 402, "删除购物车失败:"+err.Error())
		return
	}
	ReturnSuccess(c, 0, "删除成功", nil, 0)
}

func (s CartController) List(c *gin.Context) {
	uid := c.Param("user_id")
	list, err := model.GetAllCart(uid)
	if err != nil {
		ReturnError(c, 402, "获取购物车列表失败:"+err.Error())
		return
	}
	ReturnSuccess(c, 0, "获取成功", list, int64(len(list)))
}
