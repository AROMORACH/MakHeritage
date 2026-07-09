const express = require('express');
const dotenv = require('dotenv');
const db = require('./db'); // Import the connection module

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

// API Endpoint to get all landmarks for Christian's frontend map
app.get('/api/landmarks', (req, res) => {
  const sql = 'SELECT * FROM landmarks';
  
  db.all(sql, [], (err, rows) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    res.json({
      message: "success",
      data: rows
    });
  });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});