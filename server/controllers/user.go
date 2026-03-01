package controllers

import (
	"MOOCHUB-server/model"
	"MOOCHUB-server/utils"
	"strings"

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
	role := normalizeRegisterRole(c.DefaultPostForm("role", "student"))
	if userName == "" || password == "" || nickName == "" {
		ReturnError(c, 400, "参数不能为空")
		return
	}
	if role != "student" && role != "teacher" {
		ReturnError(c, 400, "role 仅支持 student 或 teacher")
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

func normalizeRegisterRole(role string) string {
	role = strings.TrimSpace(strings.ToLower(role))
	if role == "" {
		return "student"
	}
	return role
}

func (u UserController) Login(c *gin.Context) {
	userName := c.DefaultPostForm("username", "")
	password := c.DefaultPostForm("password", "")
	if userName == "" || password == "" {
		ReturnError(c, 400, "参数不能为空")
		return
	}
	user, err := model.GetUserByUsername(userName)
	if err != nil {
		ReturnError(c, 400, "用户不存在")
		return
	}
	err = bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password))
	if err != nil {
		ReturnError(c, 400, "密码错误")
		return
	}
	token, err := utils.GenerateToken(int(user.ID), user.Role)
	if err != nil {
		ReturnError(c, 500, "生成token失败")
		return
	}
	ReturnSuccess(c, 200, "登录成功", gin.H{
		"user":  user,
		"token": token,
	}, 0)
}

func (u UserController) Me(c *gin.Context) {
	userIDVal, ok := c.Get("user_id")
	if !ok {
		ReturnError(c, 401, "未登录")
		return
	}

	userID, ok := userIDVal.(int)
	if !ok {
		ReturnError(c, 500, "用户ID类型错误")
		return
	}

	user, err := model.GetUserByID(uint(userID))
	if err != nil {
		ReturnError(c, 404, "用户不存在")
		return
	}

	// 注意：不要返回 PasswordHash
	ReturnSuccess(c, 200, "ok", gin.H{
		"id":         user.ID,
		"username":   user.Username,
		"nickname":   user.Nickname,
		"avatar_url": user.AvatarURL,
		"role":       user.Role,
	}, 0)
}
