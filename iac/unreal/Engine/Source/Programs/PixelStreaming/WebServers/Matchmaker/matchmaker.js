// Copyright Epic Games, Inc. All Rights Reserved.
var enableRedirectionLinks = true;
var enableRESTAPI = true;
// A variable to hold the last time we scaled up, used for determining if we are in a determined idle state and might need to scale down (via idleMinutes and connectionIdleRatio)
var lastScaleupTime = Date.now();
// A varible to the last time we scaled down, used for a reference to know how quick we should consider scaling down again (to avoid multiple scale downs too soon)
var lastScaledownTime = Date.now();
// The number of total app instances that are connecting to the matchmaker
var totalInstances = 0;
// The number of total client connections (users) streaming
var totalConnectedClients = 0;
// The min minutes between each scaleup (so we don't scale up every frame while we wait for the scale to complete)
var minMinutesBetweenScaleups = 1;
var minMinutesBetweenScaledowns = 2;
// This stores the current Azure Virtual Machine Scale Set node count (sku.capacity), retried by client.get(rg_name, vmss_name)
var currentVMSSNodeCount = -1;
// The stores the current Azure Virtual Machine Scale Set provisioning (i.e., scale) state (Succeeded, etc..)
var currentVMSSProvisioningState = null;
// The amount of ms for checking the VMSS state (10 seconds * 1000 ms) = 10 second intervals
var vmssUpdateStateInterval = 10 * 1000;
// The amount of percentage we need to scale up when autoscaling with a percentage policy
var scaleUpPercentage = 10;
// The amount of scaling up when we fall below a desired node buffer count policy
var scaleUpNodeCount = 5;

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
	minIdleInstanceCount: 0,
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
var cors = require('cors');
const app = express();
const http = require('http').Server(app);

// Azure SDK Clients
const { ComputeManagementClient, VirtualMachineScaleSets } = require('@azure/arm-compute');
const msRestNodeAuth = require('@azure/ms-rest-nodeauth');
const logger = require('@azure/logger');
logger.setLogLevel('info');
const appInsights = require('applicationinsights');

if (config.appInsightsId) {
	appInsights.setup(config.appInsightsId).setSendLiveMetrics(true).start();
}
if (!appInsights || !appInsights.defaultClient) {
	console.log("No valid appInsights object to use");
}


function appInsightsLogError(err) {

	if (!appInsights || !appInsights.defaultClient) {
		return;
	}

	appInsights.defaultClient.trackMetric({ name: "MatchMakerErrors", value: 1 });
	appInsights.defaultClient.trackException({ exception: err });
}

function appInsightsLogEvent(eventName, eventCustomValue) {

	if (!appInsights || !appInsights.defaultClient) {
		return;
	}

	appInsights.defaultClient.trackEvent({ name: eventName, properties: { customProperty: eventCustomValue } });
}

function appInsightsLogMetric(metricName, metricValue) {

	if (!appInsights || !appInsights.defaultClient) {
		return;
	}

	appInsights.defaultClient.trackMetric({ name: metricName, value: metricValue });
}

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

http.listen(config.httpPort, () => {
    console.log('HTTP listening on *:' + config.httpPort);
});

function validateConfigs() {
	// TODO: Do validations on config params to ensure valid data
}

var lastVMSSCapacity = 0;
var lastVMSSProvisioningState = "";

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
			if (result == null || result.sku == null) {
				console.error(`ERROR getting VMSS sku info`);
				return;
			}

			// Set our global variables so we know the totaly capacity and VMSS status
			currentVMSSNodeCount = result.sku.capacity;
			currentVMSSProvisioningState = result.provisioningState;

			// Only log if it changed
			if (currentVMSSNodeCount != lastVMSSCapacity || currentVMSSProvisioningState != lastVMSSProvisioningState) {
				console.log(`VMSS Capacity: ${currentVMSSNodeCount} and State: ${currentVMSSProvisioningState}`);
			}

			lastVMSSCapacity = currentVMSSNodeCount;
			lastVMSSProvisioningState = currentVMSSProvisioningState;
			appInsightsLogMetric("VMSSGetSuccess", 1);
		}).catch((err) => {
			console.error(`ERROR getting VMSS info: ${err}`);
			appInsightsLogError(err);
			appInsightsLogMetric("VMSSGetError", 1);
		});
	}).catch((err) => {
		console.error(err);
		appInsightsLogError(err);
		appInsightsLogMetric("MSILoginGetError", 1);
	});
}

// Call out to Azure to get the current VMSS initial capacity and status
getVMSSNodeCountAndState(config.subscriptionId, config.resourceGroup, config.virtualMachineScaleSet);

// Set a timed refresh interval for getting the latest update from the state and capacity of the VMSS
setInterval(function () {

	getVMSSNodeCountAndState(config.subscriptionId, config.resourceGroup, config.virtualMachineScaleSet);

}, vmssUpdateStateInterval);

function getConnectedClients() {

	var connectedClients = 0;

	for (cirrusServer of cirrusServers.values()) {
		connectedClients += cirrusServer.numConnectedClients;

		if (cirrusServer.numConnectedClients > 1) {
			console.log(`WARNING: cirrusServer ${cirrusServer.address} has ${cirrusServer.numConnectedClients}`);
        }
	}

	console.log(`Total Connected Clients Found: ${connectedClients}`);
	return connectedClients;
}

// No servers are available so send some simple JavaScript to the client to make
// it retry after a short period of time.
function sendRetryResponse(res) {
	res.send(`
	<html>
<head>
<title>Demo Everywhere</title>
<style>
 body {background-image: url('https://cdn2.unrealengine.com/unreal-iitsec-header-img-1920x1080-554773395.jpg');text-align: center; background-repeat: no-repeat; background-color:black; background-position: center;}
 p {
   font-family: Verdana, Geneva, sans-serif;
   font-size: 15px;
	letter-spacing: 1px;
	word-spacing: 2px;
	color: #FFFFFF;
	font-weight: normal;
	text-decoration: none;
	font-style: normal;
	text-transform: none;}
a {
   font-family: Verdana, Geneva, sans-serif;
   font-size: 15px;
	letter-spacing: 1px;
	word-spacing: 2px;
	color: #0AAFF1;
	font-weight: bold;
	text-decoration: underline;
	font-style: normal;
	text-transform: none;}
</style>
</head>
?
<body>
<p>&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</p>
<p>&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</p><p>Welcome to the Everywhere demo page. </p><p>&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</p><p>Thank you for your patience, a large number of visitors is currently  connected.</p><p>&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</p><p>This page will automatically reload in <span id="countdown">10</span>.</p><p></p><p>&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</p><p>Register for a private demo or attend our livestreamed demos during vIITSEC using the following link </p><p><a href="https://www.unrealengine.com/en-US/industry/training-simulation"target="_blank">"EVERYWHERE Landing page"</a></p>
?
</body>
</html>

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

// Get a Cirrus server if there is one available which has no clients connected.
function getAvailableCirrusServer() {
	for (cirrusServer of cirrusServers.values()) {
		console.log(`getAvailableCirrusServers testing ${cirrusServer.address} numCon: ${cirrusServer.numConnectedClients} ready: ${cirrusServer.ready}`);
		if (cirrusServer.numConnectedClients === 0 && cirrusServer.ready === true) {
			console.log(`FOUND: getAvailableCirrusServers ${cirrusServer.address} numCon: ${cirrusServer.numConnectedClients}`);
			return cirrusServer;
		}
	}
	
	console.log('WARNING: No empty Cirrus servers are available');
	return undefined;
}

if(enableRESTAPI) {
	// Handle REST signalling server only request.
	app.options('/signallingserver', cors())
	app.get('/signallingserver', cors(),  (req, res) => {
		cirrusServer = getAvailableCirrusServer();
		if (cirrusServer != undefined) {
			res.json({ signallingServer: `${cirrusServer.address}:${cirrusServer.port}`});
			console.log(`Returning ${cirrusServer.address}:${cirrusServer.port}`);
		} else {
			res.json({ signallingServer: '', error: 'No signalling servers available'});
		}
	});
}

if(enableRedirectionLinks) {
	// Handle standard URL.
	app.get('/', (req, res) => {
		cirrusServer = getAvailableCirrusServer();
		if (cirrusServer != undefined) {
			res.redirect(`http://${cirrusServer.address}:${cirrusServer.port}/`);
			//console.log(req);
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
}

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
			appInsightsLogMetric("VMSSScaleSuccess", 1);
		}).catch((err) => {
			console.error(`ERROR Scaling VMSS: ${err}`);
			appInsightsLogError(err);
			appInsightsLogMetric("VMSSScaleUpdateError", 1);
		});
	}).catch((err) => {
		console.error(err);
		appInsightsLogError(err);
		appInsightsLogMetric("MSILoginError", 1);
	});
}

function scaleupInstances(newNodeCount) {
	console.log(`Scaling up${newNodeCount}!!!`);

	// Make sure we don't try to scale past our desired max instances
	if (cirrusServers.size >= config.maxInstanceScaleCount) {
		console.log(`Reached max instance count for scale out: ${config.maxInstanceScaleCount}`);
		return;
	}

	appInsightsLogEvent("ScaleUp", newNodeCount);

	lastScaleupTime = Date.now();

	scaleSignalingWebServers(newNodeCount);
}

function scaledownInstances(newNodeCount) {
	console.log(`Scaling down to ${newNodeCount}!!!`);
	lastScaledownTime = Date.now();

	// If set, make sure we don't try to scale below our desired min node count
	if ((config.minIdleInstanceCount > 0) && (newNodeCount < config.minIdleInstanceCount)) {
		console.log(`Using minIdleInstanceCount to scale down: ${config.minIdleInstanceCount}`);
		newNodeCount = config.minIdleInstanceCount;
	}

	// Mode sure we keep at least 1 node
	if (newNodeCount <= 0)
		newNodeCount = 1;

	appInsightsLogEvent("ScaleDown", newNodeCount);

	scaleSignalingWebServers(newNodeCount);
}

// Called when we want to review the autoscale policy to see if there needs to be scaling up or down
function evaluateAutoScalePolicy() {

	console.log(`Evaluating AutoScale Policy....`);

	totalInstances = cirrusServers.size;
	totalConnectedClients = getConnectedClients();

	console.log(`Current Servers Connected: ${totalInstances} Current Clients Connected: ${totalConnectedClients}`);
	appInsightsLogMetric("TotalInstances", totalInstances);
	appInsightsLogMetric("TotalConnectedClients", totalConnectedClients);

	var availableConnections = Math.max(totalInstances - totalConnectedClients, 0);

	var timeElapsedSinceScaleup = Date.now() - lastScaleupTime;
	var minutesSinceScaleup = Math.round(((timeElapsedSinceScaleup % 86400000) % 3600000) / 60000);

	var timeElapsedSinceScaledown = Date.now() - lastScaledownTime;
	var minutesSinceScaledown = Math.round(((timeElapsedSinceScaledown % 86400000) % 3600000) / 60000);
	var percentUtilized = 0;
	var remainingUtilization = 100;

	// Get the percentage of total available signaling servers taken by users
	if (totalConnectedClients > 0 && totalInstances > 0) {
		percentUtilized = (totalConnectedClients / totalInstances) * 100;
		remainingUtilization = 100 - percentUtilized;
	}

	console.log(`Minutes since last scaleup: ${minutesSinceScaleup} and scaledown: ${minutesSinceScaledown} and availConnections: ${availableConnections} and % used: ${percentUtilized}`);
	appInsightsLogMetric("PercentUtilized", percentUtilized);
	appInsightsLogMetric("AvailableConnections", availableConnections);

	// Don't try and scale up/down if there is already a scaling operation in progress
	if (currentVMSSProvisioningState != 'Succeeded') {
		console.log(`Ignoring scale check as VMSS provisioning state isn't in Succeeded state: ${currentVMSSProvisioningState}`);
		appInsightsLogMetric("VMSSProvisioningStateNotReady", 1);
		appInsightsLogEvent("VMSSNotReady", currentVMSSProvisioningState);
		return;
	}

	// Make sure all the cirrus servers on the VMSS have caught up and connected to the MM before considering scaling, or at least 15 minutes since starting up 
	if (totalInstances < currentVMSSNodeCount && minutesSinceScaleup < 15) {
		console.log(`Ignoring scale check as only ${totalInstances} cirrus servers out of ${currentVMSSNodeCount} total VMSS nodes have connected`);
		appInsightsLogMetric("CirrusServersNotAllReady", 1);
		appInsightsLogEvent("CirrusServersNotAllReady", currentVMSSNodeCount - totalInstances);
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
		appInsightsLogMetric("VMSSNodeCountScaleUp", 1);
		appInsightsLogEvent("Scaling up VMSS node count", availableConnections);
		scaleupInstances(currentVMSSNodeCount + config.instanceCountBuffer - availableConnections);
		return;
	}
	// Else if the remaining utilization percent is less than our desired min percentage. scale up 10% of total instances
	else if ((config.percentBuffer > 0) && (remainingUtilization < config.percentBuffer)) {

		// Get a percentage of the total instances that we want to scale up by
		var newNodeCountIncrease = Math.max(totalInstances * (scaleUpPercentage * .01), 1);
		//var percentageBufferNodes = totalInstances * (config.percentBuffer * .01);
		console.log(`We are below the needed percent buffer--scaling up ${scaleUpPercentage}% by ${newNodeCountIncrease}`);
		appInsightsLogMetric("VMSSPercentageScaleUp", 1);
		appInsightsLogEvent("Scaling up VMSS percentage", newNodeCount);
		scaleupInstances(currentVMSSNodeCount + newNodeCountIncrease);
		return;
	}
	// Else if our current VMSS nodes are less than the desired node count buffer (i.e., we started with 2 VMSS but we wanted a buffer of 5)
	else if (currentVMSSNodeCount < config.instanceCountBuffer) {
		var newNodeCount = config.instanceCountBuffer - currentVMSSNodeCount;
		console.log(`Scaling up ${newNodeCount} VMSS nodes since available nodes (${currentVMSSNodeCount}) are less than desired buffer (${config.instanceCountBuffer})`);
		appInsightsLogMetric("VMSSDesiredBufferScaleUp", 1);
		appInsightsLogEvent("Scaling up VMSS to meet initial desired buffer", newNodeCount);
		scaleupInstances(currentVMSSNodeCount + newNodeCount);
		return;
	}

	// Adding hysteresis check to make sure we didn't just scale down and should wait until the scaling has enough time to react
	if (minutesSinceScaledown < minMinutesBetweenScaledowns) {
		console.log(`Waiting to scale down since we already recently scaled down or started the service`);
		appInsightsLogEvent("Waiting to scale down due to recent scale down", minutesSinceScaledown);
		return;
	}
	// Else if we've went long enough without scaling up to consider scaling down when we reach a low enough usage ratio
	else if ((config.connectionIdleRatio > 0) && ((minutesSinceScaledown >= config.idleMinutes) && (percentUtilized <= config.connectionIdleRatio))) {
		console.log(`It's been a while since scaling activity--scale down`);
		var newNodeCount = Math.max(Math.ceil(totalInstances * (config.connectionIdleRatio * .01)), 1);
		appInsightsLogMetric("VMSSScaleDown", 1);
		appInsightsLogEvent("Scaling down VMSS due to idling", percentUtilized + "%, count:" + newNodeCount);
		scaledownInstances(newNodeCount);
	}
}


const matchmaker = net.createServer((connection) => {
	connection.on('data', (data) => {
		try {
			message = JSON.parse(data);
		} catch(e) {
			console.log(`ERROR (${e.toString()}): Failed to parse Cirrus information from data: ${data.toString()}`);
			disconnect(connection);
			appInsightsLogError(e);
			return;
		}
		if (message.type === 'connect') {
			// A Cirrus server connects to this Matchmaker server.
			cirrusServer = {
				address: message.address,
				port: message.port,
				numConnectedClients: 0
			};
			cirrusServer.ready = message.ready === true;

			let server = [...cirrusServers.entries()].find(([key, val]) => val.address === cirrusServer.address);

			// if a duplicate server with the same address isn't found -- add it to the map as an availble server to send users to
			if (!server || server.size <= 0) {
				console.log("Setting cirrus server as none found for this connection.")
				cirrusServers.set(connection, cirrusServer);
            } else {
				console.log("WARNING::::::cirrus server connection already found--not adding to list.")
				var foundServer = cirrusServers.get(server[0]);
				
				// Make sure to retain the numConnectedClients from the last one before the reconnect to MM
				if (foundServer) {
					cirrusServer.numConnectedClients = foundServer.numConnectedClients;
					cirrusServers.set(connection, foundServer);
					console.log(`Replacing server with original with numConn: ${cirrusServer.numConnectedClients}`);
					cirrusServers.delete(server[0]);
					totalInstances = cirrusServers.size;
				}
				else {
					cirrusServers.set(connection, cirrusServer);
					console.log("Connection not found in Map() -- adding a new one");
				}
				
				appInsightsLogMetric("DuplicateCirrusConnection", 1);
				appInsightsLogEvent("DuplicateCirrusConnection", message.address);
			}

			/*
			cirrusServers.set(connection, cirrusServer);
			console.log(`Cirrus server ${cirrusServer.address}:${cirrusServer.port} connected to Matchmaker, ready: ${cirrusServer.ready}`);
			appInsightsLogMetric("CirrusConnection", 1);
			appInsightsLogEvent("CirrusConnection", message.address);
			*/
		} else if (message.type === 'streamerConnected') {
			// The stream connects to a Cirrus server and so is ready to be used
			cirrusServer = cirrusServers.get(connection);
			if(cirrusServer) {
				cirrusServer.ready = true;
				console.log(`Cirrus server ${cirrusServer.address}:${cirrusServer.port} ready for use`);
				appInsightsLogMetric("StreamerConnected", 1);
				appInsightsLogEvent("StreamerConnected", cirrusServer.address);
			} else {
				appInsightsLogMetric("CirrusServerUndefined", 1);
				appInsightsLogEvent("CirrusServerUndefined", `No cirrus server found on streamer connect: ${connection.remoteAddress}`);
				disconnect(connection);
			}
		} else if (message.type === 'streamerDisconnected') {
			// The stream connects to a Cirrus server and so is ready to be used
			cirrusServer = cirrusServers.get(connection);
			if(cirrusServer) {
				cirrusServer.ready = false;
				console.log(`Cirrus server ${cirrusServer.address}:${cirrusServer.port} no longer ready for use`);
				appInsightsLogMetric("StreamerDisconnected", 1);
				appInsightsLogEvent("StreamerDisconnected", cirrusServer.address);
			} else {
				appInsightsLogMetric("CirrusServerUndefined", 1);
				appInsightsLogEvent("CirrusServerUndefined", `No cirrus server found on streamer disconnect: ${connection.remoteAddress}`);
				disconnect(connection);
			}
		} else if (message.type === 'clientConnected') {
			// A client connects to a Cirrus server.
			cirrusServer = cirrusServers.get(connection);
			if(cirrusServer) {
				cirrusServer.numConnectedClients++;
				console.log(`Client connected to Cirrus server ${cirrusServer.address}:${cirrusServer.port}`);
				appInsightsLogMetric("ClientConnection", 1);
				appInsightsLogEvent("ClientConnection", cirrusServer.address);
			} else {
				appInsightsLogMetric("CirrusServerUndefined", 1);
				appInsightsLogEvent("CirrusServerUndefined", `No cirrus server found on client connect: ${connection.remoteAddress}`);
				disconnect(connection);
			}
		} else if (message.type === 'clientDisconnected') {
			// A client disconnects from a Cirrus server.
			cirrusServer = cirrusServers.get(connection);
			if(cirrusServer) {
				cirrusServer.numConnectedClients--;
				console.log(`Client disconnected from Cirrus server ${cirrusServer.address}:${cirrusServer.port}`);
				appInsightsLogMetric("ClientDisconnected", 1);
				appInsightsLogEvent("ClientDisconnected", cirrusServer.address);
			} else {				
				appInsightsLogMetric("CirrusServerUndefined", 1);
				appInsightsLogEvent("CirrusServerUndefined", `No cirrus server found on client disconnect: ${connection.remoteAddress}`);
				disconnect(connection);
			}
		} else {
			console.log('ERROR: Unknown data: ' + JSON.stringify(message));
			disconnect(connection);
			appInsightsLogMetric("MMBadMessageType", 1);
			appInsightsLogEvent("MMBadMessageType", JSON.stringify(message));
		}
		evaluateAutoScalePolicy();
	});

	// A Cirrus server disconnects from this Matchmaker server.
	connection.on('error', () => {
		cirrusServer = cirrusServers.get(connection);
		cirrusServers.delete(connection);
		if(cirrusServer) {
			console.log(`Cirrus server ${cirrusServer.address}:${cirrusServer.port} disconnected from Matchmaker`);
			appInsightsLogEvent("MMCirrusDisconnect", `Cirrus server ${cirrusServer.address}:${cirrusServer.port} disconnected from Matchmaker`);
		} else {
			console.log(`Disconnected machine that wasn't a registered cirrus server, remote address: ${connection.remoteAddress}`);
			appInsightsLogEvent("MMCirrusDisconnect", `Disconnected machine that wasn't a registered cirrus server, remote address: ${connection.remoteAddress}`);
		}
		appInsightsLogMetric("MMCirrusDisconnect", 1);
	});
});

matchmaker.listen(config.matchmakerPort, () => {
	console.log('Matchmaker listening on *:' + config.matchmakerPort);
});