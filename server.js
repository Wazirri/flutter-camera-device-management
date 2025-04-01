const express = require('express');
const path = require('path');
const app = express();
const PORT = 5000;

// Serve static files from the 'build/web' directory
app.use(express.static(path.join(__dirname, 'build/web')));

// For any other request, send the index.html file
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'build/web/index.html'));
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server is running on http://0.0.0.0:${PORT}`);
});