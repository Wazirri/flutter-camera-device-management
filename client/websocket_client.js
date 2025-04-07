// Basic WebSocket client for testing Flutter WebSocket connection

function createWebSocketClient() {
  // Determine the protocol based on whether we're using HTTPS
  const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
  const wsUrl = `${protocol}//${window.location.host}/ws`;
  
  console.log(`Attempting to connect to WebSocket at: ${wsUrl}`);
  
  // Create WebSocket instance
  const socket = new WebSocket(wsUrl);
  
  // Connection opened
  socket.addEventListener('open', (event) => {
    console.log('Connected to WebSocket server');
    
    // Send a test message
    socket.send(JSON.stringify({
      type: 'hello',
      message: 'Hello from JavaScript client',
      timestamp: new Date().toISOString()
    }));
  });
  
  // Listen for messages
  socket.addEventListener('message', (event) => {
    try {
      const data = JSON.parse(event.data);
      console.log('Message from server:', data);
      
      // Process different message types
      switch (data.type) {
        case 'echo':
          console.log('Server echoed:', data.data);
          break;
        case 'broadcast':
          console.log(`Broadcast from ${data.from}: ${data.message}`);
          break;
        case 'server_status':
          console.log(`Server status: Uptime ${Math.round(data.uptime)}s, Clients: ${data.clientCount}`);
          break;
        default:
          console.log('Unknown message type:', data.type);
      }
    } catch (error) {
      console.log('Received non-JSON message:', event.data);
    }
  });
  
  // Connection closed
  socket.addEventListener('close', (event) => {
    console.log(`WebSocket connection closed. Code: ${event.code}, Reason: ${event.reason || 'No reason provided'}`);
  });
  
  // Connection error
  socket.addEventListener('error', (error) => {
    console.error('WebSocket error:', error);
  });
  
  // Expose methods for external use
  return {
    sendMessage: (message) => {
      if (socket.readyState === WebSocket.OPEN) {
        const messageData = typeof message === 'string' 
          ? message 
          : JSON.stringify(message);
        
        socket.send(messageData);
        return true;
      } else {
        console.error('WebSocket is not connected. Current state:', socket.readyState);
        return false;
      }
    },
    
    disconnect: () => {
      if (socket.readyState === WebSocket.OPEN) {
        socket.close();
        return true;
      }
      return false;
    },
    
    getStatus: () => {
      switch (socket.readyState) {
        case WebSocket.CONNECTING:
          return 'connecting';
        case WebSocket.OPEN:
          return 'connected';
        case WebSocket.CLOSING:
          return 'closing';
        case WebSocket.CLOSED:
          return 'disconnected';
        default:
          return 'unknown';
      }
    }
  };
}

// Example usage:
// const wsClient = createWebSocketClient();
// wsClient.sendMessage({ type: 'broadcast', from: 'Web Client', message: 'Hello everyone!' });
// console.log('Connection status:', wsClient.getStatus());
// wsClient.disconnect();