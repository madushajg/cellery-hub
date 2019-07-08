/*
 * Copyright (c) 2019 WSO2 Inc. (http:www.wso2.org) All Rights Reserved.
 *
 * WSO2 Inc. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http:www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package db

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"strconv"
	"time"
)

//const (
//	MysqlUserEnvVar             = "MYSQL_USER"
//	MysqlPasswordEnvVar         = "MYSQL_PASSWORD"
//	MysqlHostEnvVar             = "MYSQL_HOST"
//	MysqlPortEnvVar             = "MYSQL_PORT"
//	MysqlDriver                 = "mysql"
//	MysqlDbName                 = "CELLERY_HUB"
//	maxOpenConnectionsEnvVar    = "MAX_OPEN_CONNECTIONS"
//	maxIdleConnectionsEnvVar    = "MAX_IDLE_CONNECTIONS"
//	connectionMaxLifetimeEnvVar = "MAX_LIFE_TIME"
//)

func GetDbConnectionPool() (*sql.DB, error) {
	dbDriver := MysqlDriver
	dbUser := os.Getenv(MysqlUserEnvVar)
	dbPass := os.Getenv(MysqlPasswordEnvVar)
	dbName := MysqlDbName
	host := os.Getenv(MysqlHostEnvVar)
	port := os.Getenv(MysqlPortEnvVar)
	dbPoolConfigurations, err := resolvePoolingConfigurations()
	if err != nil {
		log.Printf("No db connction pooling configurations found : %s", err)
		return nil, fmt.Errorf("failed to fetch db connection pooling configurations : %v", err)
	}

	conn := fmt.Sprint(dbUser, ":", dbPass, "@tcp(", host, ":", port, ")/"+dbName)
	log.Printf("Creating a new db connection pool: %v", conn)

	dbConnection, err := sql.Open(dbDriver, conn)

	if err != nil {
		log.Printf("Failed to create database connection pool: %s", err)
		return nil, fmt.Errorf("error occurred while establishing database connection pool "+
			" : %v", err)
	}
	log.Printf("DB connection pool established")

	dbConnection.SetMaxOpenConns(dbPoolConfigurations[maxOpenConnectionsEnvVar])
	dbConnection.SetMaxIdleConns(dbPoolConfigurations[maxIdleConnectionsEnvVar])
	dbConnection.SetConnMaxLifetime(time.Minute * time.Duration(dbPoolConfigurations[connectionMaxLifetimeEnvVar]))

	return dbConnection, nil
}

func resolvePoolingConfigurations() (map[string]int, error) {
	m := make(map[string]int)

	maxOpenConnections, err := strconv.Atoi(os.Getenv(maxOpenConnectionsEnvVar))
	if err != nil {
		log.Printf("Failed to convert max open connections string into integer : %s", err)
		return nil, fmt.Errorf("error occurred while converting max open connections string into integer "+
			" : %v", err)
	}
	m[maxOpenConnectionsEnvVar] = maxOpenConnections
	maxIdleConnections, err := strconv.Atoi(os.Getenv(maxIdleConnectionsEnvVar))
	if err != nil {
		log.Printf("Failed to convert max idle connections string into integer : %s", err)
		return nil, fmt.Errorf("error occurred while converting max idle connections string into integer "+
			" : %v", err)
	}
	m[maxIdleConnectionsEnvVar] = maxIdleConnections
	maxLifetime, err := strconv.Atoi(os.Getenv(connectionMaxLifetimeEnvVar))
	if err != nil {
		log.Printf("Failed to convert max lifetime string into integer : %s", err)
		return nil, fmt.Errorf("error occurred while converting max lifetime string into integer "+
			" : %v", err)
	}
	m[connectionMaxLifetimeEnvVar] = maxLifetime
	log.Printf("Fetched db connection pooling configurations. MaxOpenConns = %d, "+
		"MaxIdleConns = %d, MaxLifetime = %d", maxOpenConnections, maxIdleConnections, maxLifetime)

	return m, nil
}
