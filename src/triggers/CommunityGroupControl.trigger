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

trigger CommunityGroupControl on Community_Group_Control__c (before insert, after insert, after update) {

	if (Trigger.isBefore && Trigger.isInsert) {
		Boolean validationPassed = true;
		Map<String, CollaborationGroup> newChatterGroupsByGCid = new Map<String, CollaborationGroup>();
		Map<String, Community_Group_Control__c> checkUniqueNamesMap = new Map<String, Community_Group_Control__c>();
		Map<String, Id> communityIdByName = new Map<String, Id>();
		Boolean firstCommunity = true;
		for (Network nItem : [SELECT Id, Name FROM Network LIMIT 100]) {
			communityIdByName.put(nItem.Name, nItem.Id);
			if (firstCommunity) {
				communityIdByName.put('Community', nItem.Id);
				firstCommunity = false;
			}
		}
		for (Community_Group_Control__c cgcItem : Trigger.new) {
			// Validation block
			if (String.isNotBlank(cgcItem.Chatter_Group_ID__c) && !CommunityUtils.isValidId(cgcItem.Chatter_Group_ID__c)) {
				cgcItem.addError('Value of Chatter Group ID field is not a valid Id.');
				validationPassed = false;
			}
			if (checkUniqueNamesMap.containsKey(cgcItem.Name)) {
				cgcItem.addError(Label.ERR_Dup_Group_Name);
				validationPassed = false;
			}
			else {
				if (cgcItem.Name.Length()>40) {
					cgcItem.addError(Label.ERR_Name_is_too_long);
					validationPassed = false;
				}
				else {
					checkUniqueNamesMap.put(cgcItem.Name, cgcItem);
				}
			}
			// Operation block
			if (validationPassed && cgcItem.Chatter_Group_ID__c == NULL) {
				newChatterGroupsByGCid.put(cgcItem.Name, new CollaborationGroup(
					CollaborationType = cgcItem.Type__c,
					Description = cgcItem.Description__c,
					InformationTitle = 'Information',
					InformationBody = cgcItem.Information__c,
					IsArchived = false,
					Name = cgcItem.Name,
					IsAutoArchiveDisabled = !cgcItem.Automatic_Archiving__c,
					NetworkId = Network.getNetworkId()
				));
			}
		}
		// Check for duplicated Group Name
		if (validationPassed) {
			for (Community_Group_Control__c cgcItem2 : [SELECT Name FROM Community_Group_Control__c WHERE Name IN :checkUniqueNamesMap.keySet()]) {
				checkUniqueNamesMap.get(cgcItem2.Name).addError(Label.ERR_Dup_Group_Name);
				validationPassed = false;
			}
		}
		// Create CollaborationGroup and populate Chatter_Group_ID__c field
		if (validationPassed && newChatterGroupsByGCid.size() > 0) {
			insert newChatterGroupsByGCid.values();
			for (Community_Group_Control__c cgcItem3 : Trigger.new) {
				if (cgcItem3.Chatter_Group_ID__c == NULL ) {
					cgcItem3.Chatter_Group_ID__c = newChatterGroupsByGCid.get(cgcItem3.Name).Id;
				}
			}
		}
	}

	if (Trigger.isAfter && Trigger.isInsert) {
		Map<Id, Community_Group_Control__c> GroupControlIdByChatterGroupId = new Map<Id, Community_Group_Control__c>();
		for (Community_Group_Control__c cgcItem : Trigger.new) {
			if (cgcItem.Chatter_Group_ID__c != NULL) {
				GroupControlIdByChatterGroupId.put(Id.valueOf(cgcItem.Chatter_Group_ID__c), cgcItem);
			}
		}
		if (GroupControlIdByChatterGroupId.size() > 0) {
			List<Community_Group_Manager__c> membersCommunityGroup = new List<Community_Group_Manager__c>();
			for (CollaborationGroupMember cgmItem : [
				SELECT MemberId, CollaborationGroup.OwnerId
				FROM CollaborationGroupMember
				WHERE CollaborationGroupId IN :GroupControlIdByChatterGroupId.keySet() AND CollaborationRole = 'Admin']
			) {
				Community_Group_Control__c cgcFromMap = GroupControlIdByChatterGroupId.get(cgmItem.CollaborationGroupId);
				membersCommunityGroup.add(
					new Community_Group_Manager__c(
						Group_Control__c = cgcFromMap.Id,
						Group_Manager_User__c = cgmItem.MemberId,
						Manager_Role__c = (cgmItem.CollaborationGroup.OwnerId == cgmItem.MemberId ? 'Owner' : 'Manager')
					)
				);
			}
			if (membersCommunityGroup.size() > 0) {
				CommunityUtils.isGroupTriggerWorked = true;
				insert membersCommunityGroup;
			}
		}
	}

	if (Trigger.isAfter && Trigger.isUpdate) {
		CommunityUtils.isChatterGroupTriggerWorked = true;
		Boolean validationPassed2 = true;
		Map<String, Community_Group_Control__c> checkUniqueNamesMap2 = new Map<String, Community_Group_Control__c>();
		Map<String,String> changedCollaborationType = new Map<String,String>();
		Map<String,Boolean> changedCollaborationArchiveDisabled = new Map<String,Boolean>();
		Set<Id> excludeCurrentGroupControls = new Set<Id>();

		// change owner collections
		Map<Id,Id> chatterGroupsWithNewOwners = new Map<Id,Id>();
		Map<Id,Id> groupControlsWithNewOwners = new Map<Id,Id>();
		List<Community_Group_Control__c> groupControlsList = new List<Community_Group_Control__c>();

		// change name in chatter group collection
		Map<Id, String> chatterGroupToNewNameMap = new Map<Id, String>();

		for (Community_Group_Control__c cgcItem2 : Trigger.new) {
			if (cgcItem2.Name != Trigger.oldMap.get(cgcItem2.Id).Name) {
				if (String.isNotBlank(cgcItem2.Chatter_Group_ID__c) && !CommunityUtils.isValidId(cgcItem2.Chatter_Group_ID__c)) {
					cgcItem2.addError('Value of Chatter Group ID field is not a valid Id.');
					validationPassed2 = false;
				}
				if (checkUniqueNamesMap2.containsKey(cgcItem2.Name)) {
					cgcItem2.addError(Label.ERR_Dup_Group_Name);
					validationPassed2 = false;
				}
				if (cgcItem2.Name.Length()>40) {
					cgcItem2.addError(Label.ERR_Name_is_too_long);
					validationPassed2 = false;
				}
				checkUniqueNamesMap2.put(cgcItem2.Name, cgcItem2);
				excludeCurrentGroupControls.add(cgcItem2.Id);
				if (cgcItem2.Chatter_Group_ID__c != NULL) {
					chatterGroupToNewNameMap.put(cgcItem2.Chatter_Group_ID__c, cgcItem2.Name);
				}
			}

			// Change archived block
			if (cgcItem2.Automatic_Archiving__c != Trigger.oldMap.get(cgcItem2.Id).Automatic_Archiving__c && cgcItem2.Chatter_Group_ID__c != NULL) {
				changedCollaborationArchiveDisabled.put(cgcItem2.Chatter_Group_ID__c, !cgcItem2.Automatic_Archiving__c);
			}

			// Change owner block
			if (cgcItem2.Type__c != Trigger.oldMap.get(cgcItem2.Id).Type__c && cgcItem2.Chatter_Group_ID__c != NULL) {
				changedCollaborationType.put(cgcItem2.Chatter_Group_ID__c, cgcItem2.Type__c);
			}
			if (cgcItem2.OwnerId != Trigger.oldMap.get(cgcItem2.Id).OwnerId) {
				groupControlsList.add(cgcItem2);
				groupControlsWithNewOwners.put(cgcItem2.Id, cgcItem2.OwnerId);
				if (cgcItem2.Chatter_Group_ID__c != NULL) {
					Id tId = Id.valueOf(cgcItem2.Chatter_Group_ID__c);
					chatterGroupsWithNewOwners.put(tId, cgcItem2.OwnerId);
				}
			}
		}

		if (validationPassed2 && checkUniqueNamesMap2.size() > 0) {
			for (Community_Group_Control__c cgcItem3 : [SELECT Name FROM Community_Group_Control__c WHERE Name IN :checkUniqueNamesMap2.keySet() AND Id NOT IN :excludeCurrentGroupControls]) {
				checkUniqueNamesMap2.get(cgcItem3.Name).addError(Label.ERR_Dup_Group_Name);
				validationPassed2 = false;
			}
		}
		if (validationPassed2 && chatterGroupToNewNameMap.size() > 0) {
			List<CollaborationGroup> changeNameList = [SELECT Id, Name FROM CollaborationGroup WHERE Id IN :chatterGroupToNewNameMap.keySet()];
			for (CollaborationGroup cgItem : changeNameList) {
				cgItem.Name = chatterGroupToNewNameMap.get(cgItem.Id);
			}
			update changeNameList;
		}
		if (validationPassed2 && changedCollaborationType.size() > 0) {
			List<CollaborationGroup> cgList = [SELECT Id, CollaborationType FROM CollaborationGroup WHERE Id IN :changedCollaborationType.keySet()];
			for (CollaborationGroup cgItem : cgList) {
				cgItem.CollaborationType = changedCollaborationType.get(cgItem.Id);
			}
			update cgList;
		}
		if (validationPassed2 && changedCollaborationArchiveDisabled.size() > 0) {
			List<CollaborationGroup> cgList = [SELECT Id, IsAutoArchiveDisabled FROM CollaborationGroup WHERE Id IN :changedCollaborationArchiveDisabled.keySet()];
			for (CollaborationGroup cgItem : cgList) {
				cgItem.IsAutoArchiveDisabled = changedCollaborationArchiveDisabled.get(cgItem.Id);
			}
			update cgList;
		}

		// Change owner block
		if (validationPassed2 && groupControlsWithNewOwners.size() > 0) {
			Set<Id> newLuckyOnes = new Set<Id>();
			newLuckyOnes.addAll(groupControlsWithNewOwners.values());
			Set<String> groupManagersUniqueId = new Set<String>();
			List<Community_Group_Manager__c> cgmListToUpsert = new List<Community_Group_Manager__c>();
			for (Community_Group_Manager__c cgmItem : [
				SELECT Id, Group_Manager_User__c, Group_Control__c, Manager_Role__c FROM Community_Group_Manager__c
				WHERE (Group_Manager_User__c IN :newLuckyOnes OR Manager_Role__c = 'Owner')
					AND Group_Control__c IN :groupControlsWithNewOwners.keySet()
			]) {
				Id currentNewGroupOwnerId = groupControlsWithNewOwners.get(cgmItem.Group_Control__c);
				if (cgmItem.Group_Manager_User__c != currentNewGroupOwnerId && cgmItem.Manager_Role__c == 'Owner') {
					cgmItem.Manager_Role__c = 'Manager';
					cgmListToUpsert.add(cgmItem);
				}
				if (cgmItem.Group_Manager_User__c == currentNewGroupOwnerId && cgmItem.Manager_Role__c != 'Owner') {
					cgmItem.Manager_Role__c = 'Owner';
					cgmListToUpsert.add(cgmItem);
				}
				groupManagersUniqueId.add('' + cgmItem.Group_Control__c + cgmItem.Group_Manager_User__c);
			}

			Set<String> existingChatterGroupManagers = new Set<String>();
			Map<String,CollaborationGroupMember> chatterMemberUniqueIdMap = new Map<String,CollaborationGroupMember>();
			if (chatterGroupsWithNewOwners.size() > 0) {
				for (CollaborationGroupMember cgmItem2 : [
					SELECT Id, MemberId, CollaborationGroupId, CollaborationRole FROM CollaborationGroupMember
					WHERE MemberId IN :newLuckyOnes AND CollaborationGroupId IN :chatterGroupsWithNewOwners.keySet()
				]) {
					chatterMemberUniqueIdMap.put('' + cgmItem2.CollaborationGroupId + cgmItem2.MemberId, cgmItem2);
				}
			}

			List<CollaborationGroupMember> chatterMembersToUpsert = new List<CollaborationGroupMember>();
			for (Community_Group_Control__c cgcItem : groupControlsList) {
				if (!groupManagersUniqueId.contains('' + cgcItem.Id + cgcItem.OwnerId)) {
					cgmListToUpsert.add(new Community_Group_Manager__c(
						Group_Manager_User__c = cgcItem.OwnerId,
						Group_Control__c = cgcItem.Id,
						Manager_Role__c = 'Owner'
					));
				}
				CollaborationGroupMember tCgm = chatterMemberUniqueIdMap.get('' + cgcItem.Chatter_Group_ID__c + cgcItem.OwnerId);
				if (tCgm == NULL) {
					chatterMembersToUpsert.add(new CollaborationGroupMember(
						MemberId = cgcItem.OwnerId,
						CollaborationGroupId = cgcItem.Chatter_Group_ID__c,
						CollaborationRole = 'Admin'
					));
				}
				else if (tCgm.CollaborationRole != 'Admin') {
					tCgm.CollaborationRole = 'Admin';
					chatterMembersToUpsert.add(tCgm);
				}
			}

			CommunityUtils.isGroupTriggerWorked = true;
			if (chatterMembersToUpsert.size() > 0) {
				upsert chatterMembersToUpsert;
			}
			if (cgmListToUpsert.size() > 0) {
				upsert cgmListToUpsert;
			}

			if (chatterGroupsWithNewOwners.size() > 0) {
				List<CollaborationGroup> updateOwnerList = [SELECT Id, OwnerId FROM CollaborationGroup WHERE Id IN :chatterGroupsWithNewOwners.keySet()];
				for (CollaborationGroup cgItem : updateOwnerList) {
					cgItem.OwnerId = chatterGroupsWithNewOwners.get(cgItem.Id);
				}
				update updateOwnerList;
			}

		}

		// synchronize "Description" and "Information" fields
		Map<Id, Community_Group_Control__c> cgcMap = new Map<Id, Community_Group_Control__c>();
		for (Community_Group_Control__c cgcItem : Trigger.new) {
			Community_Group_Control__c oldValue = Trigger.oldMap.get(cgcItem.Id);
			if (cgcItem.Description__c != oldValue.Description__c || cgcItem.Information__c != oldValue.Information__c) {
				cgcMap.put(cgcItem.Chatter_Group_Id__c, cgcItem);
			}
		}
		if (cgcMap.size() > 0) {
			List<CollaborationGroup> cgList = [SELECT Id, Name, Description, InformationBody, InformationTitle FROM CollaborationGroup WHERE Id IN :cgcMap.keySet()];
			for (CollaborationGroup cg : cgList) {
				Community_Group_Control__c cgcv = cgcMap.get(cg.Id);
				cg.Description = cgcv.Description__c;
				cg.InformationBody = cgcv.Information__c;
				cg.InformationTitle = cg.InformationTitle == null ? 'Information' : cg.InformationTitle;
			}
			try {
				update cgList;
			}
			catch (Exception e) {}
		}
	}
}