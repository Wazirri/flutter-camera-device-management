const express = require('express');
const http = require('http');
const { WebSocketServer } = require('ws');
const app = express();
const port = 5000;

// Create HTTP server
const server = http.createServer(app);

// Create WebSocket server
const wss = new WebSocketServer({ server, path: '/ws' });

// Handle WebSocket connections
wss.on('connection', (ws) => {
  console.log('Client connected to WebSocket');
  
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
      
      // Example camera device data
      const cameraData = {
        c: "changed",
        data: "ecs.slaves.m_96_A6_0B_19_63_XX.cam.0.xAddrs",
        value: "http://192.168.1.30/onvif/device_service"
      };
      
      // Send example camera data
      setTimeout(() => {
        ws.send(JSON.stringify(cameraData));
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
  });
  
  // Handle errors
  ws.on('error', (error) => {
    console.error('WebSocket error:', error);
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
          <p>For more information, check the GitHub repository.</p>
        </div>
      </div>
    </body>
    </html>
  `);
});

// Start the server
server.listen(port, '0.0.0.0', () => {
  console.log(`HTTP Server running at http://0.0.0.0:${port}`);
  console.log(`WebSocket Server running at ws://0.0.0.0:${port}/ws`);
});