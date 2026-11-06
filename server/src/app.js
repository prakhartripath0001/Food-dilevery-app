const express = require("express");
const cors = require("cors");
require("dotenv").config();

const db = require("./config/database");
const errorHandler = require("./middlewares/error.middleware");

// Routes
const categoryRoutes = require("./routes/category.routes");
const restaurantRoutes = require("./routes/restaurant.routes");
const orderRoutes = require("./routes/order.routes");

const app = express();

app.use(cors());
app.use(express.json());

// Health check endpoints
app.get("/", (req, res) => {
  res.json({ message: "Backend is running!" });
});

app.get("/api/health", (req, res) => {
  res.json({
    success: true,
    message: "Flutter connected to Express!"
  });
});

app.get("/health", async (req, res) => {
  try {
    await db.query("SELECT 1");
    res.json({
      status: "OK",
      database: "Connected"
    });
  } catch (error) {
    res.status(500).json({
      status: "ERROR",
      message: error.message
    });
  }
});

// API Routes
app.use("/api/categories", categoryRoutes);
app.use("/api/restaurants", restaurantRoutes);
app.use("/api/orders", orderRoutes);

// Centralized error handler
app.use(errorHandler);

const PORT = process.env.PORT || 5001;

app.listen(PORT, "0.0.0.0", async () => {
  console.log(`Server running on http://localhost:${PORT}`);
  try {
    const connection = await db.getConnection();
    console.log("Connected to MySQL database successfully!");
    connection.release();
  } catch (err) {
    console.error("Failed to connect to MySQL database:", err.message);
  }
});
