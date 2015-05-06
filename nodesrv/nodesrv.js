(function() {
    "use strict";

    var net   = require('net');
    var mysql = require('mysql');

    var nodePort = 33120;
    var sphinxHost = 'sphinx.ut.int.vb.lt';
    var sphinxPort = 9306;

    var sqlPool   = null;
    var tcpServer = null;

    // Main received data processing
    function processRequest(dataString, c) {
      var q;
      var callback = function(result) {
          c.end(JSON.stringify(result) + "{{E}}");
          callback = null;
      };

      try {
        sqlPool.getConnection(function(err, connection){
          if (err) {
            callback({error: 'getConnection fail: ' + err});
            return;
          }
          q = dataString.replace(/[a-z0-9]/gi, ' ');
          connection.query(
            { 
              sql: 'SELECT * FROM article WHERE MATCH(' + q + ');',
              timeout: 5000
            },
            function (err, rows, fields) {
              if (err) {
                console.error('sql: ' + err.message.replace("\u0000", ""));
                callback({error: 'sql: ' + err.message.replace("\u0000", "")});
                connection.release();
                return;
              }
              callback({error: '', rows: rows});
            }
          );
        });
      } catch (e) {
        // fallback to json input
        console.error("Failed while parsing input data");
        console.error(e);
        callback({error: e.message});
        return;
      }
    }

    sqlPool = mysql.createPool({
        host: sphinxHost,
        port: sphinxPort,
        acquireTimeout: 10000,
        waitForConnections: true, // queue connections
        connectionLimit: 3,
        queueLimit: 0
    });

    // make TCP-IP server for sending information to client
    tcpServer = net.createServer(function(c) {

      var wholeData = '';
      c.on('end', function() {
        console.log('end connection');
        wholeData = null;
      });

      c.on('data', function(data) {
        console.log('data received', data);
        wholeData += data;
        var len = wholeData.length;
        var endpart = wholeData.substr(len - 5);
        if (endpart === '{{E}}') {
          wholeData = wholeData.substr(0, wholeData.length - 5);
          processRequest(wholeData, c);
        }
      });
    });

    tcpServer.listen(nodePort, function() {
      console.log('nodesrv listens port ' + nodePort);
    });

    tcpServer.on('connection', function(c) {
      c.setEncoding('utf8');
      console.log('start connection');
    });

}).call();
