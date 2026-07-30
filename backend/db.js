require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

// Polyfill WebSocket for Node.js < 22 (Render uses Node 20 by default)
if (!globalThis.WebSocket) {
    globalThis.WebSocket = require('ws');
}

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
    console.error('Missing SUPABASE_URL or SUPABASE_ANON_KEY environment variables.');
    process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

console.log('Connected to Supabase (PostgreSQL).');

module.exports = { supabase };