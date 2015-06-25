
Atomic Plugins for Social integration
========================================

This repo contains Social Services APIs designed using the [Atomic Plugins paradigm](#about-atomic-plugins). Integrate Social services in your app easily and take advantage of all the features provided: elegant API, flexible solution that works across multiple platforms, single API for different Social Services and more. 
 
Currently there are 3 social services implemented but new ones can be easily added:

* GameCenter
* GooglePlay 
* Facebook

You can contribute and help to create more awesome plugins.

##About Atomic Plugins

Atomic Plugins provide an elegant and minimalist API and are designed with portability in mind from the beginning. Framework dependencies are avoided by design so the plugins can run on any platform and can be integrated with any app framework or game engine. 

#Provided APIs

  * [JavaScript API](#javascript-api)
  * [API Reference](#api-reference)
  * [Introduction](#introduction)
  * [Setup your project](#setup-your-project)
  * [Example](#example-1)

##JavaScript API:

###API Reference

See [API Documentation](http://ludei.github.io/cocoon-common/dist/doc/js/Cocoon.Social.html)

###Introduction 

Cocoon.Social class provides an easy to use Social API that can be used with different Social Services: Facebook, GooglePlay games and GameCenter.

###Setup your project

Releases are deployed to Cordova Plugin Registry. You only have to install the desired plugins using Cordova CLI, CocoonJS CLI or Ludei's Cocoon.io Cloud Server.

    cordova plugin add com.ludei.social.ios.gamecenter;
    cordova plugin add com.ludei.social.android.googleplaygames --variable APP_ID=the_app_id;
    cordova plugin add com.ludei.social.ios.facebook;
    cordova plugin add com.ludei.social.android.facebook;

The following JavaScript file is included automatically:

[`cocoon_social.js`](src/js/cocoon_social.js)

And, depending on the social service used, also: 

[`cocoon_gamecenter.js`](https://github.com/ludei/atomic-plugins-gamecenter/blob/master/src/js/cocoon_gamecenter.js)
[`cocoon_googleplaygames.js`]()
[`cocoon_facebook.js`]()

###Example

	var social;
	if (Cocoon.getPlatform() === 'ios') {
		social = Cocoon.Social.GameCenter.init();
		social = Cocoon.Social.GameCenter.getSocialInterface();
	}
	else {
		social = Cocoon.Social.GooglePlayGames.init();
		social = Cocoon.Social.GooglePlayGames.getSocialInterface();
	}

	var loggedIn = social.isLoggedIn();

	function loginSocial() {
	  if (!social.isLoggedIn()) {
	      social.login(function(loggedIn, error) {
	           if (error) {
	              console.error("login error: " + error.message);
	           }
	           else if (loggedIn) {
	              console.log("login succeeded");
	           }
	           else {
	              console.log("login cancelled");
	           }
	      });
	  }
	}

	loginSocial();

    social.submitAchievement(achievementID, function(error){
    	if (error)
        	console.error("submitAchievement error: " + error.message);
	});

	social.showAchievements(function(error){
    	if (error)
        	console.error("showAchievements error: " + error.message);
	});

	social.submitScore( score, function(error){
		if (error)
    		console.error("submitScore error: " + error.message);
	});

	social.showLeaderboard(function(error){
			if (error)
 			console.error("showLeaderbord error: " + error.message);
	});
	
    social.logout();

#License

Mozilla Public License, version 2.0

Copyright (c) 2015 Ludei 

See [`MPL 2.0 License`](LICENSE)

