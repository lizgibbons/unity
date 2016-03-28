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

public with sharing class CommunityMenuController {

	
	public String currentUserRole { get{ return CommunityFeedController.getUserRoles(new List<String>{UserInfo.getUserId()}).get(UserInfo.getUserId());} }
	public String conversationId { get; set; }
	public Boolean read { get; set; }

	public List<ChatterConversation> getUnityConversations(){
		UnityMessage umn = new UnityMessage();
		umn.Conversations.sort();
		return umn.Conversations;
	}

	public CommunityMenuController(){
	}

	public Integer MessageUnreadCount { get {
			Integer unreadCountMessages;
			try {
				ConnectApi.UnreadConversationCount unreadCount = ConnectApi.ChatterMessages.getUnreadCount(Network.getNetworkId());
				unreadCountMessages = unreadCount.UnreadCount;
			}
			catch (exception e) {
				return 0;
			}
			return unreadCountMessages;
		} }

	public Integer getActivePage(){
		String currentPage = ApexPages.currentPage().getUrl().replace('/apex','');
		if(currentPage.containsIgnoreCase('Home')) return 1;
		if(currentPage.containsIgnoreCase('Groups')) return 2;
		if(currentPage.containsIgnoreCase('Events')) return 3;
		if(currentPage.containsIgnoreCase('Discover')) return 4;
		if(currentPage.containsIgnoreCase('Resourses')) return 5;
		return 0;
	}	

	private static Boolean currentPage(String urlToCompare) {
		String currentPageName = ApexPages.currentPage().getUrl().replace('/apex','');
		urlToCompare = urlToCompare.replace('/apex','');
		String pp = CommunityUtils.getPackagePrefix();
		if (String.isNotBlank(pp)) {
			urlToCompare = urlToCompare.replace(pp, '');
			currentPageName = currentPageName.replace(pp, '');
		}
		return currentPageName.containsIgnoreCase(urlToCompare);
	}

	public static String getRegistration() {
		String result = 'false';
		if (UserInfo.getUserType() != 'Guest'
			&& !currentPage(Page.CommunityRegTerms.getUrl())
			&& !currentPage(Page.Community404.getUrl())
		) {
			CommunityRegTermsController crtc = new CommunityRegTermsController();
			result = crtc.checkAndPrepareMenu();
		}
		return result;
	}
	
	public static Boolean getShowPrivateMessages(){
		if(Network.getNetworkId() == NULL) return true;
		return [SELECT OptionsPrivateMessagesEnabled, Id FROM Network WHERE Id =: Network.getNetworkId() LIMIT 1].OptionsPrivateMessagesEnabled;
	}
	
	public static Boolean getShowHideMenu() {
		Community_Template_Settings__c cts = Community_Template_Settings__c.getOrgDefaults();
		return !((String.isBlank(cts.Header_Logo_ImageID__c)) && getIsRegTermsPage());
	}

	public static String getColorScheme() {
		Community_Template_Settings__c cts = Community_Template_Settings__c.getInstance();
		return String.isNotBlank(cts.Color_Scheme__c) ? cts.Color_Scheme__c : 'Green';
	}

	public static Boolean getIsDefaultBackground() {
		Community_Template_Settings__c cts = Community_Template_Settings__c.getInstance();
		return String.isBlank(cts.Background_ImageID__c);
	}

	public static String getBackgroundImageId() {
		Community_Template_Settings__c cts = Community_Template_Settings__c.getInstance();
		return String.isNotBlank(cts.Background_ImageID__c) ? cts.Background_ImageID__c : '';
	}

	public static Boolean getIsRegTermsPage() {
		return currentPage(Page.CommunityRegTerms.getUrl());
	}

	public String getAlert() {
		DateTime Now = DateTime.now();
		if (!SObjectType.Community_News__c.isAccessible()) CommunityAccess.ThrowAccessException(SObjectType.Community_News__c);
		List<Community_News__c> newsList = [
			SELECT Id, Name, Teaser__c
			FROM Community_News__c
			WHERE Alert__c = true AND Status__c != 'Pending'
			AND Entry_Date__c <= :Now AND (Expiration_Date__c >= :Now OR Expiration_Date__c = NULL)
			ORDER BY CreatedDate ASC
			LIMIT 1
		];
		return newsList.isEmpty() ? NULL : newsList[0].Teaser__c;
	}

	public String getHelpLink() {
		if (!SObjectType.Community_Resource__c.isAccessible()) CommunityAccess.ThrowAccessException(SObjectType.Community_Resource__c);
		List<Community_Resource__c> helpList = [SELECT Id, Link__c FROM Community_Resource__c WHERE Status__c = 'Active' AND Help_Link__c = true AND Link__c != NULL];
		return (helpList.size() > 0 && String.isNotBlank(helpList[0].Link__c)) ? helpList[0].Link__c : NULL;
	}

	public String getBackCRMlink() {
		String result;
		if (UserInfo.getUserType() == 'Standard' || Test.isRunningTest()) {
			try {
				PageReference pr = new PageReference('/id/' + UserInfo.getOrganizationId() + '/' + UserInfo.getUserId());
				pr.getParameters().put('oauth_token', UserInfo.getSessionId());
				pr.getParameters().put('format', 'json');
				Map<String,Object> identityContent = (Map<String,Object>)Json.deserializeUntyped(pr.getContent().toString());
				Map<String,Object> urls = (Map<String,Object>)identityContent.get('urls');
				result = (String)urls.get('custom_domain');
			}
			catch(Exception e) {
			}
			result = result == null ? ApexPages.currentPage().getHeaders().get('X-Salesforce-Forwarded-To') : result;
			if (String.isNotBlank(result)) {
				result = result.contains('://') ? result : ('https://' + result);
			}
		}
		return result == null ? null : (result + '/home/home.jsp');
	}

	// -- variables -- lists for wrapper class --
	public static List<LinkItem> LinkItems {
		get {
			List<LinkItem> temp = new List<LinkItem>();

			if (!SObjectType.Community_Resource__c.isAccessible()) CommunityAccess.ThrowAccessException(SObjectType.Community_Resource__c);
			List<Community_Resource__c>  tmp = [
				SELECT Name, Link__c, Sort__c
				FROM Community_Resource__c 
				WHERE Quick_Link__c = TRUE AND Link__c != NULL AND Status__c = 'Active'
				ORDER BY Sort__c, Name
			];
			// As each CommunityResource__c is processed we create a new LinkItem object and add it to the LinkItems
			for (Community_Resource__c cr : tmp) {
				temp.add(new LinkItem(cr.Name, cr.Link__c));
			}

			return temp;
		}
	}
	
	public User getCurrentUser(){
		return CommunityUtils.getUser();
	}
	
	public void readConversation(){
		try{
			ConnectApi.ChatterConversationSummary ccs = ConnectApi.ChatterMessages.markConversationRead(Network.getNetworkId(), conversationId, read);
		}catch(Exception ex){}
	}

	// -- Wrapper class --
	public class LinkItem {
		public String Name {get; set;}
		public String Link {get; set;}

		public LinkItem(String Name, String Link) {
			this.Name = Name;
			this.Link = Link;
		} 
	}

	
	public class UnityMessage{
		private final Integer MESSAGES_PER_PAGE = 10;
		public List<ChatterConversation> Conversations { get; set; }

		public UnityMessage(){
			this.Conversations = new List<ChatterConversation>();
			this.Conversations = getConversations(NULL, NULL, this.MESSAGES_PER_PAGE);
			this.Conversations = filterConversations(this.Conversations);
		}

		public List<ChatterConversation> getConversations(String query, String pageToken, Integer messagesPerPage) {
			List<ChatterConversation> result = new List<ChatterConversation>();

			ConnectApi.ChatterConversationPage conversationPage = ConnectApi.ChatterMessages.getConversations(Network.getNetworkId(), pageToken, messagesPerPage);
			
			for (ConnectApi.ChatterConversationSummary conversationSummary : conversationPage.conversations) {
				result.add(new ChatterConversation(conversationPage.currentPageToken, conversationPage.nextPageToken, conversationSummary));
			}
			return result;
		}

		public List<ChatterConversation> filterConversations(List<ChatterConversation> convList){
			List<ChatterConversation> resultConv = new List<ChatterConversation>();
			for(ChatterConversation cc : convList){
				if(cc.LatestMessage.Sender.MemberId != UserInfo.getUserId()){
					resultConv.add(cc);
				}
			}
			return resultConv;
		}
	}

	public class ChatterConversation implements Comparable{
		public String ConversationId { get; set; }
		public Boolean IsRead { get; set; }
		public ChatterMessage LatestMessage { get; set; }
		
		public ChatterConversation(String cPageToken, String nPageToken, ConnectApi.ChatterConversationSummary summary) {
			this.ConversationId = summary.Id;
			this.IsRead = summary.Read;
			this.LatestMessage = new ChatterMessage(summary.LatestMessage);
		}
		public Integer compareTo(Object compareTo) {
	    	ChatterConversation compareToEmp = (ChatterConversation)compareTo;
	        if (this.IsRead == compareToEmp.IsRead) return 0;
	        if (this.IsRead == true && compareToEmp.IsRead == false) return 1;
	        return -1;   
		}
	}	
	public class ChatterMessage {
		public String MessageId { get; set; }
		public String ConversationId { get; set; }
		public ChatterMessageBody MessageBody { get; set; }
		public Datetime SentDate { get; set; }
		public String SentDateFormatted { 
			get { 
				if (String.isBlank(this.SentDateFormatted) && this.SentDate != NULL) {
					this.SentDateFormatted = formatSentDate();
				}
				return this.SentDateFormatted;
			}
			set;
		}
		public ChatterGroupMember Sender { get; set; }
		private String formatSentDate() {
			return String.format('{0} at {1}',
				new List<String> {
					this.SentDate.format('MMMMM d, yyyy'),
					this.SentDate.format('HH:mm a')
				}
			);
		}

		public ChatterMessage(ConnectApi.ChatterMessage message) {
			this.MessageId = message.Id;
			this.ConversationId = message.ConversationId;
			this.MessageBody = new ChatterMessageBody(message.Body);
			this.SentDate = message.SentDate;
			this.SentDateFormatted = formatSentDate();
			this.Sender = new ChatterGroupMember(message.Sender);
		}
	}

	public class ChatterMessageBody {
		public String Text { get; set; }
	
		public ChatterMessageBody(ConnectApi.AbstractMessageBody body) {
			this.Text = body.Text;
		}
	}

	public class ChatterGroupMember {
		public Id MemberId { get; set; }
		public String MemberName { get; set; }
		public String MemberRole { get; set; }
		public String MemberContactRole { get; set; }
		public String MemberPhotoUrl {
			get {
				if (String.isBlank(this.MemberPhotoUrl)) {
					this.MemberPhotoUrl = '/profilephoto/005/T';
				}
				//this.MemberPhotoUrl = this.MemberPhotoUrl.replace(Site.getBaseUrl(), '');
				return this.MemberPhotoUrl;
			}
			set;
		}
		public String SubscriptionId { get; set; }
		public Boolean MemberIsFollowing { get; set; }

		public ChatterGroupMember(ConnectApi.UserSummary member) {
			this.MemberId = member.Id;
			this.MemberName = String.format('{0}{1}',
				new List<String> {
					!String.isBlank(member.FirstName) ? member.FirstName + ' ' : '',
					!String.isBlank(member.LastName) ? member.LastName : ''
				}
			);
			String roleMember = (CommunityFeedController.getUserRoles(new List<String>{this.MemberId})).get(this.MemberId);
			if(roleMember != null){
				this.MemberRole = '('+roleMember+')';
			}else{
				this.MemberRole = '';
			}
			//this.MemberRole = '';
			this.MemberPhotoUrl = (member.Photo != NULL) ? member.Photo.SmallPhotoUrl : NULL;
		}

	}

}