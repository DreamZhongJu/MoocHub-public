package workers

import (
	"MOOCHUB-server/cache"
	"MOOCHUB-server/global"
	"MOOCHUB-server/model"
	"context"
	"strconv"
	"time"

	"go.uber.org/zap"
)

const (
	coursePageSize  = 10
	articlePageSize = 10
)

func StartCacheWarmupWorker() {
	go func() {
		RunCacheWarmupNow("startup")

		ticker := time.NewTicker(5 * time.Minute)
		defer ticker.Stop()
		for range ticker.C {
			RunCacheWarmupNow("ticker")
		}
	}()
}

func RunCacheWarmupNow(trigger string) {
	start := time.Now()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if cache.Client() == nil {
		return
	}

	if err := prewarmCategories(ctx); err != nil {
		global.Log.Warn("cache warmup categories failed", zap.String("trigger", trigger), zap.Error(err))
	}
	if err := prewarmCourseLists(ctx); err != nil {
		global.Log.Warn("cache warmup course lists failed", zap.String("trigger", trigger), zap.Error(err))
	}
	if err := prewarmCourseDetails(ctx); err != nil {
		global.Log.Warn("cache warmup course details failed", zap.String("trigger", trigger), zap.Error(err))
	}
	if err := prewarmArticles(ctx); err != nil {
		global.Log.Warn("cache warmup articles failed", zap.String("trigger", trigger), zap.Error(err))
	}

	global.Log.Info("cache warmup done",
		zap.String("trigger", trigger),
		zap.Duration("cost", time.Since(start)),
	)
}

func prewarmCategories(ctx context.Context) error {
	target := make([]model.CourseCategory, 0)
	_, _, err := cache.FillJSONWithHotKey(
		ctx,
		"categories:list",
		&target,
		func(loadCtx context.Context) (interface{}, error) {
			return model.GetAllCourseCategories()
		},
		cache.CacheLoadOptions{
			TTL:      5 * time.Minute,
			StaleTTL: 30 * time.Minute,
		},
	)
	return err
}

func prewarmCourseLists(ctx context.Context) error {
	sorts := []string{"default", "view_count", "favorite_count"}
	for _, sort := range sorts {
		key := buildCourseListCacheKey(0, sort, 1, coursePageSize)
		target := make([]model.Courses, 0)
		if _, _, err := cache.FillJSONWithHotKey(
			ctx,
			key,
			&target,
			func(loadCtx context.Context) (interface{}, error) {
				return model.GetCoursesByCategory(0, sort, "1", strconv.Itoa(coursePageSize))
			},
			cache.CacheLoadOptions{
				TTL:      2 * time.Minute,
				StaleTTL: 10 * time.Minute,
			},
		); err != nil {
			return err
		}
	}

	categories, err := model.GetAllCourseCategories()
	if err != nil {
		return err
	}
	limit := 8
	if len(categories) < limit {
		limit = len(categories)
	}
	for i := 0; i < limit; i++ {
		categoryID := categories[i].ID
		key := buildCourseListCacheKey(categoryID, "default", 1, coursePageSize)
		target := make([]model.Courses, 0)
		if _, _, err := cache.FillJSONWithHotKey(
			ctx,
			key,
			&target,
			func(loadCtx context.Context) (interface{}, error) {
				return model.GetCoursesByCategory(categoryID, "default", "1", strconv.Itoa(coursePageSize))
			},
			cache.CacheLoadOptions{
				TTL:      2 * time.Minute,
				StaleTTL: 10 * time.Minute,
			},
		); err != nil {
			return err
		}
	}
	return nil
}

func prewarmCourseDetails(ctx context.Context) error {
	ids, err := model.GetHotCourseIDs(12)
	if err != nil {
		return err
	}
	for _, courseID := range ids {
		cacheKey := "courses:detail:" + strconv.FormatInt(courseID, 10)
		target := struct {
			Courses []model.Courses `json:"courses"`
			Videos  []model.Video   `json:"videos"`
		}{}
		if _, _, err := cache.FillJSONWithHotKey(
			ctx,
			cacheKey,
			&target,
			func(loadCtx context.Context) (interface{}, error) {
				courses, err := model.GetCoursesDetails(courseID)
				if err != nil {
					return nil, err
				}
				videos, err := model.GetVideosByCourseID(courseID)
				if err != nil {
					return nil, err
				}
				return struct {
					Courses []model.Courses `json:"courses"`
					Videos  []model.Video   `json:"videos"`
				}{
					Courses: courses,
					Videos:  videos,
				}, nil
			},
			cache.CacheLoadOptions{
				TTL:      2 * time.Minute,
				StaleTTL: 10 * time.Minute,
			},
		); err != nil {
			return err
		}
	}
	return nil
}

func prewarmArticles(ctx context.Context) error {
	sorts := []string{"default", "view_count", "like_count"}
	for _, sort := range sorts {
		cacheKey := "articles:list:sort:" + sort + ":page:1:size:" + strconv.Itoa(articlePageSize)
		target := make([]model.Article, 0)
		if _, _, err := cache.FillJSONWithHotKey(
			ctx,
			cacheKey,
			&target,
			func(loadCtx context.Context) (interface{}, error) {
				return model.GetArticles(sort, "1", strconv.Itoa(articlePageSize))
			},
			cache.CacheLoadOptions{
				TTL:      2 * time.Minute,
				StaleTTL: 10 * time.Minute,
			},
		); err != nil {
			return err
		}
	}

	ids, err := model.GetHotArticleIDs(12)
	if err != nil {
		return err
	}
	for _, articleID := range ids {
		cacheKey := "articles:detail:" + strconv.FormatInt(articleID, 10)
		target := model.Article{}
		if _, _, err := cache.FillJSONWithHotKey(
			ctx,
			cacheKey,
			&target,
			func(loadCtx context.Context) (interface{}, error) {
				return model.GetArticleByID(articleID)
			},
			cache.CacheLoadOptions{
				TTL:      2 * time.Minute,
				StaleTTL: 10 * time.Minute,
			},
		); err != nil {
			return err
		}
	}
	return nil
}

func buildCourseListCacheKey(categoryID int64, sort string, page int, pageSize int) string {
	return "courses:list:cat:" + strconv.FormatInt(categoryID, 10) +
		":sort:" + sort +
		":page:" + strconv.Itoa(page) +
		":size:" + strconv.Itoa(pageSize)
}
