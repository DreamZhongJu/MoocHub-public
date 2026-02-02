package controllers

import (
	"MOOCHUB-server/model"
	"MOOCHUB-server/utils"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
)

type UserController struct{}

// func (u UserController) GetUserTest(c *gin.Context) {
// 	pageStr := c.DefaultPostForm("page", "1")
// 	countStr := c.DefaultPostForm("count", "10")
// 	page, _ := strconv.Atoi(pageStr)
// 	count, _ := strconv.Atoi(countStr)
// 	data, total, err := model.GetUsersPaginated(page, count)
// 	if err != nil {
// 		ReturnError(c, 400, "获取用户列表失败")
// 	}
// 	ReturnSuccess(c, 200, "获取成功", gin.H{"data": data}, total)
// }

func (u UserController) Register(c *gin.Context) {
	userName := c.DefaultPostForm("username", "")
	password := c.DefaultPostForm("password", "")
	nickName := c.DefaultPostForm("nickname", "")
	role := c.DefaultPostForm("role", "student")
	if userName == "" || password == "" || nickName == "" {
		ReturnError(c, 400, "参数不能为空")
		return
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		ReturnError(c, 500, "密码加密失败")
		return
	}
	password = string(hash)
	data, err := model.UsersRegister(userName, password, nickName, role)
	if err != nil {
		ReturnError(c, 400, "注册失败："+err.Error())
		return
	}
	token, err := utils.GenerateToken(int(data.ID), data.Role)
	if err != nil {
		ReturnError(c, 500, "生成token失败")
		return
	}
	ReturnSuccess(c, 200, "注册成功", gin.H{
		"user":  data,
		"token": token,
	}, 0)
	return
}
