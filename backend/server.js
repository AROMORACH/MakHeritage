const express = require('express');
const cors = require('cors');
const nodemailer = require('nodemailer');
const { getLandmarks, db } = require('./db'); 

const app = express();
const PORT = process.env.PORT || 3000;
const ADMIN_SECRET = "MAK2026"; // Secret code for admin verification

app.use(cors({
    origin: '*',
    methods: ['GET', 'POST'],
    allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json());

db.run(`CREATE TABLE IF NOT EXISTS otps (
    email TEXT PRIMARY KEY,
    code TEXT,
    expires_at INTEGER
)`);

// --- MAILTRAP TRANSPORTER ---
const transporter = nodemailer.createTransport({
    host: process.env.MAIL_HOST || 'sandbox.smtp.mailtrap.io',
    port: process.env.MAIL_PORT || 2525,
    auth: {
        user: process.env.MAIL_USER,
        pass: process.env.MAIL_PASS
    }
});

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

app.post('/api/landmarks', (req, res) => {
    const { name, category, description, latitude, longitude } = req.body;

    if (!name || !latitude || !longitude) {
        return res.status(400).json({ error: "Name, latitude, and longitude are required." });
    }

    const sql = `INSERT INTO landmarks (name, category, description, latitude, longitude) 
                    VALUES (?, ?, ?, ?, ?)`;
    const params = [name, category || 'Uncategorised', description || '', latitude, longitude];

    db.run(sql, params, function (err) {
        if (err) return res.status(500).json({ error: err.message });
        res.status(201).json({ message: "Landmark added successfully!", id: this.lastID });
    });
});

app.post('/api/admin/request-otp', (req, res) => {
    const { email } = req.body;
    const cleanEmail = email.trim().toLowerCase();
    
    const isAllowedDomain = cleanEmail.endsWith('@students.mak.ac.ug') || cleanEmail.endsWith('@mak.ac.ug');
    const isDevGmail = cleanEmail === 'joshuassenyonjo1@gmail.com'; 

    if (!isAllowedDomain && !isDevGmail) {
        return res.status(403).json({ error: "Unauthorised email domain. Must be a Makerere address." });
    }

    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = Date.now() + 5 * 60 * 1000; 

    db.run(
        `INSERT INTO otps (email, code, expires_at) VALUES (?, ?, ?) 
         ON CONFLICT(email) DO UPDATE SET code = excluded.code, expires_at = excluded.expires_at`,
        [email, otp, expiresAt],
        function(err) {
            if (err) return res.status(500).json({ error: "Database error" });

            const mailOptions = {
                from: '"MakHeritage Admin" <admin@makheritage.com>', 
                to: email,
                subject: 'MakHeritage Admin Login Code',
                text: `Your admin access code is: ${otp}. It expires in 5 minutes.`
            };

            transporter.sendMail(mailOptions, (error, info) => {
                if (error) {
                    console.error("NODEMAILER ERROR:", error); 
                    return res.status(500).json({ error: "Failed to send email" });
                }
                res.status(200).json({ message: "OTP sent successfully" });
            });
        }
    );
});

app.post('/api/admin/verify-otp', (req, res) => {
    const { email, code, secretCode } = req.body;

    if (secretCode !== MAK2026) {
        return res.status(403).json({ error: "Invalid admin secret code" });
    }

    db.get(`SELECT * FROM otps WHERE email = ?`, [email], (err, row) => {
        if (err) return res.status(500).json({ error: "Database error" });
        if (!row) return res.status(400).json({ error: "No OTP requested for this email" });
        if (Date.now() > row.expires_at) return res.status(400).json({ error: "OTP has expired" });
        if (row.code !== code) return res.status(400).json({ error: "Invalid OTP" });

        db.run(`DELETE FROM otps WHERE email = ?`, [email]);
        res.status(200).json({ message: "Verification successful. Admin authenticated." });
    });
});

app.get('/api/health', (req, res) => res.json({ status: 'API operational', timestamp: new Date() }));

app.listen(PORT, '0.0.0.0', () => console.log(`Server running on http://127.0.0.1:${PORT}`));