package main

import (
	"database/sql"
	"fmt"
	_ "github.com/go-sql-driver/mysql"
)

func main() {
	dsn := "root:root@tcp(127.0.0.1:3306)/moochub?parseTime=true"
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		panic(err)
	}
	defer db.Close()
	var c1, c2 int64
	if err := db.QueryRow("SELECT COUNT(*) FROM event_logs").Scan(&c1); err != nil {
		fmt.Println("event_logs err:", err)
		return
	}
	if err := db.QueryRow("SELECT COUNT(*) FROM event_stats_hourly").Scan(&c2); err != nil {
		fmt.Println("event_stats_hourly err:", err)
		return
	}
	fmt.Println("event_logs", c1)
	fmt.Println("event_stats_hourly", c2)
	rows, err := db.Query("SELECT bucket_hour, event_type, pv, uv FROM event_stats_hourly ORDER BY bucket_hour DESC LIMIT 10")
	if err != nil {
		fmt.Println("query err:", err)
		return
	}
	defer rows.Close()
	for rows.Next() {
		var bh string
		var et string
		var pv, uv int64
		_ = rows.Scan(&bh, &et, &pv, &uv)
		fmt.Println(bh, et, pv, uv)
	}
}
