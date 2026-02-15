package controllers

import (
	"MOOCHUB-server/cache"
	"MOOCHUB-server/model"
	"MOOCHUB-server/storage"
	"context"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

type CoursesController struct{}

const (
	maxCoursePageSize = 50
)

func (cc CoursesController) GetCourses(c *gin.Context) {
	categoryID, page, pageSize, sort, err := parseCourseListQuery(c)
	if err != nil {
		ReturnError(c, 400, err.Error())
		return
	}

	courses, err := loadCourseListWithCache(c.Request.Context(), categoryID, sort, page, pageSize)
	if err != nil {
		ReturnError(c, 500, "获取课程列表失败: "+err.Error())
		return
	}
	ReturnSuccess(c, 200, "获取成功", gin.H{"courses": courses}, int64(len(courses)))
}

func (cc CoursesController) GetCourseDetails(c *gin.Context) {
	idInt, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil || idInt <= 0 {
		ReturnError(c, 400, "invalid course id")
		return
	}

	cacheKey := "courses:detail:" + strconv.FormatInt(idInt, 10)
	payload := struct {
		Courses []model.Courses `json:"courses"`
		Videos  []model.Video   `json:"videos"`
	}{}

	_, _, err = cache.FillJSONWithHotKey(
		c.Request.Context(),
		cacheKey,
		&payload,
		func(ctx context.Context) (interface{}, error) {
			courses, err := model.GetCoursesDetails(idInt)
			if err != nil {
				return nil, err
			}
			videos, err := model.GetVideosByCourseID(idInt)
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
	)
	if err != nil {
		ReturnError(c, 500, "获取课程详情失败: "+err.Error())
		return
	}

	videos := make([]model.Video, len(payload.Videos))
	copy(videos, payload.Videos)
	for i := range videos {
		if url, resolveErr := storage.ResolveObjectURL(videos[i].VideoURL); resolveErr == nil && url != "" {
			videos[i].VideoURL = url
		}
		if url, resolveErr := storage.ResolveObjectURL(videos[i].ThumbURL); resolveErr == nil && url != "" {
			videos[i].ThumbURL = url
		}
	}

	ReturnSuccess(c, 200, "获取成功", gin.H{
		"courses": payload.Courses,
		"videos":  videos,
	}, int64(len(payload.Courses)))
}

func (cc CoursesController) GetCoursesByCategoryID(c *gin.Context) {
	categoryID, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil || categoryID <= 0 {
		ReturnError(c, 400, "invalid category id")
		return
	}
	sort := c.DefaultQuery("sort", "default")
	page, pageSize, pageErr := parsePageAndSize(c.DefaultQuery("page", "1"), c.DefaultQuery("page_size", "10"), maxCoursePageSize)
	if pageErr != nil {
		ReturnError(c, 400, pageErr.Error())
		return
	}

	courses, err := loadCourseListWithCache(c.Request.Context(), categoryID, sort, page, pageSize)
	if err != nil {
		ReturnError(c, 500, "获取课程列表失败: "+err.Error())
		return
	}
	ReturnSuccess(c, 200, "获取成功", gin.H{"courses": courses}, int64(len(courses)))
}

func parseCourseListQuery(c *gin.Context) (categoryID int64, page int, pageSize int, sort string, err error) {
	categoryID, err = strconv.ParseInt(c.DefaultQuery("category_id", "0"), 10, 64)
	if err != nil || categoryID < 0 {
		return 0, 0, 0, "", errInvalid("invalid category_id")
	}
	sort = c.DefaultQuery("sort", "default")
	page, pageSize, err = parsePageAndSize(c.DefaultQuery("page", "1"), c.DefaultQuery("page_size", "10"), maxCoursePageSize)
	if err != nil {
		return 0, 0, 0, "", err
	}
	return categoryID, page, pageSize, sort, nil
}

func parsePageAndSize(pageRaw string, sizeRaw string, maxSize int) (int, int, error) {
	page, err := strconv.Atoi(pageRaw)
	if err != nil || page <= 0 {
		return 0, 0, errInvalid("invalid page")
	}
	size, err := strconv.Atoi(sizeRaw)
	if err != nil || size <= 0 {
		return 0, 0, errInvalid("invalid page_size")
	}
	if size > maxSize {
		size = maxSize
	}
	return page, size, nil
}

func loadCourseListWithCache(ctx context.Context, categoryID int64, sort string, page int, pageSize int) ([]model.Courses, error) {
	cacheKey := buildCourseListCacheKey(categoryID, sort, page, pageSize)
	courses := make([]model.Courses, 0)
	_, _, err := cache.FillJSONWithHotKey(
		ctx,
		cacheKey,
		&courses,
		func(loadCtx context.Context) (interface{}, error) {
			return model.GetCoursesByCategory(
				categoryID,
				sort,
				strconv.Itoa(page),
				strconv.Itoa(pageSize),
			)
		},
		cache.CacheLoadOptions{
			TTL:      2 * time.Minute,
			StaleTTL: 10 * time.Minute,
		},
	)
	return courses, err
}

func buildCourseListCacheKey(categoryID int64, sort string, page int, pageSize int) string {
	return "courses:list:cat:" + strconv.FormatInt(categoryID, 10) +
		":sort:" + sort +
		":page:" + strconv.Itoa(page) +
		":size:" + strconv.Itoa(pageSize)
}

type invalidParamError struct {
	msg string
}

func (e invalidParamError) Error() string { return e.msg }

func errInvalid(msg string) error {
	return invalidParamError{msg: msg}
}
