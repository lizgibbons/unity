/* 
 * Unity - Communities
 * 
 * Community is critical to the student experience--but building community is 
 * just plain hard. Built on Communities and designed specifically for higher ed, 
 * Unity is a powerful networking tool to help you generate engagement and 
 * connect your campus.
 * 
 * Copyright (C) 2015 Motivis Learning Systems Inc.
 * 
 * This program is free software: you can redistribute it and/or modify 
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 * 
 * To contact Motivis Learning Systems Inc.
 * 25 Pelham Road
 * Salem, NH 03790
 * unity@motivislearning.com
 */

global with sharing class CommunityHomeNotificationsController {

	public Id ParentIdParam {get;set;}
	public Id ItemIdParam {get;set;}
	public Boolean IsReadParam {get;set;}
	public Id ContactIdParam {get;set;}

	
	public CommunityHomeNotificationsController() {
		User u = [SELECT Id, ContactId, Community_Contact_ID__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
		ContactIdParam = (u.ContactId != null) ? u.ContactId : u.Community_Contact_ID__c;
	}

	@RemoteAction
	global static String notifications(){
		Community_Template_Settings__c cts = Community_Template_Settings__c.getOrgDefaults();
		List<NotificationWrapper> notificationsData = new List<NotificationWrapper>();
		List<NotificationWrapper> getGroupManagerFeeds = getGroupManagerFeeds();

		if(getGroupManagerFeeds == null) return 'EMPTY You have no notifications.';
		if(getGroupManagerFeeds != null) notificationsData.addAll(getGroupManagerFeeds);
		
		notificationsData.sort();

		return JSON.serialize(notificationsData);
	} 


	// get Messages
	@TestVisible
	private static List<NotificationWrapper> privateHPMessages(){
		
		List<NotificationWrapper> hpMessages = new List<NotificationWrapper>();
		Set<Id> userIds = new Set<Id>();
		

		// used existing method for messages
		//feedMessages = CommunityHelperWithoutSharing.MyMessages();
		CommunityFeed_MyMessagesController feedMessages = new CommunityFeed_MyMessagesController();
		
		if(feedMessages.Conversations.isEmpty()) return NULL;

		for(CommunityFeed_MyMessagesController.ChatterConversation feedMessage : feedMessages.Conversations){
		// check owner messageges 
			if(feedMessage.LatestMessage.Sender.MemberId != UserInfo.getUserId()){
				
				userIds.add(feedMessage.LatestMessage.Sender.MemberId);
				hpMessages.add(new NotificationWrapper(
					feedMessage.LatestMessage.Sender.MemberId,
					feedMessage.LatestMessage.Sender.MemberName,
					feedMessage.LatestMessage.Sender.MemberPhotoUrl,
					Label.LBL_Notifications_Message,
					prepareUrl(Page.CommunityFeed_MyMessages.getUrl())+'?c='+feedMessage.ConversationId,
					feedMessage.LatestMessage.SentDate));
			}

		}

		
		return formNameWithRoles(hpMessages, userIds);
		
	}
	// get feeds and comments for them from groups
	// where user is owner or manager
	@TestVisible
	private static List<NotificationWrapper> getGroupManagerFeeds(){
		
		String userType = UserInfo.getUserType();
		
		Set<Id> managersIds = new Set<Id>();
		Set<Id> controlsIds = new Set<Id>();
		List<FeedItem> feedsPosted = new List<FeedItem>();
		Set<Id> userPostedIds = new Set<Id>();
		Map<Id, List<String>> userPhotoAndName = new Map<Id, List<String>>();
		List<NotificationWrapper> hpGroupsFeeds = new List<NotificationWrapper>();
		Map<Id, List<String>> gControlGroups = new Map<Id, List<String>>();
		
		List<EntitySubscription> follows = new List<EntitySubscription>();
		Set<Id> followsIds = new Set<Id>();
	// get Group_Control 
	// where user is owner or manager
		if (!SObjectType.Community_Group_Manager__c.isAccessible()) CommunityAccess.ThrowAccessException(SObjectType.Community_Group_Manager__c);
		List<Community_Group_Manager__c> cGManagers = [SELECT Manager_Role__c, Group_Manager_User__c, Group_Control__c 
														FROM Community_Group_Manager__c 
														WHERE Group_Manager_User__c = :UserInfo.getUserId()];

		if(cGManagers.isEmpty()) return NULL;

		for(Community_Group_Manager__c cGManager : cGManagers){
			managersIds.add(cGManager.Group_Control__c);
		}

		
		if(userType.equalsIgnoreCase('Standard')){
			if (!SObjectType.EntitySubscription.isAccessible()) CommunityAccess.ThrowAccessException(SObjectType.EntitySubscription);
			follows = [SELECT Id, ParentId, SubscriberId, NetworkId 
						FROM EntitySubscription
						WHERE SubscriberId = :UserInfo.getUserId()
						];
		}
		Schema.DescribeSObjectResult cg = Community_Group_Control__c.sObjectType.getDescribe();
		String keyPrefixCG = cg.getKeyPrefix();
		for(EntitySubscription follow : follows){
			if(String.valueOf(follow.ParentId).substring(0,3).equalsIgnoreCase(keyPrefixCG)){
				followsIds.add(follow.ParentId);
			}
		}		 
		if (!SObjectType.Community_Group_Control__c.isAccessible()) CommunityAccess.ThrowAccessException(SObjectType.Community_Group_Control__c);
		List<Community_Group_Control__c> gControls = [SELECT Id, Chatter_Group_ID__c, Name, Group_Control_SF_ID__c 
										   				FROM Community_Group_Control__c
														WHERE id IN :managersIds
														OR id IN :followsIds];
		
		for(Community_Group_Control__c gControl : gControls){
			controlsIds.add(gControl.Id);
			gControlGroups.put(gControl.Id, new List<String>{gControl.Chatter_Group_ID__c, gControl.Name});
		}


	// get feed from groups
	/*
		List<FeedItem> feeds = [SELECT Id, ParentId, Type, CommentCount, LinkUrl, LastModifiedDate, CreatedById, Visibility 
								FROM FeedItem
							   WHERE ParentId IN :controlsIds 
							   AND CreatedById != :UserInfo.getUserId()
							   AND Visibility = 'AllUsers'
							   LIMIT 10000];
							   */
							   
		List<FeedItem> feeds = CommunityHelperWithoutSharing.getFeeds(controlsIds);

	   if(feeds.isEmpty()) {
	    	System.debug('feednul');
	   		return NULL;
	   }
	//check GroupManager feeds 
		Set<Id> parentIds = new Set<Id>();
		Set<Id> feedItemsIds = new Set<Id>();
		for(FeedItem feed : feeds){
				feedItemsIds.add(feed.Id);
				parentIds.add(feed.ParentId);
				userPostedIds.add(feed.CreatedById);
				if (feed.CreatedById != UserInfo.getUserId()) feedsPosted.add(feed);
		}

		List<FeedComment> comments = CommunityHelperWithoutSharing.getComments(feedItemsIds, UserInfo.getUserId());
		for(FeedComment comment : comments){
				userPostedIds.add(comment.CreatedById);
		}
	// get users Name and SmallPhoto
		if (!SObjectType.User.isAccessible()) CommunityAccess.ThrowAccessException(SObjectType.User);
		for(User us : [SELECT Id, SmallPhotoUrl, Name FROM User WHERE Id IN :userPostedIds]){
			userPhotoAndName.put(us.id, new List<String>{us.SmallPhotoUrl, us.Name});	
		}

		User u = [SELECT Id, ContactId, Community_Contact_ID__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
		String currenContactId = (u.ContactId != null) ? u.ContactId : u.Community_Contact_ID__c;
		Map<Id, Set<Id>> checkViews = new Map<Id, Set<Id>>();
		for (Task fnv : [SELECT WhatId, Description FROM Task WHERE WhatId IN :parentIds AND WhoId = :currenContactId AND Subject = 'Feed Notification Viewed']) {
			if (!checkViews.containsKey(fnv.WhatId)) {
				checkViews.put(fnv.WhatId, new Set<Id>());
			}
			checkViews.get(fnv.WhatId).add(fnv.Description);
		}

	// fill Wrapper class
		for(FeedItem feedPosted : feedsPosted){

			hpGroupsFeeds.add(new NotificationWrapper(
						feedPosted.Id,
						feedPosted.ParentId,
						feedPosted.CreatedById,
						userPhotoAndName.get(feedPosted.CreatedById)[1].replace(Site.getBaseUrl(), ''),
						Label.LBL_Notifications_Post.replace('{0}',gControlGroups.get(feedPosted.ParentId)[1]),
						gControlGroups.get(feedPosted.ParentId)[1],
						prepareUrl(Page.CommunityGroupManager.getUrl())+'?gr='+gControlGroups.get(feedPosted.ParentId)[0],
						feedPosted.CreatedDate,
						Label.LBL_NotificationType_Post,
						userPhotoAndName.get(feedPosted.CreatedById)[0],
						(checkViews.containsKey(feedPosted.ParentId) && checkViews.get(feedPosted.ParentId).contains(feedPosted.Id))));
		}
		for(FeedComment commentPosted : comments){

			hpGroupsFeeds.add(new NotificationWrapper(
						commentPosted.Id,
						commentPosted.ParentId,
						commentPosted.CreatedById,
						userPhotoAndName.get(commentPosted.CreatedById)[1].replace(Site.getBaseUrl(), ''),
						Label.LBL_Notifications_Post.replace('{0}',gControlGroups.get(commentPosted.ParentId)[1]),
						gControlGroups.get(commentPosted.ParentId)[1],
						prepareUrl(Page.CommunityGroupManager.getUrl())+'?gr='+gControlGroups.get(commentPosted.ParentId)[0],
						commentPosted.CreatedDate,
						Label.LBL_NotificationType_Comment,
						userPhotoAndName.get(commentPosted.CreatedById)[0],
						(checkViews.containsKey(commentPosted.ParentId) && checkViews.get(commentPosted.ParentId).contains(commentPosted.Id))));
		}

		return formNameWithRoles(hpGroupsFeeds, userPhotoAndName.keySet());
	}

	// set Names of users with Roles
	private static List<NotificationWrapper> formNameWithRoles(List<NotificationWrapper> posting, Set<Id> userIds){

		List<Id> userIdsList = new List<Id>();
		userIdsList.addAll(userIds);
		Map<Id, String> mapUserIdRole = CommunityFeedController.getUserRoles(userIdsList);

		for(NotificationWrapper nWrap : posting){
			if(mapUserIdRole.get(nWrap.MemberId) != null){
				nWrap.Name = nWrap.Name +' ('+mapUserIdRole.get(nWrap.MemberId)+')';
			}
		}
		return posting;

	}

	public void markNotification() {
		if (IsReadParam) CommunityUtils.insertNotificationViewedTask(ParentIdParam, ItemIdParam, ContactIdParam);
		if (!IsReadParam) CommunityUtils.removeNotificationViewedTask(ParentIdParam, ItemIdParam, ContactIdParam);
	}

	private static String prepareUrl(String inUncouthUrl) {
		return String.isNotBlank(Site.getPathPrefix()) ? inUncouthUrl.replace('/apex/', Site.getPathPrefix() + '/') : inUncouthUrl;
	}

	global class NotificationWrapper implements Comparable{

		public String Name {get; set;}
		public String Message {get; set;}
		public String StrongMessage { get; set; }
		public String DateString {get; set;}
		public String Type {get; set;}
		public String ClassStyle {get; set;}
		public String Image {get; set;}
		public String MemberId {get; set;}
		public Datetime SentDate {get; set;}
		public String ParentURL {get; set;}
		public String ItemId {get; set;}
		public String ParentId {get; set;}
		public Boolean IsRead {get; set;}


		public NotificationWrapper(String memberId, String name, String sPhoto, String message, String urlPath, Datetime dateD){

			this.MemberId = memberId;
			this.Name = name;
			this.Message = message;
			this.ParentURL = urlPath;
			this.SentDate = dateD;
			this.DateString = CommunityFeedController.convertTimeDiff(dateD);
			this.Type = 'Message';
			this.ClassStyle = 'icon-custom icon-sm rounded-x icon-bg-red icon-line icon-envelope';
			this.Image = sPhoto;
		}

		public NotificationWrapper(String itemId, String parentId, String memberId, String name, String message, String strongMessage, String urlPath, Datetime dateD, String type, String image, Boolean isRead){

			this.ItemId = itemId;
			this.ParentId = parentId;
			this.MemberId = memberId;
			this.Name = name;
			this.Message = message;
			this.ParentURL = urlPath;
			this.SentDate = dateD;
			this.DateString = CommunityFeedController.convertTimeDiff(dateD);
			this.Type = type;
			this.Image = image;
			this.StrongMessage = strongMessage;
			this.IsRead = isRead;
		}

		global Integer compareTo(Object compareTo) {
			NotificationWrapper compareToEmp = (NotificationWrapper)compareTo;
			if (this.SentDate == compareToEmp.SentDate) return 0;
			return (this.SentDate < compareToEmp.SentDate) ? 1 : -1;
		}

	}


}