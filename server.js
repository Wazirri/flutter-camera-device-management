const express = require('express');
const http = require('http');
const { WebSocketServer } = require('ws');
const app = express();
const port = 5000;

// Serve static files from the 'public' directory
app.use(express.static('public'));

// Create HTTP server
const server = http.createServer(app);

// Create WebSocket server
const wss = new WebSocketServer({ server, path: '/ws' });

// Track connected clients
const clients = new Set();

// Handle WebSocket connections
wss.on('connection', (ws) => {
  console.log('Client connected to WebSocket');
  clients.add(ws);
  
  // Set up ping-pong for connection heartbeat
  ws.isAlive = true;
  ws.on('pong', () => {
    ws.isAlive = true;
  });
  
  // Initial system info message
  const systemInfo = {
    c: "sysinfo",
    cpuTemp: "45.32",
    upTime: "3600",
    date: new Date().toISOString(),
    diskSize: "512GB",
    diskFree: "256GB",
    memTotal: "8192MB",
    memFree: "4096MB"
  };
  
  // Send initial system info
  ws.send(JSON.stringify(systemInfo));
  
  // Handle login
  ws.on('message', (message) => {
    const messageStr = message.toString();
    console.log(`Received message: ${messageStr}`);
    
    // Check for login message
    if (messageStr.startsWith('LOGIN')) {
      console.log('Processing login request');
      // Send login success
      ws.send(JSON.stringify({ c: "login", msg: "Login successful" }));
    }
    
    // Check for monitor request
    if (messageStr === 'DO MONITORECS') {
      console.log('Processing monitor request');
      
      // Send multiple camera device data for different MAC addresses
      setTimeout(() => {
        // First device with 2 cameras
        const device1Mac = "m_26_C1_7A_0B_1F_19";
        
        // Device information
        ws.send(JSON.stringify({
          c: "changed",
          data: `ecs.slaves.${device1Mac}.connected`,
          val: 1
        }));
        
        ws.send(JSON.stringify({
          c: "changed",
          data: `ecs.slaves.${device1Mac}.ipv4`,
          val: "192.168.1.211"
        }));
        
        // First camera
        ws.send(JSON.stringify({
          c: "changed",
          data: `ecs.slaves.${device1Mac}.cam[0].xAddrs`,
          val: "http://192.168.1.20:80/onvif/device_service"
        }));
        
        ws.send(JSON.stringify({
          c: "changed",
          data: `ecs.slaves.${device1Mac}.cam[0].name`,
          val: "KAMERA1"
        }));
        
        ws.send(JSON.stringify({
          c: "changed",
          data: `ecs.slaves.${device1Mac}.cam[0].username`,
          val: "admin"
        }));
        
        ws.send(JSON.stringify({
          c: "changed",
          data: `ecs.slaves.${device1Mac}.cam[0].password`,
          val: "admin123"
        }));
        
        ws.send(JSON.stringify({
          c: "changed",
          data: `ecs.slaves.${device1Mac}.cam[0].manufacturer`,
          val: "Vatilon"
        }));
        
        ws.send(JSON.stringify({
          c: "changed",
          data: `ecs.slaves.${device1Mac}.cam[0].mediaUri`,
          val: "rtsp://192.168.1.20:554/stream1"
        }));
        
        ws.send(JSON.stringify({
          c: "changed",
          data: `ecs.slaves.${device1Mac}.cam[0].recordUri`,
          val: "rtsp://192.168.1.20:554/stream1"
        }));
        
        ws.send(JSON.stringify({
          c: "changed",
          data: `ecs.slaves.${device1Mac}.camreports.KAMERA1.recording`,
          val: true
        }));
        
        // Second camera
        ws.send(JSON.stringify({
          c: "changed",
          data: `ecs.slaves.${device1Mac}.cam[1].xAddrs`,
          val: "http://192.168.1.21:80/onvif/device_service"
        }));
        
        ws.send(JSON.stringify({
          c: "changed",
          data: `ecs.slaves.${device1Mac}.cam[1].name`,
          val: "KAMERA2"
        }));
        
        ws.send(JSON.stringify({
          c: "changed",
          data: `ecs.slaves.${device1Mac}.cam[1].username`,
          val: "admin"
        }));
        
        ws.send(JSON.stringify({
          c: "changed",
          data: `ecs.slaves.${device1Mac}.cam[1].password`,
          val: "admin123"
        }));
        
        ws.send(JSON.stringify({
          c: "changed",
          data: `ecs.slaves.${device1Mac}.cam[1].manufacturer`,
          val: "Vatilon"
        }));
        
        ws.send(JSON.stringify({
          c: "changed",
          data: `ecs.slaves.${device1Mac}.cam[1].mediaUri`,
          val: "rtsp://192.168.1.21:554/stream1"
        }));
        
        ws.send(JSON.stringify({
          c: "changed",
          data: `ecs.slaves.${device1Mac}.cam[1].recordUri`,
          val: "rtsp://192.168.1.21:554/stream1"
        }));
        
        ws.send(JSON.stringify({
          c: "changed",
          data: `ecs.slaves.${device1Mac}.camreports.KAMERA2.recording`,
          val: true
        }));
        
        // Second device with 1 camera
        const device2Mac = "m_96_A6_0B_19_63_XX";
        
        // Device information
        ws.send(JSON.stringify({
          c: "changed",
          data: `ecs.slaves.${device2Mac}.connected`,
          val: 1
        }));
        
        ws.send(JSON.stringify({
          c: "changed",
          data: `ecs.slaves.${device2Mac}.ipv4`,
          val: "192.168.1.222"
        }));
        
        // Camera
        ws.send(JSON.stringify({
          c: "changed",
          data: `ecs.slaves.${device2Mac}.cam[0].xAddrs`,
          val: "http://192.168.1.30:80/onvif/device_service"
        }));
        
        ws.send(JSON.stringify({
          c: "changed",
          data: `ecs.slaves.${device2Mac}.cam[0].name`,
          val: "KAMERA1"
        }));
        
        ws.send(JSON.stringify({
          c: "changed",
          data: `ecs.slaves.${device2Mac}.cam[0].username`,
          val: "admin"
        }));
        
        ws.send(JSON.stringify({
          c: "changed",
          data: `ecs.slaves.${device2Mac}.cam[0].password`,
          val: "admin123"
        }));
        
        ws.send(JSON.stringify({
          c: "changed",
          data: `ecs.slaves.${device2Mac}.cam[0].manufacturer`,
          val: "Vatilon"
        }));
        
        ws.send(JSON.stringify({
          c: "changed",
          data: `ecs.slaves.${device2Mac}.cam[0].mediaUri`,
          val: "rtsp://192.168.1.30:554/stream1"
        }));
        
        ws.send(JSON.stringify({
          c: "changed",
          data: `ecs.slaves.${device2Mac}.cam[0].recordUri`,
          val: "rtsp://192.168.1.30:554/stream1"
        }));
        
        ws.send(JSON.stringify({
          c: "changed",
          data: `ecs.slaves.${device2Mac}.camreports.KAMERA1.recording`,
          val: true
        }));
      }, 1000);
      
      // Update system info periodically
      setInterval(() => {
        systemInfo.cpuTemp = (40 + Math.random() * 20).toFixed(2);
        systemInfo.date = new Date().toISOString();
        ws.send(JSON.stringify(systemInfo));
      }, 5000);
    }
  });
  
  // Handle client disconnect
  ws.on('close', () => {
    console.log('Client disconnected from WebSocket');
    clients.delete(ws);
  });
  
  // Handle errors
  ws.on('error', (error) => {
    console.error('WebSocket error:', error);
    clients.delete(ws);
  });
});

// Simple status route to check if server is running
app.get('/status', (req, res) => {
  res.json({ status: 'ok', message: 'Server is running properly' });
});

// Route to show information to user with WebSocket details
app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>Flutter Camera Device Management</title>
      <style>
        body {
          font-family: Arial, sans-serif;
          background-color: #282c34;
          color: white;
          margin: 0;
          padding: 20px;
          text-align: center;
        }
        .container {
          max-width: 800px;
          margin: 0 auto;
        }
        h1 {
          color: #F7941E;
        }
        .status {
          background-color: #00ADEE;
          padding: 15px;
          border-radius: 5px;
          margin: 20px 0;
        }
        .info {
          text-align: left;
          background-color: #333;
          padding: 15px;
          border-radius: 5px;
        }
        code {
          background-color: #444;
          padding: 2px 4px;
          border-radius: 3px;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>Camera Device Management App</h1>
        <div class="status">
          Server is running properly on port ${port}
        </div>
        <div class="info">
          <p>Flutter web app is currently in development and may need additional configuration to run properly in the Replit environment.</p>
          <p>For development and testing, consider:</p>
          <ul>
            <li>Running the Flutter web app locally</li>
            <li>Using the Flutter extension in VS Code</li>
            <li>Testing on physical devices</li>
          </ul>
          <p>Current WebSocket configuration: <code>85.104.114.145:1200</code> (original server)</p>
          <p>Local WebSocket test server: <code>ws://${req.headers.host}/ws</code></p>
          <p><a href="/websocket-test.html" style="color: #F7941E; text-decoration: none; padding: 5px 10px; background-color: #444; border-radius: 5px;">Open WebSocket Test Page</a></p>
          <p>For more information, check the GitHub repository.</p>
        </div>
      </div>
    </body>
    </html>
  `);
});

// Heartbeat interval to check for dead connections
const heartbeatInterval = setInterval(() => {
  wss.clients.forEach((ws) => {
    if (ws.isAlive === false) {
      console.log('Terminating inactive client connection');
      return ws.terminate();
    }
    
    ws.isAlive = false;
    ws.ping();
  });
}, 30000); // Check every 30 seconds

// Clean up the interval when the server closes
wss.on('close', () => {
  clearInterval(heartbeatInterval);
});

// Start the server
server.listen(port, '0.0.0.0', () => {
  console.log(`HTTP Server running at http://0.0.0.0:${port}`);
  console.log(`WebSocket Server running at ws://0.0.0.0:${port}/ws`);
});