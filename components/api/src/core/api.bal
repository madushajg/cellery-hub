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
//import ballerina/openapi;
import cellery_hub_api/filter;
import cellery_hub_api/constants;
import cellery_hub_api/gen;
import ballerina/io;
import ballerina/stringutils;

http:ListenerConfiguration celleryHubAPIEPConfig = {
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

//@openapi:ServiceInfo {
//    contract: "/Users/madushagunasekara/go_workspace/src/github.com/cellery-io/cellery-hub/docker/api/target/src/core/resources/CelleryHubApi.yaml"
//}

@http:ServiceConfig {
    basePath: "/api/0.1.0",
    cors: {
        allowOrigins: [config:getAsString("portal.publicurl")],
        allowCredentials: true
    }
}
service CelleryHubAPI on ep {


    @http:ResourceConfig {
        methods: ["GET"],
        path: "/"
    }
    resource function ping(http:Caller outboundEp, http:Request _getHealthReq) returns error? {
        map<string[]> queryParams = _getHealthReq.getQueryParams();
        boolean validateUser = false;
        if (queryParams.hasKey(constants:VALIDATE_USER)) {
            boolean | error validateUserQueryParam = boolean.constructFrom(_getHealthReq.getQueryParamValue(constants:VALIDATE_USER));
            if (validateUserQueryParam is boolean) {
                validateUser = validateUserQueryParam;
            }
        }

        int statusCode = http:STATUS_OK;
        map<json> payload = {
            status: "healthy"
        };
        if (validateUser) {
            if (_getHealthReq.hasHeader(constants:AUTHENTICATED_USER)) {
                payload["isUserSessionValid"] = true;
            } else {
                statusCode = http:STATUS_UNAUTHORIZED;
                payload["isUserSessionValid"] = false;
            }
        }

        http:Response _getHealthRes = new;
        _getHealthRes.statusCode = statusCode;
        _getHealthRes.setJsonPayload(payload);
        error? x = outboundEp->respond(_getHealthRes);
    }

    @http:ResourceConfig {
        methods: ["GET"],
        path: "/orgs"
    }
    resource function listOrgs(http:Caller outboundEp, http:Request _listOrgsReq) returns error? {
        map<string[]> queryParams = _listOrgsReq.getQueryParams();
        int offset = 0;
        int resultLimit = 10;
        string orgName = "%";
        if (queryParams.hasKey(constants:OFFSET)) {
            int | error offsetQueryParam = int.constructFrom(_listOrgsReq.getQueryParamValue(constants:OFFSET));
            if (offsetQueryParam is int) {
                offset = offsetQueryParam;
            }
        }
        if (queryParams.hasKey(constants:RESULT_LIMIT)) {
            int | error resultLimitQueryParam = int.constructFrom(_listOrgsReq.getQueryParamValue(constants:RESULT_LIMIT));
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
            orgName = _listOrgsReq.getQueryParamValue(constants:ORG_NAME) ?: "";
            orgName = stringutils:replace(orgName, "*", "%");
        }
        http:Response _listOrgsRes = listOrgs(_listOrgsReq, orgName, offset, resultLimit);
        error? x = outboundEp->respond(_listOrgsRes);
    }

    @http:ResourceConfig {
        methods: ["GET", "POST"],
        path: "/auth/token"
    }
    resource function getTokens(http:Caller outboundEp, http:Request _getTokensReq) returns error? {
        http:Response _getTokensRes;
        if (stringutils:equalsIgnoreCase("get", _getTokensReq.method)) {
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
    
        if (stringutils:equalsIgnoreCase("get", _revokeReqeust.method)) {
            log:printDebug("Recieved a get request to revoke endpoint. Logging out");
            _revokeTokensRes = revokeToken(_revokeReqeust, true);
        } else {
            log:printDebug("Recieved a post request to revoke endpoint. Assuming revocation for CLI token");
            _revokeTokensRes = revokeToken(_revokeReqeust, false);
        } 
        error? x = outboundEp->respond(_revokeTokensRes);
    }

    @http:ResourceConfig {
        methods: ["POST"],
        path: "/orgs",
        body: "_createOrgBody"
    }
    resource function createOrg(http:Caller outboundEp, http:Request _createOrgReq, gen:OrgCreateRequest _createOrgBody) returns error? {
        http:Response _createOrgRes = createOrg(_createOrgReq, _createOrgBody);
        error? x = outboundEp->respond(_createOrgRes);
    }

    @http:ResourceConfig {
        methods: ["GET"],
        path: "/orgs/{orgName}"
    }
    resource function getOrg(http:Caller outboundEp, http:Request _getOrgReq, string orgName) returns error? {
        http:Response _getOrgRes = getOrg(_getOrgReq, orgName);
        error? x = outboundEp->respond(_getOrgRes);
    }

    @http:ResourceConfig {
        methods: ["GET"],
        path: "/images/{orgName}/{imageName}"
    }
    resource function getImage(http:Caller outboundEp, http:Request _getImageReq, string orgName, string imageName)
    returns error? {
        http:Response _getImageRes = getImageByImageName(_getImageReq, orgName, imageName);
        error? x = outboundEp->respond(_getImageRes);
    }

    @http:ResourceConfig {
        methods: ["GET"],
        path: "/artifacts/{orgName}/{imageName}"
    }
    resource function listArtifacts(http:Caller outboundEp, http:Request _getImageReq, string orgName, string imageName)
    returns error? {
        map<string[]> queryParams = _getImageReq.getQueryParams();
        int offset = 0;
        int resultLimit = 10;
        string artifactVersion = "%";
        if (queryParams.hasKey(constants:OFFSET)) {
            int | error offsetQueryParam = int.constructFrom(_getImageReq.getQueryParamValue(constants:OFFSET));
            if (offsetQueryParam is int) {
                offset = offsetQueryParam;
            }
        }
        if (queryParams.hasKey(constants:RESULT_LIMIT)) {
            int | error resultLimitQueryParam = int.constructFrom(_getImageReq.getQueryParamValue(constants:RESULT_LIMIT));
            if (resultLimitQueryParam is int) {
                resultLimit = resultLimitQueryParam;
            }
        }
        if (queryParams.hasKey(constants:ARTIFACT_VERSION)) {
            log:printDebug("artifactVersion is present");
            artifactVersion = _getImageReq.getQueryParamValue(constants:ARTIFACT_VERSION) ?: "";
            artifactVersion = stringutils:replace(artifactVersion, "*", "%");
        }
        http:Response _getImageRes = getArtifactsOfImage(_getImageReq, orgName, imageName, artifactVersion,
        offset, resultLimit);
        error? x = outboundEp->respond(_getImageRes);
    }


    @http:ResourceConfig {
        methods: ["GET"],
        path: "/artifacts/{orgName}/{imageName}/{artifactVersion}"
    }
    resource function getArtifact(http:Caller outboundEp, http:Request _getArtifactReq, string orgName, string imageName, string artifactVersion)
    returns error? {
        http:Response _getArtifactRes = getArtifact(_getArtifactReq, orgName, imageName, artifactVersion);
        error? x = outboundEp->respond(_getArtifactRes);
    }


    @http:ResourceConfig {
        methods: ["GET"],
        path: "/users/orgs/{orgName}"
    }
    resource function getOrgUsers(http:Caller outboundEp, http:Request _orgUserRequest, string orgName) returns error? {

        map<string[]> queryParams = _orgUserRequest.getQueryParams();
        int offset = 0;
        int resultLimit = 10;
        if (queryParams.hasKey(constants:OFFSET)) {
            int | error offsetQueryParam = int.constructFrom(_orgUserRequest.getQueryParamValue(constants:OFFSET));
            if (offsetQueryParam is int) {
                offset = offsetQueryParam;
            }
        }
        if (queryParams.hasKey(constants:RESULT_LIMIT)) {

            int | error resultLimitQueryParam = int.constructFrom(_orgUserRequest.getQueryParamValue(constants:RESULT_LIMIT));
            if (resultLimitQueryParam is int) {
                if (resultLimit < 50) {
                    resultLimit = resultLimitQueryParam;
                } else {
                    log:printError(io:sprintf("Limit exeeds maximum limit allowed for results: %d", resultLimit));
                }
            }
        }
        http:Response _getArtifactRes = getOrganizationUsers(_orgUserRequest, orgName, offset, resultLimit);
        error? x = outboundEp->respond(_getArtifactRes);
    }


    @http:ResourceConfig {
        methods: ["GET"],
        path: "/orgs/users/{userId}"
    }
    resource function getUserOrgs(http:Caller outboundEp, http:Request _getUserOrgsReq, string userId) returns error? {
        map<string[]> queryParams = _getUserOrgsReq.getQueryParams();
        int offset = 0;
        int resultLimit = 10;
        string orgName = "%";
        if (queryParams.hasKey(constants:OFFSET)) {
            int | error offsetQueryParam = int.constructFrom(_getUserOrgsReq.getQueryParamValue(constants:OFFSET));
            if (offsetQueryParam is int) {
                offset = offsetQueryParam;
            }
        }
        if (queryParams.hasKey(constants:RESULT_LIMIT)) {
            int | error resultLimitQueryParam = int.constructFrom(_getUserOrgsReq.getQueryParamValue(constants:RESULT_LIMIT));
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
            orgName = _getUserOrgsReq.getQueryParamValue(constants:ORG_NAME) ?: "";
            orgName = stringutils:replace(orgName, "*", "%");
        }
        http:Response _getUserOrgsRes = getUserOrgs(_getUserOrgsReq, userId, orgName, offset, resultLimit);
        error? x = outboundEp->respond(_getUserOrgsRes);
    }


    @http:ResourceConfig {
        methods: ["GET"],
        path: "/images/{orgName}"
    }
    resource function listOrgImages(http:Caller outboundEp, http:Request _listOrgImagesReq, string orgName) returns error? {
        map<string[]> queryParams = _listOrgImagesReq.getQueryParams();
        int offset = 0;
        int resultLimit = 10;
        string imageName = "%";
        string orderBy = constants:PULL_COUNT;
        if (queryParams.hasKey(constants:OFFSET)) {
            int | error offsetQueryParam = int.constructFrom(_listOrgImagesReq.getQueryParamValue(constants:OFFSET));
            if (offsetQueryParam is int) {
                offset = offsetQueryParam;
            }
        }
        if (queryParams.hasKey(constants:RESULT_LIMIT)) {
            int | error resultLimitQueryParam = int.constructFrom(_listOrgImagesReq.getQueryParamValue(constants:RESULT_LIMIT));
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
            imageName = _listOrgImagesReq.getQueryParamValue(constants:IMAGE_NAME) ?: "";
            imageName = stringutils:replace(imageName, "*", "%");
        }
        if (queryParams.hasKey(constants:ORDER_BY)) {
            orderBy = _listOrgImagesReq.getQueryParamValue(constants:ORDER_BY) ?: "";
            if (stringutils:equalsIgnoreCase(orderBy, "last-updated")) {
                orderBy = constants:UPDATED_DATE;
            } else {
                orderBy = constants:PULL_COUNT;
            }
        }
        http:Response _listOrgImagesRes = listOrgImages(_listOrgImagesReq, orgName, imageName, orderBy, offset, resultLimit);
        error? x = outboundEp->respond(_listOrgImagesRes);
    }


    @http:ResourceConfig {
        methods: ["GET"],
        path: "/images"
    }
    resource function listImages(http:Caller outboundEp, http:Request _listImagesReq) returns error? {
        map<string[]> queryParams = _listImagesReq.getQueryParams();
        int offset = 0;
        int resultLimit = 10;
        string orgName = "%";
        string imageName = "%";
        string orderBy = constants:PULL_COUNT;
        if (queryParams.hasKey(constants:OFFSET)) {
            int | error offsetQueryParam = int.constructFrom(_listImagesReq.getQueryParamValue(constants:OFFSET));
            if (offsetQueryParam is int) {
                offset = offsetQueryParam;
            }
        }
        if (queryParams.hasKey(constants:RESULT_LIMIT)) {
            int | error resultLimitQueryParam = int.constructFrom(_listImagesReq.getQueryParamValue(constants:RESULT_LIMIT));
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
            orgName = _listImagesReq.getQueryParamValue(constants:ORG_NAME) ?: "";
            orgName = stringutils:replace(orgName, "*", "%");
        }
        if (queryParams.hasKey(constants:IMAGE_NAME)) {
            log:printDebug("imageName is present");
            imageName = _listImagesReq.getQueryParamValue(constants:IMAGE_NAME) ?: "";
            imageName = stringutils:replace(imageName, "*", "%");
        }
        if (queryParams.hasKey(constants:ORDER_BY)) {
            orderBy = _listImagesReq.getQueryParamValue(constants:ORDER_BY) ?: "";
            if (stringutils:equalsIgnoreCase(orderBy, "last-updated")) {
                orderBy = constants:UPDATED_DATE;
            } else {
                orderBy = constants:PULL_COUNT;
            }
        }
        http:Response _listImagesRes = listImages(_listImagesReq, orgName, imageName, orderBy, offset, resultLimit);
        error? x = outboundEp->respond(_listImagesRes);
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


    @http:ResourceConfig {
        methods: ["GET"],
        path: "/images/users/{userId}"
    }
    resource function listUserImages(http:Caller outboundEp, http:Request _listUserImagesReq, string userId) returns error? {
        map<string[]> queryParams = _listUserImagesReq.getQueryParams();
        int offset = 0;
        int resultLimit = 10;
        string orgName = "%";
        string imageName = "%";
        string orderBy = constants:PULL_COUNT;
        if (queryParams.hasKey(constants:OFFSET)) {
            int | error offsetQueryParam = int.constructFrom(_listUserImagesReq.getQueryParamValue(constants:OFFSET));
            if (offsetQueryParam is int) {
                offset = offsetQueryParam;
            }
        }
        if (queryParams.hasKey(constants:RESULT_LIMIT)) {
            int | error resultLimitQueryParam = int.constructFrom(_listUserImagesReq.getQueryParamValue(constants:RESULT_LIMIT));
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
            orgName = _listUserImagesReq.getQueryParamValue(constants:ORG_NAME) ?: "";
            orgName = stringutils:replace(orgName, "*", "%");
        }
        if (queryParams.hasKey(constants:IMAGE_NAME)) {
            log:printDebug("imageName is present");
            imageName = _listUserImagesReq.getQueryParamValue(constants:IMAGE_NAME) ?: "";
            imageName = stringutils:replace(imageName, "*", "%");
        }
        if (queryParams.hasKey(constants:ORDER_BY)) {
            orderBy = _listUserImagesReq.getQueryParamValue(constants:ORDER_BY) ?: "";
            if (stringutils:equalsIgnoreCase(orderBy, "last-updated")) {
                orderBy = constants:UPDATED_DATE;
            } else {
                orderBy = constants:PULL_COUNT;
            }
        }

        http:Response _listUserImagesRes = listUserImages(_listUserImagesReq, userId, orgName, imageName, orderBy, 
        offset, resultLimit);
        error? x = outboundEp->respond(_listUserImagesRes);
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


    @http:ResourceConfig {
        methods:["DELETE"],
        path:"/images/{orgName}/{imageName}"
    }
    resource function deleteImage (http:Caller outboundEp, http:Request _deleteImageReq, string orgName, string imageName) returns error? {
        http:Response _deleteImageRes = deleteImage(_deleteImageReq, orgName, imageName);
        error? x = outboundEp->respond(_deleteImageRes);
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
