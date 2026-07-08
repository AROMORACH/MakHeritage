const sqlite3 = require('sqlite3').verbose();
const path = require('path');

// Point directly to the database folder in the root directory
const dbPath = path.resolve(__dirname, '../database/makheritage_db.sqlite');

const db = new sqlite3.Database(dbPath, (err) => {
  if (err) {
    console.error('Error connecting to the local database:', err.message);
  } else {
    console.log('Connected to the MakHeritage SQLite database.');
  }
});

module.exports = db;