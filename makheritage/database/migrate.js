const sqlite3 = require('sqlite3').verbose();
const path = require('path');

// Connect to our database file
const dbPath = path.join(__dirname, 'makheritage_db.sqlite');
const db = new sqlite3.Database(dbPath);

db.serialize(() => {
  console.log("Starting database migration...");

  // Add the latitude column
  db.run(`ALTER TABLE landmarks ADD COLUMN latitude REAL;`, (err) => {
    if (err) {
      if (err.message.includes("duplicate column name")) {
        console.log("Latitude column already exists!");
      } else {
        console.error("Error adding latitude:", err.message);
      }
    } else {
      console.log("Successfully added latitude column!");
    }
  });

  // Add the longitude column
  db.run(`ALTER TABLE landmarks ADD COLUMN longitude REAL;`, (err) => {
    if (err) {
      if (err.message.includes("duplicate column name")) {
        console.log("Longitude column already exists!");
      } else {
        console.error("Error adding longitude:", err.message);
      }
    } else {
      console.log("Successfully added longitude column!");
    }
  });
});

db.close((err) => {
  if (err) {
    console.error("Error closing database:", err.message);
  } else {
    console.log("Migration complete! Database closed safely.");
  }
});