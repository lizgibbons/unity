public with sharing class CommunityBatchHelper {

	public static Boolean migrateField(List<SObject> records, Map<String, String> fieldMapping) {
		try {
			for (String fld : fieldMapping.keySet()) {
				String mappedFld = fieldMapping.get(fld);
				for (SObject record : records) {
					if (record.get(fld) != null) {
						record.put(mappedFld, record.get(fld));
					}
				}
			}
			update records;
		} catch(Exception e) {
			System.debug(e.getMessage());
			return false;
		}
		return true;
	}

	public static void startMigrateProfileTagContactField() {
		String prefix = CommunityUtils.getPackagePrefix();
		String queryString = 'SELECT Id, {0}Contact__c, {0}Related_Contact__c FROM {0}Community_Profile_Tag__c WHERE {0}Related_Contact__c = null AND {0}Contact__c != null';
		String query = String.format(queryString, new List<String>{ prefix });
		Map<String, String> params = new Map<String, String> { prefix+'Contact__c' => prefix+'Related_Contact__c' };

		CommunityBatch b = new CommunityBatch(query, 'migrateField', params);
		Database.executeBatch(b);
	}

}