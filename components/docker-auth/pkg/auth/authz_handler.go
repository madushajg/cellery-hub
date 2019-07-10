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

package auth

import (
	"database/sql"
	"log"
)

func Authorization(dbConn *sql.DB, accessToken string, execId string) int {
	log.Printf("[%s] Authorization logic handler reached and access will be validated\n", execId)
	isValid, err := ValidateAccess(dbConn, accessToken, execId)
	if err != nil {
		log.Printf("[%s] Error occurred while validating the user :%s\n", execId, err)
		return ErrorExitCode
	}
	if isValid {
		log.Printf("[%s] Authorized user. Access granted by authz handler\n", execId)
		return SuccessExitCode
	} else {
		log.Printf("[%s] User access denied by authz handler\n", execId)
		return ErrorExitCode
	}
}
