package controllers

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"MOOCHUB-server/config"
	"MOOCHUB-server/model"
	"MOOCHUB-server/utils"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

type QQController struct{}

type qqUserInfo struct {
	Nickname     string `json:"nickname"`
	FigureURLQQ1 string `json:"figureurl_qq_1"`
	FigureURLQQ2 string `json:"figureurl_qq_2"`
}

func (q QQController) Login(c *gin.Context) {
	appID := config.QQAppID()
	appKey := config.QQAppKey()
	if appID == "" || appKey == "" {
		ReturnError(c, 500, "QQ AppID/AppKey未配置")
		return
	}

	state := config.QQState()
	authURL := fmt.Sprintf(
		"https://graph.qq.com/oauth2.0/authorize?response_type=code&client_id=%s&redirect_uri=%s&scope=%s&state=%s",
		url.QueryEscape(appID),
		url.QueryEscape(config.QQRedirectURI()),
		url.QueryEscape("get_user_info"),
		url.QueryEscape(state),
	)
	c.Redirect(http.StatusFound, authURL)
}

func (q QQController) Callback(c *gin.Context) {
	code := c.Query("code")
	state := c.Query("state")
	if code == "" {
		ReturnError(c, 400, "缺少code")
		return
	}
	if expected := config.QQState(); expected != "" && state != "" && state != expected {
		ReturnError(c, 400, "state不匹配")
		return
	}

	token, err := qqExchangeToken(code)
	if err != nil {
		ReturnError(c, 400, "获取access_token失败："+err.Error())
		return
	}

	openID, _, err := qqGetOpenID(token)
	if err != nil {
		ReturnError(c, 400, "获取openid失败："+err.Error())
		return
	}

	info, err := qqGetUserInfo(token, openID)
	if err != nil {
		ReturnError(c, 400, "获取用户信息失败："+err.Error())
		return
	}

	user, err := findOrCreateQQUser(openID, info)
	if err != nil {
		ReturnError(c, 500, "创建用户失败："+err.Error())
		return
	}

	jwtToken, err := utils.GenerateToken(int(user.ID), user.Role)
	if err != nil {
		ReturnError(c, 500, "生成token失败")
		return
	}

	ReturnSuccess(c, 200, "QQ登录成功", gin.H{
		"user":  user,
		"token": jwtToken,
	}, 0)
}

func (q QQController) SDKLogin(c *gin.Context) {
	accessToken := c.DefaultPostForm("access_token", "")
	openIDFromClient := c.DefaultPostForm("openid", "")
	if accessToken == "" {
		ReturnError(c, 400, "缺少access_token")
		return
	}

	openID, _, err := qqGetOpenID(accessToken)
	if err != nil {
		ReturnError(c, 400, "获取openid失败："+err.Error())
		return
	}
	if openIDFromClient != "" && openIDFromClient != openID {
		ReturnError(c, 400, "openid不匹配")
		return
	}

	info, err := qqGetUserInfo(accessToken, openID)
	if err != nil {
		ReturnError(c, 400, "获取用户信息失败："+err.Error())
		return
	}

	user, err := findOrCreateQQUser(openID, info)
	if err != nil {
		ReturnError(c, 500, "创建用户失败："+err.Error())
		return
	}

	jwtToken, err := utils.GenerateToken(int(user.ID), user.Role)
	if err != nil {
		ReturnError(c, 500, "生成token失败")
		return
	}

	ReturnSuccess(c, 200, "QQ登录成功", gin.H{
		"user":  user,
		"token": jwtToken,
	}, 0)
}

func findOrCreateQQUser(openID string, info qqUserInfo) (model.Users, error) {
	username := "qq_" + openID
	user, err := model.GetUserByUsername(username)
	if err == nil {
		nickname := strings.TrimSpace(info.Nickname)
		avatar := strings.TrimSpace(info.FigureURLQQ2)
		if avatar == "" {
			avatar = strings.TrimSpace(info.FigureURLQQ1)
		}
		needUpdate := false
		if nickname != "" && nickname != user.Nickname {
			user.Nickname = nickname
			needUpdate = true
		}
		if avatar != "" && avatar != user.AvatarURL {
			user.AvatarURL = avatar
			needUpdate = true
		}
		if needUpdate {
			_ = model.UpdateUserProfile(user.ID, user.Nickname, user.AvatarURL)
		}
		return user, nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return model.Users{}, err
	}

	nickname := strings.TrimSpace(info.Nickname)
	if nickname == "" {
		nickname = "QQ用户"
	}
	avatar := strings.TrimSpace(info.FigureURLQQ2)
	if avatar == "" {
		avatar = strings.TrimSpace(info.FigureURLQQ1)
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(openID+time.Now().Format("20060102150405")), bcrypt.DefaultCost)
	if err != nil {
		return model.Users{}, err
	}

	user, err = model.UsersRegister(username, string(hash), nickname, "student")
	if err != nil {
		return model.Users{}, err
	}
	if avatar != "" || nickname != "" {
		_ = model.UpdateUserProfile(user.ID, nickname, avatar)
		user.Nickname = nickname
		user.AvatarURL = avatar
	}
	return user, nil
}

func qqExchangeToken(code string) (string, error) {
	appID := config.QQAppID()
	appKey := config.QQAppKey()
	if appID == "" || appKey == "" {
		return "", errors.New("QQ AppID/AppKey未配置")
	}

	tokenURL := fmt.Sprintf(
		"https://graph.qq.com/oauth2.0/token?grant_type=authorization_code&client_id=%s&client_secret=%s&code=%s&redirect_uri=%s",
		url.QueryEscape(appID),
		url.QueryEscape(appKey),
		url.QueryEscape(code),
		url.QueryEscape(config.QQRedirectURI()),
	)
	body, err := httpGet(tokenURL)
	if err != nil {
		return "", err
	}

	if strings.HasPrefix(body, "callback(") {
		return "", errors.New(body)
	}

	values, err := url.ParseQuery(body)
	if err != nil {
		return "", err
	}
	accessToken := values.Get("access_token")
	if accessToken == "" {
		return "", errors.New("access_token为空")
	}
	return accessToken, nil
}

func qqGetOpenID(accessToken string) (string, string, error) {
	openIDURL := fmt.Sprintf("https://graph.qq.com/oauth2.0/me?access_token=%s&unionid=1", url.QueryEscape(accessToken))
	body, err := httpGet(openIDURL)
	if err != nil {
		return "", "", err
	}
	jsonStr := strings.TrimSpace(body)
	if strings.HasPrefix(jsonStr, "callback(") {
		jsonStr = strings.TrimPrefix(jsonStr, "callback(")
		jsonStr = strings.TrimSuffix(jsonStr, ");")
		jsonStr = strings.TrimSuffix(jsonStr, ")")
	}

	var payload map[string]interface{}
	if err := json.Unmarshal([]byte(jsonStr), &payload); err != nil {
		return "", "", err
	}
	if errCode, ok := payload["error"]; ok {
		return "", "", fmt.Errorf("%v", errCode)
	}

	openID, _ := payload["openid"].(string)
	unionID, _ := payload["unionid"].(string)
	if openID == "" {
		return "", "", errors.New("openid为空")
	}
	return openID, unionID, nil
}

func qqGetUserInfo(accessToken, openID string) (qqUserInfo, error) {
	appID := config.QQAppID()
	if appID == "" {
		return qqUserInfo{}, errors.New("QQ AppID未配置")
	}

	infoURL := fmt.Sprintf(
		"https://graph.qq.com/user/get_user_info?access_token=%s&oauth_consumer_key=%s&openid=%s",
		url.QueryEscape(accessToken),
		url.QueryEscape(appID),
		url.QueryEscape(openID),
	)
	body, err := httpGet(infoURL)
	if err != nil {
		return qqUserInfo{}, err
	}

	var info qqUserInfo
	if err := json.Unmarshal([]byte(body), &info); err != nil {
		return qqUserInfo{}, err
	}
	return info, nil
}

func httpGet(target string) (string, error) {
	client := &http.Client{Timeout: 8 * time.Second}
	resp, err := client.Get(target)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	bs, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}
	return string(bs), nil
}
