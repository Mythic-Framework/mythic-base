const mongodb = require('mongodb');
const utils = require('./db_utils');

let gameDb;
let authDb;

let Database = null;
let Convar = null;

const DATABASE = {
	_protected: true,
	_required: ['Game', 'Auth'],
	_name: 'base',
	/* THESE METHODS SHOULD BE CONSIDERED DEPRECATED. THEY WILL BE REMOVED BEFORE ANY PRODUCTION RELEASE */
	isConnected: () => !!Methods.isConnected(gameDb),
	insert: (t, params, callback) => {
		Log('^9DEPRECATED DATABSE METHOD USED, UPDATE ASAP^7', { console: true });
		return Methods.insert(gameDb, params, callback);
	},
	insertOne: (t, params, callback) => {
		Log('^9DEPRECATED DATABSE METHOD USED, UPDATE ASAP^7', { console: true });
		return Methods.insertOne(gameDb, params, callback);
	},
	find: (t, params, callback) => {
		Log('^9DEPRECATED DATABSE METHOD USED, UPDATE ASAP^7', { console: true });
		return Methods.find(gameDb, params, callback);
	},
	findOne: (t, params, callback) => {
		Log('^9DEPRECATED DATABSE METHOD USED, UPDATE ASAP^7', { console: true });
		return Methods.findOne(gameDb, params, callback);
	},
	update: (t, params, callback, isUpdateOne) => {
		Log('^9DEPRECATED DATABSE METHOD USED, UPDATE ASAP^7', { console: true });
		return Methods.update(gameDb, params, callback, isUpdateOne);
	},
	updateOne: (t, params, callback) => {
		Log('^9DEPRECATED DATABSE METHOD USED, UPDATE ASAP^7', { console: true });
		return Methods.updateOne(gameDb, params, callback);
	},
	delete: (t, params, callback, isDeleteOne) => {
		Log('^9DEPRECATED DATABSE METHOD USED, UPDATE ASAP^7', { console: true });
		return Methods.delete(gameDb, params, callback, isDeleteOne);
	},
	deleteOne: (t, params, callback) => {
		Log('^9DEPRECATED DATABSE METHOD USED, UPDATE ASAP^7', { console: true });
		return Methods.deleteOne(gameDb, params, callback);
	},
	count: (t, params, callback) => {
		Log('^9DEPRECATED DATABSE METHOD USED, UPDATE ASAP^7', { console: true });
		return Methods.count(gameDb, params, callback);
	},
	Game: {
		isConnected: () => !!Methods.isConnected(gameDb),
		insert: (t, params, callback) => Methods.insert(gameDb, params, callback),
		insertOne: (t, params, callback) => Methods.insertOne(gameDb, params, callback),
		find: (t, params, callback) => Methods.find(gameDb, params, callback),
		findOne: (t, params, callback) => Methods.findOne(gameDb, params, callback),
		update: (t, params, callback, isUpdateOne) => Methods.update(gameDb, params, callback, isUpdateOne),
		updateOne: (t, params, callback) => Methods.updateOne(gameDb, params, callback),
		delete: (t, params, callback, isDeleteOne) => Methods.delete(gameDb, params, callback, isDeleteOne),
		deleteOne: (t, params, callback) => Methods.deleteOne(gameDb, params, callback),
		findOneAndUpdate: (t, params, callback) => Methods.findOneAndUpdate(gameDb, params, callback),
		count: (t, params, callback) => Methods.count(gameDb, params, callback),
		aggregate: (t, params, callback) => Methods.aggregate(gameDb, params, callback),
	},
	Auth: {
		isConnected: () => !!Methods.isConnected(authDb),
		insert: (t, params, callback) => Methods.insert(authDb, params, callback),
		insertOne: (t, params, callback) => Methods.insertOne(authDb, params, callback),
		find: (t, params, callback) => Methods.find(authDb, params, callback),
		findOne: (t, params, callback) => Methods.findOne(authDb, params, callback),
		update: (t, params, callback, isUpdateOne) => Methods.update(authDb, params, callback, isUpdateOne),
		updateOne: (t, params, callback) => Methods.updateOne(authDb, params, callback),
		delete: (t, params, callback, isDeleteOne) => Methods.delete(authDb, params, callback, isDeleteOne),
		deleteOne: (t, params, callback) => Methods.deleteOne(authDb, params, callback),
		findOneAndUpdate: (t, params, callback) => Methods.findOneAndUpdate(authDb, params, callback),
		count: (t, params, callback) => Methods.count(authDb, params, callback),
		aggregate: (t, params, callback) => Methods.aggregate(authDb, params, callback),
	},
};

AddEventHandler('onResourceStop', function (resource) {
	if (resource === GetCurrentResourceName()) {
		if (gameDb) { gameDb.client.close(); gameDb = null; }
		if (authDb) { authDb.client.close(); authDb = null; }
	}
});

AddEventHandler('Database:Shared:DependencyUpdate', RetrieveComponents);

function RetrieveComponents() {
	Convar = exports[GetCurrentResourceName()].FetchComponent('Convar');
	Database = exports[GetCurrentResourceName()].FetchComponent('Database');
}

AddEventHandler('Core:Shared:Ready', () => {
	exports['mythic-base'].RequestDependencies(
		'Database',
		['Convar', 'Database'],
		(error) => {
			if (error.length > 0) return;
			RetrieveComponents();
		},
	);
});

AddEventHandler(
	'Database:Server:Initialize',
	async function (a_url, a_db, g_url, g_db) {
		if (Database !== null && Database.Game.isConnected() && Database.Auth.isConnected()) {
			emit('Database:Server:Ready');
			return;
		}
		try {
			const authClient = new mongodb.MongoClient(a_url);
			await authClient.connect();
			authDb = authClient.db(a_db);
			LogTrace(`[^31^7/^22^7] Connected to authentication database "${a_db}".`);

			const gameClient = new mongodb.MongoClient(g_url);
			await gameClient.connect();
			gameDb = gameClient.db(g_db);
			LogTrace(`[^22^7/^22^7] ^7Connected to game database "${g_db}".`);

			emit('Database:Server:Ready', DATABASE);
		} catch (err) {
			Log('Error: ' + err.message);
		}
	},
);

function LogTrace(log) {
	emit(`Logger:Trace`, 'Database', log, { console: true });
}

function Log(log, flagOverride = null) {
	emit(
		`Logger:Error`,
		'Database',
		log,
		flagOverride == null
			? { console: true, database: true, file: true, discord: { style: 'error' } }
			: flagOverride,
	);
}

function checkDatabaseReady() {
	if (!gameDb || !authDb) {
		Log(`Database is not connected.`, { console: true });
		return false;
	}
	return true;
}

function checkParams(params) {
	return params !== null && typeof params === 'object';
}

function getParamsCollection(db, params) {
	if (!params.collection) return;
	return db.collection(params.collection);
}

const Methods = {
	isConnected: (db) => !!db,

	insert: (db, params, callback) => {
		if (!checkDatabaseReady()) return;
		if (!checkParams(params)) return Log(`insert: Invalid params object.`);

		const collection = getParamsCollection(db, params);
		if (!collection) return Log(`insert: Invalid collection "${params.collection}"`);

		const documents = params.documents;
		if (!documents || !Array.isArray(documents))
			return Log(`insert: Invalid 'params.documents' value. Expected object or array of objects.`);

		const options = utils.safeObjectArgument(params.options);

		collection.insertMany(documents, options)
			.then((result) => {
				const arrayOfIds = Object.entries(result.insertedIds).map(([k, v]) => v.toString());
				utils.safeCallback(callback, true, result.insertedCount, arrayOfIds);
			})
			.catch((err) => {
				Log(`insert [${params.collection}]: Error "${err.message}".`);
				utils.safeCallback(callback, false, err.message);
			});
	},

	insertOne: (db, params, callback) => {
		if (checkParams(params)) {
			params.documents = [params.document];
			params.document = null;
		}
		return Methods.insert(db, params, callback);
	},

	find: (db, params, callback) => {
		if (!checkDatabaseReady()) return;
		if (!checkParams(params)) return Log(`find: Invalid params object.`);

		const collection = getParamsCollection(db, params);
		if (!collection) return Log(`find: Invalid collection "${params.collection}"`);

		const query = utils.safeObjectArgument(params.query);
		const options = utils.safeObjectArgument(params.options);

		let cursor = collection.find(query, options);
		if (params.limit) cursor = cursor.limit(params.limit);

		cursor.toArray()
			.then((documents) => {
				utils.safeCallback(callback, true, utils.exportDocuments(documents));
			})
			.catch((err) => {
				Log(`find [${params.collection}]: Error "${err.message}".`);
				utils.safeCallback(callback, false, err.message);
			});
	},

	findOne: (db, params, callback) => {
		if (checkParams(params)) params.limit = 1;
		return Methods.find(db, params, callback);
	},

	update: (db, params, callback, isUpdateOne) => {
		if (!checkDatabaseReady()) return;
		if (!checkParams(params)) return Log(`update: Invalid params object.`);

		const collection = getParamsCollection(db, params);
		if (!collection) return Log(`update: Invalid collection "${params.collection}"`);

		const query = utils.safeObjectArgument(params.query);
		const update = utils.safeObjectArgument(params.update);
		const options = utils.safeObjectArgument(params.options);

		const op = isUpdateOne
			? collection.updateOne(query, update, options)
			: collection.updateMany(query, update, options);

		op.then((res) => {
			utils.safeCallback(callback, true, res.modifiedCount);
		}).catch((err) => {
			Log(`update [${params.collection}]: Error "${err.message}".`);
			utils.safeCallback(callback, false, err.message);
		});
	},

	updateOne: (db, params, callback) => Methods.update(db, params, callback, true),

	delete: (db, params, callback, isDeleteOne) => {
		if (!checkDatabaseReady()) return;
		if (!checkParams(params)) return Log(`delete: Invalid params object.`);

		const collection = getParamsCollection(db, params);
		if (!collection) return Log(`delete: Invalid collection "${params.collection}"`);

		const query = utils.safeObjectArgument(params.query);
		const options = utils.safeObjectArgument(params.options);

		const op = isDeleteOne
			? collection.deleteOne(query, options)
			: collection.deleteMany(query, options);

		op.then((res) => {
			utils.safeCallback(callback, true, res.deletedCount);
		}).catch((err) => {
			Log(`delete [${params.collection}]: Error "${err.message}".`);
			utils.safeCallback(callback, false, err.message);
		});
	},

	deleteOne: (db, params, callback) => Methods.delete(db, params, callback, true),

	count: (db, params, callback) => {
		if (!checkDatabaseReady()) return;
		if (!checkParams(params)) return Log(`count: Invalid params object.`);

		const collection = getParamsCollection(db, params);
		if (!collection) return Log(`count: Invalid collection "${params.collection}"`);

		const query = utils.safeObjectArgument(params.query);
		const options = utils.safeObjectArgument(params.options);

		collection.countDocuments(query, options)
			.then((count) => {
				utils.safeCallback(callback, true, count);
			})
			.catch((err) => {
				Log(`count [${params.collection}]: Error "${err.message}".`);
				utils.safeCallback(callback, false, err.message);
			});
	},

	findOneAndUpdate: (db, params, callback) => {
		if (!checkDatabaseReady()) return;
		if (!checkParams(params)) return Log(`findOneAndUpdate: Invalid params object.`);

		const collection = getParamsCollection(db, params);
		if (!collection) return Log(`findOneAndUpdate: Invalid collection "${params.collection}"`);

		const query = utils.safeObjectArgument(params.query);
		const update = utils.safeObjectArgument(params.update);
		// returnDocument: 'before' matches old behavior of returning the original doc
		const options = { ...utils.safeObjectArgument(params.options), returnDocument: 'before' };

		collection.findOneAndUpdate(query, update, options)
			.then((res) => {
				// v5+ returns the document directly, not wrapped in { value }
				utils.safeCallback(callback, true, utils.exportDocument(res));
			})
			.catch((err) => {
				Log(`findOneAndUpdate [${params.collection}]: Error "${err.message}".`);
				utils.safeCallback(callback, false, err.message);
			});
	},

	aggregate: (db, params, callback) => {
		if (!checkDatabaseReady()) return;
		if (!checkParams(params)) return Log(`aggregate: Invalid params object.`);

		const collection = getParamsCollection(db, params);
		if (!collection) return Log(`aggregate: Invalid collection "${params.collection}"`);

		collection.aggregate(params.aggregate).toArray()
			.then((documents) => {
				utils.safeCallback(callback, true, utils.exportDocuments(documents));
			})
			.catch((err) => {
				Log(`aggregate [${params.collection}]: Error "${err.message}".`);
				utils.safeCallback(callback, false, err.message);
			});
	},
};