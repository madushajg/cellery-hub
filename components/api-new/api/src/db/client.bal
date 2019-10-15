// ------------------------------------------------------------------------
//
// Copyright 2019 WSO2, Inc. (http://wso2.com)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License
//
// ------------------------------------------------------------------------
import ballerina/io;
import ballerina/config;
import ballerinax/java.jdbc;

jdbc:Client connection = new ({
        url: io:sprintf("jdbc:mysql://%s:%s/%s",config:getAsString("database.host"), config:getAsInt("database.port"),
        config:getAsString("database.default")),
        username: config:getAsString("database.user"),
        password: config:getAsString("database.password"),
        dbOptions: {
                useSSL: true,
                allowPublicKeyRetrieval: true
        }
});
