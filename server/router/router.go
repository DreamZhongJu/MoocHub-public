package router

import (
	"MOOCHUB-server/config"
	"MOOCHUB-server/controllers"
	"MOOCHUB-server/middleware"
	"MOOCHUB-server/utils"
	"net/http"
	"strings"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

func Router() *gin.Engine {
	r := gin.New()

	r.Use(middleware.TraceIDMiddleware())
	r.Use(middleware.RateLimitMiddleware(middleware.RateLimitOptions{
		Name:          "global",
		Limit:         config.RateLimitGlobalPerMinute(),
		Window:        time.Minute,
		KeyFn:         middleware.KeyByIP,
		SkipOnNoRedis: true,
	}))
	writeLimiter := middleware.RateLimitMiddleware(middleware.RateLimitOptions{
		Name:          "write",
		Limit:         config.RateLimitWritePerMinute(),
		Window:        time.Minute,
		KeyFn:         middleware.KeyByUserOrIP,
		SkipOnNoRedis: true,
	})
	r.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"http://localhost:80", "http://127.0.0.1:80", "http://0.0.0.0:80"},
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Accept", "Authorization", utils.HeaderTraceID},
		ExposeHeaders:    []string{"Content-Length", utils.HeaderTraceID},
		AllowCredentials: true,
		AllowOriginFunc: func(origin string) bool {
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

	r.Use(middleware.GinLogger(), middleware.GinRecovery(true))
	r.GET("/uploads/*filepath", controllers.UploadController{}.ServeUpload)

	user := r.Group("/api/v1")
	{
		user.GET("/ping", func(c *gin.Context) { c.String(http.StatusOK, "pong") })
		auth := user.Group("/auth")
		auth.Use(middleware.RateLimitMiddleware(middleware.RateLimitOptions{
			Name:          "auth",
			Limit:         config.RateLimitAuthPerMinute(),
			Window:        time.Minute,
			KeyFn:         middleware.KeyByIP,
			SkipOnNoRedis: true,
		}))
		{
			auth.POST("/register", controllers.UserController{}.Register)
			auth.POST("/login", controllers.UserController{}.Login)
			auth.GET("/me", middleware.AuthMiddleware(), controllers.UserController{}.Me)
			auth.GET("/qq/login", controllers.QQController{}.Login)
			auth.GET("/qq/callback", controllers.QQController{}.Callback)
			auth.POST("/qq/sdk_login", controllers.QQController{}.SDKLogin)
		}
		user.GET("/categories", controllers.CourseCategoriesController{}.GetCategories)
		user.GET("/categories/:id/courses", controllers.CoursesController{}.GetCoursesByCategoryID)
		user.GET("/courses", controllers.CoursesController{}.GetCourses)
		user.GET("/courses/:id", controllers.CoursesController{}.GetCourseDetails)
		user.GET("/recommend/courses", controllers.RecommendController{}.GetCourseFeed)
		user.GET("/articles", controllers.ArticlesController{}.GetArticles)
		user.GET("/articles/:id", controllers.ArticlesController{}.GetArticleDetail)
		user.POST("/articles/:id/view", controllers.ArticlesController{}.ViewArticle)
		user.POST("/articles/:id/like", middleware.AuthMiddleware(), controllers.ArticlesController{}.LikeArticle)
		user.POST("/articles", middleware.AuthMiddleware(), controllers.ArticlesController{}.CreateArticle)
		user.GET("/search", controllers.SearchController{}.Search)
		user.GET("/search/suggest", controllers.SearchController{}.Suggest)
		user.POST("/ai/query", controllers.AIController{}.Query)
		user.POST("/uploads", middleware.AuthMiddleware(), controllers.UploadController{}.Upload)
		user.GET("/videos/:id", controllers.VideoController{}.GetVideoDetails)
		user.GET("/comments", controllers.CommentController{}.GetComments)
		user.POST("/comments", middleware.AuthMiddleware(), writeLimiter, middleware.IdempotencyMiddleware(), controllers.CommentController{}.CreateComment)
		user.POST("/comments/:id/like", middleware.AuthMiddleware(), controllers.CommentController{}.LikeComment)
		user.POST("/device_tokens", middleware.AuthMiddleware(), controllers.DeviceTokenController{}.Register)
		user.GET("/messages", middleware.AuthMiddleware(), controllers.MessageController{}.GetMessages)
		user.GET("/messages/unread_count", middleware.AuthMiddleware(), controllers.MessageController{}.GetUnreadCount)
		user.POST("/messages/read", middleware.AuthMiddleware(), writeLimiter, middleware.IdempotencyMiddleware(), controllers.MessageController{}.MarkRead)
		user.POST("/messages/award", middleware.InternalMiddleware(), controllers.MessageController{}.AwardMessage)

		chat := user.Group("/chat", middleware.AuthMiddleware())
		{
			chat.GET("/conversations", controllers.ChatController{}.GetConversations)
			chat.POST("/private/start", controllers.ChatController{}.CreatePrivateConversation)
			chat.POST("/groups", controllers.ChatController{}.CreateGroupConversation)
			chat.POST("/groups/:id/members", controllers.ChatController{}.AddGroupMembers)
			chat.GET("/messages", controllers.ChatController{}.GetMessages)
			chat.POST("/messages", writeLimiter, middleware.IdempotencyMiddleware(), controllers.ChatController{}.SendMessage)
			chat.POST("/read", writeLimiter, middleware.IdempotencyMiddleware(), controllers.ChatController{}.MarkRead)
			chat.GET("/unread_count", controllers.ChatController{}.GetUnreadCount)
		}

		user.POST("/progress", middleware.AuthMiddleware(), writeLimiter, middleware.IdempotencyMiddleware(), controllers.ProgressController{}.UpsertProgress)
		user.GET("/progress/:video_id", middleware.AuthMiddleware(), controllers.ProgressController{}.GetProgress)
		user.GET("/progress/latest", middleware.AuthMiddleware(), controllers.ProgressController{}.GetLatestProgress)
		user.POST("/events/exposure", controllers.EventsController{}.Exposure)
		user.POST("/events/page_view", controllers.EventsController{}.Exposure)
		user.POST("/events/click", controllers.EventsController{}.Click)
		user.POST("/events/favorite", controllers.EventsController{}.Click)
		user.POST("/events/comment", controllers.EventsController{}.Click)
		user.POST("/events/complete", writeLimiter, middleware.IdempotencyMiddleware(), controllers.EventsController{}.Complete)
		user.POST("/events/play", writeLimiter, middleware.IdempotencyMiddleware(), controllers.EventsController{}.Play)
		user.GET("/points/balance", middleware.AuthMiddleware(), controllers.PointsController{}.GetBalance)
		user.GET("/points/transactions", middleware.AuthMiddleware(), controllers.PointsController{}.GetTransactions)
		user.GET("/points/rank", middleware.AuthMiddleware(), controllers.PointsController{}.GetRank)
		user.POST("/points/award", middleware.InternalMiddleware(), controllers.PointsController{}.AwardPoints)

		internal := user.Group("/internal", middleware.InternalMiddleware())
		{
			internal.GET("/knowledge/sources", controllers.KnowledgeController{}.ExportSources)
			internal.GET("/knowledge/sources/:type", controllers.KnowledgeController{}.ListSources)
			internal.GET("/knowledge/sources/:type/:id", controllers.KnowledgeController{}.GetSourceDetail)
		}

		favorite := user.Group("/favorites", middleware.AuthMiddleware())
		{
			favorite.POST("/courses", controllers.FavoriteController{}.ToggleFavorite)
			favorite.DELETE("/courses/:id", controllers.FavoriteController{}.DeleteFavorite)
			favorite.POST("/videos", controllers.FavoriteController{}.ToggleFavoriteVideo)
			favorite.DELETE("/videos/:id", controllers.FavoriteController{}.DeleteFavoriteVideo)
			favorite.POST("/articles", controllers.FavoriteController{}.ToggleFavoriteArticle)
			favorite.DELETE("/articles/:id", controllers.FavoriteController{}.DeleteFavoriteArticle)
			favorite.GET("", controllers.FavoriteController{}.GetFavorites)
		}

		admin := user.Group("/admin", middleware.AuthMiddleware())
		{
			// teacher/admin 可新建课程与视频
			admin.POST("/courses", middleware.RoleMiddleware("admin", "teacher"), controllers.AdminController{}.CreateCourse)
			admin.POST("/videos", middleware.RoleMiddleware("admin", "teacher"), controllers.AdminController{}.CreateVideo)

			// 管理能力仅 admin 可用
			admin.GET("/analytics/overview", middleware.AdminMiddleware(), controllers.AdminAnalyticsController{}.Overview)
			admin.GET("/analytics/trend", middleware.AdminMiddleware(), controllers.AdminAnalyticsController{}.Trend)
			admin.GET("/analytics/top", middleware.AdminMiddleware(), controllers.AdminAnalyticsController{}.Top)
			admin.POST("/cache/prewarm", middleware.AdminMiddleware(), writeLimiter, middleware.IdempotencyMiddleware(), controllers.CacheOpsController{}.Prewarm)
			admin.PUT("/courses/:id", middleware.RoleMiddleware("admin", "teacher"), controllers.AdminController{}.UpdateCourse)
			admin.DELETE("/courses/:id", middleware.RoleMiddleware("admin", "teacher"), controllers.AdminController{}.DeleteCourse)
			admin.PUT("/videos/:id", middleware.RoleMiddleware("admin", "teacher"), controllers.AdminController{}.UpdateVideo)
			admin.DELETE("/videos/:id", middleware.RoleMiddleware("admin", "teacher"), controllers.AdminController{}.DeleteVideo)
			admin.DELETE("/comments/:id", middleware.AdminMiddleware(), controllers.AdminController{}.DeleteComment)
			admin.POST("/push", middleware.AdminMiddleware(), writeLimiter, middleware.IdempotencyMiddleware(), controllers.PushController{}.Send)
		}
	}

	return r
}
