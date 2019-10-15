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

import ballerina/log;
import ballerina/jsonutils;
import ballerina/stringUtils;
import ballerinax/java.jdbc;
import cellery_hub_api/gen;
import ballerina/io;
import ballerina/lang.'string as strings;

type RegistryArtifactImage record {|
    string ARTIFACT_IMAGE_ID;
|};

public function getOrganization(string orgName, string userId) returns @tainted json | error {
    log:printDebug(io:sprintf("Performing data retreival on REGISTRY_ORGANIZATION table by user \'%s\', Org name : \'%s\': ",
    userId, orgName));
    table<record {}> res = check connection->select(GET_ORG_QUERY, gen:OrgResponse, orgName, userId, orgName);
    int counter = 0;
    gen:OrgResponse orgRes;
    foreach var item in res {
        orgRes = check gen:OrgResponse.constructFrom(item);
        counter += 1;
    }
    map<json> resPayload = {};
    if counter == 1 {
        log:printDebug(io:sprintf("Building the response payload for getOrganization. user : %s, orgName : %s", userId, orgName));
        resPayload["description"] = "";
        if (!(orgRes.description is ())) {            
            resPayload["description"] =  check strings:fromBytes(<byte[]>orgRes.description);
        }
        resPayload["summary"] = orgRes.summary;
        resPayload["websiteUrl"] = orgRes.websiteUrl;
        resPayload["firstAuthor"] = orgRes.firstAuthor;
        resPayload["createdTimestamp"] = orgRes.createdTimestamp;
        resPayload["userRole"] = orgRes.userRole;
    } else if (counter == 0) {
        log:printDebug(io:sprintf("Failed to retrieve organization data. No organization found with the org name \'%s\'", orgName));
    } else {
        string errMsg = io:sprintf("Error in retrieving organization data. More than one record found for org name \'%s\'", orgName);
        log:printError(errMsg);
        error er = error(errMsg);
        return er;
    }
    res.close();
    return resPayload;
}

public function getOrganizationAvailability(string orgName) returns boolean | error {
    log:printDebug(io:sprintf("Checking whether the org name \'%s\' is available in REGISTRY_ORGANIZATION table", orgName));
    table<gen:Count> res = check connection->select(GET_ORG_AVAILABILITY_QUERY, gen:Count, orgName);
    boolean isOrgAvailable = false;

    if (res.hasNext()) {
        log:printDebug(io:sprintf("Organization \'%s\' is already existing in REGISTRY_ORGANIZATION table", orgName));
        isOrgAvailable = true;
    } else {
        log:printDebug(io:sprintf("Organization \'%s\' does not exists in REGISTRY_ORGANIZATION table", orgName));
    }

    res.close();
    return isOrgAvailable;
}

public function insertOrganization(string author, gen:OrgCreateRequest createOrgsBody) returns error? {
    log:printDebug(io:sprintf("Performing insertion on REGISTRY_ORGANIZATION table, Org name : \'%s\'", createOrgsBody.orgName));
    jdbc:UpdateResult res = check connection->update(ADD_ORG_QUERY, createOrgsBody.orgName, createOrgsBody.description,
    createOrgsBody.websiteUrl, createOrgsBody.defaultVisibility, author);
}

public function insertOrgUserMapping(string author, string orgName, string role) returns error? {
    log:printDebug(io:sprintf("Performing insertion on REGISTRY_ORG_USER_MAPPING table. User : %s, Org name : \'%s\'", author, orgName));
    jdbc:UpdateResult res = check connection->update(ADD_ORG_USER_MAPPING_QUERY, author, orgName, role);
}

public function getOrganizationCount(string userId) returns int | error {
    log:printDebug(io:sprintf("Retriving number organiations for user : \'%s\'", userId));
    table<record {}> selectRet = check connection->select(GET_ORG_COUNT_FOR_USER, (), userId);
    json[] jsonConversionRet = <json[]> jsonutils:fromTable(selectRet);
    map<json> jsonConversionRet0 = <map<json>> jsonConversionRet[0];
    log:printDebug(io:sprintf("Response from organization count query from DB: %s", jsonConversionRet.toJsonString()));
    int value = check int.constructFrom(jsonConversionRet0["COUNT(ORG_NAME)"]);
    selectRet.close();
    log:printDebug(io:sprintf("Count organiations for user : %s : %d", userId, value));
    return value;
}
public function getUserImage(string orgName, string imageName, string userId) returns @tainted table<gen:Image> | error {
    log:printDebug("Retriving image :" + imageName + " in organization : " + orgName + "for user: " + userId);
    table<gen:Image> res = check connection->select(GET_IMAGE_FOR_USER_FROM_IMAGE_NAME, gen:Image, orgName, userId,
    orgName, imageName, userId, orgName, imageName);
    return res;
}

public function getPublicImage(string orgName, string imageName) returns @tainted table<gen:Image> | error {
    log:printDebug("Retriving image :" + imageName + " in organization : " + orgName);
    table<gen:Image> res = check connection->select(GET_IMAGE_FROM_IMAGE_NAME, gen:Image,
    orgName, imageName);
    return res;
}

public function getArtifactsOfUserImage(string orgName, string imageName, string userId, string artifactVersion, int offset, int resultLimit)
returns @tainted table<gen:ArtifactDatum> | error {
    log:printDebug(io:sprintf("Performing artifact retrival from DB for org: %s, image: %s , version: %s for user: %s", orgName,
    imageName, artifactVersion, userId));
    table<gen:ArtifactDatum> res = check connection->select(GET_ARTIFACTS_OF_IMAGE_FOR_USER, gen:ArtifactDatum,
    orgName, imageName, artifactVersion, userId, orgName, imageName, artifactVersion,
    resultLimit, offset);
    return res;
}

public function getArtifactsOfPublicImage(string orgName, string imageName, string artifactVersion, int offset, int resultLimit)
returns @tainted table<gen:ArtifactDatum> | error {
    log:printDebug(io:sprintf("Performing artifact retrival from DB for org: %s, image: %s , version: %s for", orgName,
    imageName, artifactVersion));
    table<gen:ArtifactDatum> res = check connection->select(GET_ARTIFACTS_OF_PUBLIC_IMAGE, gen:ArtifactDatum, orgName, imageName,
    artifactVersion, resultLimit, offset);
    return res;
}

public function getPublicArtifact(string orgName, string imageName, string artifactVersion) returns @tainted json | error {
    log:printDebug(io:sprintf("Performing data retrieval for articat \'%s/%s:%s\'", orgName, imageName, artifactVersion));
    table<gen:Artifact> res = check connection->select(GET_ARTIFACT_FROM_IMG_NAME_N_VERSION, gen:Artifact, orgName, imageName,
    artifactVersion);
    if (res.hasNext()) {
        log:printDebug(io:sprintf("Found the artifact \'%s/%s:%s\'", orgName, imageName, artifactVersion));
        return buildJsonPayloadForGetArtifact(res, orgName, imageName, artifactVersion);
    } else {
        log:printDebug(io:sprintf("The requested artifact \'%s/%s:%s\' was not found", orgName, imageName, artifactVersion));
        res.close();
        return null;
    }
}

public function getImageKeywords(string imageId) returns @tainted table<gen:StringRecord> | error {
    log:printDebug(io:sprintf("Retriving keywords of image with id : %s", imageId));
    table<gen:StringRecord> res = check connection->select(GET_KEYWORDS_OF_IMAGE_BY_IMAGE_ID, gen:StringRecord, imageId);
    return res;
}

public function getUserArtifact(string userId, string orgName, string imageName, string artifactVersion) returns @tainted json | error {
    log:printDebug(io:sprintf("Performing data retrieval for articat \'%s/%s:%s\'", orgName, imageName, artifactVersion));
    table<gen:Artifact> res = check connection->select(GET_ARTIFACT_FOR_USER_FROM_IMG_NAME_N_VERSION, gen:Artifact, orgName,
    userId, orgName, imageName, artifactVersion, userId, orgName, imageName, artifactVersion);
    if (res.hasNext()) {
        log:printDebug(io:sprintf("Found the artifact \'%s/%s:%s\'", orgName, imageName, artifactVersion));
        return buildJsonPayloadForGetArtifact(res, orgName, imageName, artifactVersion);
    } else {
        log:printDebug(io:sprintf("The requested artifact \'%s/%s:%s\' was not found", orgName, imageName, artifactVersion));
        res.close();
        return null;
    }
}

public function getMemberOrgsUsers(string userId, string orgName, int offset, int resultLimit)
returns @tainted table<gen:User> | error {
    log:printDebug(io:sprintf("Performing data retrieval of users for organization: %s, user: %s , with offset %d,
    and result limit : %d", orgName, userId, offset, resultLimit));
    table<gen:User> res = check connection->select(GET_MEMBERS_ORG_USERS, gen:User, userId,
    orgName, resultLimit, offset);
    return res;
}

public function getMemberCountOfOrg(string orgName)
returns @tainted table<gen:Count> | error {
    log:printDebug(io:sprintf("Retriving member count of organization : %s", orgName));
    table<gen:Count> res = check connection->select(GET_MEMBERS_ORG_USERS_COUNT, gen:Count, orgName);
    return res;
}

public function searchOrganizationsWithAuthenticatedUser(string orgName, string userId, int offset, int resultLimit) returns @tainted json | error {
    log:printDebug(io:sprintf("Performing data retreival on REGISTRY_ORGANIZATION table, Org name : \'%s\', offset : %d, resultLimit : %d",
    orgName, offset, resultLimit));
    table<gen:Count> resTotal = check connection->select(SEARCH_ORGS_TOTAL_COUNT, gen:Count, orgName);
    int totalOrgs = check getTotalRecordsCount(resTotal);
    gen:OrgListResponse orgListResponse = {
        count: totalOrgs,
        data: []
    };
    if (totalOrgs > 0) {
        log:printDebug(io:sprintf("%d organization(s) found with the org name \'%s\'", totalOrgs, orgName));
        map<any> imageCountMap = {};
        log:printDebug(io:sprintf("Retreiving image count for organization(s) \'%s\' with an authenticated user \'%s\'", orgName, userId));
        table<gen:OrgListResponseImageCount> resImgCount = check connection->select(SEARCH_ORGS_QUERY_IMAGE_COUNT_FOR_AUTHENTICATED_USER,
        gen:OrgListResponseImageCount, orgName, userId, resultLimit, offset);
        foreach var orgImageCount in resImgCount {
            imageCountMap[orgImageCount.orgName] = orgImageCount.imageCount;
        }
        resImgCount.close();
        log:printDebug(io:sprintf("Retreiving summary, description and members count for organization(s) \'%s\'", orgName));
        table<gen:OrgListAtom> resData = check connection->select(SEARCH_ORGS_QUERY, gen:OrgListAtom, orgName,
        resultLimit, offset);
        int counter = 0;
        foreach var item in resData {
            gen:OrgListAtom orgListRecord = check gen:OrgListAtom.constructFrom(item);
            orgListResponse.data[counter] = check buildListOrgsResponse(orgListRecord, imageCountMap);
            counter += 1;
        }
        log:printDebug(io:sprintf("Successfully built the listOrgsResponse"));
        resData.close();
    } else {
        log:printDebug(io:sprintf("No organization found with the name \'%s\'", orgName));
    }
    return check json.constructFrom(orgListResponse);
}

public function searchOrganizationsWithoutAuthenticatedUser(string orgName, int offset, int resultLimit) returns @tainted json | error {
    log:printDebug(io:sprintf("Performing data retreival on REGISTRY_ORGANIZATION table, Org name : \'%s\', offset : %d, resultLimit : %d",
    orgName, offset, resultLimit));
    table<gen:Count> resTotal = check connection->select(SEARCH_ORGS_TOTAL_COUNT, gen:Count, orgName);
    int totalOrgs = check getTotalRecordsCount(resTotal);
    gen:OrgListResponse orgListResponse = {
        count: totalOrgs,
        data: []
    };
    if (totalOrgs > 0) {
        log:printDebug(io:sprintf("%d organization(s) found with the name \'%s\'", totalOrgs, orgName));
        map<any> imageCountMap = {};
        log:printDebug(io:sprintf("Retreiving image count for organization(s) \'%s\' with an unauthenticated user", orgName));
        table<gen:OrgListResponseImageCount> resImgCount = check connection->select(SEARCH_ORGS_QUERY_IMAGE_COUNT_FOR_UNAUTHENTICATED_USER,
        gen:OrgListResponseImageCount, orgName, resultLimit, offset);
        foreach var orgImageCount in resImgCount {
            imageCountMap[orgImageCount.orgName] = orgImageCount.imageCount;
        }
        resImgCount.close();
        log:printDebug(io:sprintf("Retreiving summary, description and members count for organization(s) \'%s\'", orgName));
        table<gen:OrgListAtom> resData = check connection->select(SEARCH_ORGS_QUERY, gen:OrgListAtom, orgName,
        resultLimit, offset);
        int counter = 0;
        foreach var item in resData {
            gen:OrgListAtom orgListRecord = check gen:OrgListAtom.constructFrom(item);
            orgListResponse.data[counter] = check buildListOrgsResponse(orgListRecord, imageCountMap);
            counter += 1;
        }
        log:printDebug(io:sprintf("Successfully built the listOrgsResponse"));
        resData.close();
    } else {
        log:printDebug(io:sprintf("No organization found with the name \'%s\'", orgName));
    }
    return check json.constructFrom(orgListResponse);
}

public function searchUserOrganizations(string userId, string apiUserId, string orgName, int offset, int resultLimit)
returns @tainted json | error {
    log:printDebug(io:sprintf("Performing data retreival on REGISTRY_ORGANIZATION table for userId : %s, Org name : \'%s\': ",
    userId, orgName));
    table<gen:Count> resTotal = check connection->select(SEARCH_USER_ORGS_TOTAL_COUNT, gen:Count, orgName, userId);
    int totalOrgs = check getTotalRecordsCount(resTotal);
    gen:OrgListResponse orgListResponse = {
        count: totalOrgs,
        data: []
    };
    if (totalOrgs > 0) {
        log:printDebug(io:sprintf("%d organization(s) found with the orgName \'%s\' for userId %s", totalOrgs, orgName, userId));
        map<any> imageCountMap = {};
        table<gen:OrgListResponseImageCount> resImgCount = check connection->select(SEARCH_USER_ORGS_QUERY_IMAGE_COUNT,
        gen:OrgListResponseImageCount, apiUserId, orgName, userId, orgName, resultLimit, offset);
        foreach var orgImageCount in resImgCount {
            imageCountMap[orgImageCount.orgName] = orgImageCount.imageCount;
        }
        resImgCount.close();
        table<gen:OrgListAtom> resData = check connection->select(SEARCH_USER_ORGS_QUERY, gen:OrgListAtom, orgName, userId,
        resultLimit, offset);
        int counter = 0;
        foreach var item in resData {
            gen:OrgListAtom orgListRecord = check gen:OrgListAtom.constructFrom(item);
            if (imageCountMap[orgListRecord.orgName] is ()) {
                imageCountMap[orgListRecord.orgName] = 0;
            }
            orgListResponse.data[counter] = check buildListOrgsResponse(orgListRecord, imageCountMap);
            counter += 1;
        }
        log:printDebug(io:sprintf("Successfully built the listOrgsResponse"));
        resData.close();
    } else {
        log:printDebug(io:sprintf("No organization found for userId %s, with the orgName \'%s\'", userId, orgName));
    }
    return check json.constructFrom(orgListResponse);
}

public function getPublicImagesOfOrg(string orgName, string imageName, string orderBy, int offset, int resultLimit)
returns @tainted json | error {
    log:printDebug(io:sprintf("Performing image retrival from DB for organization \'%s\', image name: \'%s\'", orgName, imageName));
    table<gen:Count> resTotal = check connection->select(SEARCH_PUBLIC_ORG_IMAGES_TOTAL_COUNT, gen:Count, orgName, imageName);
    int totalOrgs = check getTotalRecordsCount(resTotal);
    gen:OrgImagesListResponse orgImagesListResponse = {
        count: totalOrgs,
        data: []
    };
    if (totalOrgs > 0) {
        log:printDebug(io:sprintf("%d image(s) found with the image name \'%s\' for organization \'%s\'", totalOrgs, imageName, orgName));
        string searchQuery = stringUtils:replace(SEARCH_PUBLIC_ORG_IMAGES_QUERY, "$ORDER_BY", orderBy);
        table<gen:OrgImagesListAtom> resData = check connection->select(searchQuery, gen:OrgImagesListAtom, orgName, imageName,
        resultLimit, offset);
        int counter = 0;
        foreach var item in resData {
            gen:OrgImagesListAtom orgImagesListRecord = check gen:OrgImagesListAtom.constructFrom(item);
            orgImagesListResponse.data[counter] = check buildOrgImagesResponse(orgImagesListRecord);
            counter += 1;
        }
        log:printDebug(io:sprintf("Successfully built the listOrgImagesResponse"));
        resData.close();
    } else {
        log:printDebug(io:sprintf("No images found with the image name \'%s\' within the orgaization \'%s\'", imageName, orgName));
    }
    return check json.constructFrom(orgImagesListResponse);
}

public function getUserImagesOfOrg(string userId, string orgName, string imageName, string orderBy, int offset, int resultLimit)
returns @tainted json | error {
    log:printDebug(io:sprintf("Performing image retrival from DB for organization: \'%s\', image name: \'%s\'", orgName, imageName));
    table<gen:Count> resTotal = check connection->select(SEARCH_ORG_IMAGES_FOR_USER_TOTAL_COUNT, gen:Count, orgName, imageName, userId);
    int totalOrgs = check getTotalRecordsCount(resTotal);
    gen:OrgImagesListResponse orgImagesListResponse = {
        count: totalOrgs,
        data: []
    };
    if (totalOrgs > 0) {
        log:printDebug(io:sprintf("%d image(s) found with the image name \'%s\' for organization \'%s\', userId : \'%s\'", totalOrgs,
        imageName, orgName, userId));
        string searchQuery = stringUtils:replace(SEARCH_ORG_IMAGES_FOR_USER_QUERY, "$ORDER_BY", orderBy);
        table<gen:OrgImagesListAtom> resData = check connection->select(searchQuery, gen:OrgImagesListAtom, orgName, imageName,
        userId, resultLimit, offset);
        int counter = 0;
        foreach var item in resData {
            gen:OrgImagesListAtom orgImagesListRecord = check gen:OrgImagesListAtom.constructFrom(item);
            orgImagesListResponse.data[counter] = check buildOrgImagesResponse(orgImagesListRecord);
            counter += 1;
        }
        log:printDebug(io:sprintf("Successfully built the listOrgImagesResponse"));
        resData.close();
    } else {
        log:printDebug(io:sprintf("No images found with the image name \'%s\' within the orgaization \'%s\'", imageName, orgName));
    }
    return check json.constructFrom(orgImagesListResponse);
}

public function getUserImages(string orgName, string userId, string imageName, string orderBy, int offset, int resultLimit)
returns @tainted json | error {
    log:printDebug(io:sprintf("Retreiving images for org name \'%s\' and image name \'%s\' with an authenticated user \'%s\'",
    orgName, imageName, userId));
    table<gen:Count> resTotal = check connection->select(SEARCH_IMAGES_FOR_USER_TOTAL_COUNT, gen:Count, orgName, imageName, userId);
    int totalOrgs = check getTotalRecordsCount(resTotal);
    gen:ImagesListResponse imagesListResponse = {
        count: totalOrgs,
        data: []
    };
    if (totalOrgs > 0) {
        log:printDebug(io:sprintf("%d image(s) found with the image name \'%s\' for org name %s", totalOrgs, imageName, orgName));
        string searchQuery = stringUtils:replace(SEARCH_IMAGES_FOR_USER_QUERY, "$ORDER_BY", orderBy);
        table<gen:ImagesListAtom> resData = check connection->select(searchQuery, gen:ImagesListAtom,
        orgName, imageName, userId, resultLimit, offset);
        int counter = 0;
        foreach var item in resData {
            gen:ImagesListAtom imagesListRecord = check gen:ImagesListAtom.constructFrom(item);
            imagesListResponse.data[counter] = check buildListImagesResponse(imagesListRecord);
            counter += 1;
        }
        log:printDebug(io:sprintf("Successfully built the listImagesResponse"));
        resData.close();
    } else {
        log:printDebug(io:sprintf("No images found with the image name \'%s\' and org name \'%s\'", imageName, orgName));
    }
    return check json.constructFrom(imagesListResponse);
}

public function getPublicImages(string orgName, string imageName, string orderBy, int offset, int resultLimit)
returns @tainted json | error {
    log:printDebug(io:sprintf("Retreiving images for org name \'%s\' and image name \'%s\' with an unauthenticated user",
    orgName, imageName));
    table<gen:Count> resTotal = check connection->select(SEARCH_PUBLIC_IMAGES_TOTAL_COUNT, gen:Count, orgName, imageName);
    int totalOrgs = check getTotalRecordsCount(resTotal);
    gen:ImagesListResponse imagesListResponse = {
        count: totalOrgs,
        data: []
    };
    if totalOrgs > 0 {
        log:printDebug(io:sprintf("%d image(s) found with the image name \'%s\' for org name %s", totalOrgs, imageName, orgName));
        string searchQuery = stringUtils:replace(SEARCH_PUBLIC_IMAGES_QUERY, "$ORDER_BY", orderBy);
        table<gen:ImagesListAtom> resData = check connection->select(searchQuery, gen:ImagesListAtom,
        orgName, imageName, resultLimit, offset);
        int counter = 0;
        foreach var item in resData {
            gen:ImagesListAtom imagesListRecord = check gen:ImagesListAtom.constructFrom(item);
            imagesListResponse.data[counter] = check buildListImagesResponse(imagesListRecord);
            counter += 1;
        }
        log:printDebug(io:sprintf("Successfully built the listImagesResponse"));
        resData.close();
    } else {
        log:printDebug(io:sprintf("No images found with the image name \'%s\' and org name \'%s\'", imageName, orgName));
    }
    return check json.constructFrom(imagesListResponse);
}

public function updateImageDescriptionNSummary(string orgName, string imageName, string description, string summary, string userId) returns jdbc:UpdateResult | error? {
    log:printDebug(io:sprintf("Updating description and summary of the image %s/%s", orgName, imageName));
    jdbc:UpdateResult res = check connection->update(UPDATE_IMAGE_DESCRIPTION_N_SUMMARY_QUERY, description, summary, imageName, orgName, userId);
    return res;
}

public function updateOrgInfo(string description, string summary, string url, string orgName, string userId) returns jdbc:UpdateResult | error? {
    log:printDebug(io:sprintf("Updating description, summary and url of the organization \'%s\'", orgName));
    jdbc:UpdateResult res = check connection->update(UPDATE_ORG_INFO_QUERY, description, summary, url, orgName, userId);
    return res;
}

public function updateArtifactDescription(string description, string orgName, string imageName, string artifactVersion, string userId)
returns jdbc:UpdateResult | error? {
    log:printDebug(io:sprintf("Updating description of the artifact \'%s/%s:%s\'", orgName, imageName, artifactVersion));
    jdbc:UpdateResult res = check connection->update(UPDATE_ARTIFACT_DESCRIPTION_QUERY, description, artifactVersion, imageName, orgName, userId);
    return res;
}

public function updateImageKeywords(string orgName, string imageName, string[] keywords, string userId) returns error? {
    log:printDebug(io:sprintf("User %s is updating keywords of the image %s/%s", userId, orgName, imageName));
    string imageId = check getArtifactImageID(orgName, imageName);
    if imageId != "" {
        _ = check connection->update(DELETE_IMAGE_KEYWORDS_QUERY, imageId);
        log:printDebug(io:sprintf("Successfully deleted keywords of the image %s/%s", orgName, imageName));

        string[][] dataBatch = [];
        int i = 0;
        foreach var keyword in keywords {
            if keyword != "" {
                dataBatch[i] = [imageId, keyword];
                i = i + 1;
            }
        }
        if i > 0 {
            jdbc:BatchUpdateResult retBatch = connection->batchUpdate(INSERT_IMAGE_KEYWORDS_QUERY, true, ...dataBatch);
            error? err = retBatch.returnedError;
            if (err is error) {
                log:printError(io:sprintf("Batch update operation failed while updating keywords of the image \'%s/%s\'",
                orgName, imageName));
                return err;
            } else {
                log:printDebug(io:sprintf("Successfully inserted keywords for the image %s/%s", orgName, imageName));
            }            
        } else {
            log:printDebug(io:sprintf("No keywords found. Hence not perform keyword insertion for image %s/%s", orgName, imageName));
        }
    } else {
        string errMsg = io:sprintf("Unable to update image %s/%s. Artifact Image Id of the image is not found", orgName, imageName);
        log:printError(errMsg);
        error er = error(errMsg);
        return er;
    }
}

public function getImagesForUserIdWithAuthenticatedUser(string userId, string orgName, string imageName, string orderBy, int offset, int resultLimit,
string apiUserId) returns @tainted json | error {
    log:printDebug(io:sprintf("Performing image retrival for user %s from DB for orgName: %s, imageName: %s by user : %s", userId, orgName,
    imageName, apiUserId));
    table<gen:Count> resTotal = check connection->select(SEARCH_USER_AUTHORED_IMAGES_TOTAL_COUNT_FOR_AUTHENTICATED_USER, gen:Count,
    userId, orgName, imageName, apiUserId);
    int totalOrgs = check getTotalRecordsCount(resTotal);
    gen:ImagesListResponse imagesListResponse = {
        count: totalOrgs,
        data: []
    };
    if (totalOrgs > 0) {
        log:printDebug(io:sprintf("%d image(s) found with the image name \'%s\' and org name %s for user %s", totalOrgs, imageName,
        orgName, userId));
        string searchQuery = stringUtils:replace(SEARCH_USER_AUTHORED_IMAGES_QUERY_FOR_AUTHENTICATED_USER, "$ORDER_BY", orderBy);
        table<gen:ImagesListAtom> resData = check connection->select(searchQuery, gen:ImagesListAtom, userId, orgName, imageName,
        apiUserId, resultLimit, offset);
        int counter = 0;
        foreach var item in resData {
            gen:ImagesListAtom imagesListRecord = check gen:ImagesListAtom.constructFrom(item);
            imagesListResponse.data[counter] = check buildListImagesResponse(imagesListRecord);
            counter += 1;
        }
        log:printDebug(io:sprintf("Successfully built the listImagesResponse"));
        resData.close();
    } else {
        log:printDebug(io:sprintf("No images found with org name \'%s\' and image name \'%s\' for userId %s", orgName,
        imageName, userId));
    }
    return check json.constructFrom(imagesListResponse);
}

public function getImagesForUserIdWithoutAuthenticatedUser(string userId, string orgName, string imageName, 
string orderBy, int offset, int resultLimit) returns @tainted json | error {
    log:printDebug(io:sprintf("Performing image retrival for user %s from DB for orgName: %s, imageName: %s by unauthenticated user", userId, orgName,
    imageName));
    table<gen:Count> resTotal = check connection->select(SEARCH_USER_AUTHORED_IMAGES_TOTAL_COUNT_FOR_UNAUTHENTICATED_USER, gen:Count,
    userId, orgName, imageName);
    int totalOrgs = check getTotalRecordsCount(resTotal);
    gen:ImagesListResponse imagesListResponse = {
        count: totalOrgs,
        data: []
    };
    if (totalOrgs > 0) {
        log:printDebug(io:sprintf("%d image(s) found with the imageName \'%s\' and orgName %s for user %s", totalOrgs, imageName,
        orgName, userId));
        string searchQuery = stringUtils:replace(SEARCH_USER_AUTHORED_IMAGES_QUERY_FOR_UNAUTHENTICATED_USER, "$ORDER_BY", orderBy);
        table<gen:ImagesListAtom> resData = check connection->select(searchQuery, gen:ImagesListAtom, userId, orgName, imageName,
        resultLimit, offset);
        int counter = 0;
        foreach var item in resData {
            gen:ImagesListAtom imagesListRecord = check gen:ImagesListAtom.constructFrom(item);
            imagesListResponse.data[counter] = check buildListImagesResponse(imagesListRecord);
            counter += 1;
        }
        log:printDebug(io:sprintf("Successfully built the listImagesResponse"));
        resData.close();
    } else {
        log:printDebug(io:sprintf("No images found with orgName \'%s\' and image name \'%s\' for userId %s", orgName,
        imageName, userId));
    }
    return check json.constructFrom(imagesListResponse);
}

public function deleteArtifactFromDb(string userId, string orgName, string imageName, string artifactVersion) returns
int | error? {
    log:printDebug(io:sprintf("Deleting the artifact \'%s/%s:%s\', user : \'%s\'", orgName, imageName, artifactVersion,
    userId));
    jdbc:UpdateResult | error res = connection->update(DELETE_ARTIFACT_QUERY, imageName, userId, orgName,
    artifactVersion);
    if res is jdbc:UpdateResult {
        log:printDebug(io:sprintf("Updated %d rows to delete the artifact \'%s/%s:%s\', user : %s", res.updatedRowCount,
        orgName, imageName, artifactVersion, userId));
        return res.updatedRowCount;
    } else {
        return res;
    }        
}

public function deleteImageFromDb(string userId, string orgName, string imageName) returns int | error? {
    log:printDebug(io:sprintf("Deleting the image \'%s/%s\', user : \'%s\'", orgName, imageName, userId));
    jdbc:UpdateResult | error res = connection->update(DELETE_IMAGE_QUERY, imageName, userId, orgName);
    if res is jdbc:UpdateResult {
        log:printDebug(io:sprintf("Updated %d rows in REGISTRY_ARTIFACT_IMAGE table to delete the image \'%s/%s\',"+
        "user : %s", res.updatedRowCount, orgName, imageName, userId));
        return res.updatedRowCount;
    } else {
        return res;
    }        
}

public function deleteOrganizationFromDb(string userId, string orgName) returns int | error? {
    log:printDebug(io:sprintf("Deleting the organization \'%s\', user : \'%s\'", orgName, userId));
    jdbc:UpdateResult | error res = connection->update(DELETE_ORGANIZATION_QUERY, userId, orgName);
    if res is jdbc:UpdateResult {
        log:printDebug(io:sprintf("Updated %d rows in REGISTRY_ORGANIZATION table to delete the organization \'%s\',"+
        "user : %s", res.updatedRowCount, orgName, userId));
        return res.updatedRowCount;
    } else {
        return res;
    }        
}

public function getArtifactListLength(string imageId, string artifactVersion) returns int | error {
    log:printDebug(io:sprintf("Retriving artifact count for image ID : %s and image version %s", imageId, artifactVersion));
    table<gen:Count> res = check connection->select(GET_ARTIFACT_COUNT, gen:Count, imageId, artifactVersion);
    int length = check getTotalRecordsCount(res);
    return length;
}

function buildJsonPayloadForGetArtifact(table<gen:Artifact> res, string orgName, string imageName,
string artifactVersion) returns @tainted json | error {
    log:printDebug(io:sprintf("Building json payload for artifact \'%s/%s:%s\'", orgName, imageName, artifactVersion));
    map<json> resPayload = {};
    gen:Artifact artRes = check gen:Artifact.constructFrom(res.getNext());
    string metadataString =  check strings:fromBytes(artRes.metadata);

    io:StringReader sr = new(metadataString, encoding = "UTF-8");
    json metadataJson = check sr.readJson();
    resPayload["description"] = "";
    if (!((artRes.description) is ())) {
        resPayload["description"] = check strings:fromBytes(<byte[]>artRes.description);
    }
    resPayload["pullCount"] = artRes.pullCount;
    resPayload["lastAuthor"] = artRes.lastAuthor;
    resPayload["updatedTimestamp"] = artRes.updatedTimestamp;
    resPayload["metadata"] = metadataJson;
    resPayload["userRole"] = artRes.userRole;
    return resPayload;
}

function getArtifactImageID(string orgName, string imageName) returns string | error {
    log:printDebug(io:sprintf("Retrieving Artifact Image Id of image \'%s/%s\'", orgName, imageName));
    table<record {}> imageIdRes = check connection->select(GET_ARTIFACT_IMAGE_ID, RegistryArtifactImage, imageName, orgName);
    json[] imageIdResJson = <json[]> jsonutils:fromTable(imageIdRes);
    map<json> imageIdResJson0 = <map<json>> imageIdResJson[0];
    string imageId = check string.constructFrom(imageIdResJson0["ARTIFACT_IMAGE_ID"]);
    log:printDebug(io:sprintf("Artifact Image Id of \'%s/%s\' is %s ", orgName, imageName, imageId));
    return imageId;
}

function getTotalRecordsCount(table<gen:Count> tableRecord) returns int | error {
    log:printDebug("Converting the total in table record type into integer value");
    json[] tableJson = <json[]> jsonutils:fromTable(tableRecord);
    map<json> tableJson0 = <map<json>> tableJson[0];

    int total = check int.constructFrom(tableJson0["count"]);
    tableRecord.close();
    return total;
}

function buildListImagesResponse(gen:ImagesListAtom imagesListRecord) returns gen:ImagesListResponseAtom | error {
    string description = "";
    if (!(imagesListRecord.description is ())) {
        string | error convertedDescription =  check strings:fromBytes(<byte[]>imagesListRecord.description);
    }
    gen:ImagesListResponseAtom imagesListResponseAtom = {
        orgName: imagesListRecord.orgName,
        imageName: imagesListRecord.imageName,
        summary: imagesListRecord.summary,
        description: description,
        pullCount: imagesListRecord.pullCount,
        updatedTimestamp: imagesListRecord.updatedTimestamp,
        visibility: imagesListRecord.visibility
    };
    return imagesListResponseAtom;
}

function buildListOrgsResponse(gen:OrgListAtom orgListRecord, map<any> imageCountMap) returns gen:OrgListResponseAtom | error {
    string description = "";
    if (!(orgListRecord.description is ())) {
        description = check strings:fromBytes(<byte[]>orgListRecord.description);
    }
    gen:OrgListResponseAtom orgListResponseAtom = {
        orgName: orgListRecord.orgName,
        summary: orgListRecord.summary,
        description: description,
        membersCount: orgListRecord.membersCount,
        imageCount: <int>imageCountMap[orgListRecord.orgName]
    };
    return orgListResponseAtom;
}

function buildOrgImagesResponse(gen:OrgImagesListAtom orgImagesListRecord) returns gen:OrgImagesListResponseAtom | error {
    string description = "";
    if (!(orgImagesListRecord.description is ())) {
        description = check strings:fromBytes(<byte[]>orgImagesListRecord.description);
    }
    gen:OrgImagesListResponseAtom orgImagesListResponseAtom = {
        imageName: orgImagesListRecord.imageName,
        summary: orgImagesListRecord.summary,
        description: description,
        pullCount: orgImagesListRecord.pullCount,
        updatedTimestamp: orgImagesListRecord.updatedTimestamp,
        visibility: orgImagesListRecord.visibility
    };
    return orgImagesListResponseAtom;
}
