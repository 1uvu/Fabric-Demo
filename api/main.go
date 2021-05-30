/*
将链码封装为 http 接口
*/

package main

import (
	"fmt"
	"html/template"
	"log"
	"net/http"
	"time"

	"github.com/1uvu/Fabric-Demo/serve"
)

type person struct {
	Name string
	Age  int8
}

func onlyForV2() serve.HandlerFunc {
	// 执行顺序: onlyForV2 -> handle -> logger
	return func(c *serve.Context) {
		// Start timer
		t := time.Now()
		// // if a server error occurred
		// c.Fail(500, "Internal Server Error")
		// Calculate resolution time
		log.Printf("[%d] %s in %v for group v2", c.StatusCode, c.Req.RequestURI, time.Since(t))
	}
}

func FormatAsDate(t time.Time) string {
	year, month, day := t.Date()
	return fmt.Sprintf("%d-%02d-%02d", year, month, day)
}

func main() {
	log.Println("http api.")

	g := serve.Default()
	g.SetFuncMap(template.FuncMap{
		"FormatAsDate": FormatAsDate,
	})
	g.LoadHTMLGlob("templates/*")
	g.Static("/assets", "./assets")
	// g.Static("/assets/css", "./css") // 会覆盖之前的路由中 `重复` 的文件，所有为了避免出现异常，建议谨慎设计路由

	p1 := &person{Name: "zjh", Age: 22}
	p2 := &person{Name: "qx", Age: 20}

	g.GET("/", func(c *serve.Context) {
		c.HTML(http.StatusOK, "css.html", serve.H{
			"title": "CSS",
		})
	})

	g.GET("/index", func(c *serve.Context) {
		c.HTML(http.StatusOK, "<h1>Index Page</h1>", nil)
		log.Printf("=[Status Code: %d]=[Method: %4s]=[Path: %6s]\n", c.StatusCode, c.Method, c.Path)
	})

	g.GET("/panic", func(c *serve.Context) {
		texts := []string{"panic"}
		c.String(http.StatusOK, texts[1])
	})

	g.GET("/person", func(c *serve.Context) {
		c.HTML(http.StatusOK, "array.html", serve.H{
			"title":       "Persons",
			"personArray": [2]*person{p1, p2},
		})
	})

	g.GET("/date", func(c *serve.Context) {
		c.HTML(http.StatusOK, "func.html", serve.H{
			"title": "Function Date",
			"now":   time.Date(2021, 5, 30, 0, 0, 0, 0, time.UTC),
		})
	})

	v1 := g.Group("/v1")
	{
		v1.GET("/", func(c *serve.Context) {
			c.HTML(http.StatusOK, "<h1>Hello serve</h1>", nil)
			log.Printf("=[Status Code: %d]=[Method: %4s]=[Path: %6s]\n", c.StatusCode, c.Method, c.Path)
		})

		v1.GET("/hello", func(c *serve.Context) {
			// expect /hello?name=zjh
			c.String(http.StatusOK, "hello %s, you're at %s\n", c.Query("name"), c.Path)
			log.Printf("=[Status Code: %d]=[Method: %4s]=[Path: %6s]\n", c.StatusCode, c.Method, c.Path)
		})
	}
	v2 := g.Group("/v2")
	v2.Use(onlyForV2()) // v2 group middleware
	{
		v2.GET("/hello/:name", func(c *serve.Context) {
			// expect /hello/zjh
			c.String(http.StatusOK, "hello %s, you're at %s\n", c.Param("name"), c.Path)
			log.Printf("=[Status Code: %d]=[Method: %4s]=[Path: %6s]\n", c.StatusCode, c.Method, c.Path)
		})
		v2.POST("/login", func(c *serve.Context) {
			c.JSON(http.StatusOK, serve.H{
				"username": c.PostForm("username"),
				"password": c.PostForm("password"),
			})
			log.Printf("=[Status Code: %d]=[Method: %4s]=[Path: %6s]\n", c.StatusCode, c.Method, c.Path)
		})

	}

	g.Run(":9999")
}
