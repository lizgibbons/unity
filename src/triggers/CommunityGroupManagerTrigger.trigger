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

trigger CommunityGroupManagerTrigger on Community_Group_Manager__c (after insert, after update, after delete) {

	Boolean catchedError = false;

	// handle Follow (EntitySubscription) and Chatter Group Member
	if (Trigger.isAfter && (Trigger.isInsert || Trigger.isDelete)) {
		List<Community_Group_Manager__c> cgmList = Trigger.isInsert ? Trigger.new : Trigger.old;
		Set<Id> memberIds = new Set<Id>();
		Set<Id> groupIds = new Set<Id>();
		for (Community_Group_Manager__c cgm2 : cgmList) {
			memberIds.add(cgm2.Group_Manager_User__c);
			groupIds.add(cgm2.Group_Control__c);
		}

		Map<Id,Id> chatterGroupToUnityGroupMap2 = new Map<Id,Id>();
		Map<Id,Id> unityGroupToChatterGroupMap2 = new Map<Id,Id>();
		if (groupIds.size() > 0 && CommunityUtils.isGroupTriggerWorked != true) {
			for (Community_Group_Control__c cgc : [SELECT Id, Chatter_Group_ID__c FROM Community_Group_Control__c WHERE Id IN :groupIds]) {
				try {
					chatterGroupToUnityGroupMap2.put(Id.valueOf(cgc.Chatter_Group_ID__c), cgc.Id);
					unityGroupToChatterGroupMap2.put(cgc.Id, Id.valueOf(cgc.Chatter_Group_ID__c));
				}
				catch(Exception e) {}
			}
		}
		Map<Id,Id> unityGroupToNetworkId = new Map<Id,Id>();
		if (chatterGroupToUnityGroupMap2.size() > 0) {
			Set<Id> networkIds = new Set<Id>();
			for (CollaborationGroup cga : [SELECT Id, NetworkId FROM CollaborationGroup WHERE Id IN :chatterGroupToUnityGroupMap2.keySet()]) {
				unityGroupToNetworkId.put(chatterGroupToUnityGroupMap2.get(cga.Id), cga.NetworkId);
				if (cga.NetworkId != null) {
					networkIds.add(cga.NetworkId);
				}
			}
			Map<String, CollaborationGroupMember> chatterGroupMemberUniqueMap = new Map<String, CollaborationGroupMember>();
			for (CollaborationGroupMember cgm4 : [
				SELECT Id, CollaborationGroupId, MemberId, CollaborationRole
				FROM CollaborationGroupMember
				WHERE CollaborationGroupId IN :chatterGroupToUnityGroupMap2.keySet()
			]) {
				chatterGroupMemberUniqueMap.put('' + chatterGroupToUnityGroupMap2.get(cgm4.CollaborationGroupId) + cgm4.MemberId, cgm4);
			}
			List<CollaborationGroupMember> upsertChatterMember = new List<CollaborationGroupMember>();
			List<CollaborationGroupMember> chatterMembersToUpdateNotifications = new List<CollaborationGroupMember>();
			Set<Id> membersIdsToUpdateNotifications = new Set<Id>();
			Boolean hasNetworks = networkIds.size() > 0;
			for (Community_Group_Manager__c cgm7 : cgmList) {
				String chKey = '' + cgm7.Group_Control__c + cgm7.Group_Manager_User__c;
				if (Trigger.isDelete && chatterGroupMemberUniqueMap.containsKey(chKey)) {
					CollaborationGroupMember oskarDiCaprio = chatterGroupMemberUniqueMap.get(chKey);
					if (oskarDiCaprio.CollaborationRole != 'Standard') {
						oskarDiCaprio.CollaborationRole = 'Standard';
						upsertChatterMember.add(oskarDiCaprio);
					}
				}
				else if (Trigger.isInsert && chatterGroupMemberUniqueMap.containsKey(chKey)) {
					CollaborationGroupMember leoDiCaprio2016 = chatterGroupMemberUniqueMap.get(chKey);
					if (leoDiCaprio2016.CollaborationRole != 'Admin') {
						leoDiCaprio2016.CollaborationRole = 'Admin';
						upsertChatterMember.add(leoDiCaprio2016);
					}
				}
				else if (Trigger.isInsert && !chatterGroupMemberUniqueMap.containsKey(chKey)) {
					CollaborationGroupMember titanik = new CollaborationGroupMember(
						MemberId = cgm7.Group_Manager_User__c,
						CollaborationGroupId = unityGroupToChatterGroupMap2.get(cgm7.Group_Control__c),
						CollaborationRole = 'Admin'
					);
					if (hasNetworks) {
						chatterMembersToUpdateNotifications.add(titanik);
						membersIdsToUpdateNotifications.add(cgm7.Group_Manager_User__c);
					}
					upsertChatterMember.add(titanik);
				}
			}
			if (membersIdsToUpdateNotifications.size() > 0) {
				Map<Id,String> memberToDefaultNotification = new Map<Id,String>();
				for (NetworkMember nm : [SELECT Id, MemberId, DefaultGroupNotificationFrequency FROM NetworkMember WHERE MemberId IN :membersIdsToUpdateNotifications AND NetworkId IN :networkIds]) {
					memberToDefaultNotification.put(nm.MemberId, nm.DefaultGroupNotificationFrequency);
				}
				for (CollaborationGroupMember cgm8 : chatterMembersToUpdateNotifications) {
					String habanaCigarFestival = memberToDefaultNotification.get(cgm8.MemberId);
					if (habanaCigarFestival != null) {
						cgm8.NotificationFrequency = habanaCigarFestival;
					}
				}
			}
			if (upsertChatterMember.size() > 0) {
				try {
					upsert upsertChatterMember;
				}
				catch (Exception e) {
					catchedError = true;
				}
			}
		}

		Map<String, EntitySubscription> groupSubscriptionUniqueMap = new Map<String, EntitySubscription>();
		for (EntitySubscription es : [
			SELECT Id, ParentId, SubscriberId FROM EntitySubscription
			WHERE SubscriberId IN :memberIds AND ParentId IN :groupIds
		]) {
			groupSubscriptionUniqueMap.put('' + es.ParentId + es.SubscriberId, es);
		}

		List<EntitySubscription> operationList = new List<EntitySubscription>();
		for (Community_Group_Manager__c cgm3 : cgmList) {
			String key = '' + cgm3.Group_Control__c + cgm3.Group_Manager_User__c;
			if (Trigger.isDelete && groupSubscriptionUniqueMap.containsKey(key)) {
				operationList.add(groupSubscriptionUniqueMap.get(key));
			}
			else if (Trigger.isInsert || !groupSubscriptionUniqueMap.containsKey(key)) {
				operationList.add(new EntitySubscription(
					SubscriberId = cgm3.Group_Manager_User__c,
					ParentId = cgm3.Group_Control__c,
					NetworkId = unityGroupToNetworkId.get(cgm3.Group_Control__c)
				));
			}
		}
		if (operationList.size() > 0) {
			try {
				if (Trigger.isDelete) {
					delete operationList;
				}
				else {
					insert operationList;
				}
			}
			catch(Exception e) {}
		}
	}

	// manual select of new owner
	if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate) && CommunityUtils.isGroupTriggerWorked != true) {
		Map<Id,Id> newGroupOwners = new Map<Id,Id>();
		for (Community_Group_Manager__c cgm : Trigger.new) {
			if (cgm.Manager_Role__c == 'Owner' && (Trigger.isInsert || cgm.Manager_Role__c != Trigger.oldMap.get(cgm.Id).Manager_Role__c)) {
				newGroupOwners.put(cgm.Group_Control__c, cgm.Group_Manager_User__c);
			}
		}
		if (newGroupOwners.size() > 0) {
			List<Community_Group_Control__c> cgmToSetNewOwner = [SELECT Id, OwnerId FROM Community_Group_Control__c WHERE Id IN :newGroupOwners.keyset()];
			for (Community_Group_Control__c cgm : cgmToSetNewOwner) {
				cgm.OwnerId = newGroupOwners.get(cgm.Id);
			}
			try {
				update cgmToSetNewOwner;
			}
			catch (Exception e) {
				catchedError = true;
			}
		}
	}

	if (catchedError && (Trigger.isInsert || Trigger.isUpdate)) {
		for (Community_Group_Manager__c cgm9 : Trigger.new) {
			cgm9.addError('User can\'t be a member in this group');
		}
	}

}