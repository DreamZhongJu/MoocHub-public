package model

import (
	"MOOCHUB-server/db"
	"math"
	"math/rand"
	"sort"
	"strings"
	"time"

	"gorm.io/gorm"
)

type RecommendInteraction struct {
	ID         int64     `gorm:"column:id;primaryKey;autoIncrement"`
	UserID     int64     `gorm:"column:user_id"`
	ItemID     int64     `gorm:"column:item_id"`
	CategoryID int64     `gorm:"column:category_id"`
	Action     string    `gorm:"column:action"`
	Ts         time.Time `gorm:"column:ts"`
}

func (RecommendInteraction) TableName() string {
	return "recommend_interactions"
}

var recommendActions = map[string]struct{}{
	"view":     {},
	"click":    {},
	"like":     {},
	"favorite": {},
	"complete": {},
}

type scoredCourse struct {
	ItemID   int64     `gorm:"column:item_id"`
	Score    float64   `gorm:"column:score"`
	LatestTs time.Time `gorm:"column:latest_ts"`
}

func RecordRecommendInteraction(userID int64, itemID int64, action string) error {
	if userID <= 0 || itemID <= 0 {
		return nil
	}
	action = strings.ToLower(strings.TrimSpace(action))
	if _, ok := recommendActions[action]; !ok {
		return nil
	}

	var categoryID int64
	if err := db.GetDB().Table("courses").Where("id = ? AND status = ?", itemID, "published").Select("category_id").Scan(&categoryID).Error; err != nil {
		return err
	}
	if categoryID <= 0 {
		return nil
	}

	entry := RecommendInteraction{
		UserID:     userID,
		ItemID:     itemID,
		CategoryID: categoryID,
		Action:     action,
		Ts:         time.Now(),
	}
	return db.GetDB().Create(&entry).Error
}

func BuildMinimalPersonalizedCourseIDs(userID int64, page int, pageSize int, seed int64) ([]int64, []int64, error) {
	if page < 1 {
		page = 1
	}
	if pageSize < 1 {
		pageSize = 10
	}
	if pageSize > 50 {
		pageSize = 50
	}

	neededTotal := page * pageSize
	personalPerPage := int(math.Ceil(float64(pageSize) * 0.7))
	if personalPerPage <= 0 {
		personalPerPage = 1
	}
	globalPerPage := pageSize - personalPerPage
	if globalPerPage <= 0 {
		globalPerPage = 1
	}

	topCategories := make([]int64, 0)
	var err error
	if userID > 0 {
		topCategories, err = getTopCategoriesByRecentInteractions(userID, 20, 3)
		if err != nil {
			return nil, nil, err
		}
	}

	personalLimit := neededTotal + pageSize
	globalLimit := neededTotal + pageSize
	if personalLimit < page*personalPerPage {
		personalLimit = page*personalPerPage + pageSize
	}
	if globalLimit < page*globalPerPage {
		globalLimit = page*globalPerPage + pageSize
	}

	personalIDs := make([]int64, 0)
	if len(topCategories) > 0 {
		personalIDs, err = getHotCourseIDsByInteractions(7*24*time.Hour, personalLimit, topCategories, true)
		if err != nil {
			return nil, nil, err
		}
	}

	hot7dIDs, err := getHotCourseIDsByInteractions(7*24*time.Hour, globalLimit*2, nil, true)
	if err != nil {
		return nil, nil, err
	}
	hot24hIDs, err := getHotCourseIDsByInteractions(24*time.Hour, globalLimit*2, nil, false)
	if err != nil {
		return nil, nil, err
	}
	globalIDs := mergeUniqueInterleave(hot24hIDs, hot7dIDs, globalLimit*2)

	mixed := mixByRatio(personalIDs, globalIDs, neededTotal, 7, 3)
	if len(mixed) < neededTotal {
		fillIDs, fillErr := getNewestCourseIDs(neededTotal*2, mixed)
		if fillErr != nil {
			return nil, nil, fillErr
		}
		mixed = appendUnique(mixed, fillIDs, neededTotal)
	}
	if seed != 0 && len(mixed) > 1 {
		mixed = deterministicShuffle(mixed, seed)
	}

	start := (page - 1) * pageSize
	if start >= len(mixed) {
		return []int64{}, topCategories, nil
	}
	end := start + pageSize
	if end > len(mixed) {
		end = len(mixed)
	}
	return mixed[start:end], topCategories, nil
}

func GetCoursesByIDsPreserveOrder(ids []int64) ([]Courses, error) {
	if len(ids) == 0 {
		return []Courses{}, nil
	}
	rows := make([]Courses, 0, len(ids))
	if err := db.GetDB().Where("status = ?", "published").Where("id IN ?", ids).Find(&rows).Error; err != nil {
		return nil, err
	}
	index := make(map[int64]int, len(ids))
	for i, id := range ids {
		index[id] = i
	}
	sort.Slice(rows, func(i, j int) bool {
		return index[rows[i].ID] < index[rows[j].ID]
	})
	return rows, nil
}

func getTopCategoriesByRecentInteractions(userID int64, recentLimit int, topN int) ([]int64, error) {
	if userID <= 0 || recentLimit <= 0 || topN <= 0 {
		return []int64{}, nil
	}
	type row struct {
		CategoryID int64 `gorm:"column:category_id"`
	}
	items := make([]row, 0, topN)
	err := db.GetDB().Raw(`
SELECT category_id
FROM (
  SELECT category_id, ts
  FROM recommend_interactions
  WHERE user_id = ?
  ORDER BY ts DESC
  LIMIT ?
) recent
GROUP BY category_id
ORDER BY COUNT(*) DESC, MAX(ts) DESC
LIMIT ?`, userID, recentLimit, topN).Scan(&items).Error
	if err != nil {
		return nil, err
	}
	result := make([]int64, 0, len(items))
	for _, item := range items {
		if item.CategoryID > 0 {
			result = append(result, item.CategoryID)
		}
	}
	return result, nil
}

func getHotCourseIDsByInteractions(window time.Duration, limit int, categoryIDs []int64, weighted bool) ([]int64, error) {
	if limit <= 0 {
		return []int64{}, nil
	}
	whereScore := "COUNT(*)"
	if weighted {
		whereScore = `SUM(
CASE action
  WHEN 'view' THEN 1
  WHEN 'click' THEN 2
  WHEN 'like' THEN 3
  WHEN 'favorite' THEN 4
  WHEN 'complete' THEN 5
  ELSE 0
END
)`
	}

	q := db.GetDB().
		Table("recommend_interactions ri").
		Joins("JOIN courses c ON c.id = ri.item_id AND c.status = ?", "published").
		Where("ri.ts >= ?", time.Now().Add(-window)).
		Select("ri.item_id, " + whereScore + " AS score, MAX(ri.ts) AS latest_ts")
	if len(categoryIDs) > 0 {
		q = q.Where("ri.category_id IN ?", categoryIDs)
	}

	items := make([]scoredCourse, 0, limit)
	if err := q.Group("ri.item_id").Order("score DESC").Order("latest_ts DESC").Order("ri.item_id DESC").Limit(limit).Scan(&items).Error; err != nil {
		return nil, err
	}
	result := make([]int64, 0, len(items))
	for _, item := range items {
		result = append(result, item.ItemID)
	}
	return result, nil
}

func getNewestCourseIDs(limit int, exclude []int64) ([]int64, error) {
	if limit <= 0 {
		return []int64{}, nil
	}
	q := db.GetDB().Model(&Courses{}).Where("status = ?", "published")
	if len(exclude) > 0 {
		q = q.Where("id NOT IN ?", exclude)
	}
	result := make([]int64, 0, limit)
	if err := q.Order("created_at DESC").Order("id DESC").Limit(limit).Pluck("id", &result).Error; err != nil && err != gorm.ErrRecordNotFound {
		return nil, err
	}
	return result, nil
}

func mergeUniqueInterleave(a []int64, b []int64, limit int) []int64 {
	result := make([]int64, 0, limit)
	seen := make(map[int64]struct{}, limit)
	i, j := 0, 0
	for len(result) < limit && (i < len(a) || j < len(b)) {
		if i < len(a) {
			if _, ok := seen[a[i]]; !ok {
				result = append(result, a[i])
				seen[a[i]] = struct{}{}
				if len(result) >= limit {
					break
				}
			}
			i++
		}
		if j < len(b) {
			if _, ok := seen[b[j]]; !ok {
				result = append(result, b[j])
				seen[b[j]] = struct{}{}
				if len(result) >= limit {
					break
				}
			}
			j++
		}
	}
	return result
}

func mixByRatio(personal []int64, global []int64, total int, personalBatch int, globalBatch int) []int64 {
	result := make([]int64, 0, total)
	seen := make(map[int64]struct{}, total)
	pi, gi := 0, 0

	appendFrom := func(source []int64, idx *int, count int) int {
		added := 0
		for *idx < len(source) && added < count && len(result) < total {
			id := source[*idx]
			*idx = *idx + 1
			if _, ok := seen[id]; ok {
				continue
			}
			result = append(result, id)
			seen[id] = struct{}{}
			added++
		}
		return added
	}

	for len(result) < total && (pi < len(personal) || gi < len(global)) {
		pAdded := appendFrom(personal, &pi, personalBatch)
		gAdded := appendFrom(global, &gi, globalBatch)
		if pAdded == 0 && gAdded == 0 {
			break
		}
		if pAdded == 0 {
			_ = appendFrom(global, &gi, personalBatch)
		}
		if gAdded == 0 {
			_ = appendFrom(personal, &pi, globalBatch)
		}
	}
	return result
}

func appendUnique(base []int64, extras []int64, limit int) []int64 {
	seen := make(map[int64]struct{}, len(base))
	for _, id := range base {
		seen[id] = struct{}{}
	}
	for _, id := range extras {
		if len(base) >= limit {
			break
		}
		if _, ok := seen[id]; ok {
			continue
		}
		base = append(base, id)
		seen[id] = struct{}{}
	}
	return base
}

func deterministicShuffle(ids []int64, seed int64) []int64 {
	out := make([]int64, len(ids))
	copy(out, ids)
	r := rand.New(rand.NewSource(seed))
	r.Shuffle(len(out), func(i int, j int) {
		out[i], out[j] = out[j], out[i]
	})
	return out
}
