package router

import (
	"strings"

	"github.com/DreamZhongJu/next-shop/controllers"
	"github.com/DreamZhongJu/next-shop/middleware" // 新增中间件导入
	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

func Router() *gin.Engine {
	r := gin.Default()

	// 静态文件路由 - 公开访问上传的图片
	r.StaticFS("/uploads", gin.Dir("./uploads", false))

	r.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"http://localhost:3000", "http://127.0.0.1:3000", "http://0.0.0.0:3000"},
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Accept", "Authorization"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
		AllowOriginFunc: func(origin string) bool {
			// 允许所有本地开发环境的请求（192.168.x.x, 10.x.x.x, 172.16.x.x-172.31.x.x）
			return strings.HasPrefix(origin, "http://localhost") ||
				strings.HasPrefix(origin, "http://127.0.0.1") ||
				strings.HasPrefix(origin, "http://192.168.") ||
				strings.HasPrefix(origin, "http://10.") ||
				strings.HasPrefix(origin, "http://172.16.") ||
				strings.HasPrefix(origin, "http://172.17.") ||
				strings.HasPrefix(origin, "http://172.18.") ||
				strings.HasPrefix(origin, "http://172.19.") ||
				strings.HasPrefix(origin, "http://172.20.") ||
				strings.HasPrefix(origin, "http://172.21.") ||
				strings.HasPrefix(origin, "http://172.22.") ||
				strings.HasPrefix(origin, "http://172.23.") ||
				strings.HasPrefix(origin, "http://172.24.") ||
				strings.HasPrefix(origin, "http://172.25.") ||
				strings.HasPrefix(origin, "http://172.26.") ||
				strings.HasPrefix(origin, "http://172.27.") ||
				strings.HasPrefix(origin, "http://172.28.") ||
				strings.HasPrefix(origin, "http://172.29.") ||
				strings.HasPrefix(origin, "http://172.30.") ||
				strings.HasPrefix(origin, "http://172.31.")
		},
	}))

	// 添加日志和恢复中间件
	r.Use(middleware.GinLogger(), middleware.GinRecovery(true))

	user := r.Group("/api/v1")
	{
		user.POST("/login", controllers.UserControllers{}.Login)
		user.POST("/sign", controllers.UserControllers{}.Sign)

		user.POST("/search", controllers.UserSearch{}.Search)
		user.GET("/search/all", controllers.UserSearch{}.SearchAll)
		user.GET("/search/detail/:id", controllers.UserSearch{}.GetProductDetail)
		user.GET("/suggest", (&controllers.SuggestController{}).GetSuggestions) // 搜索联想建议
		user.GET("/categories", controllers.CategoryController{}.List)
		user.GET("/categories/:level1_id/level2", controllers.CategoryController{}.ListLevel2)
		user.GET("/categories/level2/:level2_id/products", controllers.CategoryController{}.Products)

		// 嵌套购物车
		cart := user.Group("/cart")
		cart.Use(middleware.AuthMiddleware())
		{
			cart.POST("/add", controllers.CartController{}.Add)
			cart.PUT("/update", controllers.CartController{}.Update)
			cart.POST("/delete", controllers.CartController{}.Delete)
			cart.GET("/list/:user_id", controllers.CartController{}.List)
		}

		user.GET("/user/count", controllers.UserControllers{}.Count)

		// TODO: 项目部署与优化
		// - 使用 Docker 制作前后端镜像
		// - 使用 Nginx 配置反向代理与静态资源服务
		// - 配置 CI/CD 流水线，例如 GitHub Actions

		// TODO: 实现首页个性化商品推荐功能
		// - 接入后端 /api/v1/recommend 接口，返回基于用户兴趣或热门商品列表
		// - 使用 SWR 或 React Query 实现数据请求与缓存，避免重复请求
		// - 将推荐商品列表存入全局状态管理（如 Zustand），提升页面切换时数据复用效率
		// - 支持未登录用户展示默认热门推荐，已登录用户展示个性化推荐
		// - 增加 loading 和空状态 UI 提示，提升用户体验

		// TODO: 接入全局状态管理
		// - 使用 Zustand 或 Redux Toolkit 管理登录状态与购物车状态
		// - 提高组件间状态同步效率，避免 prop drilling

		// 管理员用户管理
		admin := user.Group("/admin")
		admin.Use(middleware.AdminMiddleware()) // 需要添加管理员中间件
		{
			admin.GET("/users", (&controllers.AdminUserController{}).GetUsers)
			admin.PUT("/users/:id", (&controllers.AdminUserController{}).UpdateUser)
			admin.DELETE("/users/:id", (&controllers.AdminUserController{}).DeleteUser)
			// Dashboard endpoint
			admin.GET("/admin/dashboard", controllers.DashboardController{}.GetDashboardData)

			// 商品管理
			admin.GET("/products", (&controllers.ProductController{}).GetProducts)
			admin.GET("/products/:id", (&controllers.ProductController{}).GetProduct)
			admin.POST("/products", (&controllers.ProductController{}).CreateProduct)
			admin.PUT("/products/:id", (&controllers.ProductController{}).UpdateProduct)
			admin.DELETE("/products/:id", (&controllers.ProductController{}).DeleteProduct)
			admin.POST("/upload", (&controllers.ProductController{}).UploadImage)
		}

		// // 嵌套收藏
		// favorite := user.Group("/favorite")
		// {
		// 	favorite.POST("/add", controllers.FavoriteController{}.Add)
		// 	favorite.DELETE("/remove", controllers.FavoriteController{}.Remove)
		// 	favorite.GET("/list/:user_id", controllers.FavoriteController{}.List)
		// }
	}

	return r
}
