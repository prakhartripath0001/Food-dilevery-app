const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const db = require("../config/database");
const { getJwtSecret, JWT_ISSUER, JWT_AUDIENCE } = require("../middlewares/auth.middleware");

function createToken(userId, secret) {
  return jwt.sign({ sub: String(userId) }, secret, {
    algorithm: "HS256",
    expiresIn: "7d",
    issuer: JWT_ISSUER,
    audience: JWT_AUDIENCE
  });
}

function invalidRequest(res, message) {
  return res.status(400).json({ success: false, message });
}

async function register(req, res, next) {
  const body = req.body && typeof req.body === "object" && !Array.isArray(req.body) ? req.body : {};
  const name = typeof body.name === "string" ? body.name.trim() : "";
  const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
  const password = typeof body.password === "string" ? body.password : "";

  if (!name || name.length > 100) {
    return invalidRequest(res, "name is required and must be at most 100 characters");
  }
  if (!email || email.length > 150 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return invalidRequest(res, "A valid email address is required");
  }
  if (password.length < 8 || Buffer.byteLength(password, "utf8") > 72) {
    return invalidRequest(res, "password must be at least 8 characters and at most 72 bytes");
  }

  let secret;
  try {
    secret = getJwtSecret();
  } catch (error) {
    return next(error);
  }

  try {
    const [existingUsers] = await db.query("SELECT id FROM users WHERE email = ?", [email]);
    if (existingUsers.length > 0) {
      return res.status(409).json({ success: false, message: "An account with this email already exists" });
    }

    const passwordHash = await bcrypt.hash(password, 12);
    const [result] = await db.query(
      "INSERT INTO users (name, email, password) VALUES (?, ?, ?)",
      [name, email, passwordHash]
    );
    const user = { id: result.insertId, name, email };

    return res.status(201).json({
      success: true,
      message: "Account created successfully",
      data: { ...user, token: createToken(user.id, secret) }
    });
  } catch (error) {
    if (error.code === "ER_DUP_ENTRY") {
      return res.status(409).json({ success: false, message: "An account with this email already exists" });
    }
    return next(error);
  }
}

async function login(req, res, next) {
  const body = req.body && typeof req.body === "object" && !Array.isArray(req.body) ? req.body : {};
  const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
  const password = typeof body.password === "string" ? body.password : "";

  if (!email || !password) {
    return invalidRequest(res, "email and password are required");
  }

  let secret;
  try {
    secret = getJwtSecret();
  } catch (error) {
    return next(error);
  }

  try {
    const [users] = await db.query(
      "SELECT id, name, email, password FROM users WHERE email = ?",
      [email]
    );
    const user = users[0];
    if (!user || !(await bcrypt.compare(password, user.password))) {
      return res.status(401).json({ success: false, message: "Email or password is incorrect" });
    }

    return res.json({
      success: true,
      message: "Logged in successfully",
      data: {
        id: user.id,
        name: user.name,
        email: user.email,
        token: createToken(user.id, secret)
      }
    });
  } catch (error) {
    return next(error);
  }
}

module.exports = { register, login };
