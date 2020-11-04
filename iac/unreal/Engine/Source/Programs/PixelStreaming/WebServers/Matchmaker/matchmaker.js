// Copyright Epic Games, Inc. All Rights Reserved.

// A variable to hold the last time we scaled up, used for determining if we are in a determined idle state and might need to scale down (via idleMinutes and connectionIdleRatio)
var lastScaleupTime = Date.now();
// A varible to the last time we scaled down, used for a reference to know how quick we should consider scaling down again (to avoid multiple scale downs too soon)
var lastScaledownTime = Date.now();
// The number of total app instances that are connecting to the matchmaker
var totalInstances = 0;
// The min minutes between each scaleup (so we don't scale up every frame while we wait for the scale to complete)
var minMinutesBetweenScaleups = 1;
var minMinutesBetweenScaledowns = 2;
// This stores the current Azure Virtual Machine Scale Set node count (sku.capacity), retried by client.get(rg_name, vmss_name)
var currentVMSSNodeCount = -1;
// The stores the current Azure Virtual Machine Scale Set provisioning (i.e., scale) state (Succeeded, etc..)
var currentVMSSProvisioningState = null;
// The amount of ms for checking the VMSS state (30 seconds * 1000 ms) = 30 second intervals
var vmssUpdateStateInterval = 30 * 1000;

const defaultConfig = {
	// The port clients connect to the matchmaking service over HTTP
	httpPort: 90,
	// The matchmaking port the signaling service connects to the matchmaker
	matchmakerPort: 9999,
	// The amount of instances deployed per node, to be used in the autoscale policy (i.e., 1 unreal app running per GPU VM) -- FUTURE
	instancesPerNode: 1,
	// The amount of available signaling service / App instances we want to ensure are available before we have to scale up (0 will ignore)
	instanceCountBuffer: 5,
	// The percentage amount of available signaling service / App instances we want to ensure are available before we have to scale up (0 will ignore)
	percentBuffer: 25,
	//The amount of minutes of no scaling up activity before we decide we might want to see if we should scale down (i.e., after hours--reduce costs)
	idleMinutes: 60,
	// The percentage of active connections to total instances that we want to trigger a scale down once idleMinutes passes with no scaleup
	connectionIdleRatio: 25,
	// The minimum number of available app instances we want to scale down to during an idle period (idleMinutes passed with no scaleup)
	minIdleInstanceCount: 5,
	// The total amount of VMSS nodes that we will approve scaling up to
	maxInstanceScaleCount: 500,
	// The subscription used for autoscaling policy
	subscriptionId: "",
	// The Azure ResourceGroup where the Azure VMSS is located, used for autoscaling
	resourceGroup: "",
	// The Azure VMSS name used for scaling the Signaling Service / Unreal App compute
	virtualMachineScaleSet: "",
	// Azure App Insights ID for logging
	appInsightsId: ""
};

const argv = require('yargs').argv;

var configFile = (typeof argv.configFile != 'undefined') ? argv.configFile.toString() : '.\\config.json';
console.log(`configFile ${configFile}`);
const config = require('./modules/config.js').init(configFile, defaultConfig);
console.log("Config: " + JSON.stringify(config, null, '\t'));

const express = require('express');
const app = express();
const http = require('http').Server(app);

// Azure SDK Clients
const { ComputeManagementClient, VirtualMachineScaleSets } = require('@azure/arm-compute');
const msRestNodeAuth = require('@azure/ms-rest-nodeauth');
const logger = require('@azure/logger');
logger.setLogLevel('info');

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

//
// Connect to browser.
//

http.listen(config.httpPort, () => {
	console.log('HTTP listening on *:' + config.httpPort);
});

// This goes out to Azure and grabs the current VMSS provisioning state and current capacity
function getVMSSNodeCountAndState(subscriptionId, resourceGroup, virtualMachineScaleSet) {

	const options = {
		resource: 'https://management.azure.com'
	}

	// Use an Azure system managed identity to get a token for managing the given resource group
	msRestNodeAuth.loginWithVmMSI(options).then((creds) => {
		const client = new ComputeManagementClient(creds, subscriptionId);
		var vmss = new VirtualMachineScaleSets(client);

		// Get the latest details about the VMSS in Azure
		vmss.get(resourceGroup, virtualMachineScaleSet).then((result) => {
			console.log(`Success getting VMSS info: ${result}`);

			var propValue;
			for (var propName in result) {
				propValue = result[propName]
				console.log(propName, propValue);
			}

			if (result == null || result.sku == null) {
				console.error(`ERROR getting VMSS sku info`);
				return;
			}

			currentVMSSNodeCount = result.sku.capacity;
			currentVMSSProvisioningState = result.provisioningState;

			console.log(`VMSS Capacity: ${currentVMSSNodeCount} and State: ${currentVMSSProvisioningState}`);
		}).catch((err) => {
			console.error(`ERROR getting VMSS info: ${err}`);
		});
	}).catch((err) => {
		console.error(err);
	});
}

// Call out to Azure to get the current VMSS initial capacity and status
getVMSSNodeCountAndState(config.subscriptionId, config.resourceGroup, config.virtualMachineScaleSet);

// Set a timed refresh interval for getting the latest update from the state and capacity of the VMSS
setInterval(function () {

	getVMSSNodeCountAndState(config.subscriptionId, config.resourceGroup, config.virtualMachineScaleSet);

}, vmssUpdateStateInterval);

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

// This scales out the Azure VMSS servers with a new capacity
function scaleSignalingWebServers(newCapacity) {

	const options = {
		resource: 'https://management.azure.com'
	}

	//msRestNodeAuth.interactiveLogin().then((creds) => {  // Used for local testing
	// Use an Azure system managed identity to get a token for managing the given resource group
	msRestNodeAuth.loginWithVmMSI(options).then((creds) => {
		const client = new ComputeManagementClient(creds, config.subscriptionId);
		var vmss = new VirtualMachineScaleSets(client);

		var updateOptions = new Object();
		updateOptions.sku = new Object();
		updateOptions.sku.capacity = newCapacity;

		// Update the VMSS with the new capacity
		vmss.update(config.resourceGroup, config.virtualMachineScaleSet, updateOptions).then((result) => {
			console.log(`Success Scaling VMSS: ${result}`);
		}).catch((err) => {
			console.error(`ERROR Scaling VMSS: ${err}`);
		});
	}).catch((err) => {
		console.error(err);
	});
}

function scaleupInstances(newNodeCount) {
	console.log(`Scaling up${newNodeCount}!!!`);

	lastScaleupTime = Date.now();

	// TODO: Make sure we've added the current plus new node count
	scaleSignalingWebServers(newNodeCount);
}

function scaledownInstances(newNodeCount) {
	console.log(`Scaling down to ${newNodeCount}!!!`);
	lastScaledownTime = Date.now();

	// TODO: Make sure we've added the current plus new node count
	scaleSignalingWebServers(newNodeCount);
}

function considerAutoScale() {
	console.log(`Considering AutoScale....`);

	totalInstances = cirrusServers.size;

	console.log(`Current Servers Connected: ${totalInstances} Current Clients Connected: ${cirrusServer.numConnectedClients}`);

	var numConnections = cirrusServer.numConnectedClients;
	var availableConnections = Math.max(totalInstances - numConnections, 0);

	var timeElapsedSinceScaleup = Date.now() - lastScaleupTime;
	var minutesSinceScaleup = Math.round(((timeElapsedSinceScaleup % 86400000) % 3600000) / 60000);

	var timeElapsedSinceScaledown = Date.now() - lastScaledownTime;
	var minutesSinceScaledown = Math.round(((timeElapsedSinceScaledown % 86400000) % 3600000) / 60000);
	var percentUtilized = 0;

	if (numConnections > 0 && totalInstances > 0)
		percentUtilized = numConnections / totalInstances;

	console.log(`Elapsed minutes since last scaleup: ${minutesSinceScaleup} and scaledown: ${minutesSinceScaledown} and availableConnections: ${availableConnections} and % used: ${percentUtilized}`);

	if (currentVMSSProvisioningState != 'Succeeded') {
		console.log(`Ignoring scale check as VMSS provisioning state isn't in Succeeded state: ${currentVMSSProvisioningState}`);
		return;
	}

	// Adding hysteresis check to make sure we didn't just scale up and should wait until the scaling has enough time to react
	//if (minutessincescaleup < minminutesbetweenscaleups) {
	//	console.log(`waiting to scale since we already recently scaled up or started the service`);
	//	return;
	//}

	// If available user connections is less than our desired buffer level scale up
	if ((config.instanceCountBuffer > 0) && (availableConnections < config.instanceCountBuffer)) {
		console.log(`Not enough of a buffer--scale up`);
		scaleupInstances(currentVMSSNodeCount + config.instanceCountBuffer - availableConnections);
		return;
	}
	// Else if the available percent is less than our desired ratio
	else if ((config.percentBuffer > 0) && (1 - ((numConnections / totalInstances) * 100) <= config.percentBuffer)) {
		console.log(`Not enough percent ratio buffer--scale up`);
		var newNodeCount = Math.max(totalInstances * Math.ceil(config.percentBuffer * .1), 1);
		scaleupInstances(currentVMSSNodeCount + newNodeCount);
		return;
	}
	// Else if our current VMSS nodes are less than the desired node count buffer
	else if (currentVMSSNodeCount < config.instanceCountBuffer) {
		var newNodeCount = config.instanceCountBuffer - currentVMSSNodeCount;
		console.log(`Scaling up ${newNodeCount} VMSS nodes since available nodes (${currentVMSSNodeCount}) are less than desired buffer (${config.instanceCountBuffer})`);
		scaleupInstances(currentVMSSNodeCount + newNodeCount);
		return;
	}

	// Adding hysteresis check to make sure we didn't just scale down and should wait until the scaling has enough time to react
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
			considerAutoScale();
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