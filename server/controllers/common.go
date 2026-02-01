package controllers

import (
	"reflect"

	"github.com/fatih/structs"
	"github.com/gin-gonic/gin"
)

type JsonStruct struct {
	Code  int         `json:"Code"`
	Msg   interface{} `json:"msg"`
	Data  interface{} `json:"data"`
	Count int64       `json:"count"`
}

func ReturnSuccess(c *gin.Context, code int, msg interface{}, data interface{}, count int64) {
	// 自动结构体转 map[string]interface{}
	var processedData interface{}

	// 判断是否是 struct 或指向 struct 的指针
	val := reflect.ValueOf(data)
	if val.Kind() == reflect.Ptr {
		val = val.Elem()
	}

	if val.Kind() == reflect.Struct {
		processedData = structs.Map(data) // 使用 struct 字段名转 map
	} else {
		processedData = data // 非结构体保持原样
	}

	json := &JsonStruct{Code: code, Msg: msg, Data: processedData, Count: count}
	c.JSON(200, json)
}

func ReturnError(c *gin.Context, httpCode int, msg interface{}) {
	json := &JsonStruct{Code: httpCode, Msg: msg}
	c.JSON(httpCode, json)
}
