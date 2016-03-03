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

trigger CollaborationGroup on CollaborationGroup (after update) {

	if (Trigger.isAfter && Trigger.isUpdate && CommunityUtils.isChatterGroupTriggerWorked != true) {
		Map<Id, CollaborationGroup> changedGroupMap = new Map<Id, CollaborationGroup>();
		for (CollaborationGroup cg : Trigger.new) {
			CollaborationGroup ocg = Trigger.oldMap.get(cg.Id);
			Boolean fieldChanged = cg.Description != ocg.Description;
			fieldChanged = cg.Name != ocg.Name ? true : fieldChanged;
			fieldChanged = cg.CollaborationType != ocg.CollaborationType ? true : fieldChanged;
			fieldChanged = cg.InformationBody != ocg.InformationBody ? true : fieldChanged;
			fieldChanged = cg.IsAutoArchiveDisabled != ocg.IsAutoArchiveDisabled ? true : fieldChanged;
			fieldChanged = cg.OwnerId != ocg.OwnerId ? true : fieldChanged;
			if (fieldChanged) {
				changedGroupMap.put(cg.Id, cg);
			}
		}
		List<Community_Group_Control__c> cgcList = [
			SELECT Id, Name, Chatter_Group_ID__c, Type__c, Description__c, Information__c, Automatic_Archiving__c, OwnerId, Network__c
			FROM Community_Group_Control__c
			WHERE Chatter_Group_ID__c IN :changedGroupMap.keySet()
		];
		if (cgcList.size() > 0) {
			for (Community_Group_Control__c cgc : cgcList) {
				CollaborationGroup cg2 = changedGroupMap.get(cgc.Chatter_Group_ID__c);
				cgc.Description__c = cg2.Description;
				cgc.Name = cg2.Name;
				cgc.Type__c = cg2.CollaborationType;
				cgc.Information__c = cg2.InformationBody;
				cgc.Automatic_Archiving__c = cg2.IsAutoArchiveDisabled == false;
				cgc.OwnerId = cg2.OwnerId;
			}
			try {
				update cgcList;
			}
			catch(Exception e) {}
		}
		CommunityUtils.isChatterGroupTriggerWorked = true;
	}

}