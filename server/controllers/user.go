package controllers

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
