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

package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"

	"github.com/cellery-io/cellery-hub/components/docker-auth/pkg/db"

	"github.com/cellery-io/cellery-hub/components/docker-auth/pkg/auth"
)

type AuthParams struct {
	UName string
	Token string
}

func main() {
	authServerPort := os.Getenv("AUTH_SERVER_PORT")
	if len(authServerPort) == 0 {
		log.Printf("Failed to start the auth server : AUTH_SERVER_PORT environment variable is empty\n")
		os.Exit(auth.ErrorExitCode)
	}
	log.Printf("Auth server is starting on port %s", authServerPort)
	dbConnectionPool, err := db.GetDbConnectionPool()
	if err != nil {
		log.Printf("Failed to establish the MySql connection in Auth server : %s\n", err)
		os.Exit(auth.ErrorExitCode)
	}

	http.HandleFunc("/authentication", func(w http.ResponseWriter, r *http.Request) {
		log.Printf("Authentication endpoint reached")

		execId := r.Header.Get(auth.ExecIdHeaderName)
		decoder := json.NewDecoder(r.Body)
		var authParams AuthParams
		err := decoder.Decode(&authParams)
		if err != nil {
			log.Printf("[%s] Error occured while decoding POST request for authentication : %s", execId, err)
		}

		log.Printf("[%s] Authentication request received by server. Uname : %s, Token : %s", execId,
			authParams.UName, authParams.Token)

		authnRes := auth.Authenticate(authParams.UName, authParams.Token, execId)

		if authnRes == auth.SuccessExitCode {
			log.Printf("[%s] Authentication Success. Writing status code %d as response", execId,
				http.StatusOK)
			w.WriteHeader(http.StatusOK)
		} else {
			log.Printf("[%s] Authentication Failed. Writing status code %d as response", execId,
				http.StatusUnauthorized)
			w.WriteHeader(http.StatusUnauthorized)
		}
	})

	http.HandleFunc("/authorization", func(w http.ResponseWriter, r *http.Request) {
		log.Printf("Authorization endpoint reached")

		execId := r.Header.Get(auth.ExecIdHeaderName)
		body, err := ioutil.ReadAll(r.Body)
		if err != nil {
			log.Printf("[%s] Error occured while reading POST request for authorization : %s", execId, err)
		}

		log.Printf("[%s] Authorization request received by server", execId)

		authzRes := auth.Authorization(dbConnectionPool, string(body), execId)

		if authzRes == auth.SuccessExitCode {
			log.Printf("[%s] Authorization Success. Writing status code %d as response", execId,
				http.StatusOK)
			w.WriteHeader(http.StatusOK)
		} else {
			log.Printf("[%s] Authorization Failed. Writing status code %d as response", execId,
				http.StatusUnauthorized)
			w.WriteHeader(http.StatusUnauthorized)
		}
	})
	_ = http.ListenAndServe(fmt.Sprintf(":%s", authServerPort), nil)
}
