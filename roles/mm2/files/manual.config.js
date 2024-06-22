/* Config Sample
 *
 * For more information on how you can configure this file
 * see https://docs.magicmirror.builders/configuration/introduction.html
 * and https://docs.magicmirror.builders/modules/configuration.html
 *
 * You can use environment variables using a `config.js.template` file instead of `config.js`
 * which will be converted to `config.js` while starting. For more information
 * see https://docs.magicmirror.builders/configuration/introduction.html#enviromnent-variables
 */
let config = {
	address: "0.0.0.0",	// Address to listen on, can be:
							// - "localhost", "127.0.0.1", "::1" to listen on loopback interface
							// - another specific IPv4/6 to listen on a specific interface
							// - "0.0.0.0", "::" to listen on any interface
							// Default, when address config is left out or empty, is "localhost"
	port: 8080,
	basePath: "/",	// The URL path where MagicMirror² is hosted. If you are using a Reverse proxy
									// you must set the sub path here. basePath must end with a /
	ipWhitelist: [],	// Set [] to allow all IP addresses
									// or add a specific IPv4 of 192.168.1.5 :
									// ["127.0.0.1", "::ffff:127.0.0.1", "::1", "::ffff:192.168.1.5"],
									// or IPv4 range of 192.168.3.0 --> 192.168.3.15 use CIDR format :
									// ["127.0.0.1", "::ffff:127.0.0.1", "::1", "::ffff:192.168.3.0/28"],

	useHttps: false,			// Support HTTPS or not, default "false" will use HTTP
	httpsPrivateKey: "",	// HTTPS private key path, only require when useHttps is true
	httpsCertificate: "",	// HTTPS Certificate path, only require when useHttps is true

	language: "en",
	locale: "en-US",
	logLevel: ["INFO", "LOG", "WARN", "ERROR"], // Add "DEBUG" for even more logging
	timeFormat: 24,
	units: "imperial",

	modules: [
		{
			module: "alert",
		},
		{
			module: "updatenotification",
			position: "top_bar"
		},
		{
			module: "clock",
			position: "top_left"
		},
		{
			module: "weather",
			position: "top_left",
			config: {
				weatherProvider: "openweathermap",
				weatherEndpoint: "",
				type: "current",
				locationID: "5005703",
				apiKey: "APIKEY"
			}
		},
		{
			module: 'MMM-iFrame',
			position: 'bottom_right',
			config: {
					url: ["https://www.youtube.com/embed/Nq4Ge6foW4Y?autoplay=1"],
					updateInterval: 86400000,
					width: "1920",
					height: "1275",
					frameWidth: "510"
				}
		},
		{
			module: 'MMM-iFrame',
			position: 'bottom_left',
			config: {
					url: ["https://api.wetmet.net/client-content/PlayerFrame.php?CAMERA=210-02-01&amp;CFVER=WM&amp;WIDTH=640&amp;HEIGHT=360"],
					updateInterval: 86400000,
					width: "1920",
					height: "1275",
					frameWidth: "510"
				}
		},
		{
			module: "MMM-RAIN-MAP",
			position: "top_right",
			config: {
			 animationSpeedMs: 1000,
			 colorScheme: 8,
			 colorizeTime: true,
			 defaultZoomLevel: 8,
			 displayTime: true,
			 displayTimeline: true,
			 displayClockSymbol: true,
			 displayHoursBeforeRain: -1,
			 extraDelayLastFrameMs: 1000,
			 extraDelayCurrentFrameMs: 10000,
			 invertColors: false,
			 markers: [{ lat: 42.479840, lng: -83.893636, color: "red" },],
			 mapPositions: [{ lat: 42.479840, lng: -83.893636, zoom: 6, loops: 5 },],
			 mapUrl: "https://a.tile.openstreetmap.de/{z}/{x}/{y}.png",
			 mapHeight: "250px",
			 mapWidth: "350px",
			 maxHistoryFrames: 7,
			 maxForecastFrames: 0,
			 substitudeModules: [],
			 timeFormat: 24,
			 updateIntervalInSeconds: 300,
			}
		},
	]
};

/*************** DO NOT EDIT THE LINE BELOW ***************/
if (typeof module !== "undefined") { module.exports = config; }
