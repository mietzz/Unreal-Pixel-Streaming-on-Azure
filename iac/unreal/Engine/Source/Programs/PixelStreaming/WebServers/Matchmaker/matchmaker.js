// Copyright Epic Games, Inc. All Rights Reserved.

import * as msRestNodeAuth from "@azure/ms-rest-nodeauth";


// A variable to hold the last time we scaled up, used for determining if we are in a determined idle state and might need to scale down (via idleMinutes and connectionIdleRatio)
var lastScaleupTime = Date.now();
// A varible to the last time we scaled down, used for a reference to know how quick we should consider scaling down again (to avoid multiple scale downs too soon)
var lastScaledownTime = Date.now();
// The number of total app instances that are connecting to the matchmaker
var totalInstances = 0;
// The min minutes between each scaleup (so we don't scale up every frame while we wait for the scale to complete)
var minMinutesBetweenScaleups = 1;
var minMinutesBetweenScaledowns = 2;

const defaultConfig = {
	// The port clients connect to the matchmaking service over HTTP
	httpPort: 90,
	// The matchmaking port the signaling service connects to the matchmaker
	matchmakerPort: 9999,
	// The amount of instances deployed per node, to be used in the autoscale policy (2 unreal apps running per GPU VM)
	instancesPerNode: 2,
	// The amount of available signaling service / App instances we want to ensure are available before we have to scale up (0 will ignore)
	instanceCountBuffer: 5,
	// The percentage amount of available signaling service / App instances we want to ensure are available before we have to scale up (0 will ignore)
	percentBuffer: 75,
	//The amount of minutes of no scaling up activity before we decide we might want to see if we should scale down (i.e., after hours--reduce costs)
	idleMinutes: 60,
	// The percentage of active connections to total instances that we want to trigger a scale down once idleMinutes passes with no scaleup
	connectionIdleRatio: 25,
	// The minimum number of available app instances we want to scale down to during an idle period (idleMinutes passed with no scaleup)
	minIdleInstanceCount: 5
};

const argv = require('yargs').argv;

var configFile = (typeof argv.configFile != 'undefined') ? argv.configFile.toString() : '.\\config.json';
console.log(`configFile ${configFile}`);
const config = require('./modules/config.js').init(configFile, defaultConfig);
console.log("Config: " + JSON.stringify(config, null, '\t'));

const express = require('express');
const app = express();
const http = require('http').Server(app);

const msRestAzure = require('ms-rest-azure');
const msRest = require('ms-rest');

// A list of all the Cirrus server which are connected to the Matchmaker.
var cirrusServers = new Map();

//
// Parse command line.
//

if (typeof argv.httpPort != 'undefined') {
	config.httpPort = argv.httpPort;
}
if (typeof argv.matchmakerPort != 'undefined') {
	config.matchmakerPort = argv.matchmakerPort;
}

const options: msRestNodeAuth.MSIVmOptions = {
	// The objectId of the managed identity you would like the token for.
	// Required, if your VM has multiple user-assigned managed identities.
	//
	//     objectId: "your-managed-identity-object-id",
	//

	// The clientId of the managed identity you would like the token for.
	// Required, if your VM has any user-assigned managed identity.
	//
	//     clientId: "your-managed-identity-client-id",
	//

	// The `Azure Resource ID` of the managed identity you would like the token for.
	// Required, if your VM has multiple user-assigned managed identities.
	//
	//     identityId: "your-managed-identity-identity-id",
	//
}

msRestNodeAuth.loginWithVmMSI(options).then((msiTokenRes) => {
	console.log(msiTokenRes);
}).catch((err) => {
	console.log(err);
});


//
// Connect to browser.
//

http.listen(config.httpPort, () => {
	console.log('HTTP listening on *:' + config.httpPort);
});

// Get a Cirrus server if there is one available which has no clients connected.
function getAvailableCirrusServer() {

	for (cirrusServer of cirrusServers.values()) {
		if (cirrusServer.numConnectedClients === 0) {
			return cirrusServer;
		}
	}

	console.log('WARNING: No empty Cirrus servers are available');
	return undefined;
}

// No servers are available so send some simple JavaScript to the client to make
// it retry after a short period of time.
function sendRetryResponse(res) {
	res.send(`All ${cirrusServers.size} Cirrus servers are in use. Retrying in <span id="countdown">10</span> seconds.
	<script>
		var countdown = document.getElementById("countdown").textContent;
		setInterval(function() {
			countdown--;
			if (countdown == 0) {
				window.location.reload(1);
			} else {
				document.getElementById("countdown").textContent = countdown;
			}
		}, 1000);
	</script>`);
}

// Handle standard URL.
app.get('/', (req, res) => {
	cirrusServer = getAvailableCirrusServer();
	if (cirrusServer != undefined) {
		res.redirect(`http://${cirrusServer.address}:${cirrusServer.port}/`);
		console.log(`Redirect to ${cirrusServer.address}:${cirrusServer.port}`);
	} else {
		sendRetryResponse(res);
	}
});

// Handle URL with custom HTML.
app.get('/custom_html/:htmlFilename', (req, res) => {
	cirrusServer = getAvailableCirrusServer();
	if (cirrusServer != undefined) {
		res.redirect(`http://${cirrusServer.address}:${cirrusServer.port}/custom_html/${req.params.htmlFilename}`);
		console.log(`Redirect to ${cirrusServer.address}:${cirrusServer.port}`);
	} else {
		sendRetryResponse(res);
	}
});

//
// Connection to Cirrus.
//

const net = require('net');

function disconnect(connection) {
	console.log(`Ending connection to remote address ${connection.remoteAddress}`);
	connection.end();
}

function scaleupInstances(newNodeCount) {
	console.log(`Scaling up${newNodeCount}!!! Well.. once I code it`);

	lastScaleupTime = Date.now
	//TODO: Use Managed Identity code to scale up the new VMSS node count
}

function scaledownInstances(newNodeCount) {
	console.log(`Scaling down to ${newNodeCount}!!! Well.. once I code it`);
	lastScaledownTime = Date.now();

	//TODO: Use Managed Identity code to scale down the new VMSS node count
}

function considerAutoScale() {
	console.log(`Considering AutoScale....`);

	totalInstances = cirrusServers.size;

	console.log(`Current Servers Connected: ${totalInstances} Current Clients Connected: ${cirrusServer.numConnectedClients}`);

	var numConnections = cirrusServer.numConnectedClients;
	var safeBuffer = Math.max(totalInstances - config.instanceCountBuffer, config.instanceCountBuffer); // Get the max of the delta or the desired buffer (i.e., when totalInstances < buffer)

	var timeElapsedSinceScaleup = Date.now() - lastScaleupTime;
	var minutesSinceScaleup = Math.round(((timeElapsedSinceScaleup % 86400000) % 3600000) / 60000);

	var timeElapsedSinceScaledown = Date.now() - lastScaledownTime;
	var minutesSinceScaledown = Math.round(((timeElapsedSinceScaledown % 86400000) % 3600000) / 60000);
	var percentUtilized = 0;

	if (numConnections > 0 && totalInstances > 0)
		percentUtilized = numConnections / totalInstances;

	console.log(`Elapsed minutes since last scaleup: ${minutesSinceScaleup} and scaledown: ${minutesSinceScaledown} and safeBuffer: ${safeBuffer} and % used: ${percentUtilized}`);

	// Adding hysteresis check to make sure we didn't just scale up and should wait until the scaling has enough time to react (TODO: add logic to validate if scaling is still in process)
	if (minutesSinceScaleup < minMinutesBetweenScaleups) {
		console.log(`Waiting to scale since we already recently scaled up or started the service`);
		return;
	}
	// If the current number of user connections is greater than our buffer level that we are trying to stay under
	else if ((config.instanceCountBuffer > 0) && (numConnections >= safeBuffer)) {
		console.log(`Not enough safe buffer--scale up`);
		scaleupInstances(safeBuffer);
		return;
	}
	// Else if the available percent is less than our desired ratio
	else if ((config.percentBuffer > 0) && (numConnections / totalInstances >= config.percentBuffer)) {
		console.log(`Not enough percent ratio buffer--scale up`);
		var newNodeCount = Math.max(totalInstances * Math.ceil(config.percentBuffer * .1), 1);
	    scaleupInstances(newNodeCount);
		return;
	}

	// Adding hysteresis check to make sure we didn't just scale down and should wait until the scaling has enough time to react (TODO: add logic to validate if scaling is still in process)
	if (minutesSinceScaledown < minMinutesBetweenScaledowns) {
		console.log(`Waiting to scale down since we already recently scaled down or started the service`);
		return;
	}
	// Else if we've went long enough without scaling up to consider scaling down when we reach a low enough usage ratio
	else if ((config.connectionIdleRatio > 0) && ((minutesSinceScaleup >= config.idleMinutes) && (percentUtilized <= config.connectionIdleRatio))) {
		console.log(`It's been a while since scaling activity--scale down`);
		var newNodeCount = Math.max(totalInstances * Math.ceil(config.connectionIdleRatio * .1), 1);
		scaledownInstances(newNodeCount);
	}
}

const matchmaker = net.createServer((connection) => {
	connection.on('data', (data) => {
		try {
			message = JSON.parse(data);
		} catch (e) {
			console.log(`ERROR (${e.toString()}): Failed to parse Cirrus information from data: ${data.toString()}`);
			disconnect(connection);
			return;
		}

		if (message.type === 'connect') {
			// A Cirrus server connects to this Matchmaker server.
			cirrusServer = {
				address: message.address,
				port: message.port,
				numConnectedClients: 0
			};
			cirrusServers.set(connection, cirrusServer);
			console.log(`Cirrus server ${cirrusServer.address}:${cirrusServer.port} connected to Matchmaker`);
		} else if (message.type === 'clientConnected') {
			// A client connects to a Cirrus server.
			cirrusServer = cirrusServers.get(connection);
			cirrusServer.numConnectedClients++;
			console.log(`Client connected to Cirrus server ${cirrusServer.address}:${cirrusServer.port}`);

			considerAutoScale();
		} else if (message.type === 'clientDisconnected') {
			// A client disconnects from a Cirrus server.
			cirrusServer = cirrusServers.get(connection);
			cirrusServer.numConnectedClients--;
			console.log(`Client disconnected from Cirrus server ${cirrusServer.address}:${cirrusServer.port}`);

			considerAutoScale();
		} else {
			console.log('ERROR: Unknown data: ' + JSON.stringify(message));
			disconnect(connection);
		}
	});

	// A Cirrus server disconnects from this Matchmaker server.
	connection.on('error', () => {
		cirrusServers.delete(connection);
		console.log(`Cirrus server ${cirrusServer.address}:${cirrusServer.port} disconnected from Matchmaker`);
	});
});

matchmaker.listen(config.matchmakerPort, () => {
	console.log('Matchmaker listening on *:' + config.matchmakerPort);
});
