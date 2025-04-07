const express = require('express');
const router = express.Router();
const WebSocket = require('ws');

// Sample data for testing
const devices = [
  { id: 1, name: 'Camera 1', status: 'online', ip: '192.168.1.101' },
  { id: 2, name: 'Camera 2', status: 'offline', ip: '192.168.1.102' },
  { id: 3, name: 'Camera 3', status: 'online', ip: '192.168.1.103' },
];

// GET endpoint to list all devices
router.get('/api/devices', (req, res) => {
  res.json({
    success: true,
    data: devices
  });
});

// GET endpoint to get a specific device
router.get('/api/devices/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const device = devices.find(d => d.id === id);
  
  if (device) {
    res.json({
      success: true,
      data: device
    });
  } else {
    res.status(404).json({
      success: false,
      message: `Device with id ${id} not found`
    });
  }
});

// Setup WebSocket routes
const setupWebSocketServer = (httpServer) => {
  // Create WebSocket server instance on a specific path
  const wss = new WebSocket.Server({ server: httpServer, path: '/ws' });
  
  // Track connected clients
  const clients = new Set();
  
  // WebSocket connection handler
  wss.on('connection', (ws) => {
    console.log('New client connected');
    clients.add(ws);
    
    // Send welcome message
    ws.send(JSON.stringify({
      type: 'info',
      message: 'Connected to server',
      timestamp: new Date().toISOString()
    }));
    
    // Message handler
    ws.on('message', (message) => {
      try {
        // Try to parse as JSON
        const parsedMessage = JSON.parse(message);
        console.log('Received message:', parsedMessage);
        
        // Echo the message back to the client
        ws.send(JSON.stringify({
          type: 'echo',
          data: parsedMessage,
          timestamp: new Date().toISOString()
        }));
        
        // Handle different message types
        if (parsedMessage.type === 'broadcast') {
          // Broadcast message to all clients except sender
          clients.forEach((client) => {
            if (client !== ws && client.readyState === WebSocket.OPEN) {
              client.send(JSON.stringify({
                type: 'broadcast',
                from: parsedMessage.from || 'Anonymous',
                message: parsedMessage.message,
                timestamp: new Date().toISOString()
              }));
            }
          });
        } else if (parsedMessage.type === 'device_status') {
          // Simulate device status change and broadcast to all clients
          const deviceId = parsedMessage.deviceId;
          const device = devices.find(d => d.id === deviceId);
          
          if (device) {
            device.status = parsedMessage.status || (device.status === 'online' ? 'offline' : 'online');
            
            // Broadcast device update to all connected clients
            clients.forEach((client) => {
              if (client.readyState === WebSocket.OPEN) {
                client.send(JSON.stringify({
                  type: 'device_update',
                  device: device,
                  timestamp: new Date().toISOString()
                }));
              }
            });
          }
        }
      } catch (error) {
        // If not JSON, handle as plain text
        console.log('Received text message:', message.toString());
        
        // Echo back as text
        ws.send(JSON.stringify({
          type: 'echo',
          data: message.toString(),
          timestamp: new Date().toISOString()
        }));
      }
    });
    
    // Connection close handler
    ws.on('close', () => {
      console.log('Client disconnected');
      clients.delete(ws);
    });
    
    // Error handler
    ws.on('error', (error) => {
      console.error('WebSocket error:', error);
      clients.delete(ws);
    });
  });
  
  // Start a periodic broadcast to all clients (simulating real-time updates)
  setInterval(() => {
    const now = new Date();
    
    // Only send if there are connected clients
    if (clients.size > 0) {
      // Prepare server status update
      const statusUpdate = {
        type: 'server_status',
        timestamp: now.toISOString(),
        uptime: process.uptime(),
        clientCount: clients.size,
        memory: process.memoryUsage(),
      };
      
      // Send to all connected clients
      clients.forEach((client) => {
        if (client.readyState === WebSocket.OPEN) {
          client.send(JSON.stringify(statusUpdate));
        }
      });
    }
  }, 10000); // Every 10 seconds
  
  return wss;
};

module.exports = { router, setupWebSocketServer };