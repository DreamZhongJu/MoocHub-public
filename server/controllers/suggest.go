package controllers

import (
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

type SuggestController struct{}

// SuggestResponse 定义搜索联想响应结构
type SuggestResponse struct {
	Query       string   `json:"query"`
	Suggestions []string `json:"suggestions"`
}

// GetSuggestions 调用AI服务的搜索联想API
func (sc *SuggestController) GetSuggestions(c *gin.Context) {
	query := c.DefaultQuery("q", "")
	nStr := c.DefaultQuery("n", "8")

	if query == "" {
		ReturnSuccess(c, 0, "请输入搜索词", SuggestResponse{
			Query:       query,
			Suggestions: []string{},
		}, 0)
		return
	}

	// 解析数量参数
	n, err := strconv.Atoi(nStr)
	if err != nil || n <= 0 {
		n = 8
	}
	if n > 20 {
		n = 20
	}

	// --- 正确构造 URL（参数编码）---
	baseURL := "http://127.0.0.1:8000/suggest"
	params := url.Values{}
	params.Set("q", query) // 会自动做 URL 编码（支持中文）
	params.Set("n", strconv.Itoa(n))
	aiURL := baseURL + "?" + params.Encode()

	// --- 带超时的 HTTP 客户端 ---
	client := &http.Client{Timeout: 3 * time.Second}

	req, err := http.NewRequest(http.MethodGet, aiURL, nil)
	if err != nil {
		ReturnError(c, 500, "创建请求失败: "+err.Error())
		return
	}
	req.Header.Set("Accept", "application/json")

	// 如果你的 FastAPI 需要简单鉴权（例如我之前示例里的 header: token）
	if token := os.Getenv("SUGGEST_API_TOKEN"); token != "" {
		req.Header.Set("token", token) // 与后端校验字段一致
	}

	resp, err := client.Do(req)
	if err != nil {
		ReturnError(c, 500, "无法连接到AI服务: "+err.Error())
		return
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)

	if resp.StatusCode != http.StatusOK {
		// 把后端返回的错误详情透传出来，便于排查
		ReturnError(c, resp.StatusCode, "AI服务错误: "+string(body))
		return
	}

	var suggestResp SuggestResponse
	if err := json.Unmarshal(body, &suggestResp); err != nil {
		ReturnError(c, 500, "解析AI服务响应失败: "+err.Error())
		return
	}

	ReturnSuccess(c, 0, "获取搜索建议成功", suggestResp, 0)
}
