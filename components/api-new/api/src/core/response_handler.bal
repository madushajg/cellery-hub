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

import ballerina/http;
import cellery_hub_api/gen;
import cellery_hub_api/constants;

public function buildErrorResponse(int statusCode, int code, string message, string description) returns http:Response {
    http:Response res = new;
    gen:ErrorResponse errPassed = {
        code: code,
        message: message,
        description: description
    };
    var errJson = json.constructFrom(errPassed);
    if (errJson is json) {
        res.setJsonPayload(errJson);
        res.statusCode = statusCode;
    } else {
        res = buildUnknownErrorResponse();
    }
    return res;
}

function buildUnknownErrorResponse() returns http:Response {
    http:Response res = new;
    json errDefault = {
        code: constants:API_ERROR_CODE,
        message: "Unexpected error occurred",
        description: ""
    };
    res.setPayload(errDefault);
    res.statusCode = http:STATUS_INTERNAL_SERVER_ERROR;
    return res;
}

function buildSuccessResponse(json jsonResponse = null) returns http:Response {
    http:Response resp = new;
    resp.statusCode = http:STATUS_OK;
    resp.setJsonPayload(jsonResponse);
    return resp;
}
