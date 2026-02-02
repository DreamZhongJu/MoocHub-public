package router

import (
	"MOOCHUB-server/controllers"
	"MOOCHUB-server/middleware"
	"net/http"
	"strings"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

func Router() *gin.Engine {
	r := gin.Default()

	// 配置 CORS 中间件
	r.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"http://localhost:80", "http://127.0.0.1:80", "http://0.0.0.0:80"},
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
		user.GET("/ping", func(c *gin.Context) { c.String(http.StatusOK, "pong") })
		// user.GET("/test/comments10", controllers.CommentController{}.GetComments10)
		// user.GET("/comments", controllers.CommentController{}.GetCommentsPaginated) // 可选
		// user.POST("/getUserTest", controllers.UserController{}.GetUserTest)
		// user.POST("/login", controllers.UserControllers{}.Login)
		// user.POST("/sign", controllers.UserControllers{}.Sign)
		auth := user.Group("/auth")
		{
			auth.POST("/register", controllers.UserController{}.Register)
			auth.POST("/login", controllers.UserController{}.Login)
			auth.GET("/me", middleware.AuthMiddleware(), controllers.UserController{}.Me)
		}
		user.GET("/categories", controllers.CourseCategoriesController{}.GetCategories)
		user.GET("/courses", controllers.CoursesController{}.GetCourses)
		user.GET("/courses/:id", controllers.CoursesController{}.GetCourseDetails)
		user.GET("/videos/:id", controllers.VideoController{}.GetVideoDetails)
		user.GET("/comments", controllers.CommentController{}.GetComments)
		user.POST("/comments", middleware.AuthMiddleware(), controllers.CommentController{}.CreateComment)
		user.POST("/comments/:id/like", middleware.AuthMiddleware(), controllers.CommentController{}.LikeComment)
		user.POST("/progress", middleware.AuthMiddleware(), controllers.ProgressController{}.UpsertProgress)
		user.GET("/progress/:video_id", middleware.AuthMiddleware(), controllers.ProgressController{}.GetProgress)
		favorite := user.Group("/favorites", middleware.AuthMiddleware())
		{
			favorite.POST("/courses", controllers.FavoriteController{}.ToggleFavorite)
			favorite.DELETE("/courses/:id", controllers.FavoriteController{}.DeleteFavorite)
			favorite.POST("/videos", controllers.FavoriteController{}.ToggleFavoriteVideo)
			favorite.DELETE("/videos/:id", controllers.FavoriteController{}.DeleteFavoriteVideo)
			favorite.GET("", controllers.FavoriteController{}.GetFavorites)
		}
		admin := user.Group("/admin", middleware.AdminMiddleware())
		{
			admin.POST("/courses", controllers.AdminController{}.CreateCourse)
			admin.PUT("/courses/:id", controllers.AdminController{}.UpdateCourse)
			admin.DELETE("/courses/:id", controllers.AdminController{}.DeleteCourse)
			admin.POST("/videos", controllers.AdminController{}.CreateVideo)
			admin.PUT("/videos/:id", controllers.AdminController{}.UpdateVideo)
			admin.DELETE("/videos/:id", controllers.AdminController{}.DeleteVideo)
			admin.DELETE("/comments/:id", controllers.AdminController{}.DeleteComment)
		}
	}

	return r
}
