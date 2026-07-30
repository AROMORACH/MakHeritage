require('dotenv').config();
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
    // Extract 'year' from the Flutter payload
    const { name, category, description, latitude, longitude, year } = req.body;

    if (!name || !latitude || !longitude || !year) {
        return res.status(400).json({ error: "Name, latitude, longitude, and year are required." });
    }

    // Include foundation_year in the SQL query and mapping
    const sql = `INSERT INTO landmarks (name, category, description, latitude, longitude, foundation_year) 
                 VALUES (?, ?, ?, ?, ?, ?)`;
    const params = [name, category || 'Uncategorised', description || '', latitude, longitude, year];

    db.run(sql, params, function (err) {
        if (err) return res.status(500).json({ error: err.message });
        res.status(201).json({ message: "Landmark added successfully!", id: this.lastID });
    });
});

app.post('/api/admin/request-otp', (req, res) => {
    const { email } = req.body;
    if (!email) {
        return res.status(400).json({ error: "Email address is required." });
    }

    const cleanEmail = email.trim().toLowerCase();
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(cleanEmail)) {
        return res.status(400).json({ error: "Invalid email format." });
    }

    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = Date.now() + 5 * 60 * 1000; // 5 minutes

    db.run(
        `INSERT INTO otps (email, code, expires_at) VALUES (?, ?, ?) 
         ON CONFLICT(email) DO UPDATE SET code = excluded.code, expires_at = excluded.expires_at`,
        [cleanEmail, otp, expiresAt],
        function(err) {
            if (err) return res.status(500).json({ error: "Database error" });

            const pass = process.env.MAIL_PASS || '';
            const fromEmail = process.env.MAIL_FROM || '"MakHeritage Admin" <admin@makheritage.com>';
            const subject = 'MakHeritage Admin Login Code';
            const text = `Your 6-digit MakHeritage admin access code is: ${otp}. It expires in 5 minutes.`;

            // If using Resend API Key (starts with re_)
            if (pass.startsWith('re_')) {
                sendResendEmail(pass, fromEmail, cleanEmail, subject, text, (error, result) => {
                    if (error) {
                        console.error("RESEND API ERROR:", error.message);
                        return res.status(400).json({ error: error.message });
                    }
                    res.status(200).json({ message: "OTP sent successfully" });
                });
            } else {
                // Fallback to standard Nodemailer SMTP
                const mailOptions = { from: fromEmail, to: cleanEmail, subject, text };
                transporter.sendMail(mailOptions, (error, info) => {
                    if (error) {
                        console.error("NODEMAILER ERROR:", error);
                        return res.status(500).json({ error: "Failed to send email. Check SMTP credentials." });
                    }
                    res.status(200).json({ message: "OTP sent successfully" });
                });
            }
        }
    );
});

app.post('/api/admin/verify-otp', (req, res) => {
    const { email, code, secretCode } = req.body;

    if (secretCode !== "MAK2026") {
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

app.delete('/api/landmarks/:id', (req, res) => {
    db.run(`DELETE FROM landmarks WHERE id = ?`, req.params.id, function(err) {
        if (err) return res.status(500).json({ error: err.message });
        res.json({ message: "Landmark deleted successfully" });
    });
});

app.get('/api/health', (req, res) => res.json({ status: 'API operational', timestamp: new Date() }));

app.listen(PORT, '0.0.0.0', () => console.log(`Server running on http://127.0.0.1:${PORT}`));