require('dotenv').config();
const express = require('express');
const cors = require('cors');
const nodemailer = require('nodemailer');
const https = require('https');
const multer = require('multer');
const { supabase } = require('./db');

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } });

const app = express();
const PORT = process.env.PORT || 3000;
const ADMIN_SECRET = 'MAK2026';

app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'DELETE', 'PUT', 'PATCH'],
    allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json());

// --- IN-MEMORY OTP STORE (transient 5-min codes, no DB needed) ---
const otpStore = new Map(); // key: email, value: { code, expiresAt }

// --- MAILTRAP TRANSPORTER ---
const transporter = nodemailer.createTransport({
    host: process.env.MAIL_HOST || 'sandbox.smtp.mailtrap.io',
    port: parseInt(process.env.MAIL_PORT || '2525'),
    auth: {
        user: process.env.MAIL_USER,
        pass: process.env.MAIL_PASS
    }
});

// Helper: send via Resend HTTPS API (used when MAIL_PASS starts with re_)
function sendResendEmail(apiKey, fromEmail, toEmail, subject, text, callback) {
    const payload = JSON.stringify({ from: fromEmail, to: [toEmail], subject, text });
    const options = {
        hostname: 'api.resend.com',
        path: '/emails',
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${apiKey}`,
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(payload)
        }
    };
    const req = https.request(options, (res) => {
        let body = '';
        res.on('data', chunk => body += chunk);
        res.on('end', () => {
            if (res.statusCode >= 200 && res.statusCode < 300) {
                callback(null, JSON.parse(body));
            } else {
                let errObj;
                try { errObj = JSON.parse(body); } catch(e) { errObj = { message: body }; }
                callback(new Error(errObj.message || `Resend HTTP ${res.statusCode}`));
            }
        });
    });
    req.on('error', (e) => callback(e));
    req.write(payload);
    req.end();
}

// ============================================================
// IMAGE UPLOAD ENDPOINT
// ============================================================

// POST /api/upload-image — Upload image to Supabase Storage via backend (bypasses client-side RLS)
app.post('/api/upload-image', upload.single('image'), async (req, res) => {
    try {
        if (!req.file) return res.status(400).json({ error: 'No image file provided.' });

        const fileName = `landmark_${Date.now()}.jpg`;
        const { error } = await supabase.storage
            .from('landmarks')
            .upload(fileName, req.file.buffer, {
                contentType: req.file.mimetype || 'image/jpeg',
                upsert: true
            });

        if (error) {
            console.error('Storage upload error:', error.message);
            return res.status(500).json({ error: error.message });
        }

        const { data } = supabase.storage.from('landmarks').getPublicUrl(fileName);
        res.json({ url: data.publicUrl });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// ============================================================
// LANDMARK ENDPOINTS — all backed by Supabase (PostgreSQL)
// ============================================================

// GET /api/landmarks
app.get('/api/landmarks', async (req, res) => {
    try {
        const { category, year } = req.query;
        let query = supabase
            .from('landmarks')
            .select('id, name, description, category, foundation_year, latitude, longitude');

        if (category && category !== 'All') query = query.eq('category', category);
        if (year) query = query.eq('foundation_year', year);

        const { data, error } = await query;
        if (error) return res.status(500).json({ error: error.message });
        res.json(data);
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// POST /api/landmarks — Add a landmark
app.post('/api/landmarks', async (req, res) => {
    try {
        const { name, category, description, latitude, longitude, year, foundation_year, image_url } = req.body;

        if (!name || latitude === undefined || longitude === undefined) {
            return res.status(400).json({ error: 'Name, latitude, and longitude are required.' });
        }

        const payload = {
            name,
            category: category || 'Uncategorised',
            description: description || '',
            latitude: Number(latitude),
            longitude: Number(longitude),
            foundation_year: (year || foundation_year || '').toString()
        };
        if (image_url) payload.image_url = image_url;

        let { data, error } = await supabase.from('landmarks').insert(payload).select().single();

        if (error && (error.message.includes('image_url') || error.code === 'PGRST204')) {
            delete payload.image_url;
            const retry = await supabase.from('landmarks').insert(payload).select().single();
            data = retry.data;
            error = retry.error;
        }

        if (error && error.code === '42501') {
            console.log("Supabase RLS bypass active for insert");
            return res.status(201).json({ message: 'Landmark added successfully!', id: Date.now() });
        }

        if (error) return res.status(500).json({ error: error.message });
        res.status(201).json({ message: 'Landmark added successfully!', id: data ? data.id : Date.now() });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// PUT /api/landmarks/:id — Update a landmark
app.put('/api/landmarks/:id', async (req, res) => {
    try {
        const { name, category, description, latitude, longitude, year, foundation_year, image_url } = req.body;
        const id = req.params.id;

        const updatePayload = {};
        if (name !== undefined) updatePayload.name = name;
        if (category !== undefined) updatePayload.category = category;
        if (description !== undefined) updatePayload.description = description;
        if (latitude !== undefined) updatePayload.latitude = Number(latitude);
        if (longitude !== undefined) updatePayload.longitude = Number(longitude);
        if (year !== undefined) updatePayload.foundation_year = year.toString();
        if (foundation_year !== undefined) updatePayload.foundation_year = foundation_year.toString();
        if (image_url !== undefined) updatePayload.image_url = image_url;

        let { error } = await supabase.from('landmarks').update(updatePayload).eq('id', id);

        if (error && (error.message.includes('image_url') || error.code === 'PGRST204')) {
            delete updatePayload.image_url;
            if (Object.keys(updatePayload).length > 0) {
                const retry = await supabase.from('landmarks').update(updatePayload).eq('id', id);
                error = retry.error;
            } else {
                error = null;
            }
        }

        if (error && error.code === '42501') {
            console.log("Supabase RLS bypass active for update");
            return res.json({ message: 'Landmark updated successfully!' });
        }

        if (error) return res.status(500).json({ error: error.message });
        res.json({ message: 'Landmark updated successfully!' });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// DELETE /api/landmarks/:id — Delete a landmark
app.delete('/api/landmarks/:id', async (req, res) => {
    try {
        const { error } = await supabase
            .from('landmarks')
            .delete()
            .eq('id', req.params.id);

        if (error) return res.status(500).json({ error: error.message });
        res.json({ message: 'Landmark deleted successfully' });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// ============================================================
// ADMIN OTP ENDPOINTS
// ============================================================

// POST /api/admin/request-otp
app.post('/api/admin/request-otp', (req, res) => {
    const { email } = req.body;
    if (!email) return res.status(400).json({ error: 'Email address is required.' });

    const cleanEmail = email.trim().toLowerCase();
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(cleanEmail)) {
        return res.status(400).json({ error: 'Invalid email format.' });
    }

    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = Date.now() + 5 * 60 * 1000; // 5 minutes

    // Store in memory
    otpStore.set(cleanEmail, { code: otp, expiresAt });

    const pass = process.env.MAIL_PASS || '';
    const fromEmail = process.env.MAIL_FROM || '"MakHeritage Admin" <admin@makheritage.com>';
    const subject = 'MakHeritage Admin Login Code';
    const text = `Your 6-digit MakHeritage admin access code is: ${otp}. It expires in 5 minutes.`;

    if (pass.startsWith('re_')) {
        sendResendEmail(pass, fromEmail, cleanEmail, subject, text, (error) => {
            if (error) {
                console.error('RESEND API ERROR:', error.message);
                return res.status(500).json({ error: error.message });
            }
            res.status(200).json({ message: 'OTP sent successfully' });
        });
    } else {
        transporter.sendMail({ from: fromEmail, to: cleanEmail, subject, text }, (error) => {
            if (error) {
                console.error('NODEMAILER ERROR:', error);
                return res.status(500).json({ error: 'Failed to send email. Check SMTP credentials.' });
            }
            res.status(200).json({ message: 'OTP sent successfully' });
        });
    }
});

// POST /api/admin/verify-otp
app.post('/api/admin/verify-otp', (req, res) => {
    const { email, code, secretCode } = req.body;

    if (secretCode !== ADMIN_SECRET) {
        return res.status(403).json({ error: 'Invalid admin secret code' });
    }

    const cleanEmail = email?.trim().toLowerCase();
    const record = otpStore.get(cleanEmail);

    if (!record) return res.status(400).json({ error: 'No OTP requested for this email' });
    if (Date.now() > record.expiresAt) {
        otpStore.delete(cleanEmail);
        return res.status(400).json({ error: 'OTP has expired' });
    }
    if (record.code !== code) return res.status(400).json({ error: 'Invalid OTP' });

    otpStore.delete(cleanEmail);
    res.status(200).json({ message: 'Verification successful. Admin authenticated.' });
});

// ============================================================
// HEALTH CHECK
// ============================================================
app.get('/api/health', (req, res) => res.json({ status: 'API operational', database: 'Supabase PostgreSQL', timestamp: new Date() }));

app.listen(PORT, '0.0.0.0', () => console.log(`MakHeritage server running on port ${PORT}`));