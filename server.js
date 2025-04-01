const express = require('express');
const path = require('path');
const http = require('http');
const { WebSocketServer } = require('ws');
const app = express();
const PORT = 5000;
const WS_PORT = 5001;

// Serve static files from the 'build/web' directory
app.use(express.static(path.join(__dirname, 'build/web')));

// For any other request, send the index.html file
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'build/web/index.html'));
});

// Create HTTP server
const server = http.createServer(app);

// Create WebSocket server
const wss = new WebSocketServer({ port: WS_PORT });

// Connected clients
const clients = new Set();

// WebSocket connection handler
wss.on('connection', (ws) => {
  console.log('New WebSocket client connected');
  clients.add(ws);
  
  // Send welcome message
  ws.send(JSON.stringify({
    type: 'system',
    message: 'Connected to WebSocket server',
    timestamp: new Date().toISOString()
  }));
  
  // Message handler
  ws.on('message', (message) => {
    try {
      console.log(`Received message: ${message}`);
      const messageStr = message.toString();
      
      // Handle LOGIN command
      if (messageStr.startsWith('LOGIN')) {
        const parts = messageStr.split(' ');
        if (parts.length >= 3) {
          const username = parts[1];
          const password = parts[2];
          console.log(`Login attempt: username=${username}, password=${password}`);
          
          // Send login response
          ws.send(JSON.stringify({
            type: 'auth',
            success: true,
            message: 'Login successful',
            timestamp: new Date().toISOString()
          }));
          
          // Send simulated camera data
          setTimeout(() => {
            ws.send(JSON.stringify({
              type: 'camera_update',
              data: [
                { id: 'cam1', name: 'Front Door', status: 'online', recording: true },
                { id: 'cam2', name: 'Back Yard', status: 'online', recording: false },
                { id: 'cam3', name: 'Garage', status: 'offline', recording: false },
                { id: 'cam4', name: 'Living Room', status: 'online', recording: true }
              ],
              timestamp: new Date().toISOString()
            }));
          }, 1000);
          
          // Send simulated device data
          setTimeout(() => {
            ws.send(JSON.stringify({
              type: 'device_update',
              data: [
                { id: 'dev1', name: 'NVR System', status: 'online', type: 'recorder' },
                { id: 'dev2', name: 'Door Sensor', status: 'online', type: 'sensor' },
                { id: 'dev3', name: 'Motion Detector', status: 'offline', type: 'sensor' }
              ],
              timestamp: new Date().toISOString()
            }));
          }, 2000);
        }
      } else {
        // Echo the message back
        ws.send(JSON.stringify({
          type: 'response',
          message: `Echo: ${messageStr}`,
          timestamp: new Date().toISOString()
        }));
      }
    } catch (error) {
      console.error('Error processing message:', error);
      ws.send(JSON.stringify({
        type: 'error',
        message: 'Error processing your request',
        timestamp: new Date().toISOString()
      }));
    }
  });
  
  // Connection closed handler
  ws.on('close', () => {
    console.log('WebSocket client disconnected');
    clients.delete(ws);
  });
  
  // Error handler
  ws.on('error', (error) => {
    console.error('WebSocket error:', error);
    clients.delete(ws);
  });
});

// Send periodic updates to all connected clients
setInterval(() => {
  if (clients.size > 0) {
    const statusUpdate = JSON.stringify({
      type: 'status_update',
      status: 'ok',
      timestamp: new Date().toISOString()
    });
    
    for (const client of clients) {
      if (client.readyState === 1) { // OPEN
        client.send(statusUpdate);
      }
    }
  }
}, 60000); // Every minute

// Start HTTP server
server.listen(PORT, '0.0.0.0', () => {
  console.log(`HTTP Server is running on http://0.0.0.0:${PORT}`);
  console.log(`WebSocket Server is running on ws://0.0.0.0:${WS_PORT}`);
});