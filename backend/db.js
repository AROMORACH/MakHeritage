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
const getLandmarks = (category, year, callback) => {
    db.all("PRAGMA table_info(landmarks)", (err, columns) => {
        if (err) return callback(err, null);
        const hasGeospatial = columns.some(col => col.name === 'latitude');

        let sql = hasGeospatial 
            ? 'SELECT id, name, description, category, foundation_year, latitude, longitude, image_url FROM landmarks WHERE 1=1'
            : 'SELECT id, name, description, category, foundation_year, 0.0 AS latitude, 0.0 AS longitude, "" AS image_url FROM landmarks WHERE 1=1';

        const params = [];
        if (category && category !== 'All') {
            sql += ' AND category = ?';
            params.push(category);
        }
        if (year) {
            sql += ' AND foundation_year = ?';
            params.push(year);
        }

        db.all(sql, params, callback);
    });
};

module.exports = { db, getLandmarks };