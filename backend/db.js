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
    let sql = 'SELECT id, name, description, category, latitude, longitude, image_url FROM landmarks';
    const params = [];

    if (category) {
        sql += ' WHERE category = ?';
        params.push(category);
    }

    db.all(sql, params, (err, rows) => {
        callback(err, rows);
    });
};

module.exports = {
    getLandmarks
};