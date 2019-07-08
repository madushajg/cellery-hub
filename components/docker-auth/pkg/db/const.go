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

const MysqlUserEnvVar = "MYSQL_USER"
const MysqlPasswordEnvVar = "MYSQL_PASSWORD"
const MysqlHostEnvVar = "MYSQL_HOST"
const MysqlPortEnvVar = "MYSQL_PORT"
const MysqlDriver = "mysql"
const MysqlDbName = "CELLERY_HUB"

//Environment variables for db connection pooling
const maxOpenConnectionsEnvVar = "MAX_OPEN_CONNECTIONS"
const maxIdleConnectionsEnvVar = "MAX_IDLE_CONNECTIONS"
const connectionMaxLifetimeEnvVar = "MAX_LIFE_TIME"
