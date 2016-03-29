global class CommunityBatch implements Database.Batchable<sObject> {

	String query;
	String method;
	Map<String, String> params;

	global CommunityBatch(String q, String m, Map<String, String> p) {
		query = q;
		method = m;
		params = p;
	}

	global Database.QueryLocator start(Database.BatchableContext BC) {
		return Database.getQueryLocator(query);
	}

	global void execute(Database.BatchableContext BC, List<sObject> scope) {
		if (method == 'migrateField') {
			CommunityBatchHelper.migrateField(scope, params);
		}
		System.debug('scope: ' + scope + '\nmethod: ' + method + '\nparams: ' + params);
	}

	global void finish(Database.BatchableContext BC) {

	}
}