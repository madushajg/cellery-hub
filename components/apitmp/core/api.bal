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

import ballerina/config;
import ballerina/http;
import ballerina/log;
import ballerina/mime;
import ballerina/openapi;
import cellery_hub_api/gen;
import cellery_hub_api/filter;
import cellery_hub_api/constants;
import ballerina/io;

http:ServiceEndpointConfiguration celleryHubAPIEPConfig = {
    secureSocket: {
        certFile: config:getAsString("security.certfile"),
        keyFile: config:getAsString("security.keyfile")
    },
    filters: [
        new filter:validateRequestFilter(),
        new filter:CaptchaRequestFilter()
    ]
};

listener http:Listener ep = new(9090, config = celleryHubAPIEPConfig);

@openapi:ServiceInfo {
    title: "Cellery Hub API",
    description: "Cellery Hub API",
    serviceVersion: "0.1.0",
    contact: {
        name: "",
        email: "architecture@wso2.com",
        url: ""
    },
    license: {
        name: "Apache 2.0",
        url: "http://www.apache.org/licenses/LICENSE-2.0"
    }
}
@http:ServiceConfig {
    basePath: "/api/0.1.0",
    cors: {
        allowOrigins: [config:getAsString("portal.publicurl")],
        allowCredentials: true
    }
}
service CelleryHubAPI on ep {

    @openapi:ResourceInfo {
        summary: "Ping the API",
        description: "Ping the API to validate",
        parameters: [
        {
            name: "validateUser",
            inInfo: "query",
            paramType: "boolean",
            description: "If true check whether the user is valid",
            allowEmptyValue: ""
        }
        ]
    }
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/"
    }
    resource function ping(http:Caller outboundEp, http:Request _getHealthReq) returns error? {
        map<string> queryParams = _getHealthReq.getQueryParams();
        boolean validateUser = false;
        if (queryParams.hasKey(constants:VALIDATE_USER)) {
            boolean | error validateUserQueryParam = boolean.convert(queryParams.validateUser);
            if (validateUserQueryParam is boolean) {
                validateUser = validateUserQueryParam;
            }
        }

        int statusCode = http:OK_200;
        json payload = {
            status: "healthy"
        };
        if (validateUser) {
            if (_getHealthReq.hasHeader(constants:AUTHENTICATED_USER)) {
                payload.isUserSessionValid = true;
            } else {
                statusCode = http:UNAUTHORIZED_401;
                payload.isUserSessionValid = false;
            }
        }

        http:Response _getHealthRes = new;
        _getHealthRes.statusCode = statusCode;
        _getHealthRes.setJsonPayload(payload);
        error? x = outboundEp->respond(_getHealthRes);
    }

    @openapi:ResourceInfo {
        summary: "Retrieve organizations",
        description: "Retrieve organizations",
        parameters: [
        {
            name: "orgName",
            inInfo: "query",
            paramType: "string",
            description: "Name of the organization",
            allowEmptyValue: ""
        },
        {
            name: "limit",
            inInfo: "query",
            paramType: "int",
            description: "Number of results returned for pagination",
            required: true,
            allowEmptyValue: ""
        },
        {
            name: "offset",
            inInfo: "query",
            paramType: "int",
            description: "Offset of the result set returned for pagination",
            required: true,
            allowEmptyValue: ""
        }
        ]
    }
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/orgs"
    }
    resource function listOrgs(http:Caller outboundEp, http:Request _listOrgsReq) returns error? {
        map<string> queryParams = _listOrgsReq.getQueryParams();
        int offset = 0;
        int resultLimit = 10;
        string orgName = "%";
        if (queryParams.hasKey(constants:OFFSET)) {
            int | error offsetQueryParam = int.convert(queryParams.offset);
            if (offsetQueryParam is int) {
                offset = offsetQueryParam;
            }
        }
        if (queryParams.hasKey(constants:RESULT_LIMIT)) {
            int | error resultLimitQueryParam = int.convert(queryParams.
            resultLimit);
            if (resultLimitQueryParam is int) {
                resultLimit = resultLimitQueryParam;
                if (resultLimit > 25) {
                    log:printDebug(io:sprintf("Requested result limit exeeded 25. Hense reset resultLimit to 25"));
                    resultLimit = 25;
                }
            }
        }
        if (queryParams.hasKey(constants:ORG_NAME)) {
            log:printDebug("orgName is present");
            orgName = queryParams.orgName;
            orgName = orgName.replace("*", "%");
        }
        http:Response _listOrgsRes = listOrgs(_listOrgsReq, orgName, offset, resultLimit);
        error? x = outboundEp->respond(_listOrgsRes);
    }

    @openapi:ResourceInfo {
        summary: "Get tokens",
        parameters: [
        {
            name: "authCode",
            inInfo: "query",
            paramType: "string",
            description: "Auth code retrieved from a OIDC provider",
            required: true,
            allowEmptyValue: ""
        },
        {
            name: "callbackUrl",
            inInfo: "query",
            paramType: "string",
            description: "callback Url used in the OIDC flow",
            required: true,
            allowEmptyValue: ""
        }
        ]
    }
    @http:ResourceConfig {
        methods: ["GET", "POST"],
        path: "/auth/token"
    }
    resource function getTokens(http:Caller outboundEp, http:Request _getTokensReq) returns error? {
        http:Response _getTokensRes;
        if ("get".equalsIgnoreCase(_getTokensReq.method)) {
            log:printDebug("Recieved a get request to token endpoint. Interpretting it as auth code reqeust");
            _getTokensRes = getTokens(_getTokensReq);
        } else {
            log:printDebug("Recieved a post request to token endpoint. Assuming token exchange request");
            _getTokensRes = exchangeTokensWithJWTGrant(_getTokensReq);
        }
        error? x = outboundEp->respond(_getTokensRes);
    }

     @http:ResourceConfig {
        methods: ["GET", "POST"],
        path: "/auth/revoke"
    }
    resource function revokeToken(http:Caller outboundEp, http:Request _revokeReqeust) returns error? {
        http:Response _revokeTokensRes;
    
        if ("get".equalsIgnoreCase(_revokeReqeust.method)) {
            log:printDebug("Recieved a get request to revoke endpoint. Logging out");
            _revokeTokensRes = revokeToken(_revokeReqeust, true);
        } else {
            log:printDebug("Recieved a post request to revoke endpoint. Assuming revocation for CLI token");
            _revokeTokensRes = revokeToken(_revokeReqeust, false);
        } 
        error? x = outboundEp->respond(_revokeTokensRes);
    }

    @openapi:ResourceInfo {
        summary: "Create organization"
    }
    @http:ResourceConfig {
        methods: ["POST"],
        path: "/orgs",
        body: "_createOrgBody"
    }
    resource function createOrg(http:Caller outboundEp, http:Request _createOrgReq, gen:OrgCreateRequest _createOrgBody) returns error? {
        http:Response _createOrgRes = createOrg(_createOrgReq, untaint _createOrgBody);
        error? x = outboundEp->respond(_createOrgRes);
    }

    @openapi:ResourceInfo {
        summary: "Get a specific organization",
        parameters: [
        {
            name: "orgName",
            inInfo: "path",
            paramType: "string",
            description: "Name of the organization",
            required: true,
            allowEmptyValue: ""
        }
        ]
    }
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/orgs/{orgName}"
    }
    resource function getOrg(http:Caller outboundEp, http:Request _getOrgReq, string orgName) returns error? {
        http:Response _getOrgRes = getOrg(_getOrgReq, untaint orgName);
        error? x = outboundEp->respond(_getOrgRes);
    }

    @openapi:ResourceInfo {
        summary: "Get a specific Image",
        parameters: [
        {
            name: "orgName",
            inInfo: "path",
            paramType: "string",
            description: "Name of the organization which the image belogs to",
            required: true,
            allowEmptyValue: ""
        },
        {
            name: "imageName",
            inInfo: "path",
            paramType: "string",
            description: "Name of the image",
            required: true,
            allowEmptyValue: ""
        }
        ]
    }
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/images/{orgName}/{imageName}"
    }
    resource function getImage(http:Caller outboundEp, http:Request _getImageReq, string orgName, string imageName)
    returns error? {
        http:Response _getImageRes = getImageByImageName(_getImageReq, untaint orgName, untaint imageName);
        error? x = outboundEp->respond(_getImageRes);
    }


    @openapi:ResourceInfo {
        summary: "Get a specific Image with versions",
        parameters: [
        {
            name: "orgName",
            inInfo: "path",
            paramType: "string",
            description: "Name of the organization which the image belogs to",
            required: true,
            allowEmptyValue: ""
        },
        {
            name: "imageName",
            inInfo: "path",
            paramType: "string",
            description: "Name of the image",
            required: true,
            allowEmptyValue: ""
        }
        ]
    }
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/artifacts/{orgName}/{imageName}"
    }
    resource function listArtifacts(http:Caller outboundEp, http:Request _getImageReq, string orgName, string imageName)
    returns error? {
        map<string> queryParams = _getImageReq.getQueryParams();
        int offset = 0;
        int resultLimit = 10;
        string artifactVersion = "%";
        if (queryParams.hasKey(constants:OFFSET)) {
            int | error offsetQueryParam = int.convert(queryParams.offset);
            if (offsetQueryParam is int) {
                offset = offsetQueryParam;
            }
        }
        if (queryParams.hasKey(constants:RESULT_LIMIT)) {

            int | error resultLimitQueryParam = int.convert(queryParams.
            resultLimit);
            if (resultLimitQueryParam is int) {
                resultLimit = resultLimitQueryParam;
            }
        }
        if (queryParams.hasKey(constants:ARTIFACT_VERSION)) {
            log:printDebug("artifactVersion is present");
            artifactVersion = queryParams.artifactVersion;
            artifactVersion = artifactVersion.replace("*", "%");
        }
        http:Response _getImageRes = getArtifactsOfImage(_getImageReq, untaint orgName, untaint imageName, untaint artifactVersion,
        untaint offset, resultLimit);
        error? x = outboundEp->respond(_getImageRes);
    }

    @openapi:ResourceInfo {
        summary: "Get a specific artifact",
        parameters: [
        {
            name: "orgName",
            inInfo: "path",
            paramType: "string",
            description: "Name of the organization",
            required: true,
            allowEmptyValue: ""
        },
        {
            name: "imageName",
            inInfo: "path",
            paramType: "string",
            description: "Name of the image",
            required: true,
            allowEmptyValue: ""
        },
        {
            name: "artifactVersion",
            inInfo: "path",
            paramType: "string",
            description: "Version of the artifact",
            required: true,
            allowEmptyValue: ""
        }
        ]
    }
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/artifacts/{orgName}/{imageName}/{artifactVersion}"
    }
    resource function getArtifact(http:Caller outboundEp, http:Request _getArtifactReq, string orgName, string imageName, string artifactVersion)
    returns error? {
        http:Response _getArtifactRes = getArtifact(_getArtifactReq, untaint orgName, untaint imageName, untaint artifactVersion);
        error? x = outboundEp->respond(_getArtifactRes);
    }

    @openapi:ResourceInfo {
        summary: "Get list of members in an organization",
        parameters: [
        {
            name: "orgName",
            inInfo: "path",
            paramType: "string",
            description: "Name of the organization",
            required: true,
            allowEmptyValue: ""
        }
        ]
    }
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/users/orgs/{orgName}"
    }
    resource function getOrgUsers(http:Caller outboundEp, http:Request _orgUserRequest, string orgName) returns error? {

        map<string> queryParams = _orgUserRequest.getQueryParams();
        int offset = 0;
        int resultLimit = 10;
        if (queryParams.hasKey(constants:OFFSET)) {
            int | error offsetQueryParam = int.convert(queryParams.offset);
            if (offsetQueryParam is int) {
                offset = offsetQueryParam;
            }
        }
        if (queryParams.hasKey(constants:RESULT_LIMIT)) {

            int | error resultLimitQueryParam = int.convert(queryParams.resultLimit);
            if (resultLimitQueryParam is int) {
                if (resultLimit < 50) {
                    resultLimit = resultLimitQueryParam;
                } else {
                    log:printError("Limit exeeds maximum limit allowed for results: " + resultLimit);
                }
            }
        }
        http:Response _getArtifactRes = getOrganizationUsers(_orgUserRequest, untaint orgName, offset, resultLimit);
        error? x = outboundEp->respond(_getArtifactRes);
    }

    @openapi:ResourceInfo {
        summary: "Get user\'s organizations",
        parameters: [
        {
            name: "orgName",
            inInfo: "query",
            paramType: "string",
            description: "Name of the organization",
            allowEmptyValue: ""
        },
        {
            name: "limit",
            inInfo: "query",
            paramType: "int",
            description: "Number of results returned for pagination",
            required: true,
            allowEmptyValue: ""
        },
        {
            name: "offset",
            inInfo: "query",
            paramType: "int",
            description: "Offset of the result set returned for pagination",
            required: true,
            allowEmptyValue: ""
        },
        {
            name: "userId",
            inInfo: "path",
            paramType: "string",
            description: "UserId of the user",
            required: true,
            allowEmptyValue: ""
        }
        ]
    }
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/orgs/users/{userId}"
    }
    resource function getUserOrgs(http:Caller outboundEp, http:Request _getUserOrgsReq, string userId) returns error? {
        map<string> queryParams = _getUserOrgsReq.getQueryParams();
        int offset = 0;
        int resultLimit = 10;
        string orgName = "%";
        if (queryParams.hasKey(constants:OFFSET)) {
            int | error offsetQueryParam = int.convert(queryParams.offset);
            if (offsetQueryParam is int) {
                offset = offsetQueryParam;
            }
        }
        if (queryParams.hasKey(constants:RESULT_LIMIT)) {
            int | error resultLimitQueryParam = int.convert(queryParams.
            resultLimit);
            if (resultLimitQueryParam is int) {
                resultLimit = resultLimitQueryParam;
                if (resultLimit > 25) {
                    log:printDebug(io:sprintf("Requested result limit exeeded 25. Hense reset resultLimit to 25"));
                    resultLimit = 25;
                }
            }
        }
        if (queryParams.hasKey(constants:ORG_NAME)) {
            log:printDebug("orgName is present");
            orgName = queryParams.orgName;
            orgName = orgName.replace("*", "%");
        }
        http:Response _getUserOrgsRes = getUserOrgs(_getUserOrgsReq, userId, orgName, offset, resultLimit);
        error? x = outboundEp->respond(_getUserOrgsRes);
    }

    @openapi:ResourceInfo {
        summary: "Search images of a specific organization",
        parameters: [
        {
            name: "orgName",
            inInfo: "path",
            paramType: "string",
            description: "Name of the organization",
            required: true,
            allowEmptyValue: ""
        },
        {
            name: "imageName",
            inInfo: "query",
            paramType: "string",
            description: "Name of the Image",
            allowEmptyValue: ""
        },
        {
            name: "orderBy",
            inInfo: "query",
            paramType: "string",
            description: "Enum to oder result",
            required: true,
            allowEmptyValue: ""
        },
        {
            name: "limit",
            inInfo: "query",
            paramType: "int",
            description: "Number of results returned for pagination",
            required: true,
            allowEmptyValue: ""
        },
        {
            name: "offset",
            inInfo: "query",
            paramType: "int",
            description: "Offset of the result set returned for pagination",
            required: true,
            allowEmptyValue: ""
        }
        ]
    }
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/images/{orgName}"
    }
    resource function listOrgImages(http:Caller outboundEp, http:Request _listOrgImagesReq, string orgName) returns error? {
        map<string> queryParams = _listOrgImagesReq.getQueryParams();
        int offset = 0;
        int resultLimit = 10;
        string imageName = "%";
        string orderBy = constants:PULL_COUNT;
        if (queryParams.hasKey(constants:OFFSET)) {
            int | error offsetQueryParam = int.convert(queryParams.offset);
            if (offsetQueryParam is int) {
                offset = offsetQueryParam;
            }
        }
        if (queryParams.hasKey(constants:RESULT_LIMIT)) {
            int | error resultLimitQueryParam = int.convert(queryParams.
            resultLimit);
            if (resultLimitQueryParam is int) {
                resultLimit = resultLimitQueryParam;
                if (resultLimit > 25) {
                    log:printDebug(io:sprintf("Requested result limit exeeded 25. Hense reset resultLimit to 25"));
                    resultLimit = 25;
                }
            }
        }
        if (queryParams.hasKey(constants:IMAGE_NAME)) {
            log:printDebug("imageName is present");
            imageName = queryParams.imageName;
            imageName = imageName.replace("*", "%");
        }
        if (queryParams.hasKey(constants:ORDER_BY)) {
            orderBy = queryParams.orderBy;
            if (orderBy.equalsIgnoreCase("last-updated")) {
                orderBy = constants:UPDATED_DATE;
            } else {
                orderBy = constants:PULL_COUNT;
            }
        }
        http:Response _listOrgImagesRes = listOrgImages(_listOrgImagesReq, orgName, imageName, untaint orderBy, untaint offset, untaint resultLimit);
        error? x = outboundEp->respond(_listOrgImagesRes);
    }

    @openapi:ResourceInfo {
        summary: "Search images of any organization",
        parameters: [
        {
            name: "orgName",
            inInfo: "query",
            paramType: "string",
            description: "Name of the organization",
            allowEmptyValue: ""
        },
        {
            name: "imageName",
            inInfo: "query",
            paramType: "string",
            description: "Name of the Image",
            allowEmptyValue: ""
        },
        {
            name: "orderBy",
            inInfo: "query",
            paramType: "string",
            description: "Enum to oder result",
            required: true,
            allowEmptyValue: ""
        },
        {
            name: "limit",
            inInfo: "query",
            paramType: "int",
            description: "Number of results returned for pagination",
            required: true,
            allowEmptyValue: ""
        },
        {
            name: "offset",
            inInfo: "query",
            paramType: "int",
            description: "Offset of the result set returned for pagination",
            required: true,
            allowEmptyValue: ""
        }
        ]
    }
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/images"
    }
    resource function listImages(http:Caller outboundEp, http:Request _listImagesReq) returns error? {
        map<string> queryParams = _listImagesReq.getQueryParams();
        int offset = 0;
        int resultLimit = 10;
        string orgName = "%";
        string imageName = "%";
        string orderBy = constants:PULL_COUNT;
        if (queryParams.hasKey(constants:OFFSET)) {
            int | error offsetQueryParam = int.convert(queryParams.offset);
            if (offsetQueryParam is int) {
                offset = offsetQueryParam;
            }
        }
        if (queryParams.hasKey(constants:RESULT_LIMIT)) {
            int | error resultLimitQueryParam = int.convert(queryParams.
            resultLimit);
            if (resultLimitQueryParam is int) {
                resultLimit = resultLimitQueryParam;
                if (resultLimit > 25) {
                    log:printDebug(io:sprintf("Requested result limit exeeded 25. Hense reset resultLimit to 25"));
                    resultLimit = 25;
                }
            }
        }
        if (queryParams.hasKey(constants:ORG_NAME)) {
            log:printDebug("orgName is present");
            orgName = queryParams.orgName;
            orgName = orgName.replace("*", "%");
        }
        if (queryParams.hasKey(constants:IMAGE_NAME)) {
            log:printDebug("imageName is present");
            imageName = queryParams.imageName;
            imageName = imageName.replace("*", "%");
        }
        if (queryParams.hasKey(constants:ORDER_BY)) {
            orderBy = queryParams.orderBy;
            if (orderBy.equalsIgnoreCase("last-updated")) {
                orderBy = constants:UPDATED_DATE;
            } else {
                orderBy = constants:PULL_COUNT;
            }
        }
        http:Response _listImagesRes = listImages(_listImagesReq, orgName, imageName, untaint orderBy, untaint offset, untaint resultLimit);
        error? x = outboundEp->respond(_listImagesRes);
    }

    @openapi:ResourceInfo {
        summary: "Update an existing image",
        parameters: [
        {
            name: "orgName",
            inInfo: "path",
            paramType: "string",
            description: "Name of the organization",
            required: true,
            allowEmptyValue: ""
        },
        {
            name: "imageName",
            inInfo: "path",
            paramType: "string",
            description: "Name of the image",
            required: true,
            allowEmptyValue: ""
        }
        ]
    }
    @http:ResourceConfig {
        methods: ["PUT"],
        path: "/images/{orgName}/{imageName}",
        body: "_updateImageBody"
    }
    resource function updateImage(http:Caller outboundEp, http:Request _updateImageReq, string orgName, string imageName,
    gen:ImageUpdateRequest _updateImageBody) returns error? {
        http:Response _updateImageRes = updateImage(_updateImageReq, orgName, imageName, _updateImageBody);
        error? x = outboundEp->respond(_updateImageRes);
    }

    @openapi:ResourceInfo {
        summary: "Update an existing artifact",
        parameters: [
        {
            name: "orgName",
            inInfo: "path",
            paramType: "string",
            description: "Name of the organization",
            required: true,
            allowEmptyValue: ""
        },
        {
            name: "imageName",
            inInfo: "path",
            paramType: "string",
            description: "Name of the image",
            required: true,
            allowEmptyValue: ""
        },
        {
            name: "artifactVersion",
            inInfo: "path",
            paramType: "string",
            description: "Version of the artifact",
            required: true,
            allowEmptyValue: ""
        }
        ]
    }
    @http:ResourceConfig {
        methods: ["PUT"],
        path: "/artifacts/{orgName}/{imageName}/{artifactVersion}",
        body: "_updateArtifactBody"
    }
    resource function updateArtifact(http:Caller outboundEp, http:Request _updateArtifactReq, string orgName, string imageName, string artifactVersion,
    gen:ArtifactUpdateRequest _updateArtifactBody) returns error? {
        http:Response _updateArtifactRes = updateArtifact(_updateArtifactReq, orgName, imageName, artifactVersion, _updateArtifactBody);
        error? x = outboundEp->respond(_updateArtifactRes);
    }

    @openapi:ResourceInfo {
        summary: "Update an existing organization",
        parameters: [
        {
            name: "orgName",
            inInfo: "path",
            paramType: "string",
            description: "Name of the organization",
            required: true,
            allowEmptyValue: ""
        }
        ]
    }
    @http:ResourceConfig {
        methods: ["PUT"],
        path: "/orgs/{orgName}",
        body: "_updateOrganizationBody"
    }
    resource function updateOrganization(http:Caller outboundEp, http:Request _updateOrganizationReq, string orgName,
    gen:OrgUpdateRequest _updateOrganizationBody) returns error? {
        http:Response _updateOrganizationRes = updateOrganization(_updateOrganizationReq, orgName, _updateOrganizationBody);
        error? x = outboundEp->respond(_updateOrganizationRes);
    }

    @openapi:ResourceInfo {
        summary: "Find images which user is the first author",
        parameters: [
        {
            name: "userId",
            inInfo: "path",
            paramType: "string",
            description: "UserId of the user",
            required: true,
            allowEmptyValue: ""
        },
        {
            name: "orgName",
            inInfo: "query",
            paramType: "string",
            description: "Name of the organization",
            allowEmptyValue: ""
        },
        {
            name: "imageName",
            inInfo: "query",
            paramType: "string",
            description: "Name of the Image",
            allowEmptyValue: ""
        },
        {
            name: "orderBy",
            inInfo: "query",
            paramType: "string",
            description: "Enum to oder result",
            required: true,
            allowEmptyValue: ""
        },
        {
            name: "limit",
            inInfo: "query",
            paramType: "int",
            description: "Number of results returned for pagination",
            required: true,
            allowEmptyValue: ""
        },
        {
            name: "offset",
            inInfo: "query",
            paramType: "int",
            description: "Offset of the result set returned for pagination",
            required: true,
            allowEmptyValue: ""
        }
        ]
    }
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/images/users/{userId}"
    }
    resource function listUserImages(http:Caller outboundEp, http:Request _listUserImagesReq, string userId) returns error? {
        map<string> queryParams = _listUserImagesReq.getQueryParams();
        int offset = 0;
        int resultLimit = 10;
        string orgName = "%";
        string imageName = "%";
        string orderBy = constants:PULL_COUNT;
        if (queryParams.hasKey(constants:OFFSET)) {
            int | error offsetQueryParam = int.convert(queryParams.offset);
            if (offsetQueryParam is int) {
                offset = offsetQueryParam;
            }
        }
        if (queryParams.hasKey(constants:RESULT_LIMIT)) {
            int | error resultLimitQueryParam = int.convert(queryParams.
            resultLimit);
            if (resultLimitQueryParam is int) {
                resultLimit = resultLimitQueryParam;
                if (resultLimit > 25) {
                    log:printDebug(io:sprintf("Requested result limit exeeded 25. Hense reset resultLimit to 25"));
                    resultLimit = 25;
                }
            }
        }
        if (queryParams.hasKey(constants:ORG_NAME)) {
            log:printDebug("orgName is present");
            orgName = queryParams.orgName;
            orgName = orgName.replace("*", "%");
        }
        if (queryParams.hasKey(constants:IMAGE_NAME)) {
            log:printDebug("imageName is present");
            imageName = queryParams.imageName;
            imageName = imageName.replace("*", "%");
        }
        if (queryParams.hasKey(constants:ORDER_BY)) {
            orderBy = queryParams.orderBy;
            if (orderBy.equalsIgnoreCase("last-updated")) {
                orderBy = constants:UPDATED_DATE;
            } else {
                orderBy = constants:PULL_COUNT;
            }
        }

        http:Response _listUserImagesRes = listUserImages(_listUserImagesReq, userId, orgName, imageName, untaint orderBy, 
        untaint offset, untaint resultLimit);
        error? x = outboundEp->respond(_listUserImagesRes);
    }

    @openapi:ResourceInfo {
        summary: "Delete an artifact",
        parameters: [
            {
                name: "orgName",
                inInfo: "path",
                paramType: "string",
                description: "Name of the organization",
                required: true,
                allowEmptyValue: ""
            },
            {
                name: "imageName",
                inInfo: "path",
                paramType: "string",
                description: "Name of the image",
                required: true,
                allowEmptyValue: ""
            },
            {
                name: "artifactVersion",
                inInfo: "path",
                paramType: "string",
                description: "Version of the artifact",
                required: true,
                allowEmptyValue: ""
            }
        ]
    }
    @http:ResourceConfig {
        methods:["DELETE"],
        path:"/artifacts/{orgName}/{imageName}/{artifactVersion}"
    }
    resource function deleteArtifact (http:Caller outboundEp, http:Request _deleteArtifactReq, string orgName, string imageName, string artifactVersion)
    returns error? {
        http:Response _deleteArtifactRes = deleteArtifact(_deleteArtifactReq, orgName, imageName, artifactVersion);
        error? x = outboundEp->respond(_deleteArtifactRes);
    }

    @openapi:ResourceInfo {
        summary: "Delete an image",
        parameters: [
            {
                name: "orgName",
                inInfo: "path",
                paramType: "string",
                description: "Name of the organization",
                required: true,
                allowEmptyValue: ""
            },
            {
                name: "imageName",
                inInfo: "path",
                paramType: "string",
                description: "Name of the image",
                required: true,
                allowEmptyValue: ""
            }
        ]
    }
    @http:ResourceConfig {
        methods:["DELETE"],
        path:"/images/{orgName}/{imageName}"
    }
    resource function deleteImage (http:Caller outboundEp, http:Request _deleteImageReq, string orgName, string imageName) returns error? {
        http:Response _deleteImageRes = deleteImage(_deleteImageReq, orgName, imageName);
        error? x = outboundEp->respond(_deleteImageRes);
    }

    @openapi:ResourceInfo {
        summary: "Delete an organization",
        parameters: [
            {
                name: "orgName",
                inInfo: "path",
                paramType: "string",
                description: "Name of the organization",
                required: true,
                allowEmptyValue: ""
            }
        ]
    }
    @http:ResourceConfig {
        methods:["DELETE"],
        path:"/orgs/{orgName}"
    }
    resource function deleteOrganization (http:Caller outboundEp, http:Request _deleteOrganizationReq, string orgName) returns error? {
        http:Response _deleteOrganizationRes = deleteOrganization(_deleteOrganizationReq, orgName);
        error? x = outboundEp->respond(_deleteOrganizationRes);
    }
}
