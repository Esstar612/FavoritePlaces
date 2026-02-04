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

if (process.env.FIREBASE_CONFIG) {
  // Cloud Run deployment: service account JSON in env var
  serviceAccount = JSON.parse(process.env.FIREBASE_CONFIG);
} else if (process.env.FIREBASE_SERVICE_ACCOUNT_PATH) {
  // Local development: load from file
  serviceAccount = await import(process.env.FIREBASE_SERVICE_ACCOUNT_PATH, {
    with: { type: 'json' }
  }).then(m => m.default);
} else {
  console.error('❌ No Firebase credentials found. Set FIREBASE_SERVICE_ACCOUNT_PATH or FIREBASE_CONFIG');
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
const PORT = process.env.PORT || 3000;

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
const corsOptions = {
  origin: process.env.CORS_ORIGIN === '*' 
    ? '*' 
    : process.env.CORS_ORIGIN?.split(',').map(o => o.trim()),
  credentials: true,
};
app.use(cors(corsOptions));

// Rate limiting
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000, // 15 minutes
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100,
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/ai/', limiter); // Apply only to AI routes

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