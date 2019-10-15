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

import ballerina/auth;
import ballerina/config;
import ballerina/http;

function getBasicAuthIDPClient(string username, string password) returns http:Client {
    auth:OutboundBasicAuthProvider outboundBasicAuthProvider = new({
        username: username,
        password: password
    });
    http:BasicAuthHandler outboundBasicAuthHandler = new(outboundBasicAuthProvider);

    http:Client basicAuthClientEP = new(config:getAsString("idp.endpoint"), {
        auth: {
            authHandler: outboundBasicAuthHandler
        },
        secureSocket: {
            trustStore: {
                path: config:getAsString("security.truststore"),
                password: config:getAsString("security.truststorepass")
            },
            verifyHostname: false
        }
    });
    return basicAuthClientEP;
}
