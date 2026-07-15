const express = require('express');
const cors = require('cors');
const { getLandmarks } = require('./db');

const app = express();
const PORT = process.env.PORT || 5000;

// Enable CORS so Christian's emulator can access endpoints across local origins
app.use(cors({
    origin: '*', // Allows access from any development browser or mobile simulator context
    methods: ['GET', 'POST'],
    allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json());

// Main entry route
app.get('/api/landmarks', (req, res) => {
    const { category, year } = req.query;

    getLandmarks(category, year, (err, rows) => {
        if (err) {
            console.error(err.message);
            return res.status(500).json({ error: 'Database query execution failed.' });
        }
        res.json(rows);
    });
});

// Health check route
app.get('/api/health', (req, res) => {
    res.json({ status: 'API operational', timestamp: new Date() });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on http://127.0.0.1:${PORT}`);
});