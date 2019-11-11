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
import ballerina/encoding;
import ballerina/http;
import ballerina/io;
import ballerina/log;
import ballerina/stringutils;
import ballerina/lang.'string as strings;
import cellery_hub_api/constants;
import cellery_hub_api/gen;

public function getTokens(string authCode, string callbackUrl) returns @tainted (gen:TokensResponse | error) {
    http:Request tokenReq = new;
    var reqBody = io:sprintf("grant_type=authorization_code&code=%s&redirect_uri=%s", authCode, callbackUrl);
    tokenReq.setTextPayload(reqBody, contentType = constants:APPLICATION_URL_ENCODED_CONTENT_TYPE);
    // TODO There is a bug on ballerina that when there are more than one global client endpoints,
    // we have to reinitialize the endpoint. Need to remove this after the bug on this in ballerina is fixed
    http:Client oidcProviderClientEP = getBasicAuthIDPClient(config:getAsString("idp.oidc.clientid"),
    config:getAsString("idp.oidc.clientsecret"));
    var response = check oidcProviderClientEP->post(config:getAsString("idp.token.endpoint"), tokenReq);

    map<json> responsePayload = <map<json>> response.getJsonPayload();
    if (responsePayload["error"] != null) {
        error err = error(io:sprintf("Failed to call IdP token endpoint with error \"%s\" due to \"%s\"", <string>responsePayload["error"],
            <string>responsePayload.error_description));
        return err;
    } else if (response.statusCode >= 400) {
        error err = error(io:sprintf("Failed to call IdP token endpoint with status code ", response.statusCode));
        return err;
    } else {
        gen:TokensResponse tokens = {
            accessToken: <string>responsePayload.access_token,
            idToken: <string>responsePayload.id_token
        };
        log:printDebug("Successfully retrieved tokens from IdP");
        return tokens;
    }
}
public function revokeToken(string accessToken, string clientId, string clientSecret) returns error? {
    http:Request revocationReq = new;
    var reqBody = io:sprintf("token=%s&token_type_hint=access_token", accessToken);
    revocationReq.setTextPayload(reqBody, contentType = constants:APPLICATION_URL_ENCODED_CONTENT_TYPE);
    // TODO There is a bug on ballerina that when there are more than one global client endpoints,
    // we have to reinitialize the endpoint. Need to remove this after the bug on this in ballerina is fixed
    http:Client tokenRevocationClientEP = getBasicAuthIDPClient(clientId,clientSecret);
    log:printDebug("Sending revocation reqesut to IDP "); 
    var response = check tokenRevocationClientEP->post(config:getAsString("idp.revocation.endpoint"), revocationReq);
    if (response.statusCode >= 300) {
        error err = error(io:sprintf("Failed to call IdP token endpoint with status code ", response.statusCode));
        return err;
    } else {
        log:printDebug(io:sprintf("Successfully revoked token. Status code recieved: %d", response.statusCode)); 
    }
}


public function exchangeJWTWithToken(string jwt, string userId) returns @tainted (gen:TokensResponse | error) {
    http:Request tokenReq = new;
    var reqBody = io:sprintf("grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=%s&scope=openid", jwt);
    tokenReq.setTextPayload(reqBody, contentType = constants:APPLICATION_URL_ENCODED_CONTENT_TYPE);
    // TODO There is a bug on ballerina that when there are more than one global client endpoints,
    // we have to reinitialize the endpoint. Need to remove this after the bug on this in ballerina is fixed
    http:Client oidcProviderClientEP = getBasicAuthIDPClient(config:getAsString("idp.jwt.bearer.grant.clientid"),
    config:getAsString("idp.jwt.bearer.grant.clientsecret"));
    var response = check oidcProviderClientEP->post(config:getAsString("idp.token.endpoint"), tokenReq);

    map<json> responsePayload = <map<json>> response.getJsonPayload();
    if (responsePayload["error"] != null) {
        error err = error(io:sprintf("Failed to call IdP token endpoint with error \"%s\" due to \"%s\"", <string>responsePayload["error"],
            <string>responsePayload.error_description));
        return err;
    } else if (response.statusCode >= 400) {
        error err = error(io:sprintf("Failed to call IdP token endpoint with status code ", response.statusCode));
        return err;
    } else {
        string idToken = <string>responsePayload.id_token;
        string subject = check extractSubject(idToken);
        if(!stringutils:equalsIgnoreCase(userId, subject)){
            error err = error(io:sprintf("Authenticated user does not match with the subject of the retrieved token : " + userId,
              401));
            return err;
        }
        log:printDebug("Subject derieved from ID Token:" + subject);
        gen:TokensResponse tokens = {
            accessToken: <string>responsePayload.access_token,
            idToken: ""
        };
        log:printDebug("Successfully retrieved tokens from IdP");
        return tokens;
    }
}

public function extractSubject(string jwt) returns @tainted (error | string){
    log:printDebug("Decoding jwt token body :" + jwt);
    string[] split_string = stringutils:split(jwt, "\\."); // Split the string
    string base64EncodedBody = split_string[1]; // Payload part
    byte[] bodyBytes = check encoding:decodeBase64Url(base64EncodedBody);
    string body = check strings:fromBytes(bodyBytes);
    log:printDebug("Decoded jwt token body :" + body);
    io:StringReader sr = new(body, encoding = "UTF-8");
    json jsonBody = check sr.readJson();
    return <string>jsonBody.sub;
}

public function validateUsername(string token, string userId) returns error? {
    TokenDetail tokenDetail = check getTokenDetails(token);
    if (!stringutils:equalsIgnoreCase(userId, tokenDetail.username)) {
        error err = error(io:sprintf("%d : Authenticated user does not match with the subject of 
        the token passed for revoking: %s", 401, userId));
        return err;
    }
}
