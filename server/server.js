const express = require('express');
const http = require('http');
const { router, setupWebSocketServer } = require('./routes');

// Initialize Express app
const app = express();
const port = process.env.PORT || 5000;

// Create HTTP server instance
const httpServer = http.createServer(app);

// Setup middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve static files from the public directory
app.use(express.static('public'));

// Basic route for testing
app.get('/', (req, res) => {
  res.send('WebSocket Server is running. Connect to /ws endpoint for WebSocket communication.');
});

// Use API routes from routes.js
app.use(router);

// Setup the WebSocket server
const wss = setupWebSocketServer(httpServer);

// Start the server
httpServer.listen(port, () => {
  console.log(`Server listening on port ${port}`);
  console.log(`WebSocket server available at ws://localhost:${port}/ws`);
});