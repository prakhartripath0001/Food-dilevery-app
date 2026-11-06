const jwt = require("jsonwebtoken");
const db = require("../config/database");

const JWT_ISSUER = "food-delivery-api";
const JWT_AUDIENCE = "food-delivery-app";

function getJwtSecret() {
  const secret = process.env.JWT_SECRET;
  if (!secret || secret.length < 32) {
    const error = new Error("JWT_SECRET must be configured with at least 32 characters");
    error.statusCode = 500;
    throw error;
  }
  return secret;
}

async function authenticate(req, res, next) {
  const authorization = req.get("authorization");
  const match = authorization && authorization.match(/^Bearer ([^\s]+)$/i);

  if (!match) {
    return res.status(401).json({
      success: false,
      message: "A valid bearer token is required"
    });
  }

  let payload;
  try {
    payload = jwt.verify(match[1], getJwtSecret(), {
      algorithms: ["HS256"],
      issuer: JWT_ISSUER,
      audience: JWT_AUDIENCE
    });
  } catch (error) {
    if (error.name === "TokenExpiredError" || error.name === "JsonWebTokenError") {
      return res.status(401).json({
        success: false,
        message: "The bearer token is invalid or expired"
      });
    }
    return next(error);
  }

  const userId = Number(payload.sub);
  if (!Number.isSafeInteger(userId) || userId < 1) {
    return res.status(401).json({
      success: false,
      message: "The bearer token is invalid or expired"
    });
  }

  try {
    const [users] = await db.query("SELECT id, role FROM users WHERE id = ?", [userId]);
    if (users.length === 0) {
      return res.status(401).json({
        success: false,
        message: "The bearer token is invalid or expired"
      });
    }

    req.user = { id: users[0].id, role: users[0].role };
    return next();
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  authenticate,
  getJwtSecret,
  JWT_ISSUER,
  JWT_AUDIENCE
};
