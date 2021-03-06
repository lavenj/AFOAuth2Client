// AFOAuth2Client.m
//
// Copyright (c) 2012 Mattt Thompson (http://mattt.me/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "AFJSONRequestOperation.h"

#import "AFOAuth2Client.h"

NSString * const kAFOAuthCodeGrantType = @"authorization_code";
NSString * const kAFOAuthClientCredentialsGrantType = @"client_credentials";
NSString * const kAFOAuthPasswordCredentialsGrantType = @"password";
NSString * const kAFOAuthRefreshGrantType = @"refresh_token";
NSString * const kAFOAuthClientError = @"com.alamofire.networking.oauth2.error";
NSString * const kAFOAuthClientAccountIsNewKey = @"accountIsNew";

NSInteger const kAFOAuthClientErrorTokenInvalid = -2;
NSInteger const kAFOAuthClientErrorAccountAlreadyExists = -3;

#ifdef _SECURITY_SECITEM_H_
NSString * const kAFOAuthCredentialServiceName = @"AFOAuthCredentialService";

static NSMutableDictionary * AFKeychainQueryDictionaryWithIdentifier(NSString *identifier) {
	NSMutableDictionary *queryDictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:(__bridge id)kSecClassGenericPassword, kSecClass, kAFOAuthCredentialServiceName, kSecAttrService, nil];
	[queryDictionary setValue:identifier forKey:(__bridge id)kSecAttrAccount];
	
	return queryDictionary;
}
#endif

#pragma mark -

@interface AFOAuth2Client ()
@property (readwrite, nonatomic) NSString *serviceProviderIdentifier;
@property (readwrite, nonatomic) NSString *clientID;
@property (readwrite, nonatomic) NSString *secret;
@property (readwrite, nonatomic) NSURL *oAuthURL;
@end

@implementation AFOAuth2Client

+ (instancetype)clientWithBaseURL:(NSURL *)url
												 oAuthURL:(NSURL *)oAuthURL
                         clientID:(NSString *)clientID
                           secret:(NSString *)secret
{
	return [[self alloc] initWithBaseURL:url oAuthURL:oAuthURL clientID:clientID secret:secret];
}

- (id)initWithBaseURL:(NSURL *)url
						 oAuthURL:(NSURL *)oAuthURL
             clientID:(NSString *)clientID
               secret:(NSString *)secret
{
	NSParameterAssert(clientID);
	
	self = [super initWithBaseURL:url];
	if (!self) {
		return nil;
	}
	
	self.oAuthURL = oAuthURL;
	self.serviceProviderIdentifier = [self.oAuthURL host];
	self.clientID = clientID;
	self.secret = secret;
	
	[self registerHTTPOperationClass:[AFJSONRequestOperation class]];
	
	return self;
}

#pragma mark -

- (void)setAuthorizationHeaderWithToken:(NSString *)token {
	// Use the "Bearer" type as an arbitrary default
	[self setAuthorizationHeaderWithToken:token ofType:@"Bearer"];
}

- (void)setAuthorizationHeaderWithCredential:(AFOAuthCredential *)credential {
	[self setAuthorizationHeaderWithToken:credential.accessToken ofType:credential.tokenType];
}

- (void)setAuthorizationHeaderWithToken:(NSString *)token
                                 ofType:(NSString *)type
{
	// http://tools.ietf.org/html/rfc6749#section-7.1
	// The Bearer type is the only finalized type
	if ([[type lowercaseString] isEqualToString:@"bearer"]) {
		[self setDefaultHeader:@"Authorization" value:[NSString stringWithFormat:@"Bearer %@", token]];
	}
}

#pragma mark -

- (void)authenticateUsingOAuthWithPath:(NSString *)path
                                  code:(NSString *)code
                           redirectURI:(NSString *)uri
                               success:(AFOAuthSuccessBlock)success
                               failure:(void (^)(NSError *error))failure
{
	NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
	[mutableParameters setObject:kAFOAuthCodeGrantType forKey:@"grant_type"];
	[mutableParameters setValue:code forKey:@"code"];
	[mutableParameters setValue:uri forKey:@"redirect_uri"];
	NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
	
	[self authenticateUsingOAuthWithPath:path parameters:parameters success:success failure:failure];
}

- (void)authenticateUsingOAuthWithPath:(NSString *)path
                              username:(NSString *)username
                              password:(NSString *)password
                                 scope:(NSString *)scope
                               success:(AFOAuthSuccessBlock)success
                               failure:(void (^)(NSError *error))failure
{
	NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
	[mutableParameters setObject:kAFOAuthPasswordCredentialsGrantType forKey:@"grant_type"];
	[mutableParameters setValue:username forKey:@"username"];
	[mutableParameters setValue:password forKey:@"password"];
	[mutableParameters setValue:scope forKey:@"scope"];
	NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
	
	[self authenticateUsingOAuthWithPath:path parameters:parameters success:success failure:failure];
}

- (void)authenticateUsingOAuthWithPath:(NSString *)path
                                 scope:(NSString *)scope
                               success:(AFOAuthSuccessBlock)success
                               failure:(void (^)(NSError *error))failure
{
	NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
	[mutableParameters setObject:kAFOAuthClientCredentialsGrantType forKey:@"grant_type"];
	[mutableParameters setValue:scope forKey:@"scope"];
	NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
	
	[self authenticateUsingOAuthWithPath:path parameters:parameters success:success failure:failure];
}

- (void)authenticateUsingOAuthWithPath:(NSString *)path
                          refreshToken:(NSString *)refreshToken
                               success:(AFOAuthSuccessBlock)success
                               failure:(void (^)(NSError *error))failure
{
	NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
	[mutableParameters setObject:kAFOAuthRefreshGrantType forKey:@"grant_type"];
	[mutableParameters setValue:refreshToken forKey:@"refresh_token"];
	NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
	
	[self authenticateUsingOAuthWithPath:path parameters:parameters success:success failure:failure];
}

- (void)authenticateUsingOAuthWithPath:(NSString *)path
                            parameters:(NSDictionary *)parameters
                               success:(AFOAuthSuccessBlock)success
                               failure:(void (^)(NSError *error))failure
{
	NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionaryWithDictionary:parameters];
	[mutableParameters setObject:self.clientID forKey:@"client_id"];
	[mutableParameters setValue:self.secret forKey:@"client_secret"];
	parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
	
	[self clearAuthorizationHeader];
	
	//switch our base url real quick
	
	NSMutableURLRequest *mutableRequest = [self requestWithMethod:@"POST" path:path parameters:parameters];
	
	NSString *oldUrl = mutableRequest.URL.absoluteString;
	NSString *url = [oldUrl stringByReplacingOccurrencesOfString:self.baseURL.absoluteString withString:self.oAuthURL.absoluteString];
	//	NSLog(@"string change:\nold: %@\nnew: %@", oldUrl, url);
	mutableRequest.URL = [NSURL URLWithString:url];
	//	NSLog(@"url: %@", mutableRequest.URL);
	[mutableRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
	
	AFHTTPRequestOperation *requestOperation = [self HTTPRequestOperationWithRequest:mutableRequest success:^(AFHTTPRequestOperation *operation, id responseObject) {
		
		if ([responseObject valueForKey:@"error"]) {
			if (failure) {
				NSLog(@"failing in request op");
				// TODO: Resolve the `error` field into a proper NSError object
				// http://tools.ietf.org/html/rfc6749#section-5.2
				failure(nil);
			}
			
			return;
		}
		
		NSString *refreshToken = [responseObject valueForKey:@"refresh_token"];
		if (refreshToken == nil || [refreshToken isEqual:[NSNull null]]) {
			refreshToken = [parameters valueForKey:@"refresh_token"];
		}
		
		AFOAuthCredential *credential = [AFOAuthCredential credentialWithOAuthToken:[responseObject valueForKey:@"access_token"] tokenType:[responseObject valueForKey:@"token_type"]];
		
		NSDate *expireDate = nil;
		id expiresIn = [responseObject valueForKey:@"expires_in"];
		if (expiresIn != nil && ![expiresIn isEqual:[NSNull null]]) {
			expireDate = [NSDate dateWithTimeIntervalSinceNow:[expiresIn doubleValue]];
		}
		
		[credential setRefreshToken:refreshToken expiration:expireDate];
		
		[self setAuthorizationHeaderWithCredential:credential];
		
		if (success) {
			NSDictionary *info = @{kAFOAuthClientAccountIsNewKey: [NSNumber numberWithBool:operation.response.statusCode == 201]};
			success(credential, info);
		}
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (failure) {
			failure(error);
		}
	}];
	
	[self enqueueHTTPRequestOperation:requestOperation];
}


-(NSError *)errorFromDictionary:(NSDictionary *)dict originalError:(NSError *)originalError {
	NSLog(@"errorFromDictionary: %@", dict);
	NSString *reason = nil;
	id errorResponse = dict[@"error"];
	if( [errorResponse isKindOfClass:[NSDictionary class]] ) {
		//find the reason.
		NSArray *keys = @[@"message", @"error"];
		for(NSString *key in keys) {
			if( [errorResponse[key] isKindOfClass:[NSString class]] ) {
				NSLog(@"error for key %@ is %@", key, reason);
				reason = errorResponse[key];
				break;
			}
		}
	}
	else if( [errorResponse isKindOfClass:[NSString class]] ) {
		reason = errorResponse;
	}
	
	NSLog(@"error is %@", reason);
	if( reason != nil ) {
		NSDictionary *userInfo = @{NSLocalizedFailureReasonErrorKey: reason, NSUnderlyingErrorKey:originalError};
		if( [reason hasPrefix:@"Access token"] ) {
			//for now, any error starting with "Access token" will be called a token error.
			NSError * error = [NSError errorWithDomain:kAFOAuthClientError code:kAFOAuthClientErrorTokenInvalid userInfo:userInfo];
			return error;
		}
		else if( [reason hasPrefix:@"The username has already been taken"] ) {
			NSError * error = [NSError errorWithDomain:kAFOAuthClientError code:kAFOAuthClientErrorAccountAlreadyExists userInfo:userInfo];
			return error;
		}
		else {
			NSError * error = [NSError errorWithDomain:kAFOAuthClientError code:-1 userInfo:userInfo];
			return error;
		}
	}
	return nil;
	
}

- (AFHTTPRequestOperation *)HTTPRequestOperationWithRequest:(NSURLRequest *)urlRequest
                                                    success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
                                                    failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure {
	return [super HTTPRequestOperationWithRequest:urlRequest success:success failure:^(AFHTTPRequestOperation *operation, NSError *error) {

		
		if( error ) {
			NSLog(@"failing: %@", error);
			//			NSLog(@"operation error: %@", [operation error]);
		}
		
		if( operation.responseData ) {
			NSError *jsonError = nil;
			id jsonResponse = [NSJSONSerialization JSONObjectWithData:operation.responseData options:kNilOptions error:&jsonError];
			
			if( jsonError ) {
				NSLog(@"error parsing error json: %@", jsonError);
				return failure(operation, error);
			}
			
			if( [jsonResponse isKindOfClass:[NSDictionary class]] ) {
				NSError *customError = [self errorFromDictionary:jsonResponse originalError:error];
				if( customError ) {
					return failure(operation, customError);
				}
			}
		}
		
		failure(operation, error);
	}];
}

@end

#pragma mark -

@interface AFOAuthCredential ()
@property (readwrite, nonatomic) NSString *accessToken;
@property (readwrite, nonatomic) NSString *tokenType;
@property (readwrite, nonatomic) NSString *refreshToken;
@property (readwrite, nonatomic) NSDate *expiration;
@property (readwrite, nonatomic) NSString *username;
@property (readwrite, nonatomic) NSString *password;
@end

@implementation AFOAuthCredential
@synthesize accessToken = _accessToken;
@synthesize tokenType = _tokenType;
@synthesize refreshToken = _refreshToken;
@synthesize expiration = _expiration;
@dynamic expired;
@dynamic expirationDate;

#pragma mark -

+ (instancetype)credentialWithOAuthToken:(NSString *)token
                               tokenType:(NSString *)type
{
	return [[self alloc] initWithOAuthToken:token tokenType:type];
}

- (id)initWithOAuthToken:(NSString *)token
               tokenType:(NSString *)type
{
	self = [super init];
	if (!self) {
		return nil;
	}
	
	self.accessToken = token;
	self.tokenType = type;
	
	return self;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@ accessToken:\"%@\" tokenType:\"%@\" refreshToken:\"%@\" expiration:\"%@\">", [self class], self.accessToken, self.tokenType, self.refreshToken, self.expiration];
}

- (void)setRefreshToken:(NSString *)refreshToken
             expiration:(NSDate *)expiration
{
	//    if (!refreshToken || !expiration) {
	//        return;
	//    }
	
	self.refreshToken = refreshToken;
	self.expiration = expiration;
}

- (BOOL)isExpired {
	return [self.expiration compare:[NSDate date]] == NSOrderedAscending;
}

-(NSDate *)expirationDate
{
	return self.expiration;
}

#pragma mark Keychain

#ifdef _SECURITY_SECITEM_H_

+ (BOOL)storeCredential:(AFOAuthCredential *)credential
         withIdentifier:(NSString *)identifier
{
	NSMutableDictionary *queryDictionary = AFKeychainQueryDictionaryWithIdentifier(identifier);
	
	if (!credential) {
		return [self deleteCredentialWithIdentifier:identifier];
	}
	
	NSMutableDictionary *updateDictionary = [NSMutableDictionary dictionary];
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:credential];
	[updateDictionary setObject:data forKey:(__bridge id)kSecValueData];
	
	OSStatus status;
	BOOL exists = ([self retrieveCredentialWithIdentifier:identifier] != nil);
	
	if (exists) {
		status = SecItemUpdate((__bridge CFDictionaryRef)queryDictionary, (__bridge CFDictionaryRef)updateDictionary);
	} else {
		[queryDictionary addEntriesFromDictionary:updateDictionary];
		status = SecItemAdd((__bridge CFDictionaryRef)queryDictionary, NULL);
	}
	
	if (status != errSecSuccess) {
		NSLog(@"Unable to %@ credential with identifier \"%@\" (Error %li)", exists ? @"update" : @"add", identifier, (long int)status);
	}
	
	return (status == errSecSuccess);
}

+ (BOOL)deleteCredentialWithIdentifier:(NSString *)identifier {
	NSMutableDictionary *queryDictionary = AFKeychainQueryDictionaryWithIdentifier(identifier);
	
	OSStatus status = SecItemDelete((__bridge CFDictionaryRef)queryDictionary);
	
	if (status != errSecSuccess) {
		NSLog(@"Unable to delete credential with identifier \"%@\" (Error %li)", identifier, (long int)status);
	}
	
	return (status == errSecSuccess);
}

+ (AFOAuthCredential *)retrieveCredentialWithIdentifier:(NSString *)identifier {
	NSMutableDictionary *queryDictionary = AFKeychainQueryDictionaryWithIdentifier(identifier);
	[queryDictionary setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
	[queryDictionary setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];
	
	CFDataRef result = nil;
	OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)queryDictionary, (CFTypeRef *)&result);
	
	if (status != errSecSuccess) {
		NSLog(@"Unable to fetch credential with identifier \"%@\" (Error %li)", identifier, (long int)status);
		return nil;
	}
	
	NSData *data = (__bridge_transfer NSData *)result;
	AFOAuthCredential *credential = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	
	return credential;
}

#endif

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)decoder {
	self = [super init];
	self.accessToken = [decoder decodeObjectForKey:@"accessToken"];
	self.tokenType = [decoder decodeObjectForKey:@"tokenType"];
	self.refreshToken = [decoder decodeObjectForKey:@"refreshToken"];
	self.expiration = [decoder decodeObjectForKey:@"expiration"];
	self.username = [decoder decodeObjectForKey:@"username"];
	self.password = [decoder decodeObjectForKey:@"password"];
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
	[encoder encodeObject:self.accessToken forKey:@"accessToken"];
	[encoder encodeObject:self.tokenType forKey:@"tokenType"];
	[encoder encodeObject:self.refreshToken forKey:@"refreshToken"];
	[encoder encodeObject:self.expiration forKey:@"expiration"];
	[encoder encodeObject:self.username forKey:@"username"];
	[encoder encodeObject:self.password forKey:@"password"];
}

@end

@implementation RKOAuth2HTTPRequestOperation

- (NSError *)error
{
//	NSLog(@"***** in RKOAuth2HTTPRequestOperation error *****");
	//	[self.lock lock];
	
	if( !self.responseData ) {
		return [super error];
	}
	NSError *jsonError = nil;
	id jsonResponse = [NSJSONSerialization JSONObjectWithData:self.responseData options:kNilOptions error:&jsonError];
	if( jsonResponse && [jsonResponse isKindOfClass:[NSDictionary class]] ) {
		
		id error = jsonResponse[@"error"];
		if( [error isKindOfClass:[NSDictionary class]] ) {
			NSString *reason = error[@"message"];
			//for now, any error starting with "Access token" will be called a token error.
			if( [reason isKindOfClass:[NSString class]] && [reason hasPrefix:@"Access token"] ) {
				NSError * error = [NSError errorWithDomain:kAFOAuthClientError code:kAFOAuthClientErrorTokenInvalid userInfo:jsonResponse];
				return error;
			}
		}
		else if( [error isKindOfClass:[NSString class]] ) {
			NSString *reason = error;
			//for now, any error starting with "Access token" will be called a token error.
			if( [reason hasPrefix:@"Access token"] ) {
				NSError * error = [NSError errorWithDomain:kAFOAuthClientError code:kAFOAuthClientErrorTokenInvalid userInfo:jsonResponse];
				return error;
			}
		}
	}
	if( jsonError ) {
		NSLog(@"error parsing error json: %@", jsonError);
	}
	return [super error];
}

@end

