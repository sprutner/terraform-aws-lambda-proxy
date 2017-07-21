var http = require('http');
var util = require('util');

const PROXY_PORT = process.env.PROXY_PORT
const PROXY_HOST = process.env.PROXY_HOST

exports.myHandler = function(event, context, callback) {
    // setup request options and parameters

    console.log("request: " + JSON.stringify(event));
    console.log("path " + JSON.stringify(event.pathParameters.proxy));

    var options = {
      host: PROXY_HOST,
      port: PROXY_PORT,
      path: "/" + event.pathParameters.proxy,
      method: event.httpMethod
    };

    // if you have headers set them otherwise set the property to an empty map
    if (event.headers && Object.keys(event.headers).length > 0) {
        options.headers = event.headers
    } else {
        options.headers = {};
    }

    // Force the user agent and the "forwarded for" headers because we want to
    // take them from the API Gateway context rather than letting Node.js set the Lambda ones
    options.headers["User-Agent"] = event.requestContext.identity.userAgent;
    options.headers["X-Forwarded-For"] = event.requestContext.identity.sourceIp;
    // Replace Node setting Host header to it's lambda host, change to our real host
    options.headers["Host"] = PROXY_HOST;
    // if I don't have a content type I force it application/json
    // Test invoke in the API Gateway console does not pass a value
    if (!options.headers["Content-Type"]) {
        options.headers["Content-Type"] = "application/json";
    }
    // Define my callback to read the response and generate a JSON output for API Gateway.
    // The JSON output is parsed by the mapping templates
    callback = function(response) {
        console.log(JSON.stringify(util.inspect(response)));

        var responseString = '';
        // Another chunk of data has been recieved, so append it to `str`
        response.on('data', function (chunk) {
            responseString += chunk;
            console.log("chunk: " + chunk);
        });

        // The whole response has been received
        response.on('end', function (x) {
            console.log ("x: " + x);
            // Parse response to json
           console.log("String: " + responseString);

            var output = {
                statusCode: response.statusCode,
                body: responseString,
                headers: response.headers,
                isBase64Encoded: response.isBase64Encoded
            };

           console.log("Output: " + JSON.stringify(output));

            // if the response was a 200 we can just pass the entire JSON back to
            // API Gateway for parsing. If the backend return a non 200 status
            // then we return it as an error
            context.succeed(output);
        });
    }
    console.log("Options: " + JSON.stringify(options));
    var req = http.request(options, callback);

    console.log("BODY: " + JSON.stringify(event.body));

    if (event.body && event.body !== "") {
        req.write(event.body);
    }

    req.on('error', function(e) {
        console.log('problem with request: ' + e.message);
        context.fail(JSON.stringify({
            statusCode: 500,
            body: JSON.stringify({ message: "Internal server error??" }),
            headers: event.headers,
            isBase64Encoded: event.isBase64Encoded
        }));
    });

    req.end();
}
