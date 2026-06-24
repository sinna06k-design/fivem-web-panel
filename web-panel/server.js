const express = require('express');
const path = require('path');
const app = express();
const portStr = process.env.PORT || '3000';
const PORT = parseInt(portStr, 10) || 3000;

// Serve static files from the current directory
app.use(express.static(__dirname));

// Direct all requests to index.html
app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, 'index.html'));
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server is running on port ${PORT}`);
});
