const fs = require('fs');
const path = require('path');
const sqlite3 = require('sqlite3').verbose();

const dbPath = path.resolve(__dirname, 'makheritage_db.sqlite');
const dataPath = path.resolve(__dirname, '../makheritage/assets/data/landmarks.json');

const db = new sqlite3.Database(dbPath, (err) => {
    if (err) return console.error('❌ Connection layer mapping failed:', err.message);
});

try {
    const rawData = fs.readFileSync(dataPath, 'utf8');
    const jsonData = JSON.parse(rawData);
    const landmarks = jsonData.Landmarks;

    if (!landmarks || !Array.isArray(landmarks)) {
        throw new Error('Invalid JSON formatting blueprint structure.');
    }

    db.serialize(() => {
        // Clear old records to prevent duplicate key constraint crashes
        db.run("DELETE FROM landmarks", (err) => {
            if (err) console.error('Error clearing stale database table fields:', err.message);
        });

        const stmt = db.prepare(`
            INSERT INTO landmarks (id, name, category, foundation_year, description) 
            VALUES (?, ?, ?, ?, ?)
        `);

        console.log(`Starting dynamic parsing execution for ${landmarks.length} entries...`);

        landmarks.forEach((site) => {
            stmt.run(site.id, site.name, site.category, site.foundation_year, site.description, (err) => {
                if (err) {
                    console.error(`❌ Check constraint rejection on: ${site.name} ->`, err.message);
                }
            });
        });

        stmt.finalize((err) => {
            if (err) {
                console.error('❌ Error finalizing transaction arrays:', err.message);
            } else {
                console.log('✔ Production seeder successfully injected all records into SQLite engine.');
            }
            db.close();
        });
    });

} catch (err) {
    console.error('❌ Critical seeding execution error:', err.message);
    db.close();
}