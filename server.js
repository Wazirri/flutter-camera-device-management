const express = require('express');
const app = express();
const port = 5000;

// Simple status route to check if server is running
app.get('/status', (req, res) => {
  res.json({ status: 'ok', message: 'Server is running properly' });
});

// Route to show the current issue
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
          <p>Current WebSocket configuration: Connects to <code>85.104.114.145:1200</code></p>
          <p>For more information, check the GitHub repository.</p>
        </div>
      </div>
    </body>
    </html>
  `);
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Server running at http://0.0.0.0:${port}`);
});