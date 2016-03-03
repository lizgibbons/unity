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

trigger CollaborationGroupMemberTrigger on CollaborationGroupMember (after delete, after insert, after update) {

	List<CollaborationGroupMember> newChatterManagers = new List<CollaborationGroupMember>();
	List<CollaborationGroupMember> removeChatterManagers = new List<CollaborationGroupMember>();
	Set<Id> groupIds = new Set<Id>();
	Set<Id> memberIds = new Set<Id>();

	// collect new/updated Chatter members
	if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate) && CommunityUtils.isGroupTriggerWorked != true) {
		for (CollaborationGroupMember chgm : Trigger.new) {
			if (chgm.CollaborationRole != null && (Trigger.isInsert || chgm.CollaborationRole != Trigger.oldMap.get(chgm.Id).CollaborationRole)) {
				groupIds.add(chgm.CollaborationGroupId);
				memberIds.add(chgm.MemberId);
				if (chgm.CollaborationRole == 'Admin') {
					newChatterManagers.add(chgm);
				}
				else {
					removeChatterManagers.add(chgm);
				}
			}
		}
	}

	// collect deleted Chatter members
	if (Trigger.isAfter && Trigger.isDelete && CommunityUtils.isGroupTriggerWorked != true) {
		for (CollaborationGroupMember chgm2 : Trigger.old) {
			groupIds.add(chgm2.CollaborationGroupId);
			memberIds.add(chgm2.MemberId);
			removeChatterManagers.add(chgm2);
		}
	}

	// pull Unity Managers related to found Chatter Groups
	Map<String, Community_Group_Manager__c> uniqueToManagerMap = new Map<String, Community_Group_Manager__c>();
	if (groupIds.size() > 0) {
		for (Community_Group_Manager__c cgm : [
			SELECT Id, Group_Control__r.Chatter_Group_ID__c, Group_Manager_User__c
			FROM Community_Group_Manager__c
			WHERE Group_Control__c != NULL AND Group_Control__r.Chatter_Group_ID__c IN :groupIds AND Group_Manager_User__c IN :memberIds
		]) {
			uniqueToManagerMap.put('' + cgm.Group_Control__r.Chatter_Group_ID__c + cgm.Group_Manager_User__c, cgm);
		}
	}

	// create new Unity Managers
	Map<Id,Id> chatterGroupToUnityGroupMap = new Map<Id,Id>();
	if (newChatterManagers.size() > 0) {
		for (Community_Group_Control__c cgc : [SELECT Id, Chatter_Group_ID__c FROM Community_Group_Control__c WHERE Chatter_Group_ID__c IN :groupIds]) {
			try {
				chatterGroupToUnityGroupMap.put(Id.valueOf(cgc.Chatter_Group_ID__c), cgc.Id);
			}
			catch(Exception e) {}
		}
	}
	List<Community_Group_Manager__c> newManagers = new List<Community_Group_Manager__c>();
	if (chatterGroupToUnityGroupMap.size() > 0) {
		for (CollaborationGroupMember chgm3 : newChatterManagers) {
			if (chatterGroupToUnityGroupMap.containsKey(chgm3.CollaborationGroupId) && !uniqueToManagerMap.containsKey('' + chgm3.CollaborationGroupId + chgm3.MemberId)) {
				newManagers.add(new Community_Group_Manager__c(
					Group_Manager_User__c = chgm3.MemberId,
					Group_Control__c = chatterGroupToUnityGroupMap.get(chgm3.CollaborationGroupId),
					Manager_Role__c = 'Manager'
				));
			}
		}
	}
	if (newManagers.size() > 0) {
		insert newManagers;
	}

	// delete related Unity Managers
	List<Community_Group_Manager__c> removeManagers = new List<Community_Group_Manager__c>();
	for (CollaborationGroupMember chgm4 : removeChatterManagers) {
		String dKey = '' + chgm4.CollaborationGroupId + chgm4.MemberId;
		if (uniqueToManagerMap.containsKey(dKey)) {
			removeManagers.add(uniqueToManagerMap.get(dKey));
		}
	}
	if (removeManagers.size() > 0) {
		delete removeManagers;
	}

}