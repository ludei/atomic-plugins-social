#import "LDGameCenterPlugin.h"


static NSDictionary * fromGKPlayer(GKPlayer * gkPlayer)
{
    return @{
        @"playerID": gkPlayer.playerID,
        @"alias": gkPlayer.alias,
        @"isFriend": [NSNumber numberWithBool:gkPlayer.isFriend]
    };
}

static NSDictionary * fromGKLocalPlayer(GKLocalPlayer * gkPlayer)
{
    return @{
        @"playerID": gkPlayer.playerID ?: @"",
        @"alias": gkPlayer.alias ?: @"",
        @"isFriend": [NSNumber numberWithBool:gkPlayer.isFriend],
        @"isAuthenticated": [NSNumber numberWithBool:gkPlayer.isAuthenticated],
        @"underage": [NSNumber numberWithBool:gkPlayer.underage],
    };
}

static NSDictionary * fromGKAchievement(GKAchievement * ach)
{
    return @{
        @"identifier": ach.identifier,
        @"percentComplete": [NSNumber numberWithDouble:ach.percentComplete],
        @"lastReportedDate": [NSNumber numberWithDouble:ach.lastReportedDate.timeIntervalSince1970]
    };
}

static NSDictionary * fromGKAchievementDescription(GKAchievementDescription * ach)
{
    return @{
        @"identifier": ach.identifier,
        @"title": ach.title,
        @"maximumPoints": [NSNumber numberWithInteger:ach.maximumPoints],
        @"achievedDescription": ach.achievedDescription,
        @"unachievedDescription": ach.unachievedDescription,
    };
}

static NSDictionary * fromGKScore(GKScore * score)
{
    return @{
        @"value":[NSNumber numberWithDouble:score.value],
        @"date": [NSNumber numberWithDouble:score.date.timeIntervalSinceReferenceDate],
        @"rank": [NSNumber numberWithInteger:score.rank],
        @"category": score.category,
        @"formattedValue": score.formattedValue,
        @"playerID": score.playerID
    };
}


static GKAchievement * toAchievement(NSDictionary * dic)
{
    NSString * identifier = [dic objectForKey:@"identifier"];
    NSNumber * percentComplete = [dic objectForKey:@"percentComplete"];
    GKAchievement * result = [[GKAchievement alloc] initWithIdentifier:identifier];
    if (percentComplete) {
        result.percentComplete = percentComplete.floatValue;
    }
    result.showsCompletionBanner = YES;
    return result;
}

static GKScore * toGKScore(NSDictionary * dic)
{
    NSNumber * value = [dic objectForKey:@"value"];
    NSString * category =  [dic objectForKey:@"category"];
    
    GKScore * result;
    if (category && category.length > 0) {
        result = [[GKScore alloc] initWithCategory:category];
    }
    else {
        result = [[GKScore alloc] init];
    }
    result.value = value.doubleValue;
    return result;
}

static GKLeaderboard * toLeaderboard(NSDictionary * dic)
{
    NSNumber * rangeStart = [dic objectForKey:@"rangeStart"];
    NSNumber * rangeLength = [dic objectForKey:@"rangeLength"];
    NSString * category =  [dic objectForKey:@"category"];
    NSNumber * timeScope = [dic objectForKey:@"timeScope"];
    NSNumber * playerScope = [dic objectForKey:@"playerScope"];
    NSArray * playerIDs = [dic objectForKey:@"playerIDs"];
    
    GKLeaderboard * result;
    if (playerIDs && [playerIDs isKindOfClass:[NSArray class]] && playerIDs.count) {
        result = [[GKLeaderboard alloc] initWithPlayerIDs:playerIDs];
    }
    else {
        result = [[GKLeaderboard alloc] init];
    }
    
    if (category) {
        result.category = category;
    }
    if (rangeStart && rangeLength) {
        result.range = NSMakeRange(rangeStart.unsignedIntegerValue, rangeLength.unsignedIntegerValue);
    }

    if (playerScope  && playerScope.integerValue > 0) {
        result.playerScope = GKLeaderboardPlayerScopeFriendsOnly;
    }
    
    GKLeaderboardTimeScope scope = GKLeaderboardTimeScopeAllTime;
    if (timeScope && timeScope.integerValue == 0) {
        scope = GKLeaderboardTimeScopeToday;
    }
    else if (timeScope && timeScope.integerValue == 1) {
        scope = GKLeaderboardTimeScopeWeek;
    }
    result.timeScope = scope;
    return result;
}

static NSDictionary * fromLeaderboard(GKLeaderboard * leaderboard, NSArray * scores)
{
    NSMutableDictionary * dic = [NSMutableDictionary dictionary];
    [dic setObject: [NSNumber numberWithUnsignedInt:leaderboard.range.location] forKey:@"rangeStart"];
    [dic setObject: [NSNumber numberWithUnsignedInt:leaderboard.range.location] forKey:@"rangeLength"];
    [dic setObject: leaderboard.category ?:@"" forKey:@"category"];
    NSInteger ts = 0;
    if (leaderboard.timeScope == GKLeaderboardTimeScopeWeek) {
        ts = 1;
    }
    else if (leaderboard.timeScope == GKLeaderboardTimeScopeAllTime) {
        ts = 2;
    }
    [dic setObject:[NSNumber numberWithInteger:ts] forKey:@"timeScope"];
    [dic setObject:[NSNumber numberWithInteger:leaderboard.playerScope == GKLeaderboardPlayerScopeGlobal ? 0 : 1] forKey:@"playerScope"];
    if (scores) {
        NSMutableArray * array = [NSMutableArray array];
        for (GKScore * score in scores) {
            [array addObject:fromGKScore(score)];
        }
        [dic setObject:array forKey:@"scores"];
    }
    
    if (leaderboard.localPlayerScore) {
        [dic setObject:fromGKScore(leaderboard.localPlayerScore) forKey:@"localPlayerScore"];
    }
    
    
    return dic;
}

static NSDictionary * errorToDic(NSError * error)
{
    return @{@"code":[NSNumber numberWithInteger:error.code], @"message":error.localizedDescription};
}
static NSDictionary * toError(NSString * message)
{
    return @{@"code":[NSNumber numberWithInteger:0], @"message":message};
}


@implementation LDGameCenterPlugin
{
    id _notificationObserver;
    NSString * _showLeaderboardCallbackId;
    NSString * _showAchievementsCallbackId;
    NSString * _listenerCallbackId;
    
}

- (void)pluginInitialize
{
    _notificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:GKPlayerAuthenticationDidChangeNotificationName object:nil queue:nil usingBlock:^(NSNotification * note){
        [self notifyLoginStateChanged:[GKLocalPlayer localPlayer]];
    }];
}

- (void)dispose
{
    if (_notificationObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:_notificationObserver];
        _notificationObserver = nil;
    }
}

-(void) setListener:(CDVInvokedUrlCommand*) command
{
    _listenerCallbackId = command.callbackId;
}

-(void) notifyLoginStateChanged:(GKLocalPlayer *) player
{
    if (_listenerCallbackId) {
        CDVPluginResult * result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:fromGKLocalPlayer(player)];
        [result setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:result callbackId:_listenerCallbackId];
    }
}

-(void) login:(CDVInvokedUrlCommand*) command
{
    if ([GKLocalPlayer localPlayer].isAuthenticated)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            CDVPluginResult * result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:fromGKLocalPlayer([GKLocalPlayer localPlayer])];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        });
    }
    else
    {
        [[GKLocalPlayer localPlayer] authenticateWithCompletionHandler:^(NSError *error) {
            
            NSMutableArray * array = [NSMutableArray array];
            [array addObject:fromGKLocalPlayer([GKLocalPlayer localPlayer])];
            if (error) {
                [array addObject:errorToDic(error)];
            }
            CDVPluginResult * result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsArray:array];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }];
    }
}

-(void) loadPlayers:(CDVInvokedUrlCommand*) command
{
    NSArray * playerIds = [command argumentAtIndex:0];
    if (![playerIds isKindOfClass:[NSArray class]]) {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:toError(@"Invalid argument")] callbackId:command.callbackId];
        return;
    }
    
    [GKPlayer loadPlayersForIdentifiers:playerIds withCompletionHandler:^(NSArray *players, NSError *error) {
        CDVPluginResult * result;
        if (error) {
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:errorToDic(error)];
        }
        else {
            NSMutableArray * array = [NSMutableArray array];
            for (GKPlayer * player in players) {
                [array addObject:fromGKPlayer(player)];
            }
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:array];
        }
        
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];

    }];
}

-(void) loadFriends:(CDVInvokedUrlCommand*) command
{
    [[GKLocalPlayer localPlayer] loadFriendsWithCompletionHandler:^(NSArray *players, NSError *error) {
        CDVPluginResult * result;
        if (error) {
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:errorToDic(error)];
        }
        else {
            NSMutableArray * array = [NSMutableArray array];
            for (GKPlayer * player in players) {
                [array addObject:fromGKPlayer(player)];
            }
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:array];
        }
        
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        
    }];
}

-(void) loadAchievements:(CDVInvokedUrlCommand*) command
{
    [GKAchievement loadAchievementsWithCompletionHandler:^(NSArray *achievements, NSError *error) {
        CDVPluginResult * result;
        if (error) {
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:errorToDic(error)];
        }
        else {
            NSMutableArray * array = [NSMutableArray array];
            for (GKAchievement * ach in achievements) {
                [array addObject:fromGKAchievement(ach)];
            }
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:array];
        }
        
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        
    }];
}

-(void) loadAchievementDescriptions:(CDVInvokedUrlCommand*) command
{
    [GKAchievementDescription loadAchievementDescriptionsWithCompletionHandler:^(NSArray *descriptions, NSError *error) {
        CDVPluginResult * result;
        if (error) {
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:errorToDic(error)];
        }
        else {
            NSMutableArray * array = [NSMutableArray array];
            for (GKAchievementDescription * ach in descriptions) {
                [array addObject:fromGKAchievementDescription(ach)];
            }
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:array];
        }
        
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        
    }];
}

-(void) loadScores:(CDVInvokedUrlCommand*) command
{
    NSDictionary * settings = [command argumentAtIndex:0];
    if (![settings isKindOfClass:[NSDictionary class]]) {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:toError(@"Invalid argument")] callbackId:command.callbackId];
        return;
    }
    
    GKLeaderboard * leaderboard = toLeaderboard(settings);
    [leaderboard loadScoresWithCompletionHandler:^(NSArray *scores, NSError *error) {
        CDVPluginResult * result;
        if (error) {
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:errorToDic(error)];
        }
        else {
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:fromLeaderboard(leaderboard, scores)];
        }
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }];

}


-(void) submit:(GKScore *) reporter command:(CDVInvokedUrlCommand *) command
{
    @try
    {
        [reporter reportScoreWithCompletionHandler:^(NSError *error) {
            CDVPluginResult * result;
            if (error) {
                result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:errorToDic(error)];
            }
            else {
                result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
            }
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }];
    }
    @catch (NSException *exception)
    {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:toError(exception.reason)] callbackId:command.callbackId];
    }

}

-(void) submitScore:(CDVInvokedUrlCommand*) command
{
    NSDictionary * settings = [command argumentAtIndex:0];
    if (![settings isKindOfClass:[NSDictionary class]]) {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:toError(@"Invalid argument")] callbackId:command.callbackId];
        return;
    }
    
    GKScore * reporter = toGKScore(settings);
    [self submit:reporter command:command];
}

-(void) submitAchievements:(CDVInvokedUrlCommand*) command
{
    NSArray * data = [command argumentAtIndex:0];
    if (![data isKindOfClass:[NSArray class]]) {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:toError(@"Invalid argument")] callbackId:command.callbackId];
        return;
    }
    
    NSMutableArray * achievements = [NSMutableArray array];
    for (NSDictionary * dic in data) {
        [achievements addObject:toAchievement(dic)];
    }
    
    [GKAchievement reportAchievements:achievements withCompletionHandler:^(NSError *error) {
        CDVPluginResult * result;
        if (error) {
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:errorToDic(error)];
        }
        else {
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        }
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }];
}

-(void) resetAchievements:(CDVInvokedUrlCommand*) command
{
    [GKAchievement resetAchievementsWithCompletionHandler:^(NSError *error) {
        CDVPluginResult * result;
        if (error) {
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:errorToDic(error)];
        }
        else {
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        }
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }];
}

-(void) showAchievements:(CDVInvokedUrlCommand*) command
{
    GKAchievementViewController * avc = [[GKAchievementViewController alloc] init];
    avc.achievementDelegate = self;
    _showAchievementsCallbackId = command.callbackId;
    [self.viewController presentViewController:avc animated:YES completion:nil];
}

-(void) showLeaderboards:(CDVInvokedUrlCommand*) command
{
    GKLeaderboardViewController * lvc = [[GKLeaderboardViewController alloc] init];
    lvc.leaderboardDelegate = self;
    _showLeaderboardCallbackId = command.callbackId;
    
    NSDictionary * dic = [command argumentAtIndex:0 withDefault:nil andClass:[NSDictionary class]];
    if (dic) {
        NSString * category = [dic objectForKey:@"category"];
        if (category) {
            lvc.category = category;
        }
    }
    [self.viewController presentViewController:lvc animated:YES completion:nil];
}

-(void) notifyLeaderboardVCClosed
{
    [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:_showLeaderboardCallbackId];
    _showLeaderboardCallbackId = nil;
}

-(void) notifyAchievementsVCClosed
{
    [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:_showAchievementsCallbackId];
    _showAchievementsCallbackId = nil;
}

#pragma mark GKLeaderboardViewControllerDelegate
-(void)leaderboardViewControllerDidFinish:(GKLeaderboardViewController *)viewController
{
    [viewController dismissViewControllerAnimated:YES completion:^{
        [self notifyLeaderboardVCClosed];
    }];
}

#pragma mark GKAchievementViewControllerDelegate
-(void)achievementViewControllerDidFinish:(GKAchievementViewController *)viewController
{
    [viewController dismissViewControllerAnimated:YES completion:^{
        [self notifyAchievementsVCClosed];
    }];
}


@end
