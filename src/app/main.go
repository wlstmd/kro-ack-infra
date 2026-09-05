package main

import (
	"database/sql"
	"fmt"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
	_ "github.com/lib/pq"
)

type Customer struct {
	ID   string `json:"id" binding:"required"`
	Name string `json:"name" binding:"required"`
}

var db *sql.DB

func main() {
	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=require",
		os.Getenv("DB_HOST"), os.Getenv("DB_PORT"), os.Getenv("DB_USER"),
		os.Getenv("DB_PASSWORD"), os.Getenv("DB_NAME"),
	)

	var err error
	db, err = sql.Open("postgres", dsn)
	if err != nil {
		panic(err)
	}
	db.SetMaxOpenConns(10)

	if _, err := db.Exec(`CREATE TABLE IF NOT EXISTS customer (
		id   TEXT PRIMARY KEY,
		name TEXT NOT NULL
	)`); err != nil {
		fmt.Println("warning: failed to ensure customer table:", err)
	}

	r := gin.Default()

	r.GET("/healthz", func(c *gin.Context) {
		if err := db.Ping(); err != nil {
			c.JSON(http.StatusServiceUnavailable, gin.H{"status": "ok", "db": "disconnected"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"status": "ok", "db": "connected"})
	})

	r.GET("/v1/customer", func(c *gin.Context) {
		id := c.Query("id")
		if id == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "id query parameter is required"})
			return
		}
		var cust Customer
		err := db.QueryRow(`SELECT id, name FROM customer WHERE id = $1`, id).Scan(&cust.ID, &cust.Name)
		switch {
		case err == sql.ErrNoRows:
			c.JSON(http.StatusNotFound, gin.H{"error": "customer not found"})
		case err != nil:
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		default:
			c.JSON(http.StatusOK, cust)
		}
	})

	r.POST("/v1/customer", func(c *gin.Context) {
		var cust Customer
		if err := c.ShouldBindJSON(&cust); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		_, err := db.Exec(
			`INSERT INTO customer (id, name) VALUES ($1, $2)
			 ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name`,
			cust.ID, cust.Name,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusCreated, cust)
	})

	r.Run(":8080")
}
