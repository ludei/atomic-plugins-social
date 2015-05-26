#import <Foundation/Foundation.h>
#import <Cordova/CDVPlugin.h>
#import <GameKit/GameKit.h>

@interface LDGameCenterPlugin : CDVPlugin<GKLeaderboardViewControllerDelegate, GKAchievementViewControllerDelegate>

@end
