import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import dotenv from 'dotenv';
import admin from 'firebase-admin';

// Load environment variables
dotenv.config();

// ═══════════════════════════════════════════════════════════════════════════
// FIREBASE ADMIN INITIALIZATION
// ═══════════════════════════════════════════════════════════════════════════
let serviceAccount;

if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
  // Cloud Run deployment: service account JSON in env var
  serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
} else if (process.env.FIREBASE_SERVICE_ACCOUNT_PATH) {
  // Local development: load from file
  serviceAccount = await import(process.env.FIREBASE_SERVICE_ACCOUNT_PATH, {
    with: { type: 'json' }
  }).then(m => m.default);
} else {
  console.error('❌ No Firebase credentials found. Set FIREBASE_SERVICE_ACCOUNT_PATH or FIREBASE_SERVICE_ACCOUNT_JSON');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

console.log('✅ Firebase Admin initialized');

// ═══════════════════════════════════════════════════════════════════════════
// EXPRESS APP SETUP
// ═══════════════════════════════════════════════════════════════════════════
const app = express();
const PORT = process.env.PORT || 8080;

// Cloud Run terminates TLS at a front-end proxy, so req.ip is the proxy's
// address unless we trust one hop of X-Forwarded-For.  Without this the rate
// limiters below key every caller to the same bucket.
app.set('trust proxy', 1);

// ═══════════════════════════════════════════════════════════════════════════
// IMPORT ROUTES (AFTER FIREBASE INITIALIZATION)
// ═══════════════════════════════════════════════════════════════════════════
// These must be imported AFTER Firebase Admin is initialized
// because they use admin.firestore() and admin.auth()
const { default: aiRoutes } = await import('./routes/ai.js');
const { default: userRoutes } = await import('./routes/user.js');

// ───────────────────────────────────────────────────────────────────────────
// Middleware
// ───────────────────────────────────────────────────────────────────────────
app.use(helmet()); // Security headers
app.use(compression()); // Compress responses
app.use(express.json({ limit: '10mb' })); // Parse JSON bodies

// CORS configuration
// No `credentials` — clients authenticate with a Bearer header, not cookies, and
// browsers reject `credentials: true` combined with a wildcard origin outright.
const corsOptions = {
  origin: process.env.CORS_ORIGIN === '*'
    ? '*'
    : process.env.CORS_ORIGIN?.split(',').map(o => o.trim()),
};
app.use(cors(corsOptions));

// ───────────────────────────────────────────────────────────────────────────
// Rate limiting
// ───────────────────────────────────────────────────────────────────────────
const windowMs = parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000; // 15 minutes
const maxRequests = parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100;

// AI routes: every request costs a Gemini call.
const aiLimiter = rateLimit({
  windowMs,
  max: maxRequests,
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/ai/', aiLimiter);

// User routes: cheaper than Gemini, but /user/stats and /user/export each scan
// the caller's whole places collection, so they still need a ceiling.
const userLimiter = rateLimit({
  windowMs,
  max: maxRequests * 5,
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/user/', userLimiter);

// ───────────────────────────────────────────────────────────────────────────
// Authentication Middleware
// ───────────────────────────────────────────────────────────────────────────
/**
 * Verifies Firebase ID token from Authorization header.
 * Attaches decoded token to req.user
 */
async function authenticateUser(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader?.startsWith('Bearer ')) {
      return res.status(401).json({ 
        error: 'Unauthorized', 
        message: 'Missing or invalid Authorization header' 
      });
    }

    const token = authHeader.substring(7);
    const decodedToken = await admin.auth().verifyIdToken(token);
    
    req.user = decodedToken; // { uid, email, ... }
    next();
  } catch (error) {
    console.error('Auth error:', error.message);
    return res.status(401).json({ 
      error: 'Unauthorized', 
      message: 'Invalid or expired token' 
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ROUTES
// ═══════════════════════════════════════════════════════════════════════════

// ───────────────────────────────────────────────────────────────────────────
// Health check
// ───────────────────────────────────────────────────────────────────────────
app.get('/', (req, res) => {
  res.json({ 
    status: 'ok',
    service: 'Favorite Places Backend',
    version: '1.0.0',
    timestamp: new Date().toISOString()
  });
});

app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy',
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  });
});

// ───────────────────────────────────────────────────────────────────────────
// Routes
// ───────────────────────────────────────────────────────────────────────────
app.use('/ai', authenticateUser, aiRoutes);
app.use('/user', authenticateUser, userRoutes);

// ───────────────────────────────────────────────────────────────────────────
// 404 handler
// ───────────────────────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ 
    error: 'Not Found',
    message: `Route ${req.method} ${req.path} not found`
  });
});

// ───────────────────────────────────────────────────────────────────────────
// Error handler
// ───────────────────────────────────────────────────────────────────────────
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  
  res.status(err.status || 500).json({ 
    error: 'Internal Server Error',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
});

// ═══════════════════════════════════════════════════════════════════════════
// START SERVER
// ═══════════════════════════════════════════════════════════════════════════
app.listen(PORT, () => {
  console.log(`
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   🚀 Favorite Places Backend Server                          ║
║                                                               ║
║   Status:  ✅ Running                                        ║
║   Port:    ${PORT}                                             ║
║   Env:     ${process.env.NODE_ENV || 'development'}                                  ║
║   Time:    ${new Date().toISOString()}               ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
  `);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully...');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully...');
  process.exit(0);
});