const sqlite3 = require('sqlite3').verbose();
const path = require('path');

// Target the correct sqlite flat-file inside the database folder
const dbPath = path.resolve(__dirname, '../database/makheritage_db.sqlite');

const db = new sqlite3.Database(dbPath, sqlite3.OPEN_READWRITE, (err) => {
    if (err) {
        console.error('Error opening database:', err.message);
    } else {
        console.log('Connected to the MakHeritage SQLite database.');
    }
});

/**
 * Fetch all landmarks with optional category filtering
 */
const getLandmarks = (category, callback) => {
    db.all("PRAGMA table_info(landmarks)", (err, columns) => {
        if (err) return callback(err, null);
        const hasGeospatial = columns.some(col => col.name === 'latitude');

        let sql = hasGeospatial 
            ? 'SELECT id, name, description, category, latitude, longitude, image_url FROM landmarks'
            : 'SELECT id, name, description, category, 0.0 AS latitude, 0.0 AS longitude, "" AS image_url FROM landmarks';

        const params = [];
        if (category && category !== 'All') {
            sql += ' WHERE category = ?';
            params.push(category);
        }

        db.all(sql, params, callback);
    });
};

module.exports = {
    getLandmarks
};