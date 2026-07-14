const sqlite3 = require('sqlite3').verbose();
const path = require('path');

// Connect to our database file
const dbPath = path.join(__dirname, 'makheritage_db.sqlite');
const db = new sqlite3.Database(dbPath);

// Sample landmarks data with latitude and longitude (specifically for Makerere University)
const landmarks = [
  {
    name: "Main Building",
    description: "The iconic administrative block of Makerere University, built in 1941.",
    location: "Main Campus, Kampala",
    latitude: 0.3349,
    longitude: 32.5684
  },
  {
    name: "Mary Stuart Hall",
    description: "The first female hall of residence, known for its rich history and vibrant community.",
    location: "Main Campus, Kampala",
    latitude: 0.3312,
    longitude: 32.5651
  },
  {
    name: "Freedom Square",
    description: "The large open green field at the heart of the university used for graduation and key events.",
    location: "Main Campus, Kampala",
    latitude: 0.3345,
    longitude: 32.5678
  }
];

db.serialize(() => {
  console.log("Preparing to insert landmark data...");

  // Let's make sure the table exists, just in case
  db.run(`CREATE TABLE IF NOT EXISTS landmarks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    location TEXT,
    latitude REAL,
    longitude REAL
  );`);

  // Insert each landmark with coordinates
  const stmt = db.prepare(`INSERT INTO landmarks (name, description, location, latitude, longitude) VALUES (?, ?, ?, ?, ?)`);
  
  landmarks.forEach((landmark) => {
    stmt.run(landmark.name, landmark.description, landmark.location, landmark.latitude, landmark.longitude, (err) => {
      if (err) {
        console.error(`Error inserting ${landmark.name}:`, err.message);
      } else {
        console.log(`Successfully added landmark: ${landmark.name}`);
      }
    });
  });

  stmt.finalize();
});

db.close((err) => {
  if (err) {
    console.error("Error closing database:", err.message);
  } else {
    console.log("Seeding complete! Database closed safely.");
  }
});