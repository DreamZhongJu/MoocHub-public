package controllers

type CommentController struct{}

//测试接口
// GET /api/test/comments10
// func (u CommentController) GetComments10(c *gin.Context) {
// 	comments, err := model.GetCommentsLatestN(10)
// 	if err != nil {
// 		ReturnError(c, 400, "获取失败")
// 	}
// 	ReturnSuccess(c, 200, "获取成功", gin.H{
// 		"code": 0,
// 		"msg":  "ok",
// 		"data": comments,
// 	}, 0)
// }

// // 可选：GET /api/comments?page=1&pageSize=10
// func (u CommentController) GetCommentsPaginated(c *gin.Context) {
// 	page, _ := strconv.ParseInt(c.DefaultQuery("page", "1"), 10, 64)
// 	pageSize, _ := strconv.ParseInt(c.DefaultQuery("pageSize", "10"), 10, 64)

// 	items, total, err := model.GetCommentsPaginated(page, pageSize)
// 	if err != nil {
// 		ReturnError(c, 400, "获取失败")
// 	}
// 	ReturnSuccess(c, 200, "获取成功", gin.H{
// 		"code":  0,
// 		"msg":   "ok",
// 		"data":  items,
// 		"total": total,
// 		"page":  page,
// 		"size":  pageSize,
// 	}, 0)
// }
