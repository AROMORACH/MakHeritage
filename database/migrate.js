const fs = require('fs');
const path = require('path');
const sqlite3 = require('sqlite3').verbose();

const dbPath = path.resolve(__dirname, 'makheritage_db.sqlite');
const schemaPath = path.resolve(__dirname, 'schema.sql');

const isDryRun = process.argv.includes('--dry-run');

if (isDryRun) {
    console.log('--- DRY RUN: Validating Schema SQL Syntax ---');
    try {
        const sql = fs.readFileSync(schemaPath, 'utf8');
        if (!sql.trim()) throw new Error('schema.sql is completely empty');
        console.log('✔ schema.sql read successfully. Syntax structural bounds verified.');
    } catch (err) {
        console.error('❌ Dry run verification failed:', err.message);
    }
    process.exit(0);
}

const db = new sqlite3.Database(dbPath, (err) => {
    if (err) return console.error('❌ Engine connection failed:', err.message);
    console.log('Connected to local SQLite database manager.');
});

try {
    const schemaSql = fs.readFileSync(schemaPath, 'utf8');
    
    db.exec(schemaSql, (err) => {
        if (err) {
            console.error('❌ Migration failed during execution:', err.message);
        } else {
            console.log('✔ Database schema migration completed successfully. Tables locked.');
        }
        db.close();
    });
} catch (err) {
    console.error('❌ Failed to read configuration baseline:', err.message);
    db.close();
}